-- Expand the native battle canvas. Sprites, fonts, healthboxes, animations
-- and simulation retain their authored coordinates and pixel proportions.
local mod,shared=...
if not(love and love.graphics and love.graphics.newCanvas)then return end
local g=love.graphics
local Display=require('src.core.game3.display')
local Renderer=require('src.render.Renderer')
local Battle=require('src.core.game3.battle')
local Chrome=require('src.ui.game3.battle_chrome')
local Ui=require('src.core.game3.battle.ui')
local Anim=require('src.core.game3.battle.anim')
local Coords=require('src.core.game3.battle.anim_coords')
local Healthbox=require('src.core.game3.battle.healthbox')
local Screens=require('src.ui.game3.screens')
local Help=require('src.ui.game3.help_system')
local active=false
local function enabled()return shared.bool('modern_battle_hud',true)and not Display.planesBroken end
-- Animation endpoints use the same elevated enemy anchor, including doubles.
-- Keep this coordinate transform stable throughout update and draw.
local coords=Coords.coords
local coordCache=setmetatable({},{__mode='k'})
Coords.coords=function(st,key)
  local p=coords(st,key);local id=Coords.idOf(key)
  if not(enabled()and p and id and id%2==1)then return p end
  local c=coordCache[p]or {};coordCache[p]=c
  c.x,c.y,c[1],c[2]=p.x,p.y-16,p.x,p.y-16
  return c
end
local bounce=Ui.bounceOffset
Ui.bounceOffset=function(kind,id,...)
  local y=bounce(kind,id,...)
  if enabled()and kind=='mon'and id%2==1 and not(Ui._st and Ui._st.double)then return y-16 end
  return y
end
local hb=Healthbox.draw
Healthbox.draw=function(side,b,opts,...)
  if not active then return hb(side,b,opts,...)end
  local enemy=side=='enemy'or type(side)=='number'and side%2==1
  g.push('all');if enemy then g.translate(0,-32)end
  local getClip,setClip=g.getScissor,g.setScissor
  if Chrome.layout()=='rs'then
    -- Ruby/Sapphire print HP text through 8px scissor rows. Scissors use
    -- canvas coordinates, so they must follow the relocated healthbox.
    local tx,ty=g.transformPoint(0,0)
    g.setScissor=function(x,y,w,h)
      if x==nil then return setClip()end
      return setClip(x+tx,y+ty,w,h)
    end
    g.getScissor=function()
      local x,y,w,h=getClip()
      if x~=nil then return x-tx,y-ty,w,h end
    end
  end
  local ok,r=pcall(hb,side,b,opts,...)
  g.getScissor,g.setScissor=getClip,setClip;g.pop()
  if not ok then error(r,0)end
  return r
end
local stage=Anim.stage
Anim.stage=function(...)
  local s=stage(...)
  if not(active and s and s.trainer and s.trainer.enemy)then return s end
  local copy={};for k,v in pairs(s)do copy[k]=v end
  copy.trainer={};for k,v in pairs(s.trainer)do copy.trainer[k]=v end
  local enemy={};for k,v in pairs(s.trainer.enemy)do enemy[k]=v end
  enemy.oy=(enemy.oy or 0)-16;copy.trainer.enemy=enemy
  return copy
end
local function fullscreenMenu()
  for _,name in ipairs({'bag','party','pokedex','summary'})do
    local m=Screens.get(name)
    if m and ((m.isOpen and m.isOpen())or(m.active and m.active()))then return true end
  end
  return Help.isOpen()
end
shared.gen3BattleMenuOpen=fullscreenMenu
local present=Display.present
Display.present=function(game,...)
  active=shared.bool('modern_battle_hud',true)and Battle.isActive()
    and not Display.planesBroken and not fullscreenMenu()
  local rectangle=g.rectangle
  if active then
    g.rectangle=function(mode,x,y,w,h,...)
      if mode=='fill'and g.getCanvas()==Renderer.canvas then
        if x==0 and y==0 and (w==256 and h==192 or w==240 and h==160)then
          x,y,w,h=-8,-32,256,192
        elseif w==240 and x==0 then
          local r,gg,b=g.getColor()
          if r==0 and gg==0 and b==0 and (y==0 or y+h==160)then
            local top=math.floor(y*192/160+.5)
            x,y,w,h=-8,top-32,256,math.floor((y+h)*192/160+.5)-top
          end
        elseif h==160 and y==0 and (x==0 or x+w==240)then
          if x==0 then x,w=-8,w+8 else w=w+8 end
          y,h=-32,192
        end
      end
      return rectangle(mode,x,y,w,h,...)
    end
  end
  local ok,result=pcall(present,game,...)
  g.rectangle=rectangle
  active=false
  if not ok then error(result,0)end
  return result
