local mod,shared=...
local Pokemon=require("src.core.game3.pokemon")
local Dex=require("src.core.game3.dex")
local Encounters=require("src.core.game3.encounters")
local Items=require("src.core.game3.items_data")
local Rng=require("src.core.game3.rng")
local Profile=require("src.core.game3.profile")
local function session()return shared.gen3Session()end
local function allowed()return shared.gameplayAllowed()and not shared.gen3Flying end
function shared.gen3CollectionLimit()
  local s=session()
  if Profile.family(s)=="frlg"and not require("src.core.game3.pokedex_data").isNationalUnlocked(s)then return 151 end
  return 386
end
function shared.gen3CollectionAllows(species)
  local n=Pokemon.national(species)
  return n and n>0 and n<=shared.gen3CollectionLimit()or false
end
function shared.gen3CollectionSpecies()
  local list={}
  for n=1,shared.gen3CollectionLimit()do
    local sp=Pokemon.speciesFromNational(n);if sp then list[#list+1]=sp end
  end
  return list
end
function shared.gen3Owned(species)
  local s=session();return s and s.dex and Dex.isCaught(s.dex,species)or false
end
function shared.gen3Uncaught()
  local list={}
  for _,sp in ipairs(shared.gen3CollectionSpecies())do
    if not shared.gen3Owned(sp)then list[#list+1]=sp end
  end
  return list
end
local nativeRoot,nativePresent
local function presentSpecies()
  Encounters.ensureLoaded()
  if nativeRoot==Encounters._tables and nativePresent then return nativePresent end
  nativeRoot,nativePresent=Encounters._tables,{}
  local visited={}
  local function scan(t)
    if type(t)~="table"or visited[t]then return end
    visited[t]=true
    if t.species then
      local n=Pokemon.national(tonumber(t.species)or Pokemon.speciesFromName(t.species))
      if n then nativePresent[n]=true end
    end
    for _,v in pairs(t)do if type(v)=="table"then scan(v)end end
  end
  for map in pairs(nativeRoot or {})do scan(Encounters.tableFor(map))end
  return nativePresent
end
local function currentTerrain()
  return require("src.core.game3.player").surfing and "water"or"land"
end
function shared.gen3AreaRows(terrain,map)
  local s=session();terrain=terrain or currentTerrain();map=map or(s and s.map)
  if terrain~="land"and terrain~="water"then return {}end
  local t=map and Encounters.tableFor(map)
  local group=t and(t[terrain]or(terrain=="land"and t.grass))
  if not group or not group.slots then return {}end
  local rows={}
  for _,slot in ipairs(group.slots)do
    local sp=tonumber(slot.species)or Pokemon.speciesFromName(slot.species)
    if sp and shared.gen3CollectionAllows(sp)then
      rows[#rows+1]={species=sp,minLevel=slot.minLevel or slot.level or 2,
        maxLevel=slot.maxLevel or slot.level or slot.minLevel or 2}
    end
  end
  local family=Profile.family(s)
  local present=presentSpecies()
  local added=shared.collectionAddedSpecies(family,map,terrain,present,shared.gen3CollectionLimit())
  for _,nat in ipairs(added)do
    local h=shared.collectionHomes[family][nat]
    local sp=Pokemon.speciesFromNational(nat)
    if sp then rows[#rows+1]={species=sp,minLevel=h.minLevel,maxLevel=h.maxLevel,added=true}end
  end
  return rows
end
function shared.gen3LocalSpecies(uncaught)
  local list,seen={},{}
  for _,row in ipairs(shared.gen3AreaRows())do
    if not seen[row.species]and(not uncaught or not shared.gen3Owned(row.species))then
      seen[row.species]=true;list[#list+1]=row.species
    end
  end
  table.sort(list,function(a,b)return Pokemon.national(a)<Pokemon.national(b)end)
  return list
end
local function choose(rows,uncaught,onlyAdded,species)
  local choices={}
  for _,row in ipairs(rows)do
    if(not uncaught or not shared.gen3Owned(row.species))
      and(not onlyAdded or row.added)and(not species or row.species==species)then
      choices[#choices+1]=row
    end
  end
  if #choices==0 then return end
  return choices[Rng.Random()%#choices+1]
end
local function encounter(row)
  local low=math.max(1,math.floor(row.minLevel or 2))
  local high=math.max(low,math.min(100,math.floor(row.maxLevel or low)))
  return {species=Pokemon.keyName(row.species),speciesId=row.species,
    level=low+(high>low and Rng.Random()%(high-low+1)or 0)}
end
local function specialArea()
  local s=session()
  if not s then return true end
  if(s.safari and s.safari.active)or require("src.core.game3.safari").isActive(s)then return true end
  local id=tostring(s.map or "")
  return id:find("SAFARI",1,true)or id:find("BATTLE_",1,true)
end
-- New regional species participate in ordinary encounters after the native
-- unlock. Dex Hunt prefers an uncaught LOCAL species every time, with no timer.
mod.hooks:wrap("encounter.species",function(next,original,ctx)
  local enc=next(original,ctx)
  if not enc or enc.roamer or not allowed()or specialArea()then return enc end
  local rows=shared.gen3AreaRows(ctx and ctx.terrain,ctx and ctx.mapId)
  local picked
  if shared.bool("gen3_dex_hunt",true)then picked=choose(rows,true)end
  if not picked and Rng.Random()%100<30 then picked=choose(rows,false,true)end
  return picked and encounter(picked)or enc
end)
local function startWild(species,level)
  local s=session()
  if not s or not allowed()or not shared.gen3CollectionAllows(species)or specialArea()
      or require("src.core.game3.battle").isActive()
      or require("src.core.game3.player").moving then return false end
  local healthy
  for _,mon in ipairs(s.party or {})do
    if not mon.isEgg and (tonumber(mon.hp)or 0)>0 then healthy=mon;break end
  end
  if not healthy then shared.gen3Message("Your party cannot battle.");return false end
  -- Close only our menu and the native Start menu, not an unrelated UI stack.
  require("src.ui.game3.stack").pop("silvershadow_gen3")
  require("src.ui.game3.start_menu").close(true)
  local Runtime=require("src.core.game3.runtime")
  local ok,err=require("src.core.game3.battle_bridge").startWild(Runtime._mod,shared.game,
    {species=species,level=math.max(1,math.min(100,level or healthy.level or 5))},{})
  if not ok then shared.gen3Message("Cannot start this encounter: "..tostring(err));return false end
  return true
end
function shared.gen3Summon(species)return startWild(species)end
function shared.gen3DexNav(species,silent)
  if not allowed()then return false end
  local rows=shared.gen3AreaRows()
  local row=choose(rows,not species,false,species)
  if not row then
    if not silent then shared.gen3Message(#rows>0 and "All Pokemon in this area are caught."
      or "No wild Pokemon found here.")end
    return false
  end
  return startWild(row.species,encounter(row).level)
end

-- Native evolution scenes retain Everstone, cancellation, the FRLG National
-- Dex gate, naming and stat updates. Only the trade condition is replaced.
mod.hooks:wrap("evolution.check", function(next, game, mon, evo, ctx)
  local result = next(game, mon, evo, ctx)
  if result or not shared.gameplayAllowed() or not shared.bool("gen3_no_trade", true)
      or not ctx or ctx.kind ~= "levelup" then return result end
  local method = tonumber(evo.methodId or evo.method)
  local level = tonumber(mon.level) or 1
  if method == 5 then
    local machoke = Pokemon.speciesFromNational(67)
    return level >= (Pokemon.speciesOf(mon) == machoke and 45 or 42)
  elseif method == 6 then
    local held = Items.toNumericId(mon.item or mon.heldItem) or 0
    return level >= 40 and held ~= 0 and held == tonumber(evo.param)
  end
  return result
end)
mod.events:on("pokemon.evolved", function(e)
  if not e or not e.mon or not shared.gameplayAllowed() or not shared.bool("gen3_no_trade", true) then return end
  local held = Items.toNumericId(e.mon.item or e.mon.heldItem) or 0
  for _, row in ipairs(Pokemon.evolutions(e.fromSpeciesId)) do
    if tonumber(row.method or row[1]) == 6 and tonumber(row.target or row[3]) == e.toSpeciesId
        and held ~= 0 and held == tonumber(row.param or row[2]) then
      e.mon.item, e.mon.heldItem = 0, 0
    end
  end
end)
