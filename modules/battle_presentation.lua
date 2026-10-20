-- A 4:3 presentation of the native battle surface. Simulation, input, text
-- paging, sprite effects and animation timing remain owned by the engine.
local mod, shared = ...
if shared.generation == 3 or not (love and love.graphics and love.graphics.newCanvas) then return end
local gen2 = shared.generation == 2
local B = require(gen2 and "src.ui.gen2.BattleState" or "src.battle.BattleState")
local Wide = require(gen2 and "src.ui.gen2.WideBattle" or "src.battle.WideBattle")
local Font = require("src.render.Font")
local Chrome = gen2 and require("src.ui.gen2.Chrome")
local g = love.graphics
local A=shared.battleAssets
-- 256x192 fills the Nova at an exact 5x, matching its overworld grid and
-- keeping imported Gen3 glyphs and sprites at one common source-pixel size.
local W,H = 256,192
local ChoiceBox=not gen2 and require("src.ui.ChoiceBox")
local function battleChoice(state)
  if gen2 or getmetatable(state)~=ChoiceBox then return false end
  local states=state.game and state.game.stack and state.game.stack.states or {}
  for i,s in ipairs(states)do
    if s==state then return i>1 and getmetatable(states[i-1])==B end
  end
  return false
end
-- Native party/bag/choice states are authored on a 160x144 surface. Keep
-- their background battle on that same surface for the lifetime of the menu.
local function nativeOverlay()
  if gen2 then return false end
  local states=shared.game and shared.game.stack and shared.game.stack.states or {}
  local found=false
  for _,state in ipairs(states)do
    if getmetatable(state)==B then found=true
    elseif found and getmetatable(state)~=B.StatBox and not battleChoice(state)
      and not(state.itemBox and state.kind=='bag')then return true end
  end
  return false
end
local function enabled() return shared.bool("modern_battle_hud", true) and not nativeOverlay() end
shared.modernBattleEnabled = enabled
local function wrap(name, fn)
  local original = B[name]
  B[name] = function(self,...)
    if enabled() then return fn(self,...) end
    return original(self,...)
  end
end
for _,name in ipairs(gen2 and {"wideLayout"}or {"wideLayout","isWideBattleLayout"})do
  local original=B[name]
  B[name]=function(self,...)
    if shared.bool("modern_battle_hud",true)then return not nativeOverlay()end
    return original(self,...)
  end
end
wrap("wantsFillScale",function() return true end)
if not gen2 then
  local fill=B.wantsFillScale
  B.wantsFillScale=function(self,...)
    if shared.bool("modern_battle_hud",true)and nativeOverlay()then return false end
    return fill(self,...)
  end
end
wrap("extendedHUD",function() return false end)
if not gen2 then
  local List=require('src.ui.ListMenu')
  local palettes=List.sgbPalettes
  List.sgbPalettes=function(self,game)
    if self.itemBox and self.kind=='bag'and enabled()then
      for _,s in ipairs(game.stack.states)do
        if getmetatable(s)==B then return {{colors=false,x=0,y=0,w=160,h=H}}end
      end
    end
    return palettes(self,game)
  end
  wrap("uiSize",function() return W,H end)
  wrap("sgbPalettes",function() return {{colors=false,x=0,y=0,w=W,h=H}} end)
end
local function box(x,y,w,h)
  g.setColor(.16,.25,.31,1); g.rectangle("fill",x,y,w,h,3,3)
  g.setColor(.73,.83,.82,1); g.rectangle("fill",x+2,y+2,w-4,h-4,2,2)
  g.setColor(.97,.97,.88,1); g.rectangle("fill",x+4,y+4,w-8,h-8,1,1)
end
local function label(s,x,y)
  if A and A.init() then return A.text(s,x,y-3) end
  g.setColor(.13,.19,.23,1); Font.draw(tostring(s or ""),x,y)
end
local function short(s,pixels)
  s=tostring(s or "")
  local spans=Font.split(s)
  local n=Font.spansFitting(spans,pixels)
  if n>=#spans then return s end
  return n>1 and (s:sub(1,spans[n-1].to)..".") or ""
