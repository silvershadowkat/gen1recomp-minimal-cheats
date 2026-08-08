-- Player-owned levels 101..255 for Gen1Recomp.
--
-- The engine's live Pokemon tables and Gen I save fields can represent a
-- byte-sized level, but vanilla validation and growth stop at 100.  Keep a
-- namespaced shadow only above 100 so validation can safely scrub a loaded
-- save, then restore and recalculate the player's own Pokemon afterward.

local mod, shared = ...

local Growth = require("src.pokemon.Growth")
local Stats = require("src.pokemon.Stats")
local unpack = table.unpack or unpack

local MAX_LEVEL = 255
local SHADOW_FIELD = "silverExtendedLevel"

local function clampLevel(value)
  value = math.floor(tonumber(value) or 1)
  return math.max(1, math.min(MAX_LEVEL, value))
end

-- Call a registered custom curve when present.  Built-in registry records
-- delegate back into Growth.expForLevel, so a small recursion guard lets that
-- path fall through to the original built-in curve instead.
local originalExpForLevel = Growth._silverOriginalExpForLevel
  or Growth.expForLevel
Growth._silverOriginalExpForLevel = originalExpForLevel

local evaluatingRecord = false
local function vanillaExp(growthRate, level, rates)
  local record = rates and rates[growthRate]
  if record and type(record.expForLevel) == "function" and not evaluatingRecord then
    evaluatingRecord = true
    local ok, value = pcall(record.expForLevel, level)
    evaluatingRecord = false
    if ok and type(value) == "number" then return math.max(0, value) end
  end
  return originalExpForLevel(growthRate, level, nil)
end

local function extendedExpForLevel(growthRate, level, rates)
  level = clampLevel(level)
  if level <= 100 then return vanillaExp(growthRate, level, rates) end
  local at99 = vanillaExp(growthRate, 99, rates)
  local at100 = vanillaExp(growthRate, 100, rates)
  local step = math.max(1, at100 - at99)
  return at100 + step * (level - 100)
end

Growth._silverExtendedControl = { expForLevel = extendedExpForLevel }
if Growth.expForLevel ~= Growth._silverExtendedWrapper then
  Growth._silverExtendedWrapper = function(growthRate, level, rates)
    local control = Growth._silverExtendedControl
    if control and control.expForLevel then
      return control.expForLevel(growthRate, level, rates)
    end
    return originalExpForLevel(growthRate, level, rates)
  end
  Growth.expForLevel = Growth._silverExtendedWrapper
end

local function recalculate(game, mon, level, setExp)
  if type(mon) ~= "table" or not (game and game.data and game.data.pokemon) then
    return false
  end
  local def = game.data.pokemon[mon.species]
  if not def then return false end

  level = clampLevel(level)
  local oldStats = mon.stats
  if type(oldStats) ~= "table" then
    oldStats = Stats.calc(def, mon.level or level, mon.dvs or {}, mon.statExp)
  end
  local oldMax = math.max(1, tonumber(oldStats.hp) or 1)
  local oldHp = math.max(0, math.min(oldMax, tonumber(mon.hp) or oldMax))
  local missing = math.max(0, oldMax - oldHp)

  mon.level = level
  if setExp then
    mon.exp = extendedExpForLevel(def.growthRate, level, game.data.growth_rates)
  end
  mon.stats = Stats.calc(def, level, mon.dvs or {}, mon.statExp)
  if oldHp <= 0 then
    mon.hp = 0
  else
    mon.hp = math.max(1, math.min(mon.stats.hp, mon.stats.hp - missing))
  end
  mon[SHADOW_FIELD] = level > 100 and level or nil
  return true
end

local function eachOwned(save, callback)
  if type(save) ~= "table" then return end
  for _, mon in ipairs(save.party or {}) do callback(mon) end
  for _, box in ipairs(save.boxes or {}) do
    for _, mon in ipairs(box or {}) do callback(mon) end
  end
  if save.daycare and save.daycare.mon then callback(save.daycare.mon) end
end

local function applyCap(game)
  if not (game and game.data) then return end
  game.data.constants = game.data.constants or {}
  game.data.constants.levelCap = MAX_LEVEL
end

local function restoreOwned(game, save)
  applyCap(game)
  eachOwned(save, function(mon)
    local shadow = tonumber(mon[SHADOW_FIELD])
    if shadow and shadow > 100 then
      recalculate(game, mon, shadow, false)
      local def = game.data.pokemon[mon.species]
      if def then
        local floorExp = extendedExpForLevel(def.growthRate, mon.level,
          game.data.growth_rates)
        local ceiling = extendedExpForLevel(def.growthRate, MAX_LEVEL,
          game.data.growth_rates)
        mon.exp = math.max(floorExp, math.min(tonumber(mon.exp) or floorExp, ceiling))
      end
    end
  end)
end

local function snapshotOwned(save)
  eachOwned(save, function(mon)
    local level = clampLevel(mon.level)
    mon[SHADOW_FIELD] = level > 100 and level or nil
  end)
