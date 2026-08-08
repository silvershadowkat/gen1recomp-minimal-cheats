-- SilverShadow Free Fly
--
-- Adapted from Shane Hudson's MIT-licensed Free Fly 1.4.1, but integrated
-- through SilverShadow's shared menu, movement, follower and link-safety
-- seams.  The Quick Select/whistle and Pallet Town gift are intentionally
-- excluded.  Flight keeps only the maps the engine itself needs resident.

local mod, shared = ...

local RISE_SPEED = 72
local HEIGHTS = { LOW = 32, MED = 56, HIGH = 80 }
local DIRS = {
  up = { 0, -1 }, down = { 0, 1 },
  left = { -1, 0 }, right = { 1, 0 },
}
local LAND_DIRS = { { 0, 1 }, { 1, 0 }, { -1, 0 }, { 0, -1 } }

local state = {
  phase = "idle", altitude = 0, mountMon = nil, rider = nil,
  landRequest = false, approach = nil, bob = 0,
}

local function option(key, default)
  return shared.get(key, default)
end

local function enabled(key, default)
  return shared.bool(key, default)
end

local function cruiseHeight()
  return HEIGHTS[shared.allowed("fly_height", shared.FLY_HEIGHTS, "MED")] or 56
end

local function flying()
  return state.phase ~= "idle"
end

local function knowsMove(mon, moveId)
  for _, move in ipairs((mon and mon.moves) or {}) do
    if (type(move) == "table" and move.id or move) == moveId then return true end
  end
  return false
end

local function hasType(game, mon, wanted)
  local def = mon and game and game.data and game.data.pokemon
    and game.data.pokemon[mon.species]
  for _, kind in ipairs((def and def.types) or {}) do
    if kind == wanted then return true end
  end
  return false
end

local function canLearn(game, mon, moveId)
  local def = mon and game and game.data and game.data.pokemon
    and game.data.pokemon[mon.species]
  for _, move in ipairs((def and def.tmhm) or {}) do
    if move == moveId then return true end
  end
  return false
end

local function ownedHM(game, moveId)
  return type(mod.exports.ownedHM) == "function"
    and mod.exports.ownedHM(game, moveId) == true
end

local function hasBadge(game, moveId)
  return type(mod.exports.hasBadge) ~= "function"
    or mod.exports.hasBadge(game, moveId) == true
end

local function firstHealthyKnower(game, moveId)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if (mon.hp or 0) > 0 and knowsMove(mon, moveId) then return mon end
  end
  return nil
end

local function skyAbove(game, mapDef)
  if not mapDef then return false end
  local Map = require("src.world.Map")
  local FieldDefaults = require("src.world.FieldDefaults")
  if Map.isOutside(mapDef,
      FieldDefaults.field(game.data, "outsideTilesets")) then
    return true
  end
  -- Viridian Forest and the Safari areas use the outdoor-style canopy.
  return mapDef.tileset == "FOREST"
end

local function eligibleFlyer(game, mon)
  if not mon or (mon.hp or 0) <= 0 then return false end
  if knowsMove(mon, "FLY") then return true end
  -- SilverShadow HM Anywhere may supply the field move from the Bag.  Keep
  -- the mount species-compatible when the move itself was not taught.
  return ownedHM(game, "FLY") and canLearn(game, mon, "FLY")
end

local function flyBadgeOk(game)
  if type(shared.travelBadgeAllowed) == "function" then
    return shared.travelBadgeAllowed(game, "FLY")
  end
  return not enabled("fly_badge_checks", true) or hasBadge(game, "FLY")
end

local function surfAllowed(game, ow)
  if not ownedHM(game, "SURF") then return false end
  local badgeOk = type(shared.travelBadgeAllowed) == "function"
    and shared.travelBadgeAllowed(game, "SURF")
    or (not enabled("fly_badge_checks", true) or hasBadge(game, "SURF"))
  if not badgeOk then return false end
  if ow and type(ow.partyKnows) == "function" then
    local ok, mon = pcall(ow.partyKnows, ow, "SURF")
    if ok and mon then return true end
  end
  return true -- HM Anywhere owns the actual field-use eligibility.
