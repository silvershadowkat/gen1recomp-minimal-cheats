-- Cross-cache references only. No ROM graphics are bundled or copied.
local mod,shared=...
if shared.generation==3 or not (love and love.graphics and love.graphics.newCanvas)then return end
local Cache=require("src.import.CacheFs")
local A={images={},owned=setmetatable({},{__mode="k"})}
local root="data/generated/gba/"
local tried=false
local g=love.graphics
local function bytes(rel)return Cache.readAt(A.prefix..root..rel)end
local function image(rel,w,h)
  local raw=bytes(rel)
  if not raw or #raw~=w*h*4 then return end
  local data=love.image.newImageData(w,h,"rgba8",raw)
  if rel:find("healthbox_",1,true)then
    local start=rel:find("player",1,true)and 64 or 56
    for y=10,15 do for x=start,start+7 do
      local r,gg,b,a=data:getPixel(x,y)
      if math.abs(r-66/255)<.01 and math.abs(gg-66/255)<.01
        or math.abs(r-222/255)<.02 and math.abs(gg-214/255)<.02 then
        data:setPixel(x,y,1,1,222/255,a)
      end
    end end
  end
  local img=g.newImage(data);img:setFilter("nearest","nearest")
  return img
end
local function tableData(rel)
  local src=bytes(rel);if not src then return {}end
  local chunk=(loadstring or load)(src,"@"..rel)
  return chunk and chunk() or {}
end
local quads=setmetatable({},{__mode="k"})
local function region(img,sx,sy,sw,sh,x,y)
  if not img then return end
  quads[img]=quads[img]or {};local key=sx..":"..sy..":"..sw..":"..sh
  local q=quads[img][key]
  if not q then q=g.newQuad(sx,sy,sw,sh,img:getDimensions());quads[img][key]=q end
  g.draw(img,q,x,y)
end
local function tile(sheet,id,x,y)
  g.setColor(1,1,1,1);region(sheet,(id%40)*8,math.floor(id/40)*8,8,8,x,y)
end
local C={};A.chrome=C
function A.init()
  if tried then return A.ready end;tried=true
  for _,version in ipairs({"firered","leafgreen"})do
    if Cache.readAt(version.."/"..root.."pokemon/battle/manifest.lua")then A.prefix=version.."/";break end
  end
  if not A.prefix then return false end
  -- Read graphics only; importing a different generation's engine/UI classes
  -- is deliberately disallowed by the engine's generation guard.
  C.player=image("pokemon/battle/healthbox_player.rgba",128,64)
  C.enemy=image("pokemon/battle/healthbox_enemy.rgba",128,32)
  C.textbox=image("pokemon/battle/textbox.rgba",256,512)
  C.elements=image("pokemon/battle/elements.rgba",320,24)
  C.exp=image("pokemon/battle/elements_exp.rgba",320,24)
  C.partyBar=image("pokemon/battle/party_summary_bar.rgba",128,8)
  A.fonts={}
  for _,face in ipairs({"normal","small"})do
    local f="chrome/fonts/latin_"..face
    A.fonts[face]={fg=image(f.."_fg.rgba",256,512),shadow=image(f.."_shadow.rgba",256,512),
      widths=tableData("chrome/fonts/latin_"..(face=="normal" and "widths" or "small_widths")..".lua")}
  end
  A.ready=C.player~=nil and C.enemy~=nil and C.textbox~=nil and A.fonts.normal.fg~=nil
  if A.ready then mod.log:info("Battle presentation redirects to imported %s assets",A.prefix)end
  return A.ready
end
function C.drawPlayerBox(x,y)g.setColor(1,1,1,1);g.draw(C.player,x,y)end
function C.drawEnemyBox(x,y)g.setColor(1,1,1,1);g.draw(C.enemy,x,y)end
function C.drawPartyBar(party,x,y,opponent)
  g.setColor(1,1,1,1)
  if C.partyBar then g.draw(C.partyBar,x,y,0,opponent and -1 or 1,1)end
  for i=1,6 do
    local mon=(party or {})[i]
    local id=not mon and 67 or (mon.hp or 0)<=0 and 69
      or (mon.status and mon.status~=0 and mon.status~=''and mon.status~='NONE')and 68 or 66
    local bx=opponent and x-24-10*(6-i)or x+24+10*(i-1)
    tile(C.elements,id,bx,y-8)
  end
