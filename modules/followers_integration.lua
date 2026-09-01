-- Optional PokePC integration. Sprite sheets always remain owned by the
-- external PokePCFollowers_VoxelMerge mod; SilverShadow loads no follower art.
local mod, shared = ...

local FOLLOWERS_ID = "PokePCFollowers_VoxelMerge"
local engine

local function activationEventAllowed(name)
  return shared.generation ~= 2 or name == "world.stepped"
end

local function worldFor(game)
  return game and (game.overworld or game.world) or nil
end

local function partyReady(game)
  local party = game and game.save and game.save.party
  if type(party) ~= "table" then return false end
  for _, mon in ipairs(party) do
    if type(mon) == "table" and type(mon.species) == "string"
        and mon.species ~= "" then
      return true
    end
  end
  return false
end

local function safeOverworld(game)
  local ow = worldFor(game)
  if not (ow and ow.player and ow.map) then return false end
  local runner = ow.runner
  if runner and type(runner.isRunning) == "function" then
    local ok, running = pcall(runner.isRunning, runner)
    if ok and running then return false end
  end
  local stack = game.stack
  if stack and type(stack.top) == "function" then
    local ok, top = pcall(stack.top, stack)
    if ok and top and top ~= ow then return false end
  end
  return true
end

local function external()
  return mod:find(FOLLOWERS_ID)
end

local function api()
  if engine then return engine end
  local found = external()
  return found and found.exports or nil
end

local function loadControlEngine()
  local found = external()
  if not found then return false end
  local controllerPath = shared.generation == 2
    and "modules/lib/gen2_follower_controller.lua"
    or "modules/lib/follower_control_engine.lua"
  local source, readError = mod:read(controllerPath)
  if not source then
    mod.log:warn("follower control engine unavailable: %s", tostring(readError))
    return false
  end
  local compile = loadstring or load
  local chunk, compileError = compile(source,
    "@" .. mod.path .. "/" .. controllerPath)
  if not chunk then
    mod.log:warn("follower control engine compile failed: %s", tostring(compileError))
    return false
  end
  local installer = chunk()
  local ok, result = pcall(installer, mod, found, shared)
  if not ok then
    mod.log:warn("PokePC control integration unavailable: %s", tostring(result))
    return false
  end
  engine = result or found.exports
  return true
end

shared.followersAvailable = function()
  return external() ~= nil
end

local function sync(game)
  local ex = api()
  if ex and type(ex.syncAll) == "function" then
    local exceeded = false
    local ticks = 0
    local canBudget = shared.generation == 2 and type(debug) == "table"
      and type(debug.sethook) == "function"
    if canBudget then
      debug.sethook(function()
        ticks = ticks + 1
        if ticks >= 100 then
          exceeded = true
          error("SilverShadow Gen 2 follower sync instruction budget exceeded", 0)
        end
      end, "", 20000)
    end
    local function traceback(message)
      if debug and debug.traceback then
        return debug.traceback(tostring(message), 2)
      end
      return tostring(message)
    end
    local ok, reason = xpcall(function()
      ex.syncAll(game, worldFor(game))
    end, traceback)
    if canBudget then debug.sethook() end
    if not ok or exceeded then
      local phase = type(ex.syncPhase) == "function" and ex.syncPhase() or "unknown"
      mod.log:error("Gen 2 follower controller disabled after %s: %s",
        tostring(phase), tostring(reason or "instruction budget exceeded"))
      if type(ex.disable) == "function" then pcall(ex.disable, game, worldFor(game)) end
      return false
    end
    return true
  end
  return false
end

local function followerPlan(who, trainerFollows, count)
  count = math.max(0, math.min(6, math.floor(tonumber(count) or 1)))
  if who == "trainer" then
    return "follow", count
  end

  -- In Pokemon-front mode the visible count includes the controlled lead.
  -- PokePC's engine count is trailers only, so translate 1..6 to 0..5.
  count = math.max(1, count)
  local trailers = count - 1
  if trainerFollows then return "lead_trainer", trailers end
  if trailers > 0 then return "pack", trailers end
  return "pokemon", 0
end

local function applyMode(game)
  local ex = api()
  if not (ex and type(ex.setControlMode) == "function") then return false end
  local who = shared.get("follower_mode", "trainer")
  local trainerFollows = shared.bool("trainer_follows", false)
  local count = tonumber(shared.get("follower_count", 1)) or 1
  local mode, engineCount = followerPlan(who, trainerFollows, count)
  if type(ex.setFollowerCount) == "function" then
    pcall(ex.setFollowerCount, game, engineCount)
  end
  pcall(ex.setControlMode, game, mode)
  sync(game)
  return true
end

local function tryActivate(game)
  game = game or shared.game
  if engine then return true end
  if not external() or not partyReady(game) or not safeOverworld(game) then
    return false
  end
  if not loadControlEngine() then return false end
  shared.applyFollowerCount(game, shared.get("follower_count", 1))
  return true
end

shared.applyFollowerMode = function(game, value)
  if value == "pokemon"
      and tonumber(shared.get("follower_count", 1)) == 0 then
    shared.set("follower_count", 1)
  end
  shared.set("follower_mode", value)
  return applyMode(game)
end

shared.applyTrainerFollows = function(game, value)
  shared.set("trainer_follows", value and true or false)
  if value then
    shared.set("follower_mode", "pokemon")
    if tonumber(shared.get("follower_count", 1)) == 0 then
      shared.set("follower_count", 1)
    end
  end
  return applyMode(game)
end

shared.applyFollowerCount = function(game, value)
  local count = math.max(0, math.min(6, math.floor(tonumber(value) or 1)))
  shared.set("follower_count", count)
  if count == 0 then
    -- A Pokemon-front composition necessarily has one Pokemon: the player.
    -- Selecting zero therefore switches to the only true zero-Pokemon mode.
    shared.set("follower_mode", "trainer")
    shared.set("trainer_follows", false)
  end
  applyMode(game)
  return true
end

mod.events:on("game.ready", function(event)
  -- Gen 2 emits game.ready while the Continue/save-summary stack is still
  -- active. Installing the expanded controller there can make that load path
  -- spin forever. Gen 2 hands off from world.stepped below, after World:step
  -- proves the real overworld is running. Preserve Gen 1's established seam.
  if not activationEventAllowed("game.ready") then return end
  local game = event and event.game
  tryActivate(game)
end)

-- Existing saves activate as their map loads. A brand-new game deliberately
-- stays on PokéPC's standalone controller throughout Oak/Elm's starter flow;
-- the first ordinary overworld step after receiving the starter is the safe
-- handoff point for SilverShadow's expanded controls.
mod.events:on("map.entered", function()
  if not activationEventAllowed("map.entered") then return end
  tryActivate(shared.game)
end)

mod.events:on("world.stepped", function()
  tryActivate(shared.game)
end)

mod.exports.followersIntegration = {
  available = shared.followersAvailable,
  applyMode = applyMode,
  activationEventAllowed = activationEventAllowed,
  activate = tryActivate,
  followerPlan = followerPlan,
  engine = api,
  usesExternalAssets = true,
  worldFor = worldFor,
}