end

local function currentOverworld()
  local ok, ow = pcall(function()
    return mod.world and mod.world:overworld()
  end)
  return ok and ow or nil
end

local function emit(name, payload)
  pcall(function() mod.events:emit(name, payload or {}) end)
end

local function syncFollowers(game, ow)
  local ex = mod.exports.followersIntegration
  ex = ex and ex.engine and ex.engine() or nil
  if not ex then ex = mod.exports end
  if type(ex.syncAll) == "function" then
    pcall(ex.syncAll, game, ow)
  elseif type(ex.syncPlayerControlVisual) == "function" then
    pcall(ex.syncPlayerControlVisual, game, ow, true)
  end
end

local function clearPlayerTravel(player)
  if not player then return end
  player.freeFlying = nil
  player.freeFlyAlt = nil
  player.freeFlyCanLand = nil
  player.silverTravelMount = nil
  player.silverTravelMode = nil
  player.silverTravelAltitude = nil
end

local function finishFlight(game, ow, reason, water)
  local player = ow and ow.player
  state.phase, state.altitude = "idle", 0
  state.landRequest, state.approach = false, nil
  state.forceReason = nil
  if player then
    clearPlayerTravel(player)
    if water then
      player.surfing = true
      player.silverSurfMount = firstHealthyKnower(game, "SURF")
      pcall(function() ow:syncSurfingPikachu() end)
      pcall(function()
        require("src.core.Music").setSurfing(game.data, true)
      end)
    else player.silverSurfMount = nil end
  end
  local mount = state.mountMon
  state.mountMon = nil
  syncFollowers(game, ow)
  emit("mod.silvershadow.fly.landed", {
    reason = reason or "landed", water = water and true or nil,
    species = mount and mount.species,
    x = player and player.cellX, y = player and player.cellY,
  })
end

local function startFlight(game, mon)
  if flying() or shared.online() then return false end
  -- Revalidate at execution time.  A party submenu can remain open while the
  -- option changes, so the row that was legal when drawn must not become a
  -- stale badge-check bypass.
  if not eligibleFlyer(game, mon) or not flyBadgeOk(game) then return false end
  local ow = currentOverworld()
  if not (ow and ow.player and ow.map and ow.map.def) then return false end
  if ow.player.onBike or not skyAbove(game, ow.map.def) then return false end

  state.phase, state.altitude = "rising", 0
  state.mountMon, state.landRequest, state.approach = mon, false, nil
  local player = ow.player
  player.surfing = false
  player.freeFlying = true
  player.silverTravelMode = "fly"
  player.silverTravelMount = mon
  player.silverTravelAltitude = 0
  pcall(function() require("src.core.Music").setSurfing(game.data, false) end)
  pcall(function() require("src.core.Sound").play(game.data, "Fly") end)
  syncFollowers(game, ow)
  emit("mod.silvershadow.fly.takeoff", {
    species = mon and mon.species, level = mon and mon.level,
  })
  mod.log:info("Free Fly takeoff: A lands; B controls FLY BOOST")
  return true
end

-- Public surface for tests and follower-aware companion mods.
mod.exports.freeFly = {
  isFlying = flying,
  altitude = function() return flying() and state.altitude or 0 end,
  mount = function() return flying() and state.mountMon or nil end,
  eligible = eligibleFlyer,
  surfAllowed = surfAllowed,
  classify = function(game, mon, travelMode, overWater)
    -- Move Editor knowledge is authoritative even when the species could not
    -- learn the move naturally. A dual FLY/SURF user follows in the style of
    -- the current trip rather than always preferring its airborne capability.
    local canFly = hasType(game, mon, "FLYING") or knowsMove(mon, "FLY")
    local canSurf = ownedHM(game, "SURF")
      and (hasType(game, mon, "WATER") or knowsMove(mon, "SURF"))
    local canHover = hasType(game, mon, "PSYCHIC")
      or hasType(game, mon, "GHOST")

    if travelMode == "surf" then
      if canSurf then return "surf" end
      if canFly then return "air" end
      if canHover then return "hover" end
      return nil
    end
    if travelMode == "fly" then
      if canFly then return "air" end
      if canHover then return "hover" end
      if overWater and canSurf then return "surf" end
      return nil
    end

    -- Backward-compatible generic classification for companion callers that
    -- do not yet pass the current travel mode.
    if canFly then return "air" end
    if canHover then return "hover" end
    if canSurf then return "surf" end
    return nil
  end,
}

