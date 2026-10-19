local mod, shared = ...
local Player = require("src.core.game3.player")
local Field = require("src.core.game3.field")
local Collision = require("src.core.game3.collision")
local Party = require("src.core.game3.party")
local Pokemon = require("src.core.game3.pokemon")
local Bag = require("src.core.game3.bag")
local flight, takeoff
local delta = { up = {0,-1}, down = {0,1}, left = {-1,0}, right = {1,0} }
local function session() return Field.getSession() end
local function say(text)
  local g = shared.game
  if g then
    -- A missing font/closed UI must not make the loader fall through a
    -- rejected save hook and persist an airborne coordinate.
    pcall(function() require("src.ui.game3.hud").openMessage(g, text) end)
  end
end
shared.gen3Message = say
shared.gen3Session = session
function shared.healParty()
  local s = session()
  if s and shared.gameplayAllowed() then Party.healAll(s.party) end
end
function shared.gen3Candy()
  local s = session()
  if s and shared.gameplayAllowed() then
    local have = Bag.get(s.bag, "RARE_CANDY")
    local needed = 99 - (tonumber(have) or 0)
    if needed > 0 then Bag.add(s.bag, "RARE_CANDY", needed) end
  end
end
function shared.maxCoins()
  local s = session()
  if s and shared.gameplayAllowed() then s.coins = 9999 end
end
function shared.gen3MaxMoney()
  local s = session()
  if s and shared.gameplayAllowed() then s.money = 999999 end
end
function shared.gen3Perfect(mon)
  if not mon or not shared.gameplayAllowed() then return end
  mon.ivs = {hp=31, atk=31, def=31, spe=31, spa=31, spd=31}
  Pokemon.applyStats(mon, session())
end
mod.events:on("pokemon.caught", function(e)
  if not e or not e.mon or not shared.gameplayAllowed(e.battle) then return end
  if shared.bool("perfect_dvs", false) then shared.gen3Perfect(e.mon) end
  if shared.bool("catch_heal", false) then Party.healAll({e.mon}) end
end)
mod.events:on("battle.ended", function(e)
  if shared.bool("heal_battle", false) and shared.gameplayAllowed(e and e.battle) then shared.healParty() end
end)

local function stopFlight(reset)
  local s = session()
  if reset and takeoff and s and s.map == takeoff.map then
    Player.reset(takeoff.x, takeoff.y, Player.facing)
    s.x, s.y = takeoff.x, takeoff.y
  end
  if takeoff then
    Player.fixedPriority,Player.oamPriority=takeoff.fixedPriority,takeoff.oamPriority
  end
  flight, shared.gen3Flying, takeoff = nil, false, nil
  Player.spriteYOffset = 0
end
function shared.gen3ToggleFly()
  local s = session()
  if not s or not shared.gameplayAllowed() or Player.moving or Field.locked then return false end
  if flight then
    local ok = Collision.canEnter(shared.game, Player.cellX, Player.cellY,
      {surfing=false, fromX=Player.cellX, fromY=Player.cellY})
    if not ok or Collision.isWater(Player.cellX, Player.cellY) then
      say("Land on clear ground first.")
      return false
    end
    stopFlight(false)
    Player.updateElevation(Player.cellX, Player.cellY)
    Player.syncSavePosition(shared.game)
    return true
  end
  if Player.surfing or Player.underwater or Player.biking or Player.fishing then
    say("Stand on foot before taking off."); return false
  end
  takeoff = {map=s.map, x=Player.cellX, y=Player.cellY,
    fixedPriority=Player.fixedPriority,oamPriority=Player.oamPriority}
  Player.fixedPriority,Player.oamPriority=true,1
  flight, shared.gen3Flying = true, true
  return true
end
shared.gen3ReturnToGround = function() stopFlight(true) end

-- Flight has its own per-frame movement: ordinary scripted steps still run
-- warp tiles, coordinate scripts and trainer sight in FRLG, so they are not
-- a safe way to fly. Keep coordinates within the current map and reject saves
-- until landing; a map load or online session cancels the transient state.
local update = Player.update
Player.update = function(game, input)
  if not flight then return update(game, input) end
  local s = session()
  if not s or not takeoff or s.map ~= takeoff.map then stopFlight(false); return end
  if not shared.gameplayAllowed() then stopFlight(true); return end
  local height = ({LOW=8, MED=16, HIGH=24})[shared.allowed("fly_height", shared.FLY_HEIGHTS, "MED")]
  Player.spriteYOffset = -height
  local runtime = package.loaded["src.core.game3.runtime"]
  if Field.locked or (runtime and runtime.uiBusy and runtime.uiBusy()) then return end
  if Player.moving then
    Player.progress = Player.progress + 1
    local t = math.min(1, Player.progress / Player.stepFrames)
    Player.px = (Player.cellX + (Player.targetX-Player.cellX)*t)*16
    Player.py = (Player.cellY + (Player.targetY-Player.cellY)*t)*16
    if t >= 1 then
      Player.cellX, Player.cellY = Player.targetX, Player.targetY
      Player.moving = false
      s.x, s.y, s.facing = Player.cellX, Player.cellY, Player.facing
    end
    return
  end
  for _, dir in ipairs({"up","down","left","right"}) do
    if input and input:isDown(dir) then
      local d = delta[dir]
      local x,y = Player.cellX+d[1],Player.cellY+d[2]
      Player.facing = dir
      if Collision.inBounds(x,y) then
        Player.targetX,Player.targetY,Player.progress = x,y,0
        Player.stepFrames = math.max(2, math.floor(8/shared.allowed("move_boost",shared.MOVE_MULTIPLIERS,2)))
        Player.moving = true
      end
      return
    end
  end
end
local tryMove = Player.tryMove
Player.tryMove = function(dir, game, run)
  local wasMoving = Player.moving
  local result = tryMove(dir, game, run)
  if not wasMoving and Player.moving and not Player.jumping and shared.gameplayAllowed() then
    local key = Player.surfing and "surf_boost" or Player.biking and "bike_boost" or "foot_boost"
    local mode = shared.allowed(key, shared.BOOST_STATES, key == "foot_boost" and "ON" or "OFF")
    if mode == "ON" or (mode == "HOLD" and game.input and game.input:isDown("b")) then
      Player.stepFrames = math.max(2, math.floor(Player.stepFrames/shared.allowed("move_boost",shared.MOVE_MULTIPLIERS,2)))
    end
  end
  return result
end
mod.hooks:wrap("save.write", function(next, game, ...)
  if flight then say("Land before saving, or use RETURN TO GROUND."); return false end
  return next(game, ...)
end)
mod.events:on("map.entered", function()
  stopFlight(false)
  if shared.bool("heal_map_change", false) then shared.healParty() end
end)
mod.events:on("save.loaded", function() stopFlight(false) end)
mod.events:on("world.blacked_out", function() stopFlight(false) end)
