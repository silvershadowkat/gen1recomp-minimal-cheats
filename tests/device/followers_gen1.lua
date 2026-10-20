local game,shared=...
local ow=game.overworld
local F=require("src.world.PikachuFollower")
ow:setMap("PALLET_TOWN",10,0,"up")
F.update(game,ow)
local trailers=ow.pokepcTrailers
local stock=F.current(ow)
local happiness=game.save.pikachuHappiness
if shared.gameVersion=="yellow"then
 assert(stock and F.isStarterPikachu(game.save,game.save.party[1]),"special Pikachu missing")
 for _,n in ipairs(trailers)do assert(n.pokepcSpecies~="PIKACHU","duplicate Pikachu")end
end
assert(trailers and #trailers>0,"no follower pack")
for _,npc in ipairs(trailers)do
 assert(npc.cellX==10 and npc.cellY==0,"warp did not gather followers")
end
-- A real native connection with an established, mid-step follower chain.
local originals={}
for i,npc in ipairs(trailers)do
 npc.cellX,npc.cellY=10,i
 npc.px,npc.py=160,i*16-4
 npc.targetX,npc.targetY=10,i-1
 npc.moving,npc.progress,npc.stepFrames=true,4,16
 originals[i]={npc=npc,px=npc.px,py=npc.py,targetY=npc.targetY}
 ow.pokepcTrailCells[i]={x=10,y=i-1}
end
ow.pokepcTrailHead={x=10,y=0}
assert(ow:crossConnection("up",ow.map:connection("north")),"Pallet seam refused")
local dx,dy=ow.player.cellX-10,ow.player.cellY
for i,old in ipairs(originals)do
 local n=ow.pokepcTrailers[i]
 assert(n==old.npc,"connection recreated follower")
 assert(n.px==old.px+dx*16 and n.py==old.py+dy*16,"wrong pixel rebase")
 assert(n.targetY==old.targetY+dy and n.progress==4 and n.moving,"animation reset")
 assert(ow.pokepcTrailCells[i].y==i-1+dy,"trail lost")
end
assert(ow.pokepcTrailHead.y==dy,"head lost")
F.update(game,ow)
assert(ow.pokepcTrailers[1]==originals[1].npc,"first update recreated pack")
if shared.gameVersion=="yellow"then
 assert(F.current(ow)==stock,"Pikachu entity replaced")
 assert(game.save.pikachuHappiness==happiness,"Pikachu happiness changed")
end
return "PASS "..shared.gameVersion.." warp stack + native Pallet/Route 1 seam, "..#trailers.." followers"
