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
local W,H = 304,228
local function enabled() return shared.bool("modern_battle_hud", true) end
shared.modernBattleEnabled = enabled
local function wrap(name, fn)
  local original = B[name]
  B[name] = function(self,...)
    if enabled() then return fn(self,...) end
    return original(self,...)
  end
end
wrap("wideLayout",function() return true end)
wrap("wantsFillScale",function() return true end)
wrap("extendedHUD",function() return false end)
if not gen2 then
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
local function panel(name,level,status,hp,maxhp,player,caught,exp,gender)
  local x,y=player and 160 or 8,player and 126 or 16
  if A and A.init() then
    local c=A.chrome
    g.push();g.translate(player and 156 or 8,y);g.scale(1.3,1.3)
    if player then c.drawPlayerBox(0,0) else c.drawEnemyBox(0,0) end
    local nx=player and 18 or 10
    local nm,nw=A.fit(name,gender and 46 or 54,true)
    A.text(nm,nx,4,false,true)
    if gender then A.text(gender,nx+nw,4,false,true)end
    A.text("Lv"..tostring(level or 1),player and 75 or 67,4,false,true)
    if player then g.setColor(1,1,222/255,1);g.rectangle("fill",56,21,40,11)end
    c.drawHpBar(player and 32 or 24,16,hp,maxhp)
    if caught then c.drawCaughtBall(8,17)end
    if status then A.text(status,player and 13 or 2,22,false,true)end
    if player then
      A.text(("%3d/%3d"):format(hp,maxhp),56,21,false,true)
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
  local f=(maxhp or 0)>0 and hp/maxhp or 0
  bar(x+44,y+22,84,f,f>.5 and {.25,.70,.48,1} or f>.2 and {.91,.69,.25,1} or {.84,.31,.29,1})
  if player then
    label(("%d/%d"):format(hp,maxhp),x+64,y+32)
    if exp then bar(x+8,y+43,120,exp,{.29,.61,.85,1}) end
  end
end
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
          player and (b.shownExp or 0)/64 or nil,b:genderSymbol(m))
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
          not player and b.kind=="wild" and dex and dex.owned and dex.owned[v.mon.species],exp)
      end
    end
  end
