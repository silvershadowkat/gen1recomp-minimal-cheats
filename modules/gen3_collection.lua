local mod, shared = ...
local Pokemon = require("src.core.game3.pokemon")
local Dex = require("src.core.game3.dex")
local Encounters = require("src.core.game3.encounters")
local Items = require("src.core.game3.items_data")
local Rng = require("src.core.game3.rng")
local pending, count = nil, 0
shared.gen3DexNavPending=function()return pending~=nil end
local function session() return shared.gen3Session() end
local function allowed() return shared.gameplayAllowed() and not shared.gen3Flying end
local function owned(species)
  local s = session()
  return s and s.dex and Dex.isCaught(s.dex, species) or false
end
shared.gen3Owned = owned
function shared.gen3Uncaught()
  local result = {}
  for nat = 1, 386 do
    local species = Pokemon.speciesFromNational(nat)
    if species and not owned(species) then result[#result+1] = species end
  end
  return result
end
function shared.gen3LocalSpecies()
  local s = session()
  local t = s and Encounters.tableFor(s.map)
  local result, seen = {}, {}
  for _, kind in ipairs({"land", "water", "fishing", "rock"}) do
    local group = t and t[kind]
    for _, slot in ipairs(group and group.slots or {}) do
      local species = tonumber(slot.species)
      if species and species > 0 and not seen[species] then
        result[#result+1] = species; seen[species] = true
      end
    end
  end
  table.sort(result, function(a,b) return Pokemon.name(a)<Pokemon.name(b) end)
  return result
end
function shared.gen3DexNav(species,silent)
  if not allowed() then return false end
  pending = species
  if not silent then shared.gen3Message(species and ("Searching for "..Pokemon.name(species)..". Walk into a normal wild encounter.")
    or "DexNav search cancelled.")end
  return true
end
-- Replace only an encounter already approved by the game's terrain, repel,
-- cooldown and rate rules. Scripted encounters and roamers stay untouched.
mod.hooks:wrap("encounter.species", function(next, encounter, ctx)
  local enc = next(encounter, ctx)
  local s = session()
  if not enc or enc.roamer or not s or not allowed() then return enc end
  local Safari = require("src.core.game3.safari")
  if (s.safari and s.safari.active) or (Safari and Safari.isActive(s)) then return enc end
  local target = pending
  if not target and shared.bool("gen3_dex_hunt", true) then
    count = count + 1
    if count >= shared.allowed("gen3_dex_rate", {1,10,20,50}, 20) then
      count = 0
      local choices = shared.gen3Uncaught()
      if #choices > 0 then target = choices[(Rng.Random() % #choices)+1] end
    end
  end
  if not target then return enc end
  pending = nil
  -- Do not carry a different species' held item, moves or personality over.
  return {species=Pokemon.keyName(target), speciesId=target, level=enc.level}
end)
local function reset() pending, count = nil, 0 end
mod.events:on("map.entered", reset)
mod.events:on("save.loaded", reset)

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
