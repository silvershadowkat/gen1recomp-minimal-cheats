local noop=function()end
local depth,fail=0,false
love={graphics={newCanvas=noop,push=function()depth=depth+1 end,
  pop=function()depth=depth-1 end,setColor=noop,rectangle=noop,
  draw=noop,translate=noop,scale=noop}}
local Text,Choice,List={},{},{}
local nativeUpdate=function()end
List.update=nativeUpdate
local callback
Text.new=function(game,text,done)
  callback=done
  return setmetatable({shown={{1}},arrowVisible=function()return false end},Text)
end
List.new=function(game,mon,id,done)
  callback=done
  return setmetatable({game=game,mon=mon,newMoveId=id,index=1,selecting=true},List)
end
local Game={}
Game.draw=function(self)
  local top=self.stack.states[#self.stack.states]
  if top.draw then top:draw()end
end
local types={}
local A={init=function()return true end,evolutionBackground=noop,pic=function()end,
  fit=function(s)return s end,text=function(s,_,_,_,_,color)
    if color then types[s]=color end
    if fail then error("paint failure")end
  end}
local S={generation=1,battleAssets=A,bool=function()return true end,
  typeColors={FIRE={1,0,0,1}},battleDecodeText=function()return "PROMPT"end}
package.loaded["src.core.Game"]=Game
package.loaded["src.render.TextBox"]=Text
package.loaded["src.ui.ChoiceBox"]=Choice
package.loaded["src.ui.MoveLearnMenu"]=List
package.loaded["src.core.Strings"]=function(fmt,...)return string.format(fmt,...)end
assert(loadfile("modules/move_learning_presentation.lua"))({},S)
assert(List.update==nativeUpdate,"presentation changed learning rules")
local world={}
local states={world}
local game=setmetatable({stack={states=states},data={
  pokemon={CHARMANDER={name="CHARMANDER"}},
  moves={EMBER={name="EMBER",type="FIRE_TYPE",pp=25,power=40,accuracy=100},
    GROWL={name="GROWL",type="NORMAL",pp=40}}}}, {__index=Game})
local mon={species="CHARMANDER",moves={{id="EMBER",pp=19}}}
local result
local list=List.new(game,mon,"GROWL",function(ok)result=ok end)
states[2]=list
game:draw()
assert(types.EMBER==S.typeColors.FIRE and types.FIRE==S.typeColors.FIRE)
assert(mon.moves[1].id=="EMBER"and mon.moves[1].pp==19)
assert(game.stack.states==states and not game._silverLearningDraw and depth==0)
fail=true
assert(not pcall(game.draw,game))
assert(game.stack.states==states and not game._silverLearningDraw and depth==0)
fail=false
states[3]=setmetatable({},{});assert(not S.moveLearningPresentation.view(game,states))
states[3]=nil
callback(false);assert(result==false and not S.moveLearningPresentation.view(game,states))
game.save={party={mon}}
local box=Text.new(game,"CHARMANDER learned\nEMBER!",function()result="free-slot"end)
states[3]=box
assert(S.moveLearningPresentation.view(game,states),"free-slot field learning left native")
game:draw()
callback();assert(result=="free-slot")
states[3]=nil
-- Gen 2 retains the native learner and its exact callback result.
S.generation=2
local nativeCalls=0
Game.learnMoveOn=function(self,m,id,done)
  nativeCalls=nativeCalls+1;callback=done
  self.stack.states[#self.stack.states+1]=setmetatable({
    shown={{1}},arrowVisible=function()return false end},Text)
end
Game.frameFit=function()return 4,1,2,2,1280,960 end
package.loaded["src.core.Game2"]=Game
package.loaded["src.ui.gen2.MoveDeleter"]=List
package.loaded["src.ui.gen2.Chrome"]={playfieldRect=function(w,h)return 0,0,w,h end,clipTo=noop}
assert(loadfile("modules/move_learning_presentation.lua"))({},S)
game:learnMoveOn(mon,"GROWL",function(ok)result=ok end)
assert(nativeCalls==1 and S.moveLearningPresentation.view(game,states))
game:draw();assert(depth==0 and game.stack.states==states)
game._silverLearningDraw=true
local scale,x,y=game:frameFit(640,480)
assert(scale==2.5 and x==0 and y==0)
game._silverLearningDraw=nil
callback(true);assert(result==true and not S.moveLearningPresentation.view(game,states))
print("PASS move learning presentation: rules/callbacks, colors, error cleanup, Gen 2 grid")
