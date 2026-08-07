-- Optional PokePC integration. Sprite sheets always remain owned by the
-- external PokePCFollowers_VoxelMerge mod; SilverShadow loads no follower art.
local mod, shared = ...

local FOLLOWERS_ID = "PokePCFollowers_VoxelMerge"
local engine

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
  local source, readError = mod:read("modules/lib/follower_control_engine.lua")
  if not source then
    mod.log:warn("follower control engine unavailable: %s", tostring(readError))
    return false
  end
  local compile = loadstring or load
  local chunk, compileError = compile(source,
    "@" .. mod.path .. "/modules/lib/follower_control_engine.lua")
  if not chunk then
    mod.log:warn("follower control engine compile failed: %s", tostring(compileError))
    return false
  end
  local installer = chunk()
  local ok, result = pcall(installer, mod, found)
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
    pcall(ex.syncAll, game, game and game.overworld)
  end
end

local function followerPlan(who, trainerFollows, count)
  count = math.max(1, math.min(6, math.floor(tonumber(count) or 1)))
  if who == "trainer" then
    return "follow", count
  end

  -- In Pokemon-front mode the visible count includes the controlled lead.
  -- PokePC's engine count is trailers only, so translate 1..6 to 0..5.
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

shared.applyFollowerMode = function(game, value)
  shared.set("follower_mode", value)
  return applyMode(game)
end

shared.applyTrainerFollows = function(game, value)
  shared.set("trainer_follows", value and true or false)
  if value then shared.set("follower_mode", "pokemon") end
  return applyMode(game)
end

shared.applyFollowerCount = function(game, value)
  local count = math.max(1, math.min(6, math.floor(tonumber(value) or 1)))
  shared.set("follower_count", count)
  applyMode(game)
  return true
end

if external() then loadControlEngine() end

mod.events:on("game.ready", function(event)
  local game = event and event.game
  if not engine and external() then loadControlEngine() end
  if engine and game then
    shared.applyFollowerCount(game, shared.get("follower_count", 1))
    applyMode(game)
  end
end)

mod.exports.followersIntegration = {
  available = shared.followersAvailable,
  applyMode = applyMode,
  followerPlan = followerPlan,
  usesExternalAssets = true,
}
