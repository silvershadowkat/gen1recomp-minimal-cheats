-- SilverShadow Gen 2 Free Fly
--
-- This is deliberately separate from modules/free_fly.lua. Gold, Silver and
-- Crystal have their own World/Player/FieldMoves classes; sharing the Gen 1
-- controller was the kind of cross-generation mutation that caused the old
-- follower freezes. The public freeFly surface is kept compatible so the
-- follower integration can classify travel sprites the same way in all games.

local mod, shared = ...

local FieldMoves = require("src.world.gen2.FieldMoves")
local Permissions = require("src.world.gen2.Permissions")
local Map = require("src.world.gen2.Map")
local World = require("src.world.gen2.World")
local Player = require("src.world.gen2.Player")
local Camera = require("src.render.Camera")
local SpriteRenderer = require("src.render.SpriteRenderer")
local Game2 = require("src.core.Game2")
local FixedStep = require("src.core.FixedStep")
local Strings = require("src.core.Strings")

local RISE_SPEED = 72
local HEIGHTS = { LOW = 32, MED = 56, HIGH = 80 }
local DIR_CONN = { up = "north", down = "south", left = "west", right = "east" }
local DELTA = {
  up = { 0, -1 }, down = { 0, 1 },
  left = { -1, 0 }, right = { 1, 0 },
}

local state = {
  phase = "idle", altitude = 0, mountMon = nil,
  landRequest = false, bob = 0,
}

local mountSprites = {}
local trainerSprites = {}

local function applyTrainerPalette(world, sprite)
  if not (world and sprite and type(world.applySpritePalette) == "function") then
    return sprite
  end
  -- A separately-created SpriteRenderer does not pass through World:addNpc,
  -- which is where Gen 2 normally applies the active time-of-day OBJ palette.
  -- Refresh it every draw so morning/day/night changes stay correct too.
  pcall(world.applySpritePalette, world, {
    sprite = sprite,
    spriteDef = sprite.def,
  })
  return sprite
end

local function mountSprite(mon)
  local species = mon and mon.species
  if not species then return nil end
  if mountSprites[species] ~= nil then
    return mountSprites[species] or nil
  end
  local providerMod = mod:find("PokePCFollowers_VoxelMerge")
  local provider = providerMod and providerMod.exports
  local resolve = provider and provider.resolveFollowerSprite
  if type(resolve) ~= "function" then
    mountSprites[species] = false
    return nil
  end
  local ok, source = pcall(resolve, { species = species })
  if not (ok and type(source) == "table" and type(source.image) == "string") then
    mountSprites[species] = false
    return nil
  end
  local def = {
    id = "SPRITE_SILVERSHADOW_MOUNT_" .. species,
    image = source.image, frames = source.frames or 6,
    frameWidth = source.frameWidth, frameHeight = source.frameHeight,
    anchorX = source.anchorX, anchorY = source.anchorY,
    walker = source.walker ~= false, trueColor = source.trueColor ~= false,
  }
  local made, sprite = pcall(SpriteRenderer.new, def,
    "silvershadow_gen2_mount_" .. species)
  mountSprites[species] = made and sprite or false
  return made and sprite or nil
end

local function trainerSprite(world)
  local name = world and type(world.playerSpriteName) == "function"
    and world:playerSpriteName() or "SPRITE_CHRIS"
  if trainerSprites[name] ~= nil then
    return applyTrainerPalette(world, trainerSprites[name] or nil)
  end
  local def = world and world.sprites and world.sprites[name]
  if not def then
    trainerSprites[name] = false
    return nil
  end
  local made, sprite = pcall(SpriteRenderer.new, def,
    "silvershadow_gen2_surf_trainer_" .. tostring(name))
  trainerSprites[name] = made and sprite or false
  return applyTrainerPalette(world, made and sprite or nil)
end

local function enabled(key, default)
  return shared.bool(key, default)
end

-- Gen 2's menu and contextual HM paths all consult this one function. Keep
-- the real badge store intact, but let SilverShadow's BADGE CHECK switch be
-- the single, consistent gate for CUT/FLASH/SURF/FLY/STRENGTH/WHIRLPOOL and
-- WATERFALL. Battle badge boosts use their own reader and are unaffected.
if not FieldMoves.__silverBadgeCheckWrapped then
  FieldMoves.__silverBadgeCheckWrapped = true
  FieldMoves.__silverBadgeCheckOriginal = FieldMoves.hasBadge
  FieldMoves.hasBadge = function(save, badge)
    local bypass = FieldMoves.__silverBadgeBypass
    if bypass and bypass() then return true end
    return FieldMoves.__silverBadgeCheckOriginal(save, badge)
  end
