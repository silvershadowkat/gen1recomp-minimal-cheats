local mod, shared = ...

-- LÖVE exposes L2/R2 as analog axes, not gamepad buttons. Gen1Recomp's
-- binding screen listens for button press/release events, so Android handheld
-- triggers otherwise never reach it. Convert the two axes into hysteretic
-- synthetic L2/R2 buttons at the Game routing layer. They then use the
-- engine's normal capture, saved-binding, speed-action and gameplay paths.
local BUTTON_FOR_AXIS = {
  triggerleft = "l2", lefttrigger = "l2",
  triggerright = "r2", righttrigger = "r2",
}
local PRESS_AT, RELEASE_AT = 0.55, 0.35
local heldByGame = setmetatable({}, { __mode = "k" })

local function triggerAxis(game, joystick, axis, value)
  local button = BUTTON_FOR_AXIS[axis]
  if not button then return false end
  value = tonumber(value) or 0
  local devices = heldByGame[game]
  if not devices then
    devices = setmetatable({}, { __mode = "k" })
    heldByGame[game] = devices
  end
  local device = joystick or devices
  local held = devices[device]
  if type(held) ~= "table" then held = {}; devices[device] = held end
  if not held[button] and value >= PRESS_AT then
    held[button] = true
    if game.gamepadpressed then game:gamepadpressed(joystick, button) end
  elseif held[button] and value <= RELEASE_AT then
    held[button] = nil
    if game.gamepadreleased then game:gamepadreleased(joystick, button) end
  end
  return true
end

shared.triggerAxis = triggerAxis

local className = shared.generation == 2 and "src.core.Game2" or "src.core.Game"
local okGame, GameClass = pcall(require, className)
if okGame and type(GameClass) == "table"
    and type(GameClass.gamepadaxis) == "function"
    and not GameClass._silverShadowTriggerButtons then
  local originalAxis = GameClass.gamepadaxis
  GameClass.gamepadaxis = function(self, joystick, axis, value)
    if triggerAxis(self, joystick, axis, value) then return end
    return originalAxis(self, joystick, axis, value)
  end
  GameClass._silverShadowTriggerButtons = true
end