end
local function bar(x,y,w,fraction,color)
  g.setColor(.19,.28,.30,1);g.rectangle("fill",x,y,w,6,2,2)
  g.setColor(.85,.88,.82,1);g.rectangle("fill",x+1,y+1,w-2,4)
  g.setColor(color);g.rectangle("fill",x+1,y+1,math.floor((w-2)*math.max(0,math.min(1,fraction))),4)
end
local function panel(name,level,status,hp,maxhp,player,caught,exp,gender,hpFraction)
  local x,y=player and 128 or 8,player and 104 or 16
  if A and A.init() then
    local c=A.chrome
    g.push();g.translate(x,y)
    if player then c.drawPlayerBox(0,0) else c.drawEnemyBox(0,0) end
    local nx=player and 16 or 8
    local nm,nw=A.fit(name,gender and 52 or 60,true)
    A.text(nm,nx,3,false,true)
    if gender then A.text(gender,nx+nw,3,false,true)end
    A.text("Lv"..tostring(level or 1),player and 77 or 69,3,false,true)
    if player then g.setColor(1,1,222/255,1);g.rectangle("fill",56,21,40,11)end
    c.drawHpBar(player and 32 or 24,16,hp,maxhp,hpFraction)
    if caught then c.drawCaughtBall(8,17)end
    if status then A.text(status,player and 13 or 2,22,false,true)end
    if player then
      A.text(("%3d/"):format(hp),60,21,false,true)
      A.text(("%3d"):format(maxhp),80,21,false,true)
      if exp then c.drawExpBar(32,32,exp)end
    end
    g.pop()
    return
  end
  local height=player and 50 or 42
  box(x,y,136,height)
  label(short(name,88),x+8,y+7)
  label(status or ("L"..tostring(level or 1)),x+96,y+7)
  if gender then label(gender,x+8,y+20) end
  if caught then g.setColor(.72,.29,.27,1);g.circle("fill",x+13,y+24,3) end
  label("HP",x+24,y+21)
  local f=hpFraction or ((maxhp or 0)>0 and hp/maxhp or 0)
  bar(x+44,y+22,84,f,f>.5 and {.25,.70,.48,1} or f>.2 and {.91,.69,.25,1} or {.84,.31,.29,1})
  if player then
    label(("%d/%d"):format(hp,maxhp),x+64,y+32)
    if exp then bar(x+8,y+43,120,exp,{.29,.61,.85,1}) end
  end
end
local function smoothHp(b,side,mon,target)
  target=math.max(0,math.min(1,target))
  b._silverHpVisual=b._silverHpVisual or {}
  local state=b._silverHpVisual[side]
  local now=love.timer and love.timer.getTime and love.timer.getTime()
  if not state or state.mon~=mon then
    state={mon=mon,value=target,time=now};b._silverHpVisual[side]=state
  else
    local dt=now and state.time and math.max(0,now-state.time)or 1/60
    state.value=state.value+(target-state.value)*math.min(1,dt*30)
    if math.abs(state.value-target)<.0001 then state.value=target end
    state.time=now
  end
  return state.value
end
shared.battleSmoothHp=smoothHp
local function modernHud(b)
  if not b:statusHUDVisible() then return end
  if gen2 then
    for _,side in ipairs({"enemy","player"})do
      local m=b:activeMon(side)
      local player=side=="player"
      if m and (player and b.showPlayerHud or not player and b.showEnemyHud) and not b:hudCleared(side) then
        panel(b:name(m),player and b.shownLevel or m.level,b:statusTag(m,side),
          math.floor(b:hudHp(m,side)),m.maxHp or (m.stats and m.stats.hp) or 1,
          player,not player and b.battle.wild and b.caughtMark,
          player and (b.shownExp or 0)/64 or nil,b:genderSymbol(m),
          smoothHp(b,side,m,b:hudHpPixels(m,side)/48))
      end
    end
  else
    if b.fieldCleared or (b.introSlide or 0)>0 or b.introBalls then return end
    for _,side in ipairs({"enemy","player"})do
      local v=b[side];local player=side=="player"
      local visible=v and not v.fainted
      if player then visible=visible and not b.safari and not b.demo and not b.showPlayerBack
      else visible=visible and not b.showEnemyTrainer and not b.enemySendingOut and not b:growInScale(v) end
      if visible then
        local exp
        if player and shared.bool("xp_bar",true) then
          local m=v.mon;local def=b.data.pokemon[m.species]
          local Growth=require("src.pokemon.Growth")
          local lo=Growth.expForLevel(def.growthRate,m.level,b.data.growth_rates)
          local hi=Growth.expForLevel(def.growthRate,m.level+1,b.data.growth_rates)
          exp=hi>lo and ((m.exp or lo)-lo)/(hi-lo) or 1
        end
        local dex=b.game.save.pokedex
        panel(v.name,v.mon.level,v.shownStatus and b:statusLabel({status=v.shownStatus}),
          math.max(0,math.floor(v.shownHP or v.mon.hp or 0)),v.mon.stats.hp,player,
          not player and b.kind=="wild" and dex and dex.owned and dex.owned[v.mon.species],exp,nil,
          smoothHp(b,side,v.mon,(v.shownPx or ((v.shownHP or v.mon.hp)/v.mon.stats.hp*48))/48))
      end
    end
  end
