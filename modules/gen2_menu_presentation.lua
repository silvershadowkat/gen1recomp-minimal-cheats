-- Reflow native Party and Pack drawing only; their input, item operations,
-- party rules and selection state remain entirely owned by the engine.
local mod,shared=...
if shared.generation~=2 or not(love and love.graphics and love.graphics.newCanvas)then return end
local g=love.graphics
local Chrome=require('src.ui.gen2.Chrome')
local Party=require('src.ui.gen2.PartyMenu')
local Pack=require('src.ui.gen2.PackMenu')
local Game=require('src.core.Game2')
local function enabled()return shared.bool('modern_battle_hud',true)end
local function menu(game)
  local top=game.stack and game.stack:top()
  return top and (getmetatable(top)==Party or getmetatable(top)==Pack)
end
local fit=Game.frameFit
Game.frameFit=function(self,w,h)
  local s,x,y,dpi,pw,ph=fit(self,w,h)
  if enabled()and menu(self)then
    local px,py,cw,ch=Chrome.playfieldRect(w,h)
    s=math.min(cw/256,ch/192);x,y=px+(cw-256*s)/2,py+(ch-192*s)/2
  end
  return s,x,y,dpi,pw,ph
end
local function wide(class)
  local original=class.drawWidescreen
  class.drawWidescreen=function(self,w,h)
    if not enabled()then return original(self,w,h)end
    local x,y,cw,ch=Chrome.playfieldRect(w,h)
    local s=math.min(cw/256,ch/192)
    g.push('all');Chrome.clipTo(x,y,cw,ch)
    g.translate(x+(cw-256*s)/2,y+(ch-192*s)/2);g.scale(s)
    local ok,err=pcall(self.drawPanel,self)
    g.pop();if not ok then error(err,0)end
  end
end
wide(Party);wide(Pack)
local context,overlay,depth
local function point(x,y)
  if overlay then return x+12,y+6 end
  if y>=14 then return x,y+6 end
  return x+(x>=11 and 11 or 1),y+math.max(0,math.floor((y-1)/2))
end
-- Scope the tile-coordinate remapping to one synchronous Party draw. The
-- nested Chrome.print -> printThrough path must transform only once.
local function wrapPoint(name,textFirst)
  local original=Chrome[name]
  Chrome[name]=function(a,b,c,...)
    if not context or depth then return original(a,b,c,...)end
    depth=true
    local x,y=point(textFirst and b or a,textFirst and c or b)
    local ok,result
    if textFirst then ok,result=pcall(original,a,x,y,...)
    else ok,result=pcall(original,x,y,c,...)end
    depth=false;if not ok then error(result,0)end;return result
  end
end
for _,name in ipairs({'print','printThrough'})do wrapPoint(name,true)end
for _,name in ipairs({'cursor','cursorThrough'})do wrapPoint(name,false)end
local clear=Chrome.clear
Chrome.clear=function(...)
  if context then return Chrome.paletteFill(0,0,256,192,Chrome.DEFAULT_BOX_PALETTE)end
  return clear(...)
end
local box=Chrome.box
Chrome.box=function(x,y,w,h,...)
  if context and not depth then
    if x==0 and w==20 then y,w=y+6,32
    elseif overlay then x,y=x+12,y+6 end
  end
  return box(x,y,w,h,...)
end
local icon=Party.drawIcon
Party.drawIcon=function(self,mon,x,y,...)
  if context==self then
    for i,m in ipairs(self.party)do if m==mon then y=y+(i-1)*8;break end end
    x=x+8
  end
  return icon(self,mon,x,y,...)
end
local hp=Party.drawHpBar
Party.drawHpBar=function(self,mon,x,y,...)
  if context==self then x,y=point(x,y)end
  return hp(self,mon,x,y,...)
end
local submenu=Party.drawSubmenu
Party.drawSubmenu=function(self,...)
  local old=overlay;overlay=context~=nil
  local ok,r=pcall(submenu,self,...);overlay=old
  if not ok then error(r,0)end;return r
end
local partyDraw=Party.drawPanel
Party.drawPanel=function(self,...)
  if not enabled()then return partyDraw(self,...)end
  context=self
  local ok,r=pcall(partyDraw,self,...)
  context,overlay,depth=nil,nil,nil
  if not ok then error(r,0)end;return r
end
local packDraw=Pack.drawPanel
local surface,quads
local function region(x,y,w,h,dx,dy)
  local key=table.concat({x,y,w,h},':')
  local q=quads[key]
  if not q then q=g.newQuad(x,y,w,h,160,144);quads[key]=q end
  g.setColor(1,1,1,1);g.draw(surface,q,dx,dy)
end
Pack.drawPanel=function(self,...)
  if not enabled()or not self.gfx:available()then return packDraw(self,...)end
  if not surface then surface=g.newCanvas(160,144,{dpiscale=1});surface:setFilter('nearest','nearest');quads={}end
  local target=g.getCanvas()
  g.push('all');g.setCanvas(surface);g.origin();g.setScissor();g.clear(0,0,0,0)
  local ok,err=pcall(self.gfx.draw,self.gfx,self:pocket().id)
  g.setCanvas(target);g.pop();if not ok then error(err,0)end
  Chrome.paletteFill(0,0,256,192,Chrome.DEFAULT_BOX_PALETTE)
  -- Repeat the cart's pattern; the bag and pocket plaque stay native size.
  for y=8,136,8 do for x=0,88,8 do region(0,8,8,8,x,y)end end
  g.setColor(0,0,0,1);g.rectangle('fill',0,0,256,8)
  region(0,0,80,8,0,0);region(80,0,80,8,176,0)
  region(0,24,40,24,28,32);region(0,56,40,24,28,88)
  self:drawList(18,2)
  Chrome.box(0,18,32,6)
  self:drawDescription(20)
  -- Native action/quantity/confirmation menus stay together at bottom right.
  g.push();g.translate(96,48);self:drawOverlays();g.pop()
end
shared.gen2MenuPresentation={width=256,height=192,active=menu}
