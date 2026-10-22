-- Native Gold/Silver/Crystal multi-follower controller.
-- PokePC owns the primary follower and every sprite asset. SilverShadow only
-- adds the remaining party members to the live Gen 2 World as native Npcs.
return function(mod, assetMod, shared)
  local Transitions = assert(mod.exports.followerTransitions)
  local NPC = require("src.world.NPC")
  local Follower = require("src.world.PikachuFollower")
  local FieldMoves = require("src.world.gen2.FieldMoves")
  local Permissions = require("src.world.gen2.Permissions")
  local provider = assetMod and assetMod.exports or {}
  local followerCount = tonumber(shared.get("follower_count", 1)) or 1
  local controlMode = "follow"
  local syncPhase = "not started"
  local activatedSaves = setmetatable({}, { __mode = "k" })

  local function worldFor(game)
    return game and (game.world or game.overworld) or nil
  end

  local function healthy(mon)
    return type(mon) == "table" and type(mon.species) == "string"
      and mon.species ~= "" and (tonumber(mon.hp) or 0) > 0
  end

  local function integrationReady(game, world)
    if not (game and game.save and world and world.player and world.map) then
      return false
    end
    local party = game.save.party or {}
    local hasParty = false
    for i = 1, math.min(#party, 6) do
      if healthy(party[i]) then hasParty = true; break end
    end
    if not hasParty then return false end
    if activatedSaves[game.save] then return true end
    local runner = world.runner
    if runner and type(runner.isRunning) == "function" then
      local ok, running = pcall(runner.isRunning, runner)
      if ok and running then return false end
    end
    local stack = game.stack
    if stack and type(stack.top) == "function" then
      local ok, top = pcall(stack.top, stack)
      if ok and top and top ~= world then return false end
    end
    activatedSaves[game.save] = true
    return true
  end

  local function activeMon(game)
    if type(provider.activeMon) == "function" then
      local ok, mon = pcall(provider.activeMon, game)
      if ok and healthy(mon) then return mon end
    end
    local party = game and game.save and game.save.party or {}
    for i = 1, math.min(#party, 6) do
      if healthy(party[i]) then return party[i] end
    end
  end

  local function travelMode(world)
    if world and world.player and world.player.freeFlying then return "fly" end
    if world and FieldMoves.isSurfing(world.playerState) then return "surf" end
    return nil
  end

  local function travelMount(world)
    local freeFly = mod.exports.freeFly
    if not freeFly then return nil end
    if world and world.player and world.player.freeFlying
        and type(freeFly.mount) == "function" then
      return freeFly.mount()
    end
    if world and FieldMoves.isSurfing(world.playerState)
        and type(freeFly.surfMount) == "function" then
      return freeFly.surfMount(world)
    end
    return nil
  end

  local function terrainFor(world, entity)
    if not (world and world.map and entity) then return false, false end
    local x = entity.targetX or entity.cellX
    local y = entity.targetY or entity.cellY
    if x == nil or y == nil then return false, false end
    local water = Permissions.isWater(world.map:cellCollision(x, y)) == true
    local land = type(world.map.isWalkableCell) == "function"
      and world.map:isWalkableCell(x, y) == true
    return water, land
  end

  local function travelStyle(game, world, mon, entity)
    local mode = travelMode(world)
    if not mode then return nil, nil end
    local freeFly = mod.exports.freeFly
    if not (freeFly and type(freeFly.classify) == "function") then
      return nil, mode
    end
    if travelMount(world) == mon then
      -- The selected FLY or SURF user is drawn under the trainer as the mount,
      -- not duplicated in the trailing formation.
      return nil, mode
    end
    local water, land = terrainFor(world, entity or world.player)
    return freeFly.classify(game, mon, mode, water, land), mode
  end

  local function visibleCount()
    if controlMode == "follow" then return followerCount end
    -- The shared UI expresses Pokemon-front counts as trailers; Gen 2 keeps
    -- the trainer in front for now, so retain the requested visible total.
    return followerCount + 1
  end

  local function primaryEligible(game, world)
    if visibleCount() <= 0 then return false end
    local mon = activeMon(game)
    if not mon or travelMount(world) == mon then return false end
    local style, mode = travelStyle(game, world, mon, world and world.player)
    if mode then return style ~= nil end
    if type(provider.shouldSpawn) == "function" then
      local ok, result = pcall(provider.shouldSpawn, game, world)
      return ok and result == true
    end
    return true
  end

  local function wantedExtras(game, world)
    local want = {}
    local leader = activeMon(game)
    local party = game and game.save and game.save.party or {}
    local lead = primaryEligible(game, world) and 1 or 0
    local limit = math.max(0, math.min(5, visibleCount() - lead))
    for i = 1, math.min(#party, 6) do
      local mon = party[i]
      if healthy(mon) and mon ~= leader then
        local style, mode = travelStyle(game, world, mon, world and world.player)
        if not mode or style then want[#want + 1] = mon end
        if #want >= limit then break end
      end
    end
    return want
  end

  local function removeExtras(world)
    if not world then return end
    for i = #(world.npcs or {}), 1, -1 do
      if world.npcs[i] and world.npcs[i].silverGen2Follower then
        table.remove(world.npcs, i)
      end
    end
    for i = #(world.entities or {}), 1, -1 do
      if world.entities[i] and world.entities[i].silverGen2Follower then
        table.remove(world.entities, i)
      end
    end
    world.silverGen2Followers = {}
    world.silverGen2FollowerHistory = nil
    world.silverGen2FollowerLeadSlots = nil
  end

  local function spriteDef(mon, slot)
    local resolve = provider.resolveFollowerSprite
    local def
    if type(resolve) == "function" then
      local ok, value = pcall(resolve, { species = mon.species })
      if ok and type(value) == "table" then def = value end
    end
    if not def and type(provider.assetPath) == "function" then
      local ok, path = pcall(provider.assetPath, mon.species)
      if ok and type(path) == "string" then def = { image = path } end
    end
    if not (def and type(def.image) == "string") then return nil end
    return {
      id = "SPRITE_SILVER_GEN2_" .. tostring(slot),
      image = def.image,
      frames = def.frames or 6,
      walker = def.walker ~= false,
      trueColor = def.trueColor ~= false,
      pokepcFollowerSpecies = mon.species,
    }
  end

  local function compositionMatches(game, world, want)
    local current = world and world.silverGen2Followers or {}
    if #current ~= #want then return false end
    -- Reserve the primary's cell from eligibility, not from a one-frame entity
    -- snapshot. PokePC may rebuild that entity during Surf/map transitions;
    -- allowing the slot count to flap makes every later follower jump forward.
    local lead = primaryEligible(game, world) and 1 or 0
    if world.silverGen2FollowerLeadSlots ~= lead then return false end
    for i = 1, #want do
      if not current[i] or current[i].silverGen2Species ~= want[i].species then
        return false
      end
      if current[i].pokepcMon ~= want[i] then return false end
      local alive = false
      for j = 1, #(world.npcs or {}) do
        if world.npcs[j] == current[i] then alive = true; break end
      end
      if not alive or current[i].mapId ~= world.map.id then return false end
    end
    return true
  end

  local function behindCell(world, px, py, facing, steps)
    local dx = facing == "left" and 1 or facing == "right" and -1 or 0
    local dy = facing == "up" and 1 or facing == "down" and -1 or 0
    local x, y = px, py
    for i = 1, steps do
      local nx, ny = px + dx * i, py + dy * i
      if not world.map:inBounds(nx, ny)
          or not (travelMode(world) or world.map:isWalkableCell(nx, ny)) then break end
      x, y = nx, ny
    end
    return { x = x, y = y }
  end

  local function rebuild(game, world)
    removeExtras(world)
    if not (world and world.map and world.player) then return end
    local want = wantedExtras(game, world)
    local lead = primaryEligible(game, world) and 1 or 0
    local px, py = world.player.cellX, world.player.cellY
    local facing = world.player.facing or "down"
    local history = { { x = px, y = py } }
    for i = 1, #want + lead do
      history[i + 1] = world.silverFollowerWarp
        and { x = px, y = py } or behindCell(world, px, py, facing, i)
    end
    local trailers = {}
    for i = 1, #want do
      local def = spriteDef(want[i], i)
      if def then
        -- An eligible primary keeps its cell even while PokePC rebuilds it;
        -- hidden/ineligible primaries and the mounted SURF Pokemon do not.
        local start = history[i + 1 + lead] or history[#history]
        local npc = NPC.new(world.map.id, {
          index = 250 + i,
          name = "SILVER_FOLLOWER_" .. tostring(i),
          sprite = def.id,
          movement = NPC.MOVE.STANDING_DOWN,
          x = start.x, y = start.y,
        }, def)
        npc.silverGen2Follower = true
        npc.silverGen2Species = want[i].species
        npc.pokepcMon = want[i]
        npc.passable = true
        npc.frozen = true
        npc.facing = world.player.facing or "down"
        trailers[#trailers + 1] = npc
        table.insert(world.npcs, npc)
        table.insert(world.entities, npc)
      end
    end
    world.silverGen2Followers = trailers
    world.silverGen2FollowerHistory = history
    world.silverGen2FollowerLeadSlots = lead
    world.silverFollowerWarp = nil
  end

  local function moveTo(npc, goal, frames, world)
    if not (npc and goal) or npc.moving then return end
    local dx, dy = goal.x - npc.cellX, goal.y - npc.cellY
    local distance = math.abs(dx) + math.abs(dy)
    if distance == 0 then return end
    if distance > 1 then
      npc.cellX, npc.cellY = goal.x, goal.y
      npc.px, npc.py = goal.x * 16, goal.y * 16
      npc.targetX, npc.targetY = nil, nil
      npc.moving, npc.progress = false, 0
      return
    end
    npc.facing = dx > 0 and "right" or dx < 0 and "left"
      or dy > 0 and "down" or "up"
    npc.targetX, npc.targetY = goal.x, goal.y
    npc.stepFrames = math.max(1, tonumber(frames) or 16)
    npc.progress, npc.moving, npc.frozen = 0, true, true
    -- Follower.update runs after World:updatePeople. Burn the same first frame
    -- as Gold's native primary follower so the whole chain stays phase-aligned.
    if world and npc.update then npc:update(world.map, world.entities) end
  end

  local function syncAll(game, world)
    syncPhase = "composition"
    world = world or worldFor(game)
    if not (game and world and world.player and world.map) then return end
    if world.silverFollowerConnection then return end
    local want = wantedExtras(game, world)
    if world.silverFollowerWarp or not compositionMatches(game, world, want) then rebuild(game, world) end
    syncPhase = "complete"
  end

  local function animateTravel(game, world)
    if not (world and world.player) then return end
    world.silverTravelAnimFrame = (world.silverTravelAnimFrame or 0) + 1
    local frame = world.silverTravelAnimFrame
    local mode = travelMode(world)
    local playerLift = tonumber(world.player.silverTravelAltitude) or 0

    local function apply(npc, mon)
      if not npc then return end
      local style = mode and travelStyle(game, world, mon, npc) or nil
      npc.silverTravelStyle = style
      npc.silverTravelAnimFrame = frame
      if not style then
        npc.spriteYOffset = 0
      elseif mode == "fly" and (style == "air" or style == "hover") then
        local bob = math.floor(frame / 7) % 2
        npc.spriteYOffset = -math.floor(playerLift + 0.5) - bob
      elseif mode == "surf" and style == "air" then
        npc.spriteYOffset = -10 - (math.floor(frame / 7) % 2)
      elseif mode == "surf" and style == "hover" then
        npc.spriteYOffset = -6 - (math.floor(frame / 9) % 2)
      elseif style == "surf" then
        npc.spriteYOffset = math.floor(frame / 12) % 2
      else
        npc.spriteYOffset = 0
      end
    end

    apply(world.follower, activeMon(game))
    for _, npc in ipairs(world.silverGen2Followers or {}) do
      apply(npc, npc.pokepcMon)
    end
  end

  if not NPC.__silverTravelWalkWrapped then
    NPC.__silverTravelWalkWrapped = true
    NPC.__silverTravelOrigWalkPhase = NPC.walkPhase
    NPC.walkPhase = function(self, ...)
      if self.silverTravelStyle == "air" or self.silverTravelStyle == "hover" then
        return math.floor((self.silverTravelAnimFrame or 0) / 7) % 2
      end
      if self.silverTravelStyle == "surf" then
        return math.floor((self.silverTravelAnimFrame or 0) / 12) % 2
      end
      return NPC.__silverTravelOrigWalkPhase(self, ...)
    end
  end

  local function step(game)
    local world = worldFor(game)
    if not (world and world.player and world.map) then return end
    local want = wantedExtras(game, world)
    if not compositionMatches(game, world, want) then rebuild(game, world) end
    local trailers = world.silverGen2Followers or {}
    local lead = world.silverGen2FollowerLeadSlots or 0
    -- Gold commits the primary follower at movement START using targetX/Y,
    -- not at the later world.stepped landing event. Follow the same clock.
    local px = world.player.targetX or world.player.cellX
    local py = world.player.targetY or world.player.cellY
    local history = world.silverGen2FollowerHistory
      or { { x = px, y = py } }
    local newest = history[1]
    if not (newest and px == newest.x and py == newest.y) then
      table.insert(history, 1, { x = px, y = py })
      while #history > #trailers + lead + 1 do table.remove(history) end
      world.silverGen2FollowerHistory = history
      local frames = world.player.stepFrames or 16
      for i = 1, #trailers do
        moveTo(trailers[i], history[i + 1 + lead] or history[#history], frames, world)
      end
    end
    animateTravel(game, world)
  end

  -- PokePC already wraps this function. Compose after it so its primary
  -- follower chooses a goal first, then advance every extra from the same
  -- player target and on the same logic frame.
  local originalFollowerUpdate = Follower.update
  local wrappedFollowerUpdate = function(game, world, ...)
    local result = originalFollowerUpdate(game, world, ...)
    step(game)
    return result
  end
  Follower.update = wrappedFollowerUpdate

  -- PokePC's Gen 2 map-entry wrapper has a private stock rule that purges its
  -- follower whenever playerState is Surf, even after setShouldSpawn has been
  -- replaced. Run that wrapper with a temporary walking-state view only when
  -- SilverShadow has positively classified the primary as water-capable. The
  -- real Surf state is restored before any other game logic observes it.
  local originalOnMapEntered = Follower.onMapEntered
  local wrappedOnMapEntered
  if type(originalOnMapEntered) == "function" then
    wrappedOnMapEntered = function(game, world, opts, viaMapLoad, ...)
      if world and world.silverFollowerConnection then
        opts = opts or {}
        opts.keepFollower = world.silverFollowerConnection.primary
      elseif world and viaMapLoad then
        world.silverFollowerWarp = true
      end
      if not (world and FieldMoves.isSurfing(world.playerState)
          and primaryEligible(game, world)) then
        return originalOnMapEntered(game, world, opts, viaMapLoad, ...)
      end
      local player = world.player
      local savedState = world.playerState
      local savedSurfing = player and player.surfing
      world.playerState = FieldMoves.PLAYER_NORMAL
      if player then player.surfing = false end
      local results = { pcall(originalOnMapEntered, game, world, opts, viaMapLoad, ...) }
      world.playerState = savedState
      if player then player.surfing = savedSurfing end
      if not results[1] then error(results[2], 0) end
      return results[2]
    end
    Follower.onMapEntered = wrappedOnMapEntered
  end

  local previousShouldSpawn
  if type(Follower.setShouldSpawn) == "function" then
    previousShouldSpawn = Follower.setShouldSpawn(function(game, world)
      return primaryEligible(game, world)
    end)
  end

  mod.events:on("world.stepped", function() step(shared.game) end)
  mod.events:on("map.entered", function() syncAll(shared.game, worldFor(shared.game)) end)

  local World = require("src.world.gen2.World")
  local originalConnection = World.tryConnection
  local function wrappedConnection(world, ...)
    local x, y = world.player.cellX, world.player.cellY
    local followers, history = world.silverGen2Followers, world.silverGen2FollowerHistory
    world.silverFollowerConnection = { primary = world.follower }
    local ok, result = pcall(originalConnection, world, ...)
    world.silverFollowerConnection = nil
    if not ok then error(result, 0) end
    if result then
      local dx, dy = world.player.cellX - x, world.player.cellY - y
      Follower.rebase(world, dx, dy)
      if world.follower then world.follower.mapId = world.map.id end
      Transitions.restore(world, followers, dx, dy)
      for _, cell in ipairs(history or {}) do Transitions.shiftCell(cell, dx, dy) end
      world.silverGen2Followers, world.silverGen2FollowerHistory = followers, history
      world.silverFollowerWarp = nil
    end
    return result
  end
  World.tryConnection = wrappedConnection

  local api = {
    version = "2.0.0-gen2-native",
    nativeGen2 = true,
    _followersExControlEngine = true,
    _integrationReady = integrationReady,
    syncPhase = function() return syncPhase end,
    followerCount = function() return followerCount end,
    setFollowerCount = function(_, value)
      -- Accept both method and function call shapes.
      if value == nil then value = _ end
      followerCount = math.max(0, math.min(6, math.floor(tonumber(value) or 0)))
    end,
    setControlMode = function(_, value)
      if value == nil then value = _ end
      controlMode = tostring(value or "follow")
    end,
    syncAll = syncAll,
    _step = step,
    _travelStyle = travelStyle,
    _travelMount = travelMount,
    _primaryEligible = primaryEligible,
    disable = function(game, world)
      if World.tryConnection == wrappedConnection then World.tryConnection = originalConnection end
      removeExtras(world or worldFor(game))
      if Follower.update == wrappedFollowerUpdate then
        Follower.update = originalFollowerUpdate
      end
      if wrappedOnMapEntered and Follower.onMapEntered == wrappedOnMapEntered then
        Follower.onMapEntered = originalOnMapEntered
      end
      if previousShouldSpawn and type(Follower.setShouldSpawn) == "function" then
        Follower.setShouldSpawn(previousShouldSpawn)
      end
    end,
  }
  for key, value in pairs(api) do mod.exports[key] = value end
  print("[FOLLOWERS_EX] native Gen 2 follower controller ready")
  return api
end