end
FieldMoves.__silverBadgeBypass = function()
  return not enabled("fly_badge_checks", true)
end

local function worldFor(game)
  return game and (game.world or game.overworld) or nil
end

local function currentWorld()
  return worldFor(shared.game)
end

local function flying()
  return state.phase ~= "idle"
end

local function cruiseHeight()
  return HEIGHTS[shared.allowed("fly_height", shared.FLY_HEIGHTS, "MED")] or 56
end

local function healthy(mon)
  return type(mon) == "table" and type(mon.species) == "string"
    and mon.species ~= "" and (tonumber(mon.hp) or 0) > 0
end

local function moveId(move)
  return type(move) == "table" and move.id or move
end

local function knowsMove(mon, wanted)
  for _, move in ipairs((mon and mon.moves) or {}) do
    if moveId(move) == wanted then return true end
  end
  return false
end

local function firstHealthyKnower(game, wanted)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if healthy(mon) and knowsMove(mon, wanted) then return mon end
  end
  return nil
end

local function hasType(game, mon, wanted)
  local def = mon and game and game.data and game.data.pokemon
    and game.data.pokemon[mon.species]
  for _, kind in ipairs((def and def.types) or {}) do
    if kind == wanted then return true end
  end
  return false
end

local function badgeAllowed(game, move)
  if not enabled("fly_badge_checks", true) then return true end
  return FieldMoves.hasBadge(game and game.save, FieldMoves.BADGE[move])
end

local function outdoors(world)
  local environment = world and world.map and world.map.def
    and world.map.def.environment
  return environment == "ROUTE" or environment == "TOWN"
end

local function eligibleFlyer(game, mon)
  -- Knowledge is authoritative. This intentionally has no species/TM-HM
  -- compatibility lookup, so a move-editor FLY works on any healthy Pokemon.
  return healthy(mon) and (knowsMove(mon,"FLY") or (shared.bool("hm_device",true)
    and shared.ownsFieldMachine and shared.ownsFieldMachine(game,"FLY")))
end

local function surfAllowed(game)
  return (firstHealthyKnower(game,"SURF")~=nil or (shared.bool("hm_device",true)
    and shared.ownsFieldMachine and shared.ownsFieldMachine(game,"SURF")))
    and badgeAllowed(game, "SURF")
end

local function surfMount(world)
  if not (world and world.player
      and FieldMoves.isSurfing(world.playerState)) then return nil end
  local mon = world.player.silverSurfMount
  if healthy(mon) and knowsMove(mon, "SURF") then return mon end
  mon = firstHealthyKnower(world.game or shared.game, "SURF")
  if healthy(mon) then
    world.player.silverSurfMount = mon
    return mon
  end
  return nil
end

local function setMapMusic(world)
  if world and world.map and type(world.setMapMusic) == "function" then
    pcall(world.setMapMusic, world, world.map.id, false)
  end
end

local function clearPlayer(player)
  if not player then return end
  player.freeFlying = nil
  player.freeFlyAlt = nil
  player.freeFlyCanLand = nil
  player.silverTravelMode = nil
  player.silverTravelMount = nil
  player.silverTravelAltitude = nil
  player.spriteYOffset = 0
  player.inGrass, player.grassShake = false, nil
end

local function setFlightPlayer(world)
  local player = world and world.player
  if not player then return end
  if FieldMoves.isSurfing(world.playerState) then
    world:applyPlayerState(FieldMoves.PLAYER_NORMAL)
  end
  player.freeFlying = true
  player.surfing = false
  player.silverTravelMode = "fly"
  player.silverTravelMount = state.mountMon
  player.silverTravelAltitude = state.altitude
  player.freeFlyAlt = state.altitude
  player.spriteYOffset = -math.floor(state.altitude + 0.5)
  player.inGrass, player.grassShake = false, nil
end

local function occupied(world, x, y)
  for _, entity in ipairs((world and world.entities) or {}) do
    if entity ~= world.player and not entity.passable then
      if entity.cellX == x and entity.cellY == y then return true end
      if entity.moving and entity.targetX == x and entity.targetY == y then
        return true
      end
    end
  end
  return false
end

