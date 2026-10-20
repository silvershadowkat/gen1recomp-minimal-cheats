local calls, depth, fail={},0,false
local noop=function()end
local image={getDimensions=function()return 64,64 end}
love={graphics={
  newCanvas=noop,newShader=function()return {}end,
  push=function()depth=depth+1 end,pop=function()depth=depth-1 end,
  setColor=noop,rectangle=noop,setShader=noop,translate=noop,scale=noop,
  draw=function(_,x,y)assert(x==96 and y==48,"sprite is not centered");if fail then error("draw failure")end end,
}}
local A={
  init=function()return true end,evolutionBackground=noop,
  pic=function(_,species)calls[#calls+1]=species;return image end,
  fit=function(text)return text,#text end,text=noop,
}
local E,TextBox={},{}
local nativeUpdates=0
E.update=function()nativeUpdates=nativeUpdates+1 end
E.new=function(game,mon,species,done,via)
  return setmetatable({mon=mon,newSpecies=species,t=0,done=false,
    cancelable=via~="ITEM"and via~="TRADE"},E)
end
local Evolution={}
local callback
Evolution.evolve=function(game,mon,species,done)
  callback=done
  game.stack.states[#game.stack.states+1]=setmetatable({shown={{1,2}},arrowVisible=function()return true end},TextBox)
end
local Game={}
Game.draw=function(self)
  local top=self.stack.states[#self.stack.states]
  if top.uiSize then
    local w,h=top:uiSize();assert(w==256 and h==192)
    assert(top:wantsFillScale());top:draw()
  else calls[#calls+1]="native"end
end
package.loaded["src.core.Game"]=Game
package.loaded["src.pokemon.Evolution"]=Evolution
package.loaded["src.ui.EvolutionState"]=E
package.loaded["src.render.TextBox"]=TextBox
local on=true
local S={generation=1,battleAssets=A,bool=function()return on end,
  battleDecodeText=function()return "TEST"end}
local nativeUpdate=E.update
assert(loadfile("modules/evolution_presentation.lua"))({},S)
assert(E.update==nativeUpdate,"presentation replaced evolution simulation")
local world={}
local states={world}
local game=setmetatable({data={},stack={states=states}},{__index=Game})
local mon={species="CATERPIE"}
local finished=0
Evolution.evolve(game,mon,"METAPOD",function()finished=finished+1 end,"LEVEL")
game:draw();assert(calls[#calls]=="CATERPIE" and game.stack.states==states)
local anim=E.new(game,mon,"METAPOD",nil,"LEVEL")
states[#states+1]=anim
assert(anim.cancelable)
anim.t=100;game:draw()
assert(game.stack.states==states and depth==0)
anim.done=true;anim.canceled=true;game:draw()
assert(calls[#calls]=="CATERPIE","cancel displayed evolved form")
anim.canceled=false;game:draw()
assert(calls[#calls]=="METAPOD","success did not display evolved form")
assert(mon.species=="CATERPIE","drawing mutated the Pokemon")
fail=true;assert(not pcall(game.draw,game))
assert(game.stack.states==states and depth==0,"failed draw leaked stack or graphics state")
fail=false
states[#states+1]=setmetatable({},{})
game:draw();assert(calls[#calls]=="native","move-learning menu was intercepted")
table.remove(states)
callback();assert(finished==1)
game:draw();assert(calls[#calls]=="native","context survived completion")
assert(not E.new(game,mon,"METAPOD",nil,"ITEM").cancelable)
on=false;Evolution.evolve(game,mon,"METAPOD",noop);game:draw()
assert(calls[#calls]=="native","disabled option still replaced drawing")

-- Gen 2 uses its native wide compositor and must report that same lattice
-- to ShaderFX. Other screens keep their original sampling scale.
on=true
local E2={update=function(self)self.nativeUpdates=(self.nativeUpdates or 0)+1 end,
  drawWidescreen=function()calls[#calls+1]="native2"end}
local G2={frameFit=function()return 3,1,2,2,1280,960 end}
local chrome={playfieldRect=function()return 0,0,640,480 end,clipTo=noop}
package.loaded["src.ui.gen2.EvolutionAnim"]=E2
package.loaded["src.core.Game2"]=G2
package.loaded["src.ui.gen2.Chrome"]=chrome
S.generation=2
assert(loadfile("modules/evolution_presentation.lua"))({},S)
local evo=setmetatable({data={},mon={},oldSpecies="EEVEE",newSpecies="VAPOREON",
  phase="flash",lines={"What?","EEVEE is evolving!"}},E2);E2.__index=E2
local top=evo
local g2=setmetatable({stack={top=function()return top end}},{__index=G2})
assert(g2:frameFit(640,480)==2.5,"evolution did not use the physical 5x grid")
evo:update();assert(evo.nativeUpdates==1 and evo.phase=="flash")
evo:drawWidescreen(640,480);assert(depth==0)
top={};assert(g2:frameFit(640,480)==3,"world sampling changed")
on=false;evo:drawWidescreen(640,480);assert(calls[#calls]=="native2")
print("PASS evolution: centering, 4:3/LCD fit, native rules, cancel/success, menu fallback, toggle and error cleanup")
