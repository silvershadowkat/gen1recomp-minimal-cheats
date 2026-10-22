-- Keep source pixels and the LCD sampling lattice aligned on Gen 1 boot
-- screens. Battle canvases already use integer scaling on the Nova.
local _, shared = ...
if shared.generation~=1 or not(love and love.graphics and love.graphics.newCanvas)then return end
local R=require('src.render.Renderer')
local FX=require('src.render.ShaderFX')
local Game=require('src.core.Game')
local Intro=require('src.ui.IntroMovie')
local Title=require('src.ui.TitleState')
local Yellow=require('src.ui.YellowIntro')
local Faithful=require('src.core.FaithfulRes')
local function boot()
  local states=Game.stack and Game.stack.states or {}
  for _,state in ipairs(states)do
    local mt=getmetatable(state)
    if mt==Intro or mt==Title or mt==Yellow then return state end
  end
end
local frameRects=R.frameRects
R.frameRects=function(self,...)
  local r=frameRects(self,...)
  local entry=FX.activeEntry and FX.activeEntry('main')
  if boot() and self.uiFill and entry and entry.name=='retro-v3.slangp' and r.Up>=1 then
    r.Up=math.floor(r.Up)
    r.Ux,r.Uy=r.Up/r.dpiX,r.Up/r.dpiY
    r.uvpw,r.uvph=r.uiw*r.Ux,r.uih*r.Uy
    r.uox=(r.vx+math.floor((r.pw-r.uiw*r.Up)/2))/r.dpiX
    r.uoy=(r.vy+math.max(0,math.floor((r.ph-r.uih*r.Up)/2)-r.lift))/r.dpiY
  end
  return r
end
-- The original Red/Blue movie intentionally has cinematic bars. Extend the
-- actual palette-colored canvas bands into the surround, including fades,
-- instead of leaving light strips beside two floating black rectangles.
local blit=R.blitCanvas
R.blitCanvas=function(self,canvas,sx,sy,zones,zsx,zsy,bx,by,...)
  local state=boot()
  if canvas==self.canvas and state and getmetatable(state)==Intro
      and (state.phase==2 or state.phase==3) and not Faithful.scaleCap() then
    local r=self:frameRects()
    local top=by+32*sy
    local bottom=by+112*sy
    local xs=r.vuw/160
    local ts=(top-r.vuy)/32
    local bs=(r.vuy+r.vuh-bottom)/32
    if ts>0 then
      blit(self,canvas,xs,ts,zones,xs,ts,r.vux,r.vuy,
        r.vux,r.vuy,r.vuw,top-r.vuy,r.dpiX,r.dpiY)
    end
    if bs>0 then
      blit(self,canvas,xs,bs,zones,xs,bs,r.vux,bottom-112*bs,
        r.vux,bottom,r.vuw,r.vuy+r.vuh-bottom,r.dpiX,r.dpiY)
    end
  end
  return blit(self,canvas,sx,sy,zones,zsx,zsy,bx,by,...)
end
