-- ROM-free regression: preserve fractional positions and animation clocks,
-- including negative neighbor coordinates and a failed connection.
local mod = { exports = {}, events = { on = function(self, name, fn) self[name] = fn end } }
assert(loadfile("modules/follower_transitions.lua"))(mod)
local T = mod.exports.followerTransitions
local npc = { cellX=1, cellY=2, px=19.5, py=32, targetX=2, targetY=2,
  goalX=2, goalY=2, moving=true, progress=7, facing="right" }
local world = { map={id="NEXT"}, npcs={}, entities={} }
T.restore(world,{npc},-20,4)
assert(npc.cellX==-19 and npc.px==-300.5 and npc.targetX==-18)
assert(npc.cellY==6 and npc.goalY==6 and npc.progress==7 and npc.moving)
assert(world.npcs[1]==npc and world.entities[1]==npc and npc.mapId=="NEXT")
T.restore(world,{npc},0,0)
assert(#world.npcs==1 and #world.entities==1)
local cells=T.stack({cellX=5,cellY=9},6)
for _,cell in ipairs(cells)do assert(cell.x==5 and cell.y==9)end
cells[1].x=0;assert(cells[2].x==5,"trail cells must not alias")

local player={cellX=10,cellY=10,facing="right",moving=false}
local session={map="A"}
local collision={}
function collision.tryConnection(_,success,dx,dy)
  if not success then return false end
  player.cellX,player.cellY=player.cellX+dx,player.cellY+dy
  session.map="B"
  mod.events["map.entered"]({via="connection"})
  return true
end
package.loaded["src.core.game3.player"]=player
package.loaded["src.core.game3.collision"]=collision
package.loaded["src.core.game3.field_effects"]={}
package.loaded["src.core.game3.pokemon"]={}
package.loaded["src.core.game3.field_moves"]={}
local shared={gen3Session=function()return session end}
assert(loadfile("modules/gen3_followers.lua"))(mod,shared)
local F=shared.gen3Followers
F.updateTrail(session)
for x=11,16 do player.cellX=x;F.updateTrail(session)end
local before={}
for i=1,6 do local x,y=F.pose(i);before[i]={x,y}end
assert(not collision.tryConnection(nil,false))
F.updateTrail(session)
assert(F.pose(1)==before[1][1],"failed seam changed the trail")
assert(collision.tryConnection(nil,true,-20,5))
F.updateTrail(session)
for i=1,6 do
  local x,y=F.pose(i)
  assert(x==before[i][1]-320 and y==before[i][2]+80,"seam reset follower "..i)
end
-- Same-map warps also gather at arrival rather than inheriting an old trail.
player.cellX,player.cellY=3,4
mod.events["map.entered"]({via="warp"})
F.updateTrail(session)
for i=1,6 do local x,y=F.pose(i);assert(x==48 and y==64)end
print("Follower transitions: seam continuity, failure, warp stack and animation preservation passed")