local function landingKind(game, world)
  if not (world and world.map and world.player) then return nil end
  local x, y = world.player.cellX, world.player.cellY
  if occupied(world, x, y) then return nil end
  local collision = world.map:cellCollision(x, y)
  if Permissions.isWater(collision) then
    return surfAllowed(game) and "water" or nil
  end
  if world.map:isWalkableCell(x, y) then return "land" end
  return nil
end

local function finishFlight(game, world, reason)
  local kind = landingKind(game, world)
  if not kind then return false end
  local player = world.player
  local mount = state.mountMon
  state.phase, state.altitude = "idle", 0
  state.mountMon, state.landRequest = nil, false
  clearPlayer(player)
  if kind == "water" then
    local surfer = firstHealthyKnower(game, "SURF")
    world:applyPlayerState(FieldMoves.surfType(surfer))
    player.surfing = true
    player.silverSurfMount = surfer
    player.silverTravelMode = "surf"
  else
    world:applyPlayerState(FieldMoves.PLAYER_NORMAL)
    player.surfing = false
    player.silverSurfMount = nil
  end
  setMapMusic(world)
  if mod.events and mod.events.emit then
    pcall(mod.events.emit, mod.events, "mod.silvershadow.fly.landed", {
      reason = reason or "landed", water = kind == "water",
      species = mount and mount.species,
      x = player.cellX, y = player.cellY,
    })
  end
  return true
end

local function startFlight(game, mon)
  local world = worldFor(game)
  if flying() or shared.online() or not outdoors(world) then
    return false, "location"
  end
  if FieldMoves.isBiking(world.playerState) then return false, "bike" end
  if not eligibleFlyer(game, mon) then return false, "move" end
  if not badgeAllowed(game, "FLY") then return false, "badge" end
  if world:busy() or (world.player and world.player.moving) then
    return false, "busy"
  end
  state.phase, state.altitude = "rising", 0
  state.mountMon, state.landRequest, state.bob = mon, false, 0
  setFlightPlayer(world)
  setMapMusic(world)
  if mod.events and mod.events.emit then
    pcall(mod.events.emit, mod.events, "mod.silvershadow.fly.takeoff", {
      species = mon.species, level = mon.level,
    })
  end
  return true
end

local function classify(game, mon, travelMode, overWater, overLand)
  local canFly = hasType(game, mon, "FLYING") or knowsMove(mon, "FLY")
  local canSurf = knowsMove(mon, "SURF") or hasType(game,mon,"WATER")
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
    if overLand then return "ground" end
    return nil
  end
  if canFly then return "air" end
  if canHover then return "hover" end
  if canSurf then return "surf" end
  return nil
end

mod.exports.freeFly = {
  generation = 2,
  isFlying = flying,
  altitude = function() return flying() and state.altitude or 0 end,
  mount = function() return flying() and state.mountMon or nil end,
  surfMount = surfMount,
  eligible = eligibleFlyer,
  surfAllowed = function(game) return surfAllowed(game) end,
  classify = classify,
  _start = startFlight,
  _landingKind = landingKind,
  _state = state,
  _badgeAllowed = badgeAllowed,
  _trainerSprite = trainerSprite,
}

shared.registerPartyDecorator("gen2_free_fly", 5,
  function(game, out, mon, ctx)
    local world = ctx and ctx.overworld or worldFor(game)
    if type(out) ~= "table" or (ctx and ctx.battle) or flying()
        or shared.online() or not outdoors(world)
        or FieldMoves.isBiking(world and world.playerState) then return out end
    if not eligibleFlyer(game, mon) then return out end
    for _, item in ipairs(out) do
      if tostring(item.label or ""):upper() == "FREEFLY" then return out end
    end
    table.insert(out, 1, {
      id = "SILVERSHADOW_FREEFLY", label = "FREEFLY",
      onSelect = function(selected, selectedGame)
        local g = selectedGame or game
        local ok, reason = startFlight(g, selected or mon)
        if ok then
          local stack = g and g.stack
          if stack and type(stack.clear) == "function" then stack:clear() end
          return
        end
        local current = worldFor(g)
        if current and type(current.showText) == "function" then
          local text = reason == "badge" and FieldMoves.TEXT.BADGE_REQUIRED
            or FieldMoves.TEXT.CANT_USE_HERE
          pcall(current.showText, current, Strings(text))
        end
      end,
    })
    return out
  end)