end
function C.drawWindow(x,y,w,h)
  g.setColor(1,1,1,1);g.rectangle('fill',x+4,y+4,w-8,h-8)
  -- The move-panel border, tiled at its native pixel size.
  local function part(sx,sy,sw,sh,dx,dy)region(C.textbox,sx,432+sy,sw,sh,dx,dy)end
  for xx=8,w-9,8 do local n=math.min(8,w-8-xx)
    part(8,0,n,8,x+xx,y);part(8,40,n,8,x+xx,y+h-8)end
  for yy=8,h-9,8 do local n=math.min(8,h-8-yy)
    part(0,8,8,n,x,y+yy);part(152,8,8,n,x+w-8,y+yy)end
  part(0,0,8,8,x,y);part(152,0,8,8,x+w-8,y)
  part(0,40,8,8,x,y+h-8);part(152,40,8,8,x+w-8,y+h-8)
end
function C.drawPanel(mode)
  local offset=mode=="menu" and 160 or mode=="moves" and 320 or 0
  g.setColor(1,1,1,1);region(C.textbox,0,112+offset,240,48,0,112)
end
function C.drawHpBar(x,y,hp,maxHp,fraction,width)
  local f=maxHp>0 and math.max(0,math.min(1,hp/maxHp))or 0
  f=math.max(0,math.min(1,fraction or f));width=width or 48
  local n=f*width
  local base=f>.5 and 3 or f>.2 and 47 or 56
  tile(C.elements,1,x,y);tile(C.elements,2,x+8,y)
  for i=0,width/8-1 do
    tile(C.elements,base,x+16+i*8,y)
    local fill=math.max(0,math.min(8,n-i*8))
    if fill>0 then
      local id=base+8;local sx,sy=(id%40)*8,math.floor(id/40)*8
      if not C.hpFillQuad then C.hpFillQuad=g.newQuad(sx,sy,fill,8,C.elements:getDimensions())
      else C.hpFillQuad:setViewport(sx,sy,fill,8,C.elements:getDimensions())end
      g.setColor(1,1,1,1);g.draw(C.elements,C.hpFillQuad,x+16+i*8,y)
    end
  end
end
function C.drawExpBar(x,y,f)
  local n=math.floor(math.max(0,math.min(1,f))*64)
  for i=0,7 do tile(C.exp or C.elements,12+math.max(0,math.min(8,n-i*8)),x+i*8,y)end
end
function C.drawCaughtBall(x,y)tile(C.elements,70,x,y)end
function C.drawTerrain(key)
  C.terrains=C.terrains or {}
  local t=C.terrains[key]
  if not t then
    t={bg=image("pokemon/battle/terrain_bg_"..key..".rgba",256,160),
      enemy=image("pokemon/battle/terrain_enemy_"..key..".rgba",256,160),
      player=image("pokemon/battle/terrain_player_"..key..".rgba",256,160)}
    C.terrains[key]=t
  end
  g.setColor(1,1,1,1)
  region(t.bg,0,0,240,112,0,0)
  region(t.enemy,0,0,256,112,26,0)
  region(t.player,0,0,256,112,-24,0)
end
local glyph={[' ']=0,['é']=0x1b,['É']=6,['&']=0x2d,['+']=0x2e,['=']=0x35,
  [';']=0x36,['%']=0x5b,['(']=0x5c,[')']=0x5d,['<']=0x85,['>']=0xef,
  ['!']=0xab,['?']=0xac,['.']=0xad,['-']=0xae,['…']=0xb0,["'"]=0xb4,
  ['♂']=0xb5,['♀']=0xb6,['¥']=0xb7,[',']=0xb8,['×']=0xb9,['/']=0xba,[':']=0xf0}
for i=0,25 do glyph[string.char(65+i)]=0xbb+i;glyph[string.char(97+i)]=0xd5+i end
for i=0,9 do glyph[tostring(i)]=0xa1+i end
function A.text(text,x,y,white,small,color)
  if not A.init()then return end
  local f=A.fonts[small and "small" or "normal"]
  if not f.fg then f=A.fonts.normal end
  local pen=x
  for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*")do
    local id=glyph[char]or 0xac
    local sx,sy=(id%16)*16,math.floor(id/16)*16
    g.setColor(white and .38 or 27/31,white and .38 or 26/31,white and .38 or 22/31,1)
    region(f.shadow,sx,sy,16,16,pen,y)
    if color then g.setColor(color) else g.setColor(white and 1 or 8/31,white and 1 or 8/31,white and 1 or 8/31,1)end
    region(f.fg,sx,sy,16,16,pen,y)
    pen=pen+(f.widths[id]or 6)
  end
  return pen-x