end
local surface, fieldQuad, bottomQuad, infoQuad
local captureActive=false
if gen2 then
  wrap("moveGridNavigation",function()return true end)
  local pass
  local expBurst=B.drawExpBurst
  B.drawExpBurst=function(self,...)
    if captureActive and pass then return end
    return expBurst(self,...)
  end
  local AV=require("src.ui.gen2.BattleAnimView")
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
    local lo,hi=math.huge,-math.huge
    for _,s in ipairs(sprites)do lo=math.min(lo,s.x-8);hi=math.max(hi,s.x)end
    local t=math.max(0,math.min(1,((lo+hi)/2-40)/88))
    -- Translate each complete OAM group, preserving its shapes and spacing.
    -- A projectile travelling across the field interpolates between anchors.
    local moved={}
    for _,s in ipairs(sprites)do
      local v={};for k,value in pairs(s)do v[k]=value end
      v.x=v.x+math.floor(20+108*t+.5);v.y=v.y+math.floor(8*(1-t)+.5)
      moved[#moved+1]=v
    end
    local proxy=setmetatable({oam=function()return moved end},{__index=runner})
    return objects(self,proxy,battle)
  end
  Wide.drawField=function(b)
    if not captureActive then return field(b)end
    if not b:hasBattleSides()then return false end
    for _,side in ipairs({"player","enemy"})do
      pass=side
      g.push();g.translate(side=="player"and 20 or 128,side=="player"and 8 or 0)
      b:drawSceneBody(function()b:drawPics()end)
      g.pop()
    end
    pass=nil
    if b.anim and b.animView then b.animView:drawObjects(b.anim,b.battle)end
    if b.expBurst then
      g.push();g.translate(144,0);b:drawExpBurst();g.pop()
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
  local scale,speciesSprite=B.resolveBattleScale,B.speciesSprite
  B.resolveBattleScale=function(data,side,path,species)
    if captureActive and not path then return 1 end
    return scale(data,side,path,species)
  end
  B.speciesSprite=function(self,species,back)
    if enabled()then
      local pic=A.pic(self.data,species,back)
      if pic then return pic end
    end
    return speciesSprite(self,species,back)
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
local typeColors={NORMAL={.35,.35,.30,1},FIRE={.74,.23,.10,1},WATER={.13,.35,.72,1},
  GRASS={.21,.48,.15,1},ELECTRIC={.57,.43,.02,1},ICE={.10,.47,.50,1},FIGHTING={.65,.18,.15,1},
  POISON={.51,.23,.60,1},GROUND={.55,.35,.12,1},FLYING={.40,.32,.69,1},PSYCHIC={.70,.20,.46,1},
  BUG={.36,.46,.07,1},ROCK={.49,.40,.17,1},GHOST={.36,.25,.52,1},DRAGON={.36,.20,.73,1},
  DARK={.32,.24,.20,1},STEEL={.33,.39,.45,1}}
local function moveInfo(b,move)
  local data=b.data or b.game.data
  local def=move and data.moves[move.id]
  if not def then return "",nil,""end
  local typ=def.type;local power=def.power or 0
  if gen2 and move.id=="HIDDEN_POWER"then power,typ=b.battle:hiddenPower(b.battle.player)end
  local display=tostring(typ or ""):gsub("_TYPE$","")
  if power==0 then return display,typeColors[display],"STATUS"end
  if power==1 then return display,typeColors[display],"SPECIAL"end
  local mult
  if gen2 then
    mult=require("src.battle.gen2.Damage").typeMultiplier(typ,b.battle:battlerTypes(b.battle.enemy),b.battle:matchupsAgainst(b.battle.enemy))
  else mult=require("src.battle.TypeChart").effectiveness(typ,b.enemy.curTypes)end
  local text=mult==0 and "NO EFFECT" or mult<=2 and "TYPE 1/4x" or mult<=5 and "TYPE 1/2x"
    or mult>20 and "TYPE 4x" or mult>10 and "TYPE 2x" or "TYPE 1x"
  return display,typeColors[display],text
end
shared.battleMoveInfo=moveInfo
local function decoded(b,line)
  if not reverse then
    reverse={}
    for _,e in ipairs(b.data.font.charmap or {})do
      local ch=e.seq;local code=e.code
      -- The imported table also lists Japanese aliases for the same byte.
      -- Retain Latin glyphs instead of letting those later aliases win.
      if ch and code and (not reverse[code] or ch:match("^[ -~]$"))then reverse[code]=ch end
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
  g.push();g.translate(0,68);g.scale(W/240,1)
  A.chrome.drawPanel(menu and "menu" or moves and "moves" or "message")
  g.pop()
  local function txt(text,x,y,white,small) A.text(text,x,y,white,small)end
  local function cursor(x,y)txt(">",x,y,false)end
  if menu then
    local names=gen2 and b:menuLabels() or b.safari and {"BALL","BAIT","ROCK","RUN"} or {"FIGHT","POKéMON","BAG","RUN"}
    local who=gen2 and b:name(b:activeMon("player")) or b.player and b.player.name or ""
    txt("What will",10,186,true);txt(who.." do?",10,202,true)
    if b.safari then txt("BALLS: "..tostring(b.safari.balls),10,202,true)end
    for i,name in ipairs(names)do
      local x=184+((i-1)%2)*60;local y=188+math.floor((i-1)/2)*16
      txt(name:gsub("<PK><MN>","POKéMON"),x,y,false,true)
      if b.menuIndex==i then cursor(x-9,y)end
    end
  elseif moves then
    local list=gen2 and b:playerMoves() or b.phase=="mimicSelect" and b.mimicMoves or b.player.curMoves
    local selected=b.phase=="mimicSelect" and b.mimicIndex or b.moveIndex
    local data=b.data or b.game.data
    for i,m in ipairs(list)do
      local def=data.moves[m.id]
      local x=24+((i-1)%2)*94
      local y=186+math.floor((i-1)/2)*17
      local _,color=moveInfo(b,m)
      A.text(def and def.name or m.id,x,y,false,true,color)
      if selected==i then txt(">",x-9,y,false,true)end
      if b.moveSwapIndex==i and selected~=i then txt("+",x-9,y,false,true)end
    end
    local move=list[selected];local def=move and data.moves[move.id]
    if move and def then
      local max=gen2 and require("src.battle.gen2.Mon").maxPpOf(move,data)
        or require("src.pokemon.Pokemon").maxPP(def.pp,move.ppUps)
      g.setColor(1,1,1,1);g.rectangle("fill",212,184,84,39)
      local typ,color,effect=moveInfo(b,move)
      txt(("PP %d/%d"):format(move.pp or 0,max),222,185,false,true)
      A.text(typ,222,197,false,true,color)
      txt(effect,222,209,false,true)
    end
  elseif gen2 then
    b:syncTyper()
    for i,line in ipairs(b:messageLines())do if i<=2 then txt(line,16,188+(i-1)*16,true)end end
    if b:messageArrowVisible()then txt("v",286,208,true)end
  else
    for i,line in ipairs(b.shown or {})do if i<=2 then txt(decoded(b,line),16,188+(i-1)*16+(b.scrollPx or 0),true)end end
    if (b.msgWaiting or b.msgPrompt)and b.frame%60<30 then txt("v",286,208,true)end
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
local function draw(b)
  local regular=not gen2 or (b.phase=="menu" or b.phase=="moves" or b.phase=="resolving" or b.phase=="intro")
  nativeSurface(b,regular)
  g.push("all");g.setShader()
  g.setColor(.81,.89,.87,1);g.rectangle("fill",0,0,W,H)
  if A.init()then
    g.push();g.scale(W/240,180/112);A.chrome.drawTerrain(terrain(b));g.pop()
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
    g.draw(surface,fieldQuad,0,56)
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
  local original=B.drawWidescreen
  B.drawWidescreen=function(self,winW,winH)
    if not enabled() then return original(self,winW,winH) end
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
