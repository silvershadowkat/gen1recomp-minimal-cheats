local mod, shared = ...
local Effects = require("src.core.game3.field_effects")
local Player = require("src.core.game3.player")
local Pokemon = require("src.core.game3.pokemon")
local images, trail = {}, {}
local lastMap, lastX, lastY
local function renderer(mon)
  local species = Pokemon.speciesOf(mon)
  local national = Pokemon.national(species)
  if not national or national < 1 or national > 386 then return end
  local key = string.format("%03d-%s", national, Pokemon.isShiny(mon) and "shiny" or "normal")
  if images[key] == false then return end
  if not images[key] then
    local ok, img = pcall(mod.assets.image, mod.assets, "assets/gen3_followers/" .. key .. ".png")
    if not ok or not img then images[key] = false; return end
    img:setFilter("nearest", "nearest")
    local w,h = img:getDimensions()
    local quads = {}
    for n=0,5 do quads[n] = love.graphics.newQuad(0,n*16,16,16,w,h) end
    images[key] = { draw = function(_, x,y,cx,cy,dir,phase)
      local row = dir == "up" and 1 or (dir == "left" or dir == "right") and 2 or 0
      if phase == 1 or phase == true then row = row+3 end
      local flip = dir == "right"
      love.graphics.setColor(1,1,1,1)
      love.graphics.draw(img, quads[row], math.floor(x-cx)+(flip and 16 or 0),
        math.floor(y-cy)-4, 0, flip and -1 or 1, 1)
    end }
  end
  return images[key]
end
local function updateTrail(s)
  local x,y = Player.cellX,Player.cellY
  if s.map ~= lastMap or not lastX or math.abs(x-lastX)+math.abs(y-lastY)>1 then
    trail = {}
    for i=1,7 do trail[i]={x=x,y=y,facing=Player.facing} end
  elseif x ~= lastX or y ~= lastY then
    table.insert(trail,1,{x=lastX,y=lastY,facing=Player.facing})
    while #trail>7 do table.remove(trail) end
  end
  lastMap,lastX,lastY=s.map,x,y
end
local function pose(index)
  local from = trail[index] or trail[#trail]
  local goal = index == 1 and {x=Player.cellX,y=Player.cellY} or trail[index-1]
  local t = Player.moving and math.min(1,(Player.progress or 0)/math.max(1,Player.stepFrames or 16)) or 0
  local dx,dy=goal.x-from.x,goal.y-from.y
  local facing=math.abs(dx)>math.abs(dy) and (dx>0 and "right" or "left")
    or dy~=0 and (dy>0 and "down" or "up") or from.facing
  return (from.x+dx*t)*16,(from.y+dy*t)*16,facing,t>0 and 1 or 0
end
local original = Effects.collectActors
Effects.collectActors = function(actors, cx, cy, ...)
  for _,a in ipairs(actors) do
    if a._silverPlayer then a.renderer=nil; a._silverPlayer=nil end
  end
  if original then original(actors,cx,cy,...) end
  local s=shared.gen3Session()
  if not s or not shared.gameplayAllowed() or shared.gen3Flying then return end
  updateTrail(s)
  local party={}
  for _,mon in ipairs(s.party or {}) do
    if not Pokemon.isEgg(mon) and (tonumber(mon.hp) or 0)>0 then party[#party+1]=mon end
  end
  local count=shared.allowed("follower_count",{0,1,2,3,4,5,6},1)
  local control=shared.allowed("follower_mode",{"trainer","pokemon"},"trainer")=="pokemon"
  local trainer
  if control and party[1] then
    local sprite=renderer(party[1])
    if sprite then
      for _,a in ipairs(actors) do
        if a.kind=="player" then
          trainer={}; for k,v in pairs(a) do trainer[k]=v end
          a.renderer=sprite; a._silverPlayer=true
          break
        end
      end
    end
  end
  local offset=0
  if trainer and shared.bool("trainer_follows",false) then
    trainer.x,trainer.y,trainer.facing,trainer.walkPhase=pose(1)
    trainer.sortY=trainer.y; trainer.kind="silvershadow_trainer"
    actors[#actors+1]=trainer; offset=1
  end
  for i=1,count do
    local mon=party[i+(trainer and 1 or 0)]
    local sprite=mon and renderer(mon)
    if sprite then
      local x,y,dir,phase=pose(i+offset)
      actors[#actors+1]={kind="silvershadow_follower",i=-10-i,x=x,y=y,sortY=y,
        facing=dir,walkPhase=phase,elevation=Player.elevation,renderer=sprite}
    end
  end
end
shared.gen3Followers = { renderer=renderer, updateTrail=updateTrail, pose=pose }
