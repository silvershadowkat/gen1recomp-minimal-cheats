-- Native learning owns every input, HM restriction, PP change and callback.
-- Only the synchronous render view is replaced.
local _,S=...
if S.generation==3 or not(love and love.graphics and love.graphics.newCanvas)then return end
local g,A=love.graphics,S.battleAssets
local gen2=S.generation==2
local Game=require(gen2 and "src.core.Game2"or"src.core.Game")
local TextBox=require("src.render.TextBox")
local Choice=require("src.ui.ChoiceBox")
local List=require(gen2 and "src.ui.gen2.MoveDeleter"or"src.ui.MoveLearnMenu")
local Chrome=gen2 and require("src.ui.gen2.Chrome")
local context
local function enabled()return S.bool("modern_evolution_screen",true)and A and A.init()end
local function begin(game,mon,id,done)
  local ctx={game=game,mon=mon,id=id,base=#game.stack.states}
  context=ctx
  return ctx,function(...)
    if context==ctx then context=nil end
    if done then return done(...)end
  end
end
if gen2 then
  local learn=Game.learnMoveOn
  Game.learnMoveOn=function(self,mon,id,done)
    if not enabled()then return learn(self,mon,id,done)end
    local ctx,finish=begin(self,mon,id,done)
    local ok,r=pcall(learn,self,mon,id,finish)
    if not ok then if context==ctx then context=nil end;error(r,0)end
    return r
  end
else
  local new=List.new
  List.new=function(game,mon,id,done,...)
    if not enabled()then return new(game,mon,id,done,...)end
    local ctx,finish=begin(game,mon,id,done)
    local ok,r=pcall(new,game,mon,id,finish,...)
    if not ok then if context==ctx then context=nil end;error(r,0)end
    return r
  end
  -- Bag TMs and Rare Candies with a free move slot skip MoveLearnMenu.
  -- Match the native localized result against an actual party member and
  -- known move, rather than treating arbitrary overworld dialogue as learning.
  local Strings=require("src.core.Strings")
  local textNew=TextBox.new
  TextBox.new=function(game,text,done,...)
    if not context and enabled()then
      for _,mon in ipairs(game.save and game.save.party or{})do
        local name=mon.nickname or(game.data.pokemon[mon.species]or{}).name or mon.species
        for _,move in ipairs(mon.moves or{})do
          local def=game.data.moves[move.id]
          if def and text==Strings("%s learned\n%s!",name,def.name)then
            local ctx,finish=begin(game,mon,move.id,done)
            local ok,r=pcall(textNew,game,text,finish,...)
            if not ok then if context==ctx then context=nil end;error(r,0)end
            return r
          end
        end
      end
    end
    return textNew(game,text,done,...)
  end
end
local function panel(x,y,w,h)
  g.setColor(.20,.27,.35,1);g.rectangle("fill",x,y,w,h)
  g.setColor(.64,.72,.79,1);g.rectangle("fill",x+1,y+1,w-2,h-2)
  g.setColor(.96,.97,.94,1);g.rectangle("fill",x+3,y+3,w-6,h-6)
end
local function moveType(def)
  local t=tostring(def.type or "NORMAL"):gsub("^TYPE_",""):gsub("_TYPE$",""):upper()
  return t:gsub("_"," "),S.typeColors and S.typeColors[t]
end
local function view(game,states)
  local ctx=context
  if not(ctx and ctx.game==game and enabled())then return end
  if #states<=ctx.base then context=nil;return end
  local text,choice,list
  for i=ctx.base+1,#states do
    local state=states[i];local class=getmetatable(state)
    if class==TextBox then text=state
    elseif class==Choice then choice=state
    elseif class==List then list=state
    else return end
  end
  return {ctx=ctx,text=text,choice=choice,list=list,
    selecting=list and (gen2 or list.selecting)}
end
local function paint(v)
  local ctx=v.ctx;local data,mon=ctx.game.data,ctx.mon
  A.evolutionBackground()
  local name=mon.nickname or mon.name or(data.pokemon[mon.species]or{}).name or mon.species
  local newDef=data.moves[ctx.id]or{}
  A.text(A.fit(name,v.selecting and 121 or 226),14,5)
  if v.selecting then
    local _,color=moveType(newDef)
    A.text(A.fit("NEW: "..(newDef.name or ctx.id),106,true),142,6,false,true,color)
  end
  if v.selecting then
    panel(7,24,159,116);panel(171,24,78,116)
    local index=v.list.row or v.list.index or 1
    for i,m in ipairs(mon.moves or{})do
      local def=data.moves[m.id]or{};local ty,color=moveType(def)
      local y=29+(i-1)*26
      if i==index then
        g.setColor(.83,.89,.95,1);g.rectangle("fill",11,y,151,25)
        A.text(">",13,y)
      end
      A.text(A.fit(def.name or m.id,133),24,y,false,false,color)
      A.text(ty,24,y+12,false,true,color)
      A.text("PP "..tostring(m.pp or 0),116,y+12,false,true)
    end
    local selected=(mon.moves or{})[index]
    local def=data.moves[selected and selected.id]or{}
    local ty,color=moveType(def)
    A.text("TYPE",179,31,false,true)
    A.text(A.fit(ty,62,true),179,45,false,true,color)
    A.text("POWER",179,64,false,true)
    A.text(tostring(def.power or "-"),179,78)
    A.text("ACCURACY",179,99,false,true)
    A.text(tostring(def.accuracy or "-"),179,113)
  else
    local img=A.pic(data,mon.species,false,mon)
    if img then local w,h=img:getDimensions();g.setColor(1,1,1,1);g.draw(img,math.floor((256-w)/2),38)end
    panel(17,110,222,28)
    local ty,color=moveType(newDef)
    A.text("NEW",25,116,false,true)
    A.text(A.fit(newDef.name or ctx.id,174),53,115,false,false,color)
  end
  if v.text then
    for i,line in ipairs(v.text.shown or{})do
      if i>2 then break end
      A.text(A.fit(S.battleDecodeText({data=data},line),228),12,152+(i-1)*16,true)
    end
    if v.text:arrowVisible()then A.text(">",238,172,true)end
  elseif v.selecting then
    A.text("Which move should",12,152,true)
    A.text("be forgotten?",12,168,true)
  end
  if v.choice then
    panel(187,60,62,45)
    for i,label in ipairs(v.choice.labels or{"YES","NO"})do
      A.text(A.fit(label,37),205,64+(i-1)*17)
    end
    A.text(">",193,64+((v.choice.index or 1)-1)*17)
  end
end
local function guardedPaint(v)
  g.push("all");local ok,err=pcall(paint,v);g.pop()
  if not ok then error(err,0)end
end
if gen2 then
  local fit=Game.frameFit
  Game.frameFit=function(self,w,h)
    local s,x,y,dpi,pw,ph=fit(self,w,h)
    if self._silverLearningDraw then
      local px,py,cw,ch=Chrome.playfieldRect(w,h)
      s=math.min(cw/256,ch/192);x,y=px+(cw-256*s)/2,py+(ch-192*s)/2
    end
    return s,x,y,dpi,pw,ph
  end
end
local draw=Game.draw
Game.draw=function(self,...)
  local stack=self.stack;local states=stack and stack.states
  local v=states and view(self,states)
  if not v then return draw(self,...)end
  local facade={
    isOpaque=true,holdsUIAnchors=true,
    uiSize=function()return 256,192 end,
    wantsFillScale=function()return true end,
    drawsWidescreen=function()return true end,
    sgbPalettes=function()return {{colors=false,x=0,y=0,w=256,h=192}}end,
    draw=function()guardedPaint(v)end,
    drawWidescreen=function(_,w,h)
      local x,y,cw,ch=Chrome.playfieldRect(w,h)
      local s=math.min(cw/256,ch/192)
      g.push("all");Chrome.clipTo(x,y,cw,ch)
      g.translate(x+(cw-256*s)/2,y+(ch-192*s)/2);g.scale(s)
      local ok,err=pcall(guardedPaint,v);g.pop()
      if not ok then error(err,0)end
    end,
  }
  stack.states={facade};self._silverLearningDraw=true
  local ok,r=pcall(draw,self,...)
  stack.states=states;self._silverLearningDraw=nil
  if not ok then error(r,0)end
  return r
end
S.moveLearningPresentation={enabled=enabled,view=view,paint=guardedPaint}
