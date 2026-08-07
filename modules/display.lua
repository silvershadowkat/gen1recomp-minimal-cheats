-- Clean SilverShadow presentation layer: compact XP progress, caught marker,
-- and non-blocking map banners. It uses the live battle/world state only.
local mod, shared = ...

local caughtAtStart = setmetatable({}, { __mode = "k" })
local banner

local function expRatio(battle)
  local mon = battle and battle.player and battle.player.mon
  local def = mon and battle.data and battle.data.pokemon[mon.species]
  if not (mon and def) then return 0 end
  local cap = battle.data.constants and battle.data.constants.levelCap or 100
  if mon.level >= cap then return 1 end
  local Growth = require("src.pokemon.Growth")
  local current = Growth.expForLevel(def.growthRate, mon.level,
    battle.data.growth_rates)
  local nextLevel = Growth.expForLevel(def.growthRate, mon.level + 1,
    battle.data.growth_rates)
  if nextLevel <= current then return 0 end
  return math.max(0, math.min(1, ((mon.exp or current) - current)
    / (nextLevel - current)))
end

local function drawXp(battle)
  if not shared.bool("xp_bar", true) or not battle.player or battle.safari
      or battle.demo or battle.showPlayerBack then return end
  local wide = battle.wideLayout and battle:wideLayout()
  local x, y, width = wide and 208 or 80, wide and 91 or 89, wide and 80 or 67
  local fill = math.floor(width * expRatio(battle) + 0.5)
  local g = love.graphics
  g.setShader()
  g.setColor(0, 0, 0, 1)
  g.rectangle("line", x - 1, y - 1, width + 2, 4)
  if fill > 0 then
    g.setColor(0.2, 0.6, 0.95, 1)
    g.rectangle("fill", x, y, fill, 2)
  end
end

local function enemyHudVisible(battle)
  return battle.enemy and not battle.showEnemyTrainer and not battle.enemySendingOut
    and not battle.introBalls and not battle.enemy.fainted
end

local function caughtPosition(wide)
  return wide and 120 or 87, wide and 24 or 18
end

local function drawCaught(battle)
  if not shared.bool("caught_indicator", true) or battle.kind ~= "wild"
      or not caughtAtStart[battle] or battle.demo or battle.ghost
      or not enemyHudVisible(battle) then return end
  local wide = battle.wideLayout and battle:wideLayout()
  -- Keep the marker on the HP row, beyond the bar, where neither classic
  -- name alignment nor Stadium A's left-aligned names can reach it.
  local x, y = caughtPosition(wide)
  local g = love.graphics
  g.setShader()
  g.setColor(0, 0, 0, 1)
  g.circle("line", x, y, 3)
  g.line(x - 3, y, x + 3, y)
  g.circle("fill", x, y, 1)
end

mod.hooks:wrap("battle.overlay", function(next, battle)
  next(battle)
  if not (love and love.graphics and battle) then return end
  love.graphics.push("all")
  local ok, err = pcall(function()
    drawXp(battle)
    drawCaught(battle)
  end)
  love.graphics.pop()
  if not ok then mod.log:warn("display overlay failed: %s", tostring(err)) end
end)

mod.events:on("battle.started", function(event)
  local battle = event and event.battle
  local species = event and event.species
  if not (battle and species) then return end
  local dex = battle.game and battle.game.save and battle.game.save.pokedex
  caughtAtStart[battle] = dex and dex.owned and dex.owned[species] == true or false
end)

local function locationName(game, event)
  local townMap = game.data.field and game.data.field.townMap
  local locations = townMap and (townMap.locations or townMap)
  local entry = locations and locations[event.mapId]
  local name = type(entry) == "table" and (entry.name or entry.label)
  local def = event.map and event.map.def
    or game.data.maps and game.data.maps[event.mapId]
  name = name or (def and def.label) or tostring(event.mapId):gsub("_", " ")
  return tostring(name):gsub("(%l)(%u)", "%1 %2"):upper()
end

local function now()
  return love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
end

mod.events:on("map.entered", function(event)
  local game = shared.game
  if not game or not event or not event.mapId
      or not shared.bool("location_banners", true) then return end
  banner = { name = locationName(game, event), expires = now() + 2 }
  local ow = game.overworld
  if not (ow and type(ow.drawUI) == "function") or ow._silverShadowBanner then return end
  ow._silverShadowBanner = true
  local baseDraw = ow.drawUI
  ow.drawUI = function(self, ...)
    baseDraw(self, ...)
    if not banner or not shared.bool("location_banners", true)
        or now() >= banner.expires then banner = nil; return end
    local Font = require("src.render.Font")
    Font.drawBox(0, 14, 20, 4)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(banner.name, math.max(8, math.floor((160 - Font.width(banner.name)) / 2)), 128)
    love.graphics.setColor(1, 1, 1, 1)
  end
end)

mod.exports.display = {
  expRatio = expRatio,
  locationName = locationName,
  caughtPosition = caughtPosition,
}