-- The player may pass scenery while airborne. With STORY GATES enabled,
-- ordinary NPCs still block the cell so a scripted guard cannot be skipped;
-- trainers are safe to overfly because their sight event is gated separately.
mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
  if not (flying() and ctx and ctx.mover and ctx.mover.freeFlying) then
    return next(allowed, ctx)
  end
  if ctx.reason == "tile" then
    ctx.reason = nil
    return true
  end
  if ctx.reason == "entity" then
    local permit = not enabled("fly_story_gates", true)
    if not permit then
      local world = currentWorld()
      for _, entity in ipairs((world and world.entities) or {}) do
        if entity ~= ctx.mover
            and ((entity.cellX == ctx.toX and entity.cellY == ctx.toY)
              or (entity.moving and entity.targetX == ctx.toX
                and entity.targetY == ctx.toY)) then
          permit = entity.def and entity.def.trainer ~= nil
          break
        end
      end
    end
    if permit then ctx.reason = nil; return true end
  end
  return next(allowed, ctx)
end)

mod.hooks:wrap("encounter.roll", function(next, encounter, ctx)
  if flying() then return nil end
  return next(encounter, ctx)
end)

mod.hooks:wrap("save.write", function(next, game, ...)
  if flying() then
    mod.log:warn("land before saving")
    return false
  end
  return next(game, ...)
end)

local function tickFlight(world, dt)
  if not flying() then return end
  local game = world and world.game or shared.game
  if not (game and world and world.player and world.map) then return end
  if not outdoors(world) then
    -- A script/teleport that forcibly moves indoors cannot leave the save in
    -- an airborne state. It lands only on a legal cell; otherwise it safely
    -- clears flight and restores normal movement.
    if not finishFlight(game, world, "indoors") then
      state.phase, state.altitude = "idle", 0
      state.mountMon, state.landRequest = nil, false
      clearPlayer(world.player)
      world:applyPlayerState(FieldMoves.PLAYER_NORMAL)
    end
    return
  end

  local target = cruiseHeight()
  if state.phase == "rising" then
    state.altitude = math.min(target, state.altitude + RISE_SPEED * dt)
    if state.altitude >= target then state.phase = "flying" end
  elseif state.phase == "flying" then
    state.altitude = state.altitude
      + (target - state.altitude) * math.min(1, dt * 5)
    if state.landRequest then
      state.landRequest = false
      if landingKind(game, world) then state.phase = "landing" end
    end
  elseif state.phase == "landing" then
    if not landingKind(game, world) then
      state.phase = "rising"
    else
      state.altitude = math.max(0, state.altitude - RISE_SPEED * dt)
      if state.altitude <= 0 and not world.player.moving then
        if finishFlight(game, world, "landed") then return end
        state.phase = "rising"
      end
    end
  end

  state.bob = (state.bob + dt * 4) % (2 * math.pi)
  setFlightPlayer(world)
  world.player.freeFlyCanLand = landingKind(game, world) ~= nil
end

mod.exports.freeFly._tick = tickFlight
mod.exports.freeFly._finish = finishFlight