-- SilverShadow owns the party seam; no second independent wrapper.
shared.registerPartyDecorator("free_fly", 5, function(game, out, mon, ctx)
  if type(out) ~= "table" or (ctx and ctx.battle) or flying() then return out end
  local ow = ctx and ctx.overworld
  if not (ow and ow.map and ow.map.def and ow.player) then return out end
  if shared.online() or ow.player.onBike or not skyAbove(game, ow.map.def) then
    return out
  end
  if not eligibleFlyer(game, mon) or not flyBadgeOk(game) then return out end
  for _, item in ipairs(out) do
    if tostring(item.label or ""):upper() == "FREEFLY" then return out end
  end
  table.insert(out, 1, {
    label = "FREEFLY",
    onSelect = function(selected, g)
      while g.stack:top() and not g.stack:top().isOverworld do g.stack:pop() end
      if startFlight(g, selected or mon) and not shared.bool("fly_help_seen", false) then
        shared.set("fly_help_seen", true)
        mod.world:queueScript({
          { "show_text", "Press A to land.\nB controls FLY BOOST." },
        })
      end
    end,
  })
  return out
end)

mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
  if flying() and ctx and ctx.mover and ctx.mover.freeFlying
      and (ctx.reason == "tile" or ctx.reason == "entity") then
    ctx.reason = nil
    return true
  end
  return next(allowed, ctx)
end)

mod.hooks:wrap("encounter.roll", function(next, encounter, ctx)
  if flying() then return nil end
  return next(encounter, ctx)
end)

mod.hooks:wrap("save.write", function(next, game)
  if flying() then
    mod.log:warn("land before saving")
    return false
  end
  return next(game)
end)

local function storyGateBlocks(game, mapId)
  local field = game.data and game.data.field
  local entry = field and field.badgeGates and field.badgeGates[mapId]
  if not entry then return false end
  local save = game.save or {}
  local flags, bag = save.flags or {}, save.inventory or {}
  if flags[entry.passedFlag or ("PASSED_" .. tostring(mapId))] then
    return false
  end
  if entry.badge then return not bag[entry.badge] end
  for _, guard in ipairs(entry.guards or {}) do
    if not (flags[guard.event] or (guard.badge and bag[guard.badge])) then
      return true
    end
  end
  return false
end

local function requestWindBack(game)
  pcall(function() require("src.core.Sound").play(game.data, "Collision") end)
  mod.world:queueScript({ { "show_text", "A fierce wind\nblows you back!" } })
end

mod.events:on("save.loaded", function()
  state.phase, state.altitude, state.mountMon = "idle", 0, nil
  local ow = currentOverworld()
  if ow and ow.player then clearPlayerTravel(ow.player) end
end)

mod.events:on("world.blacked_out", function()
  if not flying() then return end
  local game = shared.game
  local ow = currentOverworld()
  finishFlight(game, ow, "blackout", false)
end)