end
local surface, fieldQuad, bottomQuad, infoQuad
local captureActive=false
local captureBattle
if gen2 then
  wrap("moveGridNavigation",function()return true end)
  local pass
  local expBurst=B.drawExpBurst
  B.drawExpBurst=function(self,...)
    if captureActive and pass then return end
    return expBurst(self,...)
  end
  local AV=require("src.ui.gen2.BattleAnimView")
  local presentSlide=AV.presentSlide
  AV.presentSlide=function(self,frame,drawBg,drawBackpic)
    if not(captureActive and pass and captureBattle)then return presentSlide(self,frame,drawBg,drawBackpic)end
    local remaining=1-math.max(0,math.min(1,frame/AV.SLIDE_FRAMES))
    local old=captureBattle.slidingBackpic
    captureBattle.slidingBackpic=nil
    g.push('all');g.translate((pass=='player'and 1 or -1)*W*remaining,0)
    drawBg();g.pop()
    captureBattle.slidingBackpic=old
  end
  local picDraw,objects,fill,field=B.drawPic,AV.drawObjects,AV.fillBackground,Wide.drawField
  B.drawPic=function(self,mon,back)
    if captureActive and pass and (back and "player"or "enemy")~=pass then return end
    return picDraw(self,mon,back)
  end
  AV.fillBackground=function(self,...)
    if captureActive then return end
    return fill(self,...)
  end
  AV.drawObjects=function(self,runner,battle)
    if not captureActive then return objects(self,runner,battle)end
    if pass then return end
    local sprites=runner:oam()
    if #sprites==0 then return end
    local rest,ball
    if shared.captureBalls then rest,ball=shared.captureBalls.gen2(runner,sprites)end
    local lo,hi=math.huge,-math.huge
    for _,s in ipairs(sprites)do lo=math.min(lo,s.x-8);hi=math.max(hi,s.x)end
    local t=math.max(0,math.min(1,((lo+hi)/2-40)/88))
    -- Translate each complete OAM group, preserving its shapes and spacing.
    -- A projectile travelling across the field interpolates between anchors.
    local moved={}
    for _,s in ipairs(rest or sprites)do
      local v={};for k,value in pairs(s)do v[k]=value end
      v.x=v.x+math.floor(16+48*t+.5);v.y=v.y+math.floor(28*(1-t)+.5)
      moved[#moved+1]=v
    end
    local proxy=setmetatable({oam=function()return moved end},{__index=runner})
    local result=objects(self,proxy,battle)
    if ball then
      ball.x=ball.x+math.floor(16+48*t+.5)
      ball.y=ball.y+math.floor(28*(1-t)+.5)
      shared.captureBalls.draw(runner._silverBallItem,ball)
    end
    return result
  end
  Wide.drawField=function(b)
    if not captureActive then return field(b)end
    if not b:hasBattleSides()then return false end
    for _,side in ipairs({"player","enemy"})do
      pass=side
      g.push();g.translate(side=="player"and 16 or 64,side=="player"and 28 or 0)
      b:drawSceneBody(function()b:drawPics()end)
      g.pop()
    end
    pass=nil
    if b.anim and b.animView then b.animView:drawObjects(b.anim,b.battle)end
    if b.expBurst then
      g.push();g.translate(80,0);b:drawExpBurst();g.pop()
    end
    return true
  end
  local pic,frame=B.pic,B.frontAnimFrame
  B.pic=function(self,mon,back)
    if captureActive and mon then
      local image=A.pic(self.game.data,mon.species,back,mon)
      if image then return image,true,"silvershadow-gen3-"..mon.species end
    end
    return pic(self,mon,back)
  end
  B.frontAnimFrame=function(self,mon)
    if captureActive and mon and A.pic(self.game.data,mon.species,false,mon) then return nil end
    return frame(self,mon)
  end
else
  local AP=require("src.battle.AnimPlayer")
  local drawSprites=AP.drawSprites
  AP.drawSprites=function(self,sprites,colorFn)
    if captureActive and captureBattle and self==captureBattle.animPlayer and shared.captureBalls then
      local rest,ball=shared.captureBalls.gen1(captureBattle,self,sprites)
      if ball then
        local r=drawSprites(self,rest,colorFn)
        shared.captureBalls.draw(captureBattle._silverBallItem,ball)
        return r
      end
    end
    return drawSprites(self,sprites,colorFn)
  end
  local balls=B.drawBallRow
  B.drawBallRow=function(self,...)
    if captureActive then return end
    return balls(self,...)
  end
  local pics=B.drawPicsLayer
  B.drawPicsLayer=function(self,slide,sx,sy,side,skipMenuClip)
    if not(captureActive and side)then return pics(self,slide,sx,sy,side,skipMenuClip)end
    g.push('all');g.setScissor(0,0,W,104)
    g.translate(side=='enemy'and -64 or -4,side=='player'and 10 or 0)
    local ok,err=pcall(pics,self,slide*2,sx,sy,side,skipMenuClip)
    g.pop();if not ok then error(err,0)end
  end
  local animOffset=Wide.animationOffset
  Wide.animationOffset=function(sprites)
    local x,y=animOffset(sprites)
    if captureActive then x=math.floor(16+(x-20)*56/116+.5)end
    return x,y
  end
  local scale=B.resolveBattleScale
  B.resolveBattleScale=function(data,side,path,species)
    if captureActive and not path then return 1 end
    return scale(data,side,path,species)
  end
end
local originalWide = Wide.draw
local function nativeSurface(b,regular)
  surface=surface or g.newCanvas(304,144)
  surface:setFilter("nearest","nearest")
  local previous=g.getCanvas()
  local oldBox=gen2 and Chrome.box or Font.drawBox
  local oldStatus,oldEnemy,oldPlayer,oldBottom=b.statusHUDVisible,b.drawEnemyHud,b.drawPlayerHud,b.bottomUIVisible
  local oldFill,oldClear=gen2 and Chrome.paletteFill,gen2 and Chrome.clear
  local oldRectangle=g.rectangle
  local first=true
  g.push("all");g.setCanvas(surface);g.origin();g.setScissor();g.clear(0,0,0,0)
  local function modernBox(tx,ty,tw,th) box(tx*8,ty*8,tw*8,th*8) end
  if gen2 then Chrome.box=modernBox else Font.drawBox=modernBox end
  -- Skip only the wide surface's initial paper fill. All animation flashes
  -- and palette changes after it are preserved.
  if regular and not gen2 then
    g.rectangle=function(mode,x,y,w,h,...)
      if first and mode=="fill" and x==0 and y==0 and w==304 and h==144 then first=false;return end
      return oldRectangle(mode,x,y,w,h,...)
    end
  end
  if regular then
    b.statusHUDVisible=function()return false end
    if A.init() then b.bottomUIVisible=function()return false end end
    if gen2 then
      b.drawEnemyHud=function()end;b.drawPlayerHud=function()end
      Chrome.paletteFill=function()end;Chrome.clear=function()end
    end
  end
  local originalSprites={}
  local trainerSaved={}
  local function replace(key,img)
    if img and b[key]then trainerSaved[key]={value=b[key]};b[key]=img end
  end
  captureActive=regular and A.init()
  captureBattle=b
  if captureActive then
    if gen2 then
      local img=A.trainer(b.enemyTrainerClass,false)
      replace("enemyTrainerImage",img)
      if img then
        trainerSaved.enemyTrainerTrueColor={value=b.enemyTrainerTrueColor}
        b.enemyTrainerTrueColor=true
      end
    else
      if shared.get("follower_mode","trainer")=="trainer" then
        replace("playerBackPic",A.trainer(b.demo and 5 or 0,true))
      end
      -- Jessie & James have no matching FRLG portrait.
      if not(b.oppClass=="OPP_ROCKET"and(b.partyIndex or 1)>=42)then
        replace("trainerPic",A.trainer(b.oppClass,false))
      end
    end
  end
  if captureActive and not gen2 and not b.ghost then
    for _,side in ipairs({"player","enemy"})do
      local v=b[side]
      if v and v.mon and v.sprite and not A.owned[v.sprite]then
        -- Record the initial pic identity. A later native swap (e.g. an
        -- unrevealed ghost) must not be replaced with its real species.
        v._silverOriginalPic=v._silverOriginalPic or v.sprite
        if v.sprite==v._silverOriginalPic then
          local img=A.pic(b.data,v.mon.species,side=="player",v.mon)
          if img then originalSprites[v]=v.sprite;v.sprite=img end
        end
      end
    end
  end
  b._silverModernCapture=true
  local ok,err=pcall(function()
    if gen2 then b:drawScene(function() Wide.drawSurface(b) end) else originalWide(b) end
  end)
  b._silverModernCapture=nil
  captureActive=false
  captureBattle=nil
  for v,sprite in pairs(originalSprites)do v.sprite=sprite end
  for key,original in pairs(trainerSaved)do b[key]=original.value end
  b.statusHUDVisible,b.drawEnemyHud,b.drawPlayerHud=oldStatus,oldEnemy,oldPlayer
  b.bottomUIVisible=oldBottom
  if gen2 then Chrome.paletteFill,Chrome.clear=oldFill,oldClear end
  g.rectangle=oldRectangle
  if gen2 then Chrome.box=oldBox else Font.drawBox=oldBox end
  g.setCanvas(previous);g.pop()
  if not ok then error(err,0) end
end
local reverse
local typeColors=shared.typeColors
local function moveInfo(b,move)
  local data=b.data or b.game.data
  local def=move and data.moves[move.id]
  if not def then return "",nil,"","--"end
  local typ=def.type;local power=def.power or 0
  if gen2 and move.id=="HIDDEN_POWER"then power,typ=b.battle:hiddenPower(b.battle.player)end
  local display=tostring(typ or ""):gsub("_TYPE$","")
  if power==0 then return display,typeColors[display],"STATUS","--"end
  if power==1 then return display,typeColors[display],"SPECIAL","--"end
  local mult
  if gen2 then
    mult=require("src.battle.gen2.Damage").typeMultiplier(typ,b.battle:battlerTypes(b.battle.enemy),b.battle:matchupsAgainst(b.battle.enemy))
  else mult=require("src.battle.TypeChart").effectiveness(typ,b.enemy.curTypes)end
  local text=mult==0 and "NO EFFECT" or mult<=2 and "TYPE 1/4x" or mult<=5 and "TYPE 1/2x"
    or mult>20 and "TYPE 4x" or mult>10 and "TYPE 2x" or "TYPE 1x"
  local ownTypes=gen2 and b.battle:battlerTypes(b.battle.player)or b.player.curTypes
  local stab=false
  for _,own in ipairs(ownTypes or{})do if own==typ then stab=true;break end end
  local factor=mult==2 and .25 or mult/10
  if not gen2 then
    factor=1
    for _,row in ipairs(require("src.battle.TypeChart").rows(typ,b.enemy.curTypes))do factor=factor*row/10 end
  end
  return display,typeColors[display],text,shared.adjustedMovePower(power,stab,factor)
end
shared.battleMoveInfo=moveInfo
local function decoded(b,line)
  if not reverse then
    reverse={}
    for _,e in ipairs(b.data.font.charmap or {})do
      local ch=e.seq;local code=e.code
      -- The imported table also lists Japanese aliases for the same byte.
      -- Retain Latin glyphs instead of letting those later aliases win.
      if ch and code and (not reverse[code] or ch:match("^[ -~]$")
        or ch=="¥" or ch=="é" or ch=="♂" or ch=="♀")then reverse[code]=ch end
    end
  end
  local text={};for _,code in ipairs(line or {})do text[#text+1]=reverse[code] or " "end
  return table.concat(text):gsub("<PK>","POKé"):gsub("<MN>","MON")
end
shared.battleDecodeText=decoded
local function romBottom(b)
  if not b:bottomUIVisible()then return end
  local moves=b.phase==(gen2 and "moves" or "moveSelect") or (not gen2 and b.phase=="mimicSelect")
  local menu=b.phase=="menu"
  g.push();g.translate(0,H-160);g.scale(W/240,1)
  A.chrome.drawPanel(menu and "menu" or moves and "moves" or "message")
  g.pop()
  local function txt(text,x,y,white,small) A.text(text,x,y,white,small)end
  local function cursor(x,y)txt(">",x,y,false)end
  if menu then
    local names=gen2 and b:menuLabels() or b.safari and {"BALL","BAIT","ROCK","RUN"} or {"FIGHT","POKéMON","BAG","RUN"}
    local who=gen2 and b:name(b:activeMon("player")) or b.player and b.player.name or ""
    txt("What will",12,152,true);txt(who.." do?",12,168,true)
    if b.safari then txt("BALLS: "..tostring(b.safari.balls),12,168,true)end
    for i,name in ipairs(names)do
      local x=152+((i-1)%2)*52;local y=152+math.floor((i-1)/2)*16
      txt(name:gsub("<PK><MN>","POKéMON"),x,y,false,true)
      if b.menuIndex==i then cursor(x-9,y)end
    end
  elseif moves then
    local list=gen2 and b:playerMoves() or b.phase=="mimicSelect" and b.mimicMoves or b.player.curMoves
    local selected=b.phase=="mimicSelect" and b.mimicIndex or b.moveIndex
    local data=b.data or b.game.data
    for i,m in ipairs(list)do
      local def=data.moves[m.id]
      local x=16+((i-1)%2)*80
      local y=152+math.floor((i-1)/2)*17
      local _,color=moveInfo(b,m)
      A.text(def and def.name or m.id,x,y,false,true,color)
      if selected==i then txt(">",x-9,y,false,true)end
      if b.moveSwapIndex==i and selected~=i then txt("+",x-9,y,false,true)end
    end
    local move=list[selected];local def=move and data.moves[move.id]
    if move and def then
      local max=gen2 and require("src.battle.gen2.Mon").maxPpOf(move,data)
        or require("src.pokemon.Pokemon").maxPP(def.pp,move.ppUps)
      g.setColor(1,1,1,1);g.rectangle("fill",180,151,68,35)
      local typ,color,effect,power=moveInfo(b,move)
      txt(("PP %d/%d"):format(move.pp or 0,max),184,147,false,true)
      A.text(typ,184,156,false,true,color)
      txt(effect,184,165,false,true)
      txt("PWR "..power,184,174,false,true)
    end
  elseif gen2 then
    b:syncTyper()
    for i,line in ipairs(b:messageLines())do if i<=2 then txt(line,12,152+(i-1)*16,true)end end
    if b:messageArrowVisible()then txt("v",240,172,true)end
  else
    for i,line in ipairs(b.shown or {})do if i<=2 then txt(decoded(b,line),12,152+(i-1)*16+(b.scrollPx or 0),true)end end
    if (b.msgWaiting or b.msgPrompt)and b.frame%60<30 then txt("v",240,172,true)end
  end
end
local function terrain(b)
  local class=tostring(b.enemyTrainerClass or b.oppClass or ""):gsub("^OPP_","")
  local special={LORELEI="lorelei",BRUNO="bruno",AGATHA="agatha",LANCE="lance",
    RIVAL3="champion",CHAMPION="champion",RED="champion",WILL="lorelei",KAREN="agatha"}
  if special[class]then return special[class]end
  local leaders={BROCK=true,MISTY=true,LT_SURGE=true,ERIKA=true,KOGA=true,SABRINA=true,
    BLAINE=true,GIOVANNI=true,FALKNER=true,BUGSY=true,WHITNEY=true,MORTY=true,
    CHUCK=true,JASMINE=true,PRYCE=true,CLAIR=true,JANINE=true,BLUE=true}
  local world=gen2 and b.game.world or b.game.overworld
  local map=world and world.map and world.map.def or{}
  local id=tostring(map.id or map.name or (world and world.mapId)or""):upper()
  if leaders[class]then return "leader"end
  if id:find("GYM",1,true)then return "gym"end
  if world and world.player and (world.player.surfing or (gen2 and require("src.world.gen2.FieldMoves").isSurfing(world.playerState)))then return "water"end
  local env=tostring(map.environment or map.tileset or ""):upper()
  if env=="CAVE"or env=="CAVERN"or env=="DUNGEON"or id:find("TUNNEL",1,true)then return "cave"end
  if env=="FOREST"then return "long_grass"end
  if env=="ROUTE"or env=="TOWN"or env=="OVERWORLD"or env==""then return "grass"end
  return "building"
end
shared.battleTerrain=terrain
local function statsCard(game,mon,name)
  local stats=mon.stats or {}
  if gen2 then
    local M=require('src.battle.gen2.Mon');local def=game.data.pokemon[M.partySpecies(mon)]
    if def and def.baseStats then stats=M.stats(def.baseStats,mon.dvs,mon.level,mon.statExp)end
  end
  g.push('all');g.setShader()
  g.setColor(.12,.19,.21,1);g.rectangle('fill',0,0,W,H)
  if A.init()then A.chrome.drawWindow(16,12,224,168)else box(16,12,224,168)end
  local function text(s,x,y,small)if A.ready then A.text(s,x,y,false,small)else label(s,x,y)end end
  text('LEVEL UP',32,20)
  text(name or tostring(mon.species),32,38,true)
  text('Lv '..tostring(mon.level),32,53,true)
  local pic=A.pic(game.data,mon.species,false,mon)
  if pic then g.setColor(1,1,1,1);g.draw(pic,32,76)end
  local rows={{'HP',stats.hp or mon.maxHp},{'ATTACK',stats.attack},{'DEFENSE',stats.defense}}
  if gen2 then rows[#rows+1]={'SP. ATK',stats.specialAttack};rows[#rows+1]={'SP. DEF',stats.specialDefense}
  else rows[#rows+1]={'SPECIAL',stats.special}end
  rows[#rows+1]={'SPEED',stats.speed}
  for i,row in ipairs(rows)do
    local y=52+(i-1)*18;text(row[1],112,y,true)
    local n=tostring(row[2]or 0);local width
    if A.ready then local fitted;fitted,width=A.fit(n,40,true)end
    text(n,216-(width or #n*6),y,true)
  end
  text('A / B: CLOSE',32,160,true)
  g.pop()
end
shared.battleStatsCard=statsCard
if not gen2 then
  -- Only direct battle choices share the modern canvas. Choices nested in
  -- Party/Bag/PC screens retain their own native placement and input rules.
  local choiceDraw=ChoiceBox.draw
  local function modernChoice(self)return battleChoice(self)and enabled()end
  ChoiceBox.isWideBattleLayout=modernChoice
  ChoiceBox.uiSize=function(self)if modernChoice(self)then return W,H end;return 160,144 end
  ChoiceBox.wantsFillScale=modernChoice
  ChoiceBox.draw=function(self)
    if not modernChoice(self)or not A.init()then return choiceDraw(self)end
    if not require("src.battle.UIVisibility").bottomVisible(self,false)then return end
    g.push("all");g.setShader()
    A.chrome.drawWindow(184,48,64,52)
    local Strings=require("src.core.Strings")
    for i,text in ipairs(self.labels)do
      A.text(Strings(text),204,58+(i-1)*18,false,true)
    end
    A.text(">",192,58+(self.index-1)*18,false,true)
    g.pop()
  end
  local StatBox=B.StatBox;local originalStats=StatBox.draw
  local function active(self)
    if not enabled()then return false end
    for _,s in ipairs(self.game.stack.states)do if s~=self and getmetatable(s)==B then return true end end
    return false
  end
  StatBox.isWideBattleLayout=active
  StatBox.uiSize=function(self)if active(self)then return W,H end;return 160,144 end
  StatBox.wantsFillScale=active
  StatBox.draw=function(self)
    if not active(self)then return originalStats(self)end
    local name=self.mon.nickname
    if type(name)~='string'then name=self.mon.species end
    return statsCard(self.game,self.mon,name)
  end
end
local function draw(b)
  if gen2 and b.phase=='stats-box'and b.statsBoxMon then
    return statsCard(b.game,b.statsBoxMon,b:name(b.statsBoxMon))
  end
  local regular=not gen2 or (b.phase=="menu" or b.phase=="moves" or b.phase=="resolving" or b.phase=="intro")
  nativeSurface(b,regular)
  g.push("all");g.setShader()
  g.setColor(.81,.89,.87,1);g.rectangle("fill",0,0,W,H)
  if A.init()then
    g.push();g.scale(W/240,144/112);A.chrome.drawTerrain(terrain(b));g.pop()
  else
    g.setColor(.73,.83,.76,1);g.ellipse("fill",242,106,54,13)
    g.setColor(.68,.79,.70,1);g.ellipse("fill",72,153,68,16)
  end
  g.setColor(1,1,1,1)
  if b.blankForAskName or b.blackoutBlank then
    g.setColor(1,1,1,1);g.rectangle("fill",0,0,W,H)
  elseif regular then
    local cut=gen2 and 112 or 104
    fieldQuad=fieldQuad or g.newQuad(0,0,304,cut,304,144)
    bottomQuad=bottomQuad or g.newQuad(0,cut,304,144-cut,304,144)
    g.draw(surface,fieldQuad,0,gen2 and 32 or 40)
    if not gen2 and b.introBalls and A.ready then
      if b.kind=="trainer"then A.chrome.drawPartyBar(b.enemyParty,112,56,true)end
      A.chrome.drawPartyBar(b.playerParty or b.game.save.party,136,128,false)
    elseif gen2 and b.ballRows and A.ready then
      if b.ballRows.enemy then A.chrome.drawPartyBar(b.battle and b.battle.enemyParty,112,56,true)end
      if b.ballRows.player then A.chrome.drawPartyBar(b.battle and b.battle.party,136,128,false)end
    end
    modernHud(b)
    if A.init()then romBottom(b)
    else g.setColor(1,1,1,1);g.draw(surface,bottomQuad,0,H-(144-cut))end
    if not A.ready and gen2 and b.phase=="moves" then
      infoQuad=infoQuad or g.newQuad(0,64,88,40,304,144)
      g.draw(surface,infoQuad,0,140)
    end
  else
    -- Native yes/no, nickname, move-learning and stat windows retain their
    -- complete original surface; none of their controls are cropped away.
    g.draw(surface,0,42)
  end
  g.pop()
end
if gen2 then
  local function modernPhase(b)
    return b and (b.phase=='stats-box'or b.phase=='menu'or b.phase=='moves'
      or b.phase=='resolving'or b.phase=='intro')
  end
  -- ShaderFX must sample the lattice actually painted by this battle, rather
  -- than the engine's native 160x144 fit. Leave other screens on their own fit.
  local Game2=require('src.core.Game2')
  local frameFit=Game2.frameFit
  Game2.frameFit=function(self,w,h)
    local scale,ox,oy,dpi,pw,ph=frameFit(self,w,h)
    local top=self.stack and self.stack:top()
    if enabled()and getmetatable(top)==B and modernPhase(top)then
      local x,y,cw,ch=Chrome.playfieldRect(w,h)
      scale=math.min(cw/W,ch/H)
      ox,oy=x+(cw-W*scale)/2,y+(ch-H*scale)/2
    end
    return scale,ox,oy,dpi,pw,ph
  end
  local original=B.drawWidescreen
  B.drawWidescreen=function(self,winW,winH)
    if not enabled() then return original(self,winW,winH) end
    if not modernPhase(self)then return original(self,winW,winH)end
    local px,py,pw,ph=Chrome.playfieldRect(winW,winH)
    local scale=math.min(pw/W,ph/H)
    g.push("all");Chrome.clipTo(px,py,pw,ph)
    g.translate(px+(pw-W*scale)/2,py+(ph-H*scale)/2);g.scale(scale)
    draw(self);g.pop()
  end
else
  Wide.draw=function(b) if enabled() then return draw(b) end return originalWide(b) end
end
shared.battlePresentation={width=W,height=H,enabled=enabled}