-- Class wrappers use replaceable implementation cells so a development reload
-- updates SilverShadow's behavior without stacking another wrapper.
if not World.__silverGen2FlyWrapped then
  World.__silverGen2FlyWrapped = true
  World.__silverGen2FlyOrigStep = World.step
  World.__silverGen2FlyOrigInteract = World.interact
  World.__silverGen2FlyOrigSight = World.checkTrainerBattle
  World.__silverGen2FlyOrigWarp = World.checkWarpOnArrive
  World.__silverGen2FlyOrigCarpet = World.checkCarpetWhileStanding
  World.__silverGen2FlyOrigCoord = World.tryCoordScript
  World.__silverGen2FlyOrigForced = World.runForcedMovement
  World.__silverGen2FlyOrigLedge = World.tryLedgeJump
  World.__silverGen2FlyOrigCount = World.countStep
  World.__silverGen2FlyOrigConnection = World.tryConnection
  World.__silverGen2FlyOrigPlayerCollision = World.playerCollision

  World.step = function(self, ...)
    local result = World.__silverGen2FlyOrigStep(self, ...)
    local tick = World.__silverGen2FlyTick
    if tick then
      local ok, err = pcall(tick, self, 1 / 60)
      if not ok then print("[SilverShadow Gen 2 Free Fly] " .. tostring(err)) end
    end
    return result
  end
  World.interact = function(self, ...)
    local gate = World.__silverGen2FlyInteract
    if gate and gate(self) then return true end
    return World.__silverGen2FlyOrigInteract(self, ...)
  end
  World.checkTrainerBattle = function(self, ...)
    local gate = World.__silverGen2FlySightGate
    if gate and gate(self) then return false end
    return World.__silverGen2FlyOrigSight(self, ...)
  end
  World.checkWarpOnArrive = function(self, ...)
    if self.player and self.player.freeFlying then return false end
    return World.__silverGen2FlyOrigWarp(self, ...)
  end
  World.checkCarpetWhileStanding = function(self, ...)
    if self.player and self.player.freeFlying then return false end
    return World.__silverGen2FlyOrigCarpet(self, ...)
  end
  World.tryCoordScript = function(self, ...)
    if self.player and self.player.freeFlying then return false end
    return World.__silverGen2FlyOrigCoord(self, ...)
  end
  World.runForcedMovement = function(self, ...)
    if self.player and self.player.freeFlying then return false end
    return World.__silverGen2FlyOrigForced(self, ...)
  end
  World.tryLedgeJump = function(self, ...)
    if self.player and self.player.freeFlying then return false end
    return World.__silverGen2FlyOrigLedge(self, ...)
  end
  World.countStep = function(self, ...)
    if self.player and self.player.freeFlying then return false end
    return World.__silverGen2FlyOrigCount(self, ...)
  end
  World.playerCollision = function(self, ...)
    -- A neutral LAND collision prevents currents, waterfalls, ice, ledges and
    -- door carpets under the airborne player from overriding held direction.
    if self.player and self.player.freeFlying then return 0 end
    return World.__silverGen2FlyOrigPlayerCollision(self, ...)
  end
  World.tryConnection = function(self, dir, ...)
    if not (self.player and self.player.freeFlying) then
      return World.__silverGen2FlyOrigConnection(self, dir, ...)
    end
    -- First preserve every native land-side permission and connection rule.
    local crossed = World.__silverGen2FlyOrigConnection(self, dir, ...)
    if crossed then return crossed end
    -- Then try the native Surf arm, allowing legitimate ocean connections.
    local savedState = self.playerState
    self.playerState = FieldMoves.PLAYER_SURF
    crossed = World.__silverGen2FlyOrigConnection(self, dir, ...)
    if crossed then return crossed end
    self.playerState = savedState

    -- STORY GATES OFF is the explicit unrestricted mode. It may cross a
    -- connection whose landing strip is scenery, while still refusing indoor
    -- destinations and preserving bounds/connection metadata.
    if enabled("fly_story_gates", true) then return false end
    local key = DIR_CONN[dir]
    local connection = key and self.map:connection(key)
    local dest = connection and connection.mapId and self.maps[connection.mapId]
    if not (dest and (dest.environment == "ROUTE" or dest.environment == "TOWN")) then
      return false
    end
    local x, y = Map.connectionLanding(
      dest, connection, dir, self.player.cellX, self.player.cellY)
    if not x then return false end
    local p, d = self.player, DELTA[dir]
    if not self:setMap(connection.mapId, x, y, dir, { seamless = true }) then
      return false
    end
    p.cellX, p.cellY = x - d[1], y - d[2]
    p.px, p.py = p.cellX * 16, p.cellY * 16
    p.facing, p.targetX, p.targetY = dir, x, y
    p.moving, p.bumpFrames, p.progress = true, nil, 0
    FixedStep:discardCatchup()
    return true
  end
end

World.__silverGen2FlyTick = tickFlight
World.__silverGen2FlyInteract = function(world)
  if not (world.player and world.player.freeFlying) then return false end
  state.landRequest = true
  return true
end
World.__silverGen2FlySightGate = function(world)
  return world.player and world.player.freeFlying
    and not enabled("fly_trainer_sight", false)
end

if not Game2.__silverGen2FlyWrapped then
  Game2.__silverGen2FlyWrapped = true
  Game2.__silverGen2FlyOrigStartMenu = Game2.openStartMenu
  Game2.__silverGen2FlyOrigSelect = Game2.useSelectItem
  Game2.openStartMenu = function(self, ...)
    if self.world and self.world.player and self.world.player.freeFlying then
      return false
    end
    return Game2.__silverGen2FlyOrigStartMenu(self, ...)
  end
  Game2.useSelectItem = function(self, ...)
    if self.world and self.world.player and self.world.player.freeFlying then
      return false
    end
    return Game2.__silverGen2FlyOrigSelect(self, ...)
  end
end

if not Camera.__silverGen2FlyWrapped then
  Camera.__silverGen2FlyWrapped = true
  Camera.__silverGen2FlyOrigFollow = Camera.follow
  Camera.follow = function(self, px, py, viewW, viewH)
    local lift = 0
    local world = currentWorld()
    if world and world.camera == self and world.player
        and world.player.freeFlying then
      lift = tonumber(world.player.silverTravelAltitude) or 0
    end
    return Camera.__silverGen2FlyOrigFollow(self, px, py - lift, viewW, viewH)
  end
