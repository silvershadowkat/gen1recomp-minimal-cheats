local mod, shared = ...

local function healParty(game)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    shared.healPokemon(game, mon)
  end
end

local function perfectDVs(game, mon)
  mon.dvs = { attack = 15, defense = 15, speed = 15, special = 15, hp = 15 }
  local def = game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
  if def then
    mon.stats = require("src.pokemon.Stats").calc(def, mon.level, mon.dvs, mon.statExp)
    mon.hp = math.min(tonumber(mon.hp) or mon.stats.hp, mon.stats.hp)
  end
end

local function poisonClamp(party, damage)
  local saved = {}
  for _, mon in ipairs(party or {}) do
    if mon.status == "PSN" and (tonumber(mon.hp) or 0) > 0
        and mon.hp <= damage then
      mon.hp, mon.status = 1, nil
      saved[#saved + 1] = mon
    end
  end
  return saved
end

local baseSetDark
local function refreshLights(game)
  local ow = game and game.overworld
  if not (ow and baseSetDark) then return end
  if shared.bool("lights_on", false) then
    baseSetDark(ow, false)
  else
    baseSetDark(ow, ow._silverShadowVanillaDark == true)
  end
end
shared.refreshLights = refreshLights

mod.events:on("game.ready", function(event)
  local game = event and event.game
  if not game then return end
  local OverworldState = require("src.world.OverworldController")

  if not OverworldState._silverShadowPoisonInstalled then
    OverworldState._silverShadowPoisonInstalled = true
    local vanilla = OverworldState.applyFieldPoison
    OverworldState.applyFieldPoison = function(self)
      if not shared.bool("poison_save", false) then return vanilla(self) end
      local FieldDefaults = require("src.world.FieldDefaults")
      local interval = FieldDefaults.world(game.data, "poisonStepInterval") or 4
      local nextStep = (game.save.poisonSteps or 0) + 1
      if nextStep % interval ~= 0 then return vanilla(self) end
      local damage = FieldDefaults.world(game.data, "poisonDamage") or 1
      local rescued = poisonClamp(game.save.party, damage)
      local stopped = vanilla(self)
      if #rescued > 0 then
        local TextBox = require("src.render.TextBox")
        local Strings = require("src.core.Strings")
        local messages = {}
        for _, mon in ipairs(rescued) do
          local def = game.data.pokemon and game.data.pokemon[mon.species]
          messages[#messages + 1] = Strings("%s's poison\nhas subsided!",
            mon.nickname or (def and def.name) or "?")
        end
        local function nextMessage()
          local message = table.remove(messages, 1)
          if message then game.stack:push(TextBox.new(game, message, nextMessage)) end
        end
        nextMessage()
      end
      return stopped or #rescued > 0
    end
  end

  if not OverworldState._silverShadowLightsInstalled then
    OverworldState._silverShadowLightsInstalled = true
    OverworldState._silverShadowOriginalSetDark = OverworldState.setDark
    baseSetDark = OverworldState._silverShadowOriginalSetDark
    OverworldState.setDark = function(self, on)
      self._silverShadowVanillaDark = on and true or false
      if shared.bool("lights_on", false) then on = false end
      return baseSetDark(self, on)
    end
  elseif not baseSetDark then
    -- Hot reload reuses the original implementation stored on the class,
    -- never the installed wrapper (which would recurse into itself).
    baseSetDark = OverworldState._silverShadowOriginalSetDark
  end
  refreshLights(game)
end)

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
      and shared.bool("heal_battle", false) then
    healParty(battle.game or shared.game)
  end
end)

shared.healParty = healParty
shared.perfectDVs = perfectDVs
shared.poisonClamp = poisonClamp
mod.exports.healing = {
  healParty = healParty,
  perfectDVs = perfectDVs,
  poisonClamp = poisonClamp,
}
