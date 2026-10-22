local mod, shared = ...
local P=require("src.core.game3.pokemon")
local Types=require("src.core.game3.battle.types")
local Effects=require("src.core.game3.battle.effect_ids")
local names={};for name,id in pairs(Effects) do if type(id)=="number" then names[id]=name end end
local M={}
local groups={
  physical={"NORMAL","FIGHTING","FLYING","POISON","GROUND","ROCK","BUG","GHOST","STEEL"},
  special={"FIRE","WATER","GRASS","ELECTRIC","PSYCHIC","ICE","DRAGON","DARK"},
  status={"MAJOR STATUS","STAT LOWER","STAT RAISE","FIELD/STATE","TRAPS/TRIGGERS","RECOVERY","UTILITY/OTHER"},
}
M.groups=groups
local function set(words) local t={};for s in words:gmatch("%S+")do t[s]=true end;return t end
local recovery=set("HEAL REST MORNING_SUN SYNTHESIS MOONLIGHT PAIN_SPLIT HEAL_BELL WISH REFRESH AROMATHERAPY")
local volatile=set("CONFUSE DISABLE LEECH_SEED ENCORE SPITE DESTINY_BOND MEAN_LOOK NIGHTMARE PERISH_SONG ATTRACT SWAGGER TAUNT TORMENT IMPRISON YAWN FLATTER")
local field=set("SUBSTITUTE LIGHT_SCREEN REFLECT MIST HAZE RESET_STATS TRANSFORM CONVERSION CONVERSION_2 PROTECT ENDURE SPIKES FORESIGHT SAFEGUARD SANDSTORM RAIN_DANCE SUNNY_DAY LOCK_ON HAIL MUD_SPORT WATER_SPORT INGRAIN MAGIC_COAT")
local raise=set("FOCUS_ENERGY BELLY_DRUM CURSE PSYCH_UP DEFENSE_CURL CHARGE STOCKPILE")
local fixed=set("BIDE COUNTER MIRROR_COAT SUPER_FANG OHKO LEVEL_DAMAGE DRAGON_RAGE SONICBOOM PSYWAVE ENDEAVOR")
function M.branch(id)
  local move=P.battleMove(id)
  if not move then return nil end
  local effect=names[move.effect] or tostring(move.effect)
  if (move.power or 0)>0 or fixed[effect] then
    local typ=tonumber(move.type) or Types.ID[move.type] or 0
    local label="NORMAL";for name,num in pairs(Types.ID)do if num==typ then label=name end end
    return Types.isPhysical(typ) and "physical" or "special",label
  end
  if effect:find("SLEEP") or effect:find("POISON") or effect:find("PARALYZE") or effect=="WILL_O_WISP" then return "status","MAJOR STATUS" end
  if effect:find("_DOWN") then return "status","STAT LOWER" end
  if effect:find("_UP") or raise[effect] then return "status","STAT RAISE" end
  if recovery[effect] then return "status","RECOVERY" end
  if effect:find("CONFUS") or volatile[effect] then return "status","TRAPS/TRIGGERS" end
  if field[effect] then return "status","FIELD/STATE" end
  return "status","UTILITY/OTHER"
end
local function sorted(ids)
  table.sort(ids,function(a,b)return P.moveName(a)<P.moveName(b)end)
  return ids
end
function M.catalog(section,group)
  local ids={}
  for n=1,354 do local s,g=M.branch(n);if s==section and g==group then ids[#ids+1]=n end end
  return sorted(ids)
end
function M.eligible(mon)
  local parents={}
  for nat=1,386 do
    local species=P.speciesFromNational(nat)
    for _,row in ipairs(species and P.evolutions(species) or {})do
      local target=tonumber(row.target or row[3])
      if target and target>0 then parents[target]=parents[target] or {};table.insert(parents[target],species) end
    end
  end
  local seen,ids={},{}
  local function remember(id)
    id=tonumber(id);if id and id>=1 and id<=354 and P.battleMove(id)then ids[id]=true end
  end
  local function visit(species)
    if not species or seen[species]then return end;seen[species]=true
    for _,parent in ipairs(parents[species] or {})do visit(parent)end
    for _,row in ipairs(P.learnset(species))do
      if (tonumber(row.level or row[1])or 1)<=(tonumber(mon.level)or 1)then remember(row.move or row[2])end
    end
  end
  visit(P.speciesOf(mon))
  for _,move in ipairs(mon.moves or {})do remember(type(move)=="table" and (move.id or move.move)or move)end
  local out={};for id in pairs(ids)do out[#out+1]=id end
  return sorted(out)
end
function M.teach(mon,slot,num)
  if not shared.gameplayAllowed() or not mon or slot<1 or slot>4 or num<1 or num>354 then return false end
  local move=P.battleMove(num);if not move then return false end
  mon.moves=mon.moves or {};mon.pp=mon.pp or {};mon.maxPp=mon.maxPp or {}
  mon.moves[slot]=num;mon.pp[slot]=move.pp or 5;mon.maxPp[slot]=move.pp or 5
  local s=shared.gen3Session()
  for pi,m in ipairs(s and s.party or {})do
    if m==mon and s.move_overlay and s.move_overlay[pi]then s.move_overlay[pi][slot]=nil end
  end
  if type(mon.ppUps)=="table"then mon.ppUps[slot]=0 end
  if type(mon.ppBonuses)=="number"then
    local shift=4^(slot-1);mon.ppBonuses=mon.ppBonuses-math.floor(mon.ppBonuses/shift)%4*shift
  end
  return true
end
shared.gen3Moves=M