end

-- Rare Candy has its own hard-coded level-100 refusal.  Preserve the vanilla
-- item flow and messages below 100, and reproduce only its level-up result
-- above 100 so stocked candies remain useful through the extended cap.
local ItemEffects = require("src.inventory.ItemEffects")
local originalItemUse = ItemEffects._silverOriginalUse or ItemEffects.use
ItemEffects._silverOriginalUse = originalItemUse
ItemEffects._silverExtendedControl = {
  use = function(data, save, itemId, target, battle, moveIndex, overworld)
    if itemId ~= "RARE_CANDY" or not target or target.level < 100 then
      return originalItemUse(data, save, itemId, target, battle, moveIndex, overworld)
    end
    if target.level >= MAX_LEVEL then
      local romText = require("src.core.RomText")
      return "failed", { romText(data, "_ItemUseNoEffectText",
        "It won't have\nany effect.") }
    end
    local game = shared.game
    if not game or game.data ~= data then
      return originalItemUse(data, save, itemId, target, battle, moveIndex, overworld)
    end
    recalculate(game, target, target.level + 1, true)
    pcall(function()
      require("src.world.PikachuFollower").modifyHappiness(save, "LEVELUP", target)
    end)
    local romText = require("src.core.RomText")
    local name = target.nickname or (data.pokemon[target.species] or {}).name
      or tostring(target.species)
    return "consumed", { romText(data, "_RareCandyText",
      "%s grew\nto level %d!", name, target.level) },
      { leveledTo = target.level }
  end,
}
if ItemEffects.use ~= ItemEffects._silverExtendedWrapper then
  ItemEffects._silverExtendedWrapper = function(...)
    local control = ItemEffects._silverExtendedControl
    if control and control.use then return control.use(...) end
    return originalItemUse(...)
  end
  ItemEffects.use = ItemEffects._silverExtendedWrapper
end

-- Vanilla's second summary page hard-codes 100 as the final level.  Preserve
-- the original page and repaint only its compact "EXP TO NEXT" row so levels
-- 100..255 display the real extended requirement without disturbing layouts.
local SummaryMenu = require("src.ui.SummaryMenu")
local originalSummaryDraw = SummaryMenu._silverOriginalDraw or SummaryMenu.draw
SummaryMenu._silverOriginalDraw = originalSummaryDraw
SummaryMenu._silverExtendedControl = {
  drawNext = function(state)
    local mon = state and state.mon
    if not mon or state.page ~= 2 or (mon.level or 1) < 100 then return end
    local def = state.game and state.game.data
      and state.game.data.pokemon[mon.species]
    if not def then return end
    local nextLevel = math.min(MAX_LEVEL, (mon.level or 1) + 1)
    local needed = nextLevel > mon.level
      and (extendedExpForLevel(def.growthRate, nextLevel,
        state.game.data.growth_rates) - (mon.exp or 0)) or 0
    local Font = require("src.render.Font")
    local HudTiles = require("src.render.HudTiles")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 56, 48, 96, 8)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(("%7d"):format(math.max(0, needed)), 56, 48)
    HudTiles.statusTile(0x70, 112, 48)
    Font.draw(mon.level < MAX_LEVEL and tostring(nextLevel) or "MAX", 128, 48)
    love.graphics.setColor(1, 1, 1, 1)
  end,
}
if SummaryMenu.draw ~= SummaryMenu._silverExtendedWrapper then
  SummaryMenu._silverExtendedWrapper = function(self, ...)
    local result = { originalSummaryDraw(self, ...) }
    local control = SummaryMenu._silverExtendedControl
    if control and control.drawNext then control.drawNext(self) end
    return unpack(result)
  end
  SummaryMenu.draw = SummaryMenu._silverExtendedWrapper
end

mod.events:on("game.ready", function(event)
  local game = event and event.game
  if game then restoreOwned(game, game.save) end
end)

mod.events:on("save.loaded", function(event)
  local game = shared.game
  if game then restoreOwned(game, event and event.save or game.save) end
end)

mod.events:on("save.writing", function(event)
  snapshotOwned(event and event.save)
end)

mod.events:on("pokemon.level_up", function(event)
  local mon = event and event.mon
  if mon then mon[SHADOW_FIELD] = mon.level > 100 and mon.level or nil end
end)

-- A capped Pokemon should not accumulate an unbounded experience integer.
mod.hooks:wrap("exp.gain", function(next, ctx)
  if ctx and ctx.mon and (tonumber(ctx.mon.level) or 1) >= MAX_LEVEL
      and not shared.online() then return 0 end
  return next(ctx)
end, 1000)

shared.extendedLevels = {
  max = MAX_LEVEL,
  expForLevel = extendedExpForLevel,
  setLevel = recalculate,
  restoreOwned = restoreOwned,
}
mod.exports.extendedLevels = shared.extendedLevels
