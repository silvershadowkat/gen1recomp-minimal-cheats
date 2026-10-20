-- Substitute only ball artwork. Native capture logic and animation updates
-- still own trajectories, shake counts, breakout effects and final OAM.
local _,S=...
if S.generation==3 or not(love and love.graphics and love.graphics.newCanvas)then return end
local gen2=S.generation==2
local B=require(gen2 and "src.ui.gen2.BattleState"or"src.battle.BattleState")
local A,g=S.battleAssets,love.graphics
local phases={TOSS_ANIM=true,GREATTOSS_ANIM=true,ULTRATOSS_ANIM=true,
  SHAKE_ANIM=true,BLOCKBALL_ANIM=true}
local tiles={[2]=true,[18]=true,[6]=true,[7]=true,[22]=true,[23]=true,
  [44]=true,[45]=true,[60]=true,[61]=true}
if gen2 then
  local start=B.startBallAnim
  B.startBallAnim=function(self,param,item,...)
    local r=start(self,param,item,...)
    if self.anim then self.anim._silverBallItem=item end
    return r
  end
else
  local throw=B.throwBall
  B.throwBall=function(self,item,...)
    self._silverBallItem=item
    return throw(self,item,...)
  end
  local chain=B.ballChain
  B.ballChain=function(self,anim,caught,shakes,item,...)
    self._silverBallItem=item
    return chain(self,anim,caught,shakes,item,...)
  end
  local AP=require("src.battle.AnimPlayer")
  local start=AP.start
  AP.start=function(self,name,...)
    self._silverBallPhase=phases[name]and name or nil
    return start(self,name,...)
  end
end
local function partition(sprites,classify)
  local rest,ball={},{}
  local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
  local frame,tilt=0,0
  for _,s in ipairs(sprites)do
    local index=classify(s)
    if index~=nil then
      -- OAM extremes hide the native tile, so don't bring it back onscreen.
      if s.x>0 and s.x<168 and s.y>0 and s.y<160 then
        ball[#ball+1]=s
        x0=math.min(x0,s.x-8);x1=math.max(x1,s.x)
        y0=math.min(y0,s.y-16);y1=math.max(y1,s.y-8)
        if gen2 then
          if index==6 then frame=math.max(frame,1)
          elseif index>=7 then frame=2
          elseif index>=2 then tilt=(s.attr or 0)%64>=32 and -1 or 1 end
        elseif index==6 or index==7 or index==22 or index==23 then
          tilt=s.xf and -1 or 1
        end
      end
    else rest[#rest+1]=s end
  end
  if #ball==0 then return end
  return rest,{x=math.floor((x0+x1)/2),y=math.floor((y0+y1)/2),
    frame=frame,tilt=tilt}
end
local function draw(item,p)
  local img,quad=A.captureBall(item,p.frame)
  if not img then return false end
  g.push("all");g.setShader();g.setColor(1,1,1,1)
  local ok,err=pcall(g.draw,img,quad,p.x,p.y,p.tilt*math.pi/12,1,1,8,8)
  g.pop()
  if not ok then error(err,0)end
  return true
end
S.captureBalls={
  gen1=function(b,player,sprites)
    if not player._silverBallPhase or not A.captureBall(b._silverBallItem,0)then return end
    return partition(sprites,function(s)if s.ts==0 and tiles[s.tile]then return s.tile end end)
  end,
  gen2=function(runner,sprites)
    if not runner._silverBallItem or not A.captureBall(runner._silverBallItem,0)then return end
    return partition(sprites,function(s)
      for i=#runner.loaded,1,-1 do
        local e=runner.loaded[i]
        if s.tile>=e.tile and s.tile<e.tile+math.max(e.tiles,1)then
          if e.gfx=="BATTLE_ANIM_GFX_POKE_BALL"then return s.tile-e.tile end
          return
        end
      end
    end)
  end,
  draw=draw,partition=partition,
}
