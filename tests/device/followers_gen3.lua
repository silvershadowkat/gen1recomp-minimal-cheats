local game,shared=...
local P=require("src.core.game3.player")
local C=require("src.core.game3.collision")
local R=require("src.mods.Runtime")
local F=shared.gen3Followers
local s=shared.gen3Session()
local crossed=false
for x=0,39 do
 P.cellX,P.cellY=x,7;P.px,P.py=x*16,112;P.facing="up";P.moving=false
 R.emit("map.entered",{via="warp"})
 F.updateTrail(s)
 for y=6,0,-1 do P.cellY=y;P.py=y*16;F.updateTrail(s)end
 local old={}
 for i=1,6 do local px,py=F.pose(i);old[i]={px,py}end
 if C.tryConnection(game,x,0,"up",false)then
  local dx,dy=P.cellX-x,P.cellY
  F.updateTrail(s)
  for i=1,6 do
   local px,py=F.pose(i)
   assert(px==old[i][1]+dx*16 and py==old[i][2]+dy*16,"Gen3 seam reset follower "..i)
  end
  crossed=true;break
 end
end
assert(crossed,"no north connection")
-- Verify a warp resets every slot even if the same map is revisited.
R.emit("map.entered",{via="warp"})
F.updateTrail(s)
for i=1,6 do
 local px,py=F.pose(i)
 assert(px==P.cellX*16 and py==P.cellY*16,"Gen3 warp did not gather")
end
return "PASS "..shared.gameVersion.." six-slot native north connection and warp reset"