end
function A.fit(text,width,small)
  local f=A.fonts[small and "small" or "normal"];local out={};local used=0
  for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*")do
    local w=f.widths[glyph[char]or 0xac]or 6
    if used+w>width then break end
    out[#out+1]=char;used=used+w
  end
  return table.concat(out),used
end
function A.pic(data,species,back,mon)
  if not A.init()then return end
  local def=data and data.pokemon and data.pokemon[species]
  local nat=def and tonumber(def.dex)
  if not nat or nat<1 or nat>251 then return end
  if nat==201 then return end -- retain Gen 2's DV-selected Unown letter
  local kind=back and "back" or "front"
  if mon and mon.shiny then kind=kind.."_shiny"end
  local key=kind.."/"..nat
  if A.images[key]==false then return end
  if A.images[key]then return A.images[key]end
  local bytes=Cache.readAt(A.prefix..root.."pokemon/"..key..".rgba")
  if not bytes or #bytes~=64*64*4 then A.images[key]=false;return end
  local image=love.graphics.newImage(love.image.newImageData(64,64,"rgba8",bytes))
  image:setFilter("nearest","nearest")
  -- Bound texture memory during long sessions with many different species.
  A.count=(A.count or 0)+1
  if A.count>48 then A.images={};A.count=1 end
  A.images[key]=image;A.owned[image]=true
  return image
end
shared.battleAssets=A
-- FireRed's ROM trainer-picture IDs. Only shared characters/classes are
-- mapped: Johto-only protagonists, leaders and rivals retain their own art.
local trainers={YOUNGSTER=82,BUGCATCHER=83,LASS=84,SAILOR=85,CAMPER=86,JRTRAINERM=86,
  PICNICKER=87,JRTRAINERF=87,POKEMANIAC=88,SUPERNERD=89,HIKER=90,BIKER=91,BURGLAR=92,
  ENGINEER=93,FISHER=94,FISHERMAN=94,SWIMMER=95,SWIMMERM=95,CUEBALL=96,GAMBLER=97,
  BEAUTY=98,SWIMMERF=99,PSYCHIC=100,PSYCHICM=100,ROCKER=101,JUGGLER=102,TAMER=103,
  BIRDKEEPER=104,BLACKBELT=105,RIVAL1=106,RIVAL2=124,RIVAL3=125,SCIENTIST=107,
  GIOVANNI=108,ROCKET=109,GRUNTM=109,GRUNTF=137,COOLTRAINERM=110,COOLTRAINERF=111,
  LORELEI=112,BRUNO=113,AGATHA=114,LANCE=115,CHAMPION=115,BROCK=116,MISTY=117,
  LTSURGE=118,ERIKA=119,KOGA=120,BLAINE=121,SABRINA=122,GENTLEMAN=123,BLUE=124,
  CHANNELER=126,TWINS=127,PROFOAK=132,RED=135,SCHOOLBOY=29,POKEFANM=32,POKEFANF=33}
function A.trainer(class,back)
  if not A.init()then return end
  if not back and shared.generation==2 and tostring(class):match("^RIVAL")then return end
  local id=back and tonumber(class) or trainers[tostring(class):gsub("^OPP_",""):gsub("_","")]
  if not id then return end
  local key="trainer:"..(back and "back"or "front")..id
  if A.images[key]~=nil then return A.images[key]or nil end
  local rel="trainers/"..(back and "back_" or "front/")..id..".rgba"
  local raw=bytes(rel)
  if not raw or #raw<64*64*4 then A.images[key]=false;return end
  -- All mapped back portraits use idle frame zero. The original game still
  -- controls send-out/throw timing; this is only its standing portrait.
  local img=g.newImage(love.image.newImageData(64,64,"rgba8",raw:sub(1,64*64*4)))
  img:setFilter("nearest","nearest");A.images[key]=img;A.owned[img]=true
  return img
end
