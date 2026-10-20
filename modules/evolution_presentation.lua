-- Presentation only: native evolution code still owns input, cries, timing,
-- species/stat changes, item consumption and the move-learning continuation.
local _, shared = ...
if shared.generation==3 or not(love and love.graphics and love.graphics.newCanvas)then return end
local g=love.graphics
local A=shared.battleAssets
local gen2=shared.generation==2
local W,H=256,192
local function enabled()
  return shared.bool("modern_evolution_screen",true) and A and A.init()
end
local silhouette
if g.newShader then
  local ok,value=pcall(g.newShader,[[
    vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
      return vec4(color.rgb, Texel(image, uv).a * color.a);
    }
  ]])
  if ok then silhouette=value end
end
local function showsNew(t)
  for b=1,8 do
    local hold=18-2*b
    if t<hold then return false end
    t=t-hold
    local swap=b*6
    if t<swap then return t%6<3 end
    t=t-swap
  end
  return true
end
local function paint(view)
  g.push("all")
  local ok,err=pcall(function()
    A.evolutionBackground(view.flashing)
    local img=A.pic(view.data,view.species,false,view.mon)
    if not img and view.fallback then img=view.fallback()end
    if view.flashing then
      -- Deterministic pixel sparkles do not touch the gameplay RNG.
      for i=1,12 do
        local angle=i*math.pi/6+view.frame/45
        local radius=35+(i%3)*8
        local x=math.floor(128+math.cos(angle)*radius)
        local y=math.floor(76+math.sin(angle)*radius)
        g.setColor(.62,.82,1,1);g.rectangle("fill",x-2,y,5,1)
        g.rectangle("fill",x,y-2,1,5)
      end
    end
    if img then
      local w,h=img:getDimensions()
      g.setColor(1,1,1,1)
      if view.flashing and silhouette then g.setShader(silhouette)end
      g.draw(img,math.floor((W-w)/2),math.floor(80-h/2))
      g.setShader()
    end
    for i=1,math.min(2,#view.lines)do
      A.text(A.fit(view.lines[i],228),12,152+(i-1)*16,true)
    end
    if view.arrow then A.text(">",238,172,true)end
  end)
  g.pop()
  if not ok then error(err,0)end
end

if gen2 then
  local E=require("src.ui.gen2.EvolutionAnim")
  local Chrome=require("src.ui.gen2.Chrome")
  local Game=require("src.core.Game2")
  local function view(self)
    return {
      data=self.data,mon=self.mon,
      species=self.showNew and self.newSpecies or self.oldSpecies,
      flashing=self.phase=="flash",frame=self._silverEvoFrame or 0,
      lines=self.lines or {},fallback=function()return self:pic(self.showNew and self.newSpecies or self.oldSpecies)end,
      arrow=(self.phase=="stopped"or self.phase=="congrats"or self.phase=="learn")and (self.timer or 0)<=0,
    }
  end
  local update=E.update
  E.update=function(self,...)
    self._silverEvoFrame=(self._silverEvoFrame or 0)+1
    return update(self,...)
  end
  local wide=E.drawWidescreen
  E.drawWidescreen=function(self,w,h)
    if not enabled()then return wide(self,w,h)end
    local x,y,pw,ph=Chrome.playfieldRect(w,h)
    local s=math.min(pw/W,ph/H)
    g.push("all");Chrome.clipTo(x,y,pw,ph)
    g.translate(x+(pw-W*s)/2,y+(ph-H*s)/2);g.scale(s)
    local ok,err=pcall(paint,view(self))
    g.pop();if not ok then error(err,0)end
  end
  local fit=Game.frameFit
  Game.frameFit=function(self,w,h)
    local s,x,y,dpi,pw,ph=fit(self,w,h)
    if enabled()and getmetatable(self.stack:top())==E then
      local px,py,cw,ch=Chrome.playfieldRect(w,h)
      s=math.min(cw/W,ch/H);x,y=px+(cw-W*s)/2,py+(ch-H*s)/2
    end
    return s,x,y,dpi,pw,ph
  end
else
  local Game=require("src.core.Game")
  local Evolution=require("src.pokemon.Evolution")
  local E=require("src.ui.EvolutionState")
  local TextBox=require("src.render.TextBox")
  local context
  local evolve=Evolution.evolve
  Evolution.evolve=function(game,mon,species,onDone,...)
    if not enabled()then return evolve(game,mon,species,onDone,...)end
    local ctx={game=game,mon=mon,old=mon.species,new=species,base=#game.stack.states}
    context=ctx
    local function done(...)
      if context==ctx then context=nil end
      if onDone then return onDone(...)end
    end
    local ok,result=pcall(evolve,game,mon,species,done,...)
    if not ok then if context==ctx then context=nil end;error(result,0)end
    return result
  end
  local new=E.new
  E.new=function(game,mon,...)
    local state=new(game,mon,...)
    if context and context.game==game and context.mon==mon then context.anim=state end
    return state
  end
  local function view(game,states)
    local ctx=context
    if not(ctx and ctx.game==game and enabled())then return end
    if #states<=ctx.base then context=nil;return end
    local text
    for i=ctx.base+1,#states do
      local state=states[i]
      local class=getmetatable(state)
      -- Move-learning/party/choice menus retain their native drawing and
      -- hitboxes. Text and the native anonymous intro hold are composited here.
      if class and class~=E and class~=TextBox then return end
      if class==TextBox then text=state end
    end
    local anim=ctx.anim
    local newPic=anim and (anim.done and not anim.canceled
      or not anim.done and showsNew((anim.t or 0)-80))
    local lines={}
    if text then
      for _,line in ipairs(text.shown or {})do
        lines[#lines+1]=shared.battleDecodeText({data=game.data},line)
      end
    end
    return {
      data=game.data,mon=ctx.mon,species=newPic and ctx.new or ctx.old,
      flashing=anim and not anim.done and (anim.t or 0)>=80,
      frame=anim and anim.t or 0,lines=lines,
      arrow=text and text.arrowVisible and text:arrowVisible(),
      fallback=function()return anim and (newPic and anim.newSprite or anim.oldSprite)end,
    }
  end
  local draw=Game.draw
  Game.draw=function(self,...)
    if self._silverLearningDraw then return draw(self,...)end
    local stack=self.stack
    local states=stack and stack.states
    local v=states and view(self,states)
    if not v then return draw(self,...)end
    local facade={
      isOpaque=true,holdsUIAnchors=true,
      uiSize=function()return W,H end,
      wantsFillScale=function()return true end,
      sgbPalettes=function()return {{colors=false,x=0,y=0,w=W,h=H}}end,
      draw=function()paint(v)end,
    }
    -- A render-only view of the stack lets the engine's normal canvas, LCD,
    -- viewport and touch-control pipeline do the final composition. No
    -- states are pushed/popped, and native updates always see the real stack.
    stack.states={facade}
    local ok,result=pcall(draw,self,...)
    stack.states=states
    if not ok then error(result,0)end
    return result
  end
end
shared.evolutionPresentation={width=W,height=H,enabled=enabled,paint=paint,showsNew=showsNew}