mod.events:on("game.ready", function(event)
  local game = event and event.game or require("src.core.Game")
  shared.game = game
  local Player = require("src.world.Player")
  local OC = require("src.world.OverworldController")
  local Collision = require("src.world.Collision")
  local Map = require("src.world.Map")
  local Pipelines = require("src.render.Pipelines")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local FieldDefaults = require("src.world.FieldDefaults")

  local function followerEngine()
    local ex = mod.exports.followersIntegration
    return ex and ex.engine and ex.engine() or nil
  end

  local genericCache = {}
  local function genericMount(mon)
    local engine = followerEngine()
    if engine and type(engine.travelSprite) == "function" then
      local ok, sprite = pcall(engine.travelSprite, game, mon)
      if ok and sprite then return sprite end
    end
    local ids = { BIRD = "SPRITE_BIRD", MON = "SPRITE_MONSTER",
      WATER = "SPRITE_SEEL", FAIRY = "SPRITE_FAIRY",
      PIKACHU = "SPRITE_FAIRY" }
    local def = mon and game.data.pokemon and game.data.pokemon[mon.species]
    local icons = game.data.icons or {}
    local class = (icons.bySpecies and icons.bySpecies[mon.species])
      or (def and def.icon)
      or (def and def.dex and icons.byDex and icons.byDex[def.dex])
    local spriteDef = game.data.sprites[ids[class] or "SPRITE_BIRD"]
    if not spriteDef then return nil end
    local key = tostring(mon.species) .. "#" .. tostring(ids[class] or "SPRITE_BIRD")
    if not genericCache[key] then
      genericCache[key] = SpriteRenderer.new(spriteDef,
        "silvershadow_travel_mount_" .. key)
    end
    return genericCache[key]
  end

  local function mountScale(mon)
    local def = mon and game.data.pokemon and game.data.pokemon[mon.species]
    local dex = (def and def.dexEntry) or {}
    local feet = (dex.heightFt or 2) + (dex.heightIn or 0) / 12
    return math.max(0.85, math.min(1.6, 0.75 + feet * 0.14))
  end

  local trainerSprite
  local function getTrainerSprite()
    if trainerSprite then return trainerSprite end
    local id = FieldDefaults.fieldValue(game.data, "playerSprites", "walk")
    local def = id and game.data.sprites[id]
    if def then trainerSprite = SpriteRenderer.new(def, "silvershadow_rider") end
    return trainerSprite
  end

  local function surfMount(ow)
    if not (ow and ow.player and ow.player.surfing and ownedHM(game, "SURF")) then
      return nil
    end
    -- Retain the engine's normal surf sprite for HM-device fallback when no
    -- party member actually knows SURF.
    return firstHealthyKnower(game, "SURF")
  end

  local Rider = {}
  Rider.__index = Rider
  local function playerTravelLift(player)
    local lift = player.silverTravelLift or 0
    if player.surfing and player.silverSurfMount then
      lift = lift + (math.floor(love.timer.getTime() * 2) % 2)
    end
    return lift
  end
  function Rider.new(player)
    return setmetatable({ player = player, passable = true,
      px = player.px, py = player.py,
      cellX = player.cellX, cellY = player.cellY,
      silverTravelRider = true }, Rider)
  end
  function Rider:pose()
    local p = self.player
    local lift = playerTravelLift(p)
    -- Keep the trainer tucked into the mount billboard. A separate rider
    -- entity is needed by voxel, but this lower offset avoids the full
    -- standing-above-the-bird look of the original Free Fly implementation.
    return getTrainerSprite() or p.sprite, p.px, p.py - lift - 3,
      p.facing, 0, false, false
  end
  function Rider:draw() end

  local function removeRider(ow)
    if not state.rider or not ow then return end
    for i = #(ow.entities or {}), 1, -1 do
      if ow.entities[i] == state.rider then table.remove(ow.entities, i) end
    end
    state.rider = nil
  end

  local function syncRider(ow, active)
    if not active then removeRider(ow); return end
    local player = ow.player
    if not state.rider or state.rider.player ~= player then
      removeRider(ow)
      state.rider = Rider.new(player)
    end
    local rider = state.rider
    rider.px, rider.py = player.px, player.py
    rider.cellX, rider.cellY = player.cellX, player.cellY
    for _, entity in ipairs(ow.entities or {}) do
      if entity == rider then return end
    end
    table.insert(ow.entities, rider)
  end

  if not Player.__silverTravelWrapped then
    Player.__silverTravelWrapped = true
    Player.__silverTravelOrigPose = Player.pose
    Player.__silverTravelOrigDraw = Player.draw
    Player.pose = function(self)
      local impl = Player.__silverTravelPose
      if impl then return impl(self, Player.__silverTravelOrigPose) end
      return Player.__silverTravelOrigPose(self)
    end
    Player.draw = function(self, camX, camY)
      local impl = Player.__silverTravelDraw
      if impl then return impl(self, camX, camY, Player.__silverTravelOrigDraw) end
      return Player.__silverTravelOrigDraw(self, camX, camY)
    end
  end

  Player.__silverTravelPose = function(self, original)
    local sprite, px, py, facing, phase, flip, hopping = original(self)
    local mon = self.freeFlying and state.mountMon
      or (self.surfing and self.silverSurfMount)
    local mount = mon and genericMount(mon)
    if not mount then return sprite, px, py, facing, phase, flip, hopping end
    local lift = playerTravelLift(self)
    local rate = self.freeFlying and 8 or 5
    return mount, px, self.py - lift, facing,
      math.floor(love.timer.getTime() * rate) % 2, false, false
  end

  Player.__silverTravelDraw = function(self, camX, camY, original)
    local mon = self.freeFlying and state.mountMon
      or (self.surfing and self.silverSurfMount)
    local mount = mon and genericMount(mon)
    local trainer = getTrainerSprite()
    if not (mount and trainer) then return original(self, camX, camY) end
    local lift = playerTravelLift(self)
    local scale = mountScale(mon)
    local x, y = self.px, self.py - lift
    if self.freeFlying then
      if self.freeFlyCanLand then love.graphics.setColor(0.1, 0.45, 0.15, 0.45)
      else love.graphics.setColor(0, 0, 0, 0.35) end
      local radius = math.max(3, 7 - lift / 16) * scale
      love.graphics.ellipse("fill", self.px + 8 - camX,
        self.py + 13 - camY, radius, radius * 0.4)
    else
      love.graphics.setColor(0.2, 0.55, 0.9, 0.42)
      love.graphics.ellipse("line", self.px + 8 - camX,
        self.py + 14 - camY, 8 * scale, 3)
    end
    love.graphics.setColor(1, 1, 1, 1)
    trainer:draw(x, y - math.floor(3 + scale), camX, camY,
      self.facing, 0, false, true)
    if scale ~= 1 then
      local fx, fy = math.floor(x + 8 - camX), math.floor(y + 12 - camY)
      love.graphics.push()
      love.graphics.translate(fx, fy)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-fx, -fy)
    end
    local rate = self.freeFlying and 8 or 5
    mount:draw(x, y, camX, camY, self.facing,
      math.floor(love.timer.getTime() * rate) % 2, false)
    if scale ~= 1 then love.graphics.pop() end
  end

  local tileShape
  local function voxelHeight(ow)
    if not (Pipelines.get and Pipelines.get("voxel") and Pipelines.level
        and (Pipelines.level("voxel") or 0) > 0) then return 0, false end
    if tileShape == nil then
      tileShape = false
      local exports = game.mods and game.mods.exports
      local lib = exports and exports.DRAMATIC_SHAPE
        and exports.DRAMATIC_SHAPE.lib
      local ok, shape = pcall(function()
        local moduleName = "TileShape"
        return lib and lib.require and lib.require(moduleName)
      end)
      if ok and shape and shape.forMap then tileShape = shape end
    end
    if not tileShape then return 0, true end
    local ok, height = pcall(function()
      local p = ow.player
      local shape = tileShape.forMap(ow.map)[ow.map:cellTile(p.cellX, p.cellY)]
      return shape and shape.art ~= "stair" and math.max(0, shape.h or 0) or 0
    end)
    return ok and height or 0, true
  end

  local function landable(ow, cx, cy)
    if not ow.map:inBounds(cx, cy)
        or ow.map:warpAtCell(cx, cy)
        or Collision.occupied(ow.entities, cx, cy, ow.player) then
      return nil
    end
    if ow.map:isWalkableCell(cx, cy) then return "ground" end
    if ow.map:isWaterCell(cx, cy) and surfAllowed(game, ow) then return "water" end
    return nil
  end

  local function landingPath(ow)
    local p, map = ow.player, ow.map
    local width = map.widthCells or ((map.def.width or 0) * 2)
    if not width or width <= 0 then return nil end
    local start = p.cellY * width + p.cellX
    local seen, parent = { [start] = true }, {}
    local queue, at, water = { { p.cellX, p.cellY, 0 } }, 1, nil
    local function build(key)
      local path = {}
      while key and key ~= start do
        table.insert(path, 1, { key % width, math.floor(key / width) })
        key = parent[key]
      end
      return path
    end
    while queue[at] do
      local row = queue[at]; at = at + 1
      local cx, cy, depth = row[1], row[2], row[3]
      if depth > 0 then
        local kind = landable(ow, cx, cy)
        if kind == "ground" then return build(cy * width + cx) end
        if kind == "water" and not water then water = cy * width + cx end
      end
      if depth < 12 then
        for _, delta in ipairs(LAND_DIRS) do
          local nx, ny = cx + delta[1], cy + delta[2]
          local key = ny * width + nx
          if not seen[key] and map:inBounds(nx, ny) then
            seen[key], parent[key] = true, cy * width + cx
            queue[#queue + 1] = { nx, ny, depth + 1 }
          end
        end
      end
    end
    return water and build(water) or nil
  end

  local function tickFlight(ow, dt)
    local p = ow.player
    if not p then return end
    local sMon = surfMount(ow)
    p.silverSurfMount = sMon
    if not flying() then
      clearPlayerTravel(p)
      p.silverTravelLift = sMon and 2 or nil
      syncRider(ow, sMon ~= nil)
      return
    end
    if not skyAbove(game, ow.map and ow.map.def) then
      finishFlight(game, ow, "indoors", false)
      removeRider(ow)
      return
    end

    if shared.online() and not state.forceReason then
      local safe = not p.moving and landable(ow, p.cellX, p.cellY) or nil
      if safe then
        finishFlight(game, ow, "link", safe == "water")
        removeRider(ow)
        return
      end
      local path = landingPath(ow)
      if path and #path > 0 then
        state.phase, state.approach, state.forceReason = "approach", path, "link"
      end
    end

    dt = dt or 1 / 60
    state.warnCooldown = math.max(0, (state.warnCooldown or 0) - dt)
    p.freeFlying = true
    p.silverTravelMode = "fly"
    p.silverTravelMount = state.mountMon
    local here = not p.moving and landable(ow, p.cellX, p.cellY) or nil
    p.freeFlyCanLand = state.phase == "flying" and here ~= nil

    if state.phase == "rising" then
      state.altitude = math.min(cruiseHeight(), state.altitude + RISE_SPEED * dt)
      if state.altitude >= cruiseHeight() then state.phase = "flying" end
    elseif state.phase == "flying" then
      state.altitude = state.altitude
        + (cruiseHeight() - state.altitude) * math.min(1, dt * 2)
      if state.landRequest then
        state.landRequest = false
        if here then
          state.phase = "landing"
        else
          local path = landingPath(ow)
          if path and #path > 0 then
            state.phase, state.approach = "approach", path
          else
            pcall(function() require("src.core.Sound").play(game.data, "Collision") end)
          end
        end
      end
    elseif state.phase == "approach" then
      state.altitude = state.altitude
        + (cruiseHeight() - state.altitude) * math.min(1, dt * 2)
      if not p.moving then
        local nextCell = state.approach and state.approach[1]
        if not nextCell then
          state.approach = nil
          state.phase = landable(ow, p.cellX, p.cellY) and "landing" or "flying"
        else
          local dir = nextCell[1] > p.cellX and "right"
            or nextCell[1] < p.cellX and "left"
            or nextCell[2] > p.cellY and "down" or "up"
          local result = p:tryMove(dir, ow.map, ow.entities)
          if result == "moved" then table.remove(state.approach, 1)
          elseif result == "blocked" then state.phase, state.approach = "flying", nil end
        end
      end
    elseif state.phase == "landing" then
      state.altitude = math.max(p.moving and 1 or 0,
        state.altitude - RISE_SPEED * dt)
      if state.altitude <= 0 and not p.moving then
        local kind = landable(ow, p.cellX, p.cellY)
        if not kind then state.phase = "flying"
        else
          finishFlight(game, ow, state.forceReason or "landed", kind == "water")
          removeRider(ow)
          return
        end
      end
    end

    state.bob = (state.bob + dt * 4) % (2 * math.pi)
    local visual = state.altitude
    local ground, voxel = voxelHeight(ow)
    local cameraLift = visual
    if voxel then
      local total = math.max(visual * 0.75, 52)
      if state.phase == "rising" or state.phase == "landing" then
        total = total * math.min(1, state.altitude / math.max(1, cruiseHeight()))
      end
      p.freeFlyAlt = math.max(0, total - ground)
      cameraLift = total * 0.68
    else
      p.freeFlyAlt = visual
    end
    p.silverTravelLift = p.freeFlyAlt
    p.silverTravelAltitude = p.freeFlyAlt
    syncRider(ow, true)
    if ow.camera and game.renderer then
      ow.camera:follow(p.px, p.py - cameraLift, game.renderer:worldViewSize())
    end
  end

  if not OC.__silverFlyWrapped then
    OC.__silverFlyWrapped = true
    OC.__silverFlyOrigUpdate = OC.update
    OC.__silverFlyOrigInput = OC.handleInput
    OC.__silverFlyOrigWarp = OC.takeWarp
    OC.__silverFlyOrigSight = OC.checkTrainerSight
    OC.__silverFlyOrigForced = OC.checkForcedMovement
    OC.__silverFlyOrigLedge = OC.checkLedgeHop
    OC.__silverFlyOrigStep = OC.onStepComplete
    OC.__silverFlyOrigCross = OC.crossConnection

    OC.update = function(self, dt)
      OC.__silverFlyOrigUpdate(self, dt)
      local tick = OC.__silverFlyTick
      if tick then
        local ok, err = pcall(tick, self, dt)
        if not ok then print("[SilverShadow Free Fly] " .. tostring(err)) end
      end
    end
    OC.handleInput = function(self, ...)
      local inputGate = OC.__silverFlyInput
      if inputGate and inputGate(self, ...) then return end
      return OC.__silverFlyOrigInput(self, ...)
    end
    OC.takeWarp = function(self, ...)
      if self.player and self.player.freeFlying then return end
      return OC.__silverFlyOrigWarp(self, ...)
    end
    OC.checkTrainerSight = function(self, ...)
      local sightGate = OC.__silverFlySightGate
      if sightGate and sightGate(self) then return end
      return OC.__silverFlyOrigSight(self, ...)
    end
    OC.checkForcedMovement = function(self, ...)
      if self.player and self.player.freeFlying then return false end
      return OC.__silverFlyOrigForced(self, ...)
    end
    OC.checkLedgeHop = function(self, ...)
      if self.player and self.player.freeFlying then return false end
      return OC.__silverFlyOrigLedge(self, ...)
    end
    OC.onStepComplete = function(self, ...)
      if self.player and self.player.freeFlying then
        pcall(function() self:safariStep() end)
        return
      end
      return OC.__silverFlyOrigStep(self, ...)
    end
    OC.crossConnection = function(self, dir, connection)
      local crossGate = OC.__silverFlyCrossGate
      if crossGate and crossGate(self, dir, connection) then return false end
      local crossed = OC.__silverFlyOrigCross(self, dir, connection)
      local after = OC.__silverFlyCrossAfter
      if crossed and after then after(self) end
      return crossed
    end
  end
  OC.__silverFlyTick = tickFlight
  OC.__silverFlyInput = function(ow)
    if ow.player and ow.player.freeFlying and state.phase == "approach" then
      local steering = false
      for direction in pairs(DIRS) do
        if game.input:isDown(direction) then steering = true; break end
      end
      local cancel = game.input:wasPressed("a") or steering
      if cancel and state.forceReason then return true end
      if cancel then
        state.phase, state.approach, state.landRequest = "flying", nil, false
        if not steering then return true end
      end
    end
    if ow.player and ow.player.freeFlying and game.input:wasPressed("a") then
      state.landRequest = true
      return true
    end
    if ow.player and ow.player.freeFlying and game.input:wasPressed("start") then
      if (state.warnCooldown or 0) <= 0 then
        state.warnCooldown = 1
        mod.world:queueScript({ { "show_text", "Land before opening\nthe menu." } })
      end
      return true
    end
    return false
  end
  OC.__silverFlySightGate = function(ow)
    return ow.player and ow.player.freeFlying
      and not enabled("fly_trainer_sight", false)
  end
  OC.__silverFlyCrossGate = function(ow, _, connection)
    if ow.player and ow.player.freeFlying and connection
        and enabled("fly_story_gates", true)
        and storyGateBlocks(game, connection.map) then
      requestWindBack(game)
      return true
    end
    return false
  end
  OC.__silverFlyCrossAfter = function(ow)
    if not (ow.player and ow.player.freeFlying) then return end
    -- crossConnection bypasses tryMove's speed hook.
    local factor = shared.movementMultiplier and shared.movementMultiplier() or 1
    local boost = shared.allowed("fly_boost", shared.BOOST_STATES, "ON")
    local bHeld = game.input and game.input.isDown and game.input:isDown("b")
    local active = (boost == "ON" and not bHeld) or (boost == "HOLD" and bHeld)
    ow.player.stepFramesCur = active
      and math.max(4, math.floor(16 / factor + 0.5)) or 16
    if state.rider then
      for _, entity in ipairs(ow.entities or {}) do
        if entity == state.rider then return end
      end
      table.insert(ow.entities, state.rider)
    end
  end

  if not Map.__silverFlyWrapped then
    Map.__silverFlyWrapped = true
    Map.__silverFlyOrigPassable = Map.defPassable
    Map.defPassable = function(...)
      if Map.__silverFlyActive and Map.__silverFlyActive() then return true end
      return Map.__silverFlyOrigPassable(...)
    end
  end
  Map.__silverFlyActive = flying

  local BattleState = require("src.battle.BattleState")
  if not BattleState.__silverFlyWrapped then
    BattleState.__silverFlyWrapped = true
    BattleState.__silverFlyOrigWild = BattleState.newWild
    BattleState.newWild = function(...)
      if BattleState.__silverFlyGate and BattleState.__silverFlyGate() then
        return nil
      end
      return BattleState.__silverFlyOrigWild(...)
    end
  end
  BattleState.__silverFlyGate = flying

  -- Dramatic Shape first/third-person movement performs collision directly.
  local exports = game.mods and game.mods.exports
  local lib = exports and exports.DRAMATIC_SHAPE and exports.DRAMATIC_SHAPE.lib
  local okMove, FreeMove = pcall(function()
    local moduleName = "FreeMove"
    return lib and lib.require and lib.require(moduleName)
  end)
  if okMove and FreeMove and FreeMove.tick and not FreeMove.__silverFlyWrapped then
    FreeMove.__silverFlyWrapped = true
    local originalTick = FreeMove.tick
    local originalWalkable = Map.isWalkableCell
    local originalOccupied = Collision.occupied
    FreeMove.tick = function(...)
      local active = FreeMove.__silverFlyActive
      if not (active and active()) then return originalTick(...) end
      Map.isWalkableCell = function(self, x, y) return self:inBounds(x, y) end
      Collision.occupied = function() return false end
      local ok, a, b, c = pcall(originalTick, ...)
      Map.isWalkableCell, Collision.occupied = originalWalkable, originalOccupied
      if not ok then error(a, 0) end
      return a, b, c
    end
  end
  if FreeMove then FreeMove.__silverFlyActive = flying end
end)