end

-- Remember the actual party member used by both native Surf entry paths.
-- Gen 2's stock player state only remembers "surf" and therefore falls back
-- to the generic Lapras sheet; this adds the missing identity without changing
-- the save format or the engine's movement/terrain rules.
if not World.__silverGen2SurfMountWrapped then
  World.__silverGen2SurfMountWrapped = true
  World.__silverGen2SurfOrigRun = World.runSurf
  World.__silverGen2SurfOrigStart = World.surfStartStep
  World.__silverGen2SurfOrigApplyState = World.applyPlayerState

  World.runSurf = function(self, result, ...)
    if self.player and result and healthy(result.mon) then
      self.player.silverSurfMount = result.mon
    end
    return World.__silverGen2SurfOrigRun(self, result, ...)
  end

  World.surfStartStep = function(self, mon, ...)
    if self.player and healthy(mon) then self.player.silverSurfMount = mon end
    return World.__silverGen2SurfOrigStart(self, mon, ...)
  end

  World.applyPlayerState = function(self, nextState, ...)
    local result = World.__silverGen2SurfOrigApplyState(self, nextState, ...)
    if self.player then
      if FieldMoves.isSurfing(self.playerState) then
        self.player.silverSurfMount = self.player.silverSurfMount
          or firstHealthyKnower(self.game or shared.game, "SURF")
        self.player.silverTravelMode = "surf"
      elseif not self.player.freeFlying then
        self.player.silverSurfMount = nil
        self.player.silverTravelMode = nil
      end
    end
    return result
  end
end

if not Player.__silverGen2FlyDrawWrapped then
  Player.__silverGen2FlyDrawWrapped = true
  Player.__silverGen2FlyOrigDraw = Player.draw
  Player.draw = function(self, ox, oy, scale)
    local world = currentWorld()
    local flyingNow = world and world.player == self
      and self.freeFlying and flying()
    local surfer = not flyingNow and world and world.player == self
      and surfMount(world) or nil
    if not flyingNow and not surfer then
      return Player.__silverGen2FlyOrigDraw(self, ox, oy, scale)
    end
    local mountMon = flyingNow and state.mountMon or surfer
    local mount = mountSprite(mountMon)
    local normalSprite = surfer and trainerSprite(world) or nil
    if not (mount and love and love.graphics)
        or (surfer and not normalSprite) then
      return Player.__silverGen2FlyOrigDraw(self, ox, oy, scale)
    end
    local G = love.graphics
    local yOffset = self.spriteYOffset or 0
    local phase = math.floor((world.silverTravelAnimFrame or 0) / 7) % 2
    G.push()
    G.translate(ox or 0, oy or 0)
    G.scale(scale or 1, scale or 1)
    mount:draw(self.px, self.py + yOffset + 4, 0, 0,
      self.facing, phase, self.stepFlip)
    G.pop()
    -- Tuck the trainer into the mount rather than drawing two full sprites on
    -- the same baseline. Restore the offset immediately after the original.
    local oldSprite, oldDef = self.sprite, self.spriteDef
    if surfer then self.sprite, self.spriteDef = normalSprite, normalSprite.def end
    self.spriteYOffset = yOffset - 5
    local ok, result = pcall(Player.__silverGen2FlyOrigDraw,
      self, ox, oy, scale)
    self.spriteYOffset = yOffset
    self.sprite, self.spriteDef = oldSprite, oldDef
    if not ok then error(result, 0) end
    return result
  end
end

mod.events:on("map.entered", function()
  local world = currentWorld()
  if flying() then
    if world and outdoors(world) then setFlightPlayer(world) end
  elseif world and world.player and FieldMoves.isSurfing(world.playerState) then
    surfMount(world)
  end
end)

mod.events:on("save.loaded", function()
  state.phase, state.altitude, state.mountMon = "idle", 0, nil
  state.landRequest = false
  local world = currentWorld()
  if world and world.player then clearPlayer(world.player) end
end)

mod.events:on("world.blacked_out", function()
  if not flying() then return end
  local world = currentWorld()
  state.phase, state.altitude, state.mountMon = "idle", 0, nil
  state.landRequest = false
  if world and world.player then clearPlayer(world.player) end
end)

return mod.exports.freeFly
