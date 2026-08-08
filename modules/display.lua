-- Clean SilverShadow presentation layer: compact XP progress, caught marker,
-- and non-blocking map banners. It uses the live battle/world state only.
local mod, shared = ...

local caughtAtStart = setmetatable({}, { __mode = "k" })
local caughtEmbedded = setmetatable({}, { __mode = "k" })
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

local function caughtPosition(wide, valueWidth, status)
  -- Reserve the empty tile immediately before <LV>/status. This keeps the
  -- marker above the HP row and completely independent of level digit count.
  local radius = wide and 3 or 4
  return wide and 80 or 24, 12, radius
end

local function shouldDrawCaught(battle)
  return shared.bool("caught_indicator", true) and battle.kind == "wild"
      and caughtAtStart[battle] and not battle.demo and not battle.ghost
      and enemyHudVisible(battle)
end

local function caughtValue(battle)
  local status = battle.enemy and battle.enemy.shownStatus
  if status and type(battle.statusLabel) == "function" then
    return battle:statusLabel({ status = status }), true
  end
  local level = battle.enemy and battle.enemy.mon and battle.enemy.mon.level or 1
  return tostring(level), false
end

local function drawCaughtGlyph(battle)
  local Font = require("src.render.Font")
  local wide = battle.wideLayout and battle:wideLayout()
  local value, status = caughtValue(battle)
  local x, y, radius = caughtPosition(wide, Font.width(value), status)
  local g = love.graphics
  g.setShader()
  -- Compact pixel-style Poke Ball. Color and a filled silhouette keep it
  -- visually separate from the adjacent level digits at phone scale.
  g.setColor(0, 0, 0, 1)
  g.circle("fill", x, y, radius)
  g.setColor(1, 1, 1, 1)
  g.circle("fill", x, y, radius - 1)
  g.setColor(0.88, 0.08, 0.08, 1)
  local inner = radius - 1
  g.polygon("fill",
    x - inner, y,
    x - inner + 1, y - inner + 1,
    x, y - inner,
    x + inner - 1, y - inner + 1,
    x + inner, y)
  g.setColor(0, 0, 0, 1)
  g.line(x - inner, y, x + inner, y)
  g.circle("fill", x, y, math.max(1, radius - 2))
  g.setColor(1, 1, 1, 1)
  g.circle("fill", x, y, 0.75)
end

local function drawCaught(battle)
  if not shouldDrawCaught(battle) or caughtEmbedded[battle] then return end
  drawCaughtGlyph(battle)
end

-- Dramatic Shape renders the engine HUD to a texture and snaps that texture
-- to the window edge. A normal battle.overlay remains in the centered GB
-- frame, so an absolute icon cannot follow the moved HUD. Embed the icon in
-- the same HUD texture, then let Dramatic Shape move both as one unit.
local function embedCaught(battle, layer)
  if not layer or not shouldDrawCaught(battle)
      or not (love and love.graphics) then return false end
  local g = love.graphics
  if type(g.setCanvas) ~= "function" or type(g.getCanvas) ~= "function" then
    return false
  end
  local previousCanvas = g.getCanvas()
  local previousBlend, previousAlpha = g.getBlendMode()
  local previousShader = g.getShader and g.getShader() or nil
  local r, green, blue, alpha = g.getColor()
  local ok, err = pcall(function()
    g.setCanvas(layer)
    g.setBlendMode("alpha")
    drawCaughtGlyph(battle)
  end)
  if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
  g.setBlendMode(previousBlend or "alpha", previousAlpha)
  g.setShader(previousShader)
  g.setColor(r, green, blue, alpha)
  if not ok then mod.log:warn("caught HUD embed failed: %s", tostring(err)) end
  return ok
end

local function installDramaticShapeCaught()
  for _, id in ipairs({ "DRAMATIC_SHAPE", "DRAMATIC_SHAPE_SEAMLESS" }) do
    local found = mod:find(id)
    local lib = found and found.exports and found.exports.lib
    if lib and type(lib.require) == "function" then
      local ok, OverworldBattle = pcall(lib.require, "OverworldBattle")
      if ok and type(OverworldBattle) == "table"
          and type(OverworldBattle.hudTexture) == "function"
          and type(OverworldBattle.snapHUDs) == "function" then
        local patch = rawget(OverworldBattle, "__silverShadowCaughtPatch")
        if not patch then
          patch = {
            handlers = {},
            hudTexture = OverworldBattle.hudTexture,
            snapHUDs = OverworldBattle.snapHUDs,
          }
          rawset(OverworldBattle, "__silverShadowCaughtPatch", patch)
          OverworldBattle.hudTexture = function(battle, ...)
            local layer = patch.hudTexture(battle, ...)
            for _, handler in pairs(patch.handlers) do
              if layer and handler.embed(battle, layer) then
                handler.pending[battle] = true
              end
            end
            return layer
          end
          OverworldBattle.snapHUDs = function(battle, ...)
            for _, handler in pairs(patch.handlers) do
              handler.pending[battle] = nil
              handler.embedded[battle] = nil
            end
            local snapped = patch.snapHUDs(battle, ...)
            if snapped then
              for _, handler in pairs(patch.handlers) do
                if handler.pending[battle] then handler.embedded[battle] = true end
              end
            end
            return snapped
          end
        end
        patch.handlers[mod.id] = {
          embed = embedCaught,
          pending = setmetatable({}, { __mode = "k" }),
          embedded = caughtEmbedded,
        }
        return true
      end
    end
  end
  return false
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

installDramaticShapeCaught()
mod.events:on("game.ready", function()
  installDramaticShapeCaught()
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
  installDramaticShapeCaught = installDramaticShapeCaught,
}
