local mod, shared = ...

local Mon = require("src.battle.gen2.Mon")

local function healParty(game)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    shared.healPokemon(game, mon)
  end
end

local function perfectDVs(game, mon)
  mon.dvs = { attack = 15, defense = 15, speed = 15, special = 15, hp = 15 }
  local def = game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
  if not def then return end
  local oldMax = mon.stats and mon.stats.hp or mon.hp or 1
  local missing = math.max(0, oldMax - (tonumber(mon.hp) or oldMax))
  mon.stats = Mon.stats(def.baseStats, mon.dvs, mon.level or 1, mon.statExp)
  mon.hp = math.max(1, math.min(mon.stats.hp, mon.stats.hp - missing))
end

mod.events:on("map.entered", function()
  local game = shared.game
  if game and shared.bool("heal_map_change", false) and not shared.online() then
    healParty(game)
  end
end)

mod.events:on("pokemon.caught", function(event)
  if not (event and event.mon) or shared.online() then return end
  local game = event.game or shared.game
  if shared.bool("perfect_dvs", false) then perfectDVs(game, event.mon) end
  if shared.bool("catch_heal", false) then shared.healPokemon(game, event.mon) end
end)

mod.events:on("battle.ended", function(event)
  local battle = event and event.battle
  if battle and shared.gameplayAllowed(battle)
      and shared.bool("heal_battle", false) then healParty(shared.game) end
end)

shared.healParty = healParty
shared.perfectDVs = perfectDVs
mod.exports.healing = { healParty = healParty, perfectDVs = perfectDVs }