end
local setSize,begin=Renderer.setUISize,Renderer.beginFrame
Renderer.setUISize=function(self,w,h,...)
  if active and w==240 and h==160 then w,h=256,192 end
  return setSize(self,w,h,...)
end
Renderer.beginFrame=function(self,...)
  if active then self.uiFill=true end
  return begin(self,...)
end
local draw=Battle.draw
Battle.draw=function(game,w,h,...)
  -- Display owns a push/pop around the entire battle pass. Leave this
  -- translation in place for queued message, BG and OAM layers as well.
  if active and g.getCanvas()==Renderer.canvas then g.translate(8,32)end
  return draw(game,w,h,...)
end
local quads=setmetatable({},{__mode='k'})
local function region(img,sx,sy,w,h,x,y)
  if not img then return end
  local cache=quads[img]or {};quads[img]=cache
  local key=table.concat({sx,sy,w,h},':')
  local q=cache[key]
  if not q then q=g.newQuad(sx,sy,w,h,img:getDimensions());cache[key]=q end
  g.draw(img,q,x,y)
end
local terrain=Chrome.drawTerrain
Chrome.drawTerrain=function(key,enemyOx,playerOx,bgOx)
  if not active then return terrain(key,enemyOx,playerOx,bgOx)end
  local e=Chrome.terrain(key or 'building')
  if not(e and e.bgImage and e.enemyPlat and e.playerPlat)then
    -- Preserve rare/special terrain exactly when split layers are absent.
    -- Extend its edge pixels without scaling any of its artwork.
    if e and e.image then
      g.push('all');g.setColor(1,1,1,1)
      for yy=-32,-1 do region(e.image,0,0,240,1,0,yy)end
      for xx=-8,-1 do region(e.image,0,0,1,112,xx,0)end
      for xx=240,247 do region(e.image,239,0,1,112,xx,0)end
      g.pop()
    end
    return terrain(key,enemyOx,playerOx,bgOx)
  end
  g.push('all');g.setScissor(0,0,256,144);g.setColor(1,1,1,1)
  local off=(tonumber(bgOx)or 0)%256
  local function wallpaper(x)
    region(e.bgImage,0,0,256,112,x,-32)
    -- Keep the native sky/horizon at the top. Extend only the lower ground
    -- pattern, never its transparent tail or the sky's decorative top edge.
    for yy=80,104,8 do region(e.bgImage,0,104,256,8,x,yy)end
  end
  wallpaper(-8-off)
  if off~=0 then wallpaper(248-off)end
  g.draw(e.enemyPlat,tonumber(enemyOx)or 0,-16)
  g.draw(e.playerPlat,tonumber(playerOx)or 0,0)
  g.pop();return true
end
local panel=Chrome.drawPanel
local frameRects=Chrome.menuFrameRects
Chrome.menuFrameRects=function(...)
  local rects=frameRects(...)
  if not active or not rects then return rects end
  local out={}
  for i,r in ipairs(rects)do
    local x,y,w,h=r[1],r[2],r[3],r[4]
    local right=x+w==29
    if x==1 then x,w=0,w+1 end
    if right then w=w+1 end
    out[i]={x,y,w,h}
  end
  return out
end
Chrome.drawPanel=function(mode)
  panel(mode)
  if not active or not Chrome._textbox then return end
  local sy=112+(mode=='menu'and 160 or mode=='moves'and 320 or 0)
  g.setColor(1,1,1,1)
  -- Move the outer corners and repeat one interior tile on either side.
  -- Never stretch borders or fonts to fill the additional sixteen pixels.
  region(Chrome._textbox,0,sy,8,48,-8,112)
  region(Chrome._textbox,8,sy,8,48,0,112)
  region(Chrome._textbox,224,sy,8,48,232,112)
  region(Chrome._textbox,232,sy,8,48,240,112)
end
shared.gen3BattlePresentation={width=256,height=192,active=function()return active end}
