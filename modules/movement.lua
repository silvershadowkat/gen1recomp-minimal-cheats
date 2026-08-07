local mod, shared = ...

local WALK_FRAMES = 16
local MIN_FRAMES = 4
local tracked, boostedFrames, vanillaFrames

local function multiplier()
  local current = shared.get("move_boost", nil)
  if current == nil then
    local legacy = tonumber(shared.get("movement_speed", nil))
    if legacy == 3 or legacy == 4 then current = legacy else current = 2 end
  end
  current = tonumber(current)
  for _, allowed in ipairs(shared.MOVE_MULTIPLIERS) do
    if current == allowed then return allowed end
  end
  return 2
end

local function stateFor(ctx)
  if ctx.surfing then return shared.allowed("surf_boost", shared.BOOST_STATES, "OFF") end
  if ctx.onBike then return shared.allowed("bike_boost", shared.BOOST_STATES, "OFF") end
  return shared.allowed("foot_boost", shared.BOOST_STATES, "ON")
end

local function restore()
  local player = tracked
  tracked = nil
  if player and player.stepFramesCur == boostedFrames then
    player.stepFramesCur = vanillaFrames
  end
end

mod.events:on("script.started", restore)

-- This is SilverShadow's single input.step owner. Other modules register
-- lightweight post-step callbacks through core instead of stacking wrappers.
mod.hooks:wrap("input.step", function(next, game, dt)
  local out = next(game, dt)
  shared.game = shared.game or game
  if tracked and not tracked.moving then restore() end
  for _, entry in ipairs(shared.sortedStepCallbacks()) do
    local ok, err = pcall(entry.callback, game, dt)
    if not ok then mod.log:warn("step callback %s failed: %s", entry.id, tostring(err)) end
  end
  return out
end)

mod.hooks:wrap("movement.speed", function(next, frames, ctx)
  local base = tonumber(next(frames, ctx)) or WALK_FRAMES
  if shared.online() or type(ctx) ~= "table" or not ctx.player then return base end

  local state = stateFor(ctx)
  if state == "OFF" then return base end
  local bHeld = ctx.input and ctx.input.isDown and ctx.input:isDown("b") or false
  local apply = (state == "ON" and not bHeld) or (state == "HOLD" and bHeld)
  if not apply then return base end

  local factor = multiplier()
  if factor <= 1 then return base end
  local sped = math.max(MIN_FRAMES, math.floor(base / factor + 0.5))
  if sped >= base then return base end

  -- Only the player reaches movement.speed. Remember exactly the value we
  -- wrote so idle/script restoration never overwrites another modifier.
  tracked, boostedFrames, vanillaFrames = ctx.player, sped, base
  return sped
end)

shared.movementMultiplier = multiplier
shared.movementStateFor = stateFor
mod.exports.movement = {
  multiplier = multiplier,
  stateFor = stateFor,
  minimumFrames = MIN_FRAMES,
}
