-- Give native Party/Bag screens a 4:3 canvas. Extend only the background's
-- border tiles; every icon, font glyph, selector and item remains unscaled.
local mod,shared=...
if not(love and love.graphics and love.graphics.newCanvas)then return end
local g=love.graphics
local Display=require('src.core.game3.display')
local Renderer=require('src.render.Renderer')
local Screens=require('src.ui.game3.screens')
local active,painting=false,false
local function selected()
  if not shared.bool('modern_battle_hud',true)or Display.planesBroken then return false end
  local summary=Screens.get('summary')
  if summary and summary.isOpen and summary.isOpen()then return false end
  for _,name in ipairs({'party','bag'})do
    local m=Screens.get(name)
    if m and ((m.isOpen and m.isOpen())or(m.active and m.active()))then return name end
  end
  return false
end
local quads=setmetatable({},{__mode='k'})
local function extend(image,draw)
  local cache=quads[image]or {};quads[image]=cache
  local function part(sx,sy,w,h,x,y)
    local k=table.concat({sx,sy,w,h},':')
    local q=cache[k]
    if not q then q=g.newQuad(sx,sy,w,h,image:getDimensions());cache[k]=q end
    draw(image,q,x,y)
  end
  if active=='bag'then
    -- Bag backdrops contain complete pocket/description decorations. Repeat
    -- only clean wallpaper outside them; never cut through those decorations.
    local kanto=shared.gameVersion=='firered'or shared.gameVersion=='leafgreen'
    for y=-16,168,8 do for x=-8,240,8 do
      if x<0 or x>=240 or y<0 or y>=160 then
        if kanto and y>=112 then part(80,144,8,8,x,y)
        else part(8,40,8,8,x,y)end
      end
    end end
    draw(image,0,0)
    return
  end
  if active=='party'and shared.gameVersion~='ruby'and shared.gameVersion~='sapphire'then
    -- Emerald/FRLG bake the cancel plaque into the background. Keep it once;
    -- only the clean wallpaper tile continues outside the authored surface.
    for y=-16,168,8 do for x=-8,240,8 do
      if x<0 or x>=240 or y<0 or y>=160 then part(8,88,8,8,x,y)end
    end end
    draw(image,0,0)
    return
  end
  -- Original interior; copy whole 8px edge tiles into the extra room.
  part(8,8,224,144,8,8)
  for _,y in ipairs({-8,0,152,160})do
    part(8,y<8 and 8 or 144,224,8,8,y)
  end
  for y=-8,160,8 do
    local sy=math.max(8,math.min(144,y))
    part(8,sy,8,8,0,y);part(224,sy,8,8,232,y)
    part(0,sy,8,8,-8,y);part(232,sy,8,8,240,y)
  end
  for _,y in ipairs({-16,168})do
    local sy=y<0 and 0 or 152
    part(8,sy,224,8,8,y)
    part(8,sy,8,8,0,y);part(224,sy,8,8,232,y)
    part(0,sy,8,8,-8,y);part(232,sy,8,8,240,y)
  end
end
local size,begin,finish=Renderer.setUISize,Renderer.beginFrame,Renderer.endFrame
Renderer.setUISize=function(self,w,h,...)
  if active and w==240 and h==160 then w,h=256,192 end
  return size(self,w,h,...)
end
Renderer.beginFrame=function(self,...)
  if active then self.uiFill=true end
  return begin(self,...)
end
Renderer.endFrame=function(self,...)
  local old=painting;painting=false
  local ok,r=pcall(finish,self,...);painting=old
  if not ok then error(r,0)end;return r
end
local present=Display.present
Display.present=function(game,...)
  active=selected();painting=active
  if not active then return present(game,...)end
  local origin,draw,rectangle=g.origin,g.draw,g.rectangle
  local setClip,getClip,intersect=g.setScissor,g.getScissor,g.intersectScissor
  local function here()return painting and g.getCanvas()==Renderer.canvas end
  g.origin=function(...)
    origin(...);if here()then g.translate(8,16)end
  end
  g.draw=function(image,a,b,...)
    if here()and type(a)=='number'and type(b)=='number'and a==0 and (b==0 or b==1)
      and image and image.getDimensions then
      local w,h=image:getDimensions()
      if w==240 and h==160 and select('#',...)==0 then return extend(image,draw)end
    end
    return draw(image,a,b,...)
  end
  g.rectangle=function(mode,x,y,w,h,...)
    if here()and mode=='fill'and x==0 and y==0 and w==240 and h==160 then
      x,y,w,h=-8,-16,256,192
    elseif here()and mode=='fill'and x==0 and w==240 and (y==0 or y+h==160)then
      local r,gg,b=g.getColor()
      if r==0 and gg==0 and b==0 then
        local top=math.floor(y*192/160+.5)
        x,y,w,h=-8,top-16,256,math.floor((y+h)*192/160+.5)-top
      end
    end
    return rectangle(mode,x,y,w,h,...)
  end
  g.setScissor=function(x,y,w,h)
    if here()and x~=nil then
      if x==0 and y==0 and w==240 and h==160 then return setClip(0,0,256,192)end
      x,y=x+8,y+16
    end
    return setClip(x,y,w,h)
  end
  g.getScissor=function()
    local x,y,w,h=getClip()
    if here()and x~=nil then x,y=x-8,y-16 end
    return x,y,w,h
  end
  g.intersectScissor=function(x,y,w,h)
    if here()then x,y=x+8,y+16 end
    return intersect(x,y,w,h)
  end
  local ok,r=pcall(present,game,...)
  g.origin,g.draw,g.rectangle=origin,draw,rectangle
  g.setScissor,g.getScissor=setClip,getClip
  g.intersectScissor=intersect
  active,painting=false,false
  if not ok then error(r,0)end;return r
end
shared.gen3MenuPresentation={width=256,height=192}
