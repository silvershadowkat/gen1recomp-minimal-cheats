local game,shared=...
local w=game.world
local Mon=require("src.battle.gen2.Mon")
game.save.party={}
for _,id in ipairs({"CYNDAQUIL","TOTODILE","CHIKORITA","PIDGEY","CATERPIE","EEVEE"})do
 game.save.party[#game.save.party+1]=Mon.new(game.data,id,20)
end
shared.applyFollowerCount(game,6)
assert(game.mods.exports.minimal_cheats.followersIntegration.activate(game))
local F=require("src.world.gen2.Follower")
w:setMap("NEW_BARK_TOWN",0,6,"left")
F.update(game,w)
assert(#w.silverGen2Followers==5,"missing Gen2 extras")
for _,n in ipairs(w.silverGen2Followers)do
 assert(n.cellX==w.player.cellX and n.cellY==w.player.cellY,"warp stack")
end
local crossed=false
for y=0,w.map.heightCells-1 do
 if w.map:isWalkableCell(0,y)then
  w.player.cellX,w.player.cellY=0,y
  w.player.px,w.player.py=0,y*16
  local primary=w.follower
  assert(primary,"missing primary")
  primary.cellX,primary.cellY=1,y
  primary.px,primary.py=12,y*16
  primary.targetX,primary.targetY=0,y
  primary.moving,primary.progress,primary.stepFrames=true,4,16
  w.followerTrail={x=0,y=y};w.pikachuTrail=w.followerTrail
  local originals={}
  for i,n in ipairs(w.silverGen2Followers)do
   n.cellX,n.cellY=i+1,y;n.px,n.py=(i+1)*16-4,y*16
   n.targetX,n.targetY=i,y;n.moving,n.progress,n.stepFrames=true,4,16
   originals[i]={npc=n,px=n.px,py=n.py,targetX=n.targetX}
  end
  local history={}
  for i=1,7 do history[i]={x=i-1,y=y}end
  w.silverGen2FollowerHistory=history
  if w:tryConnection("left")then
   local dx,dy=w.player.cellX,w.player.cellY-y
   assert(w.follower==primary,"primary recreated at seam")
   assert(primary.px==12+dx*16 and primary.progress==4,"primary animation reset")
   for i,old in ipairs(originals)do
    local n=w.silverGen2Followers[i]
    assert(n==old.npc and n.px==old.px+dx*16 and n.py==old.py+dy*16,"extra reset")
    assert(n.targetX==old.targetX+dx and n.progress==4 and n.moving,"extra animation reset")
   end
   assert(history[1].x==dx and history[1].y==y+dy,"history reset")
   F.update(game,w)
   assert(w.silverGen2Followers[1]==originals[1].npc,"post seam rebuild")
   crossed=true;break
  end
 end
end
assert(crossed,"no New Bark west connection")
return "PASS "..shared.gameVersion.." warp stack + native New Bark/Route 29 seam, primary + five extras"
