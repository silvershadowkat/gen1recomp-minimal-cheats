-- B consistently exits learning. A on NO still resumes the native flow.
-- Restrict the changed answer to the stop-learning confirmation; do not
-- change other YES/NO prompts, move replacement, item costs or callbacks.
local _,S=...
if S.generation==3 then
  local Learn=require("src.core.game3.battle.learn_move")
  local Choice=require("src.ui.game3.choice")
  local stopQuestion=false
  local begin,reset,cancel=Learn.begin,Learn.reset,Choice.cancel
  local function stopText()
    if Learn._battleText and not Learn._relearner then
      return require("src.core.game3.battle.battle_text").get("STRINGID_STOPLEARNINGMOVE",
        {buff1=Learn._name,buff2=Learn._moveName})
    end
    return require("src.core.game3.rom_text").ascii(
      Learn._relearner and "gText_StopLearningMove"or"gText_StopLearningMove2",
      {stringVars={Learn._name,Learn._moveName}})
  end
  Learn.begin=function(opts)
    stopQuestion=false
    if not(opts and opts.askYesNo)then return begin(opts)end
    local copy={};for k,v in pairs(opts)do copy[k]=v end
    copy.askYesNo=function(text,done,...)
      stopQuestion=text==stopText()
      return opts.askYesNo(text,function(...)
        stopQuestion=false
        return done(...)
      end,...)
    end
    return begin(copy)
  end
  Learn.reset=function(...)
    stopQuestion=false
    return reset(...)
  end
  Choice.cancel=function(...)
    if stopQuestion and Learn.busy()and Learn.waitingChoice()
        and Choice.isOpen()and Choice.kind=="yesno"and not Choice.ignoreBPress then
      Choice.cursor=1
      return Choice.confirm()
    end
    return cancel(...)
  end
  -- Move Reminder screens own their YES/NO controls rather than Choice.
  -- Ruby/Sapphire additionally own their learning dialogue implementation.
  for _,path in ipairs({"src.ui.game3.move_relearner","src.ui.game3.rse.move_relearner"})do
    local reminder=require(path)
    local giveUp,handle=reminder.giveUpPrompt,reminder.handleInput
    reminder.giveUpPrompt=function(...)
      local result=giveUp(...)
      reminder._silverGiveUp=true
      return result
    end
    reminder.handleInput=function(input,...)
      if reminder.state~="yesno"then reminder._silverGiveUp=nil end
      local stop=stopQuestion and Learn.busy()and Learn._relearner
      local opts=reminder._opts
      if reminder.open and reminder.state=="yesno"and opts and opts.startLearn
          and opts.text and reminder._pendingMoveId then
        local P=require("src.core.game3.pokemon")
        local expected=opts.text("gOtherText_StopLearningMove",{stringVars={
          P.displayMonName(reminder._mon),P.moveName(reminder._pendingMoveId)}})
        local function clean(s)return tostring(s):gsub("\\n","\n"):gsub("\\p$",""):gsub("\\p","\n")end
        stop=clean(reminder.prompt)==clean(expected)
      end
      local cancel=reminder.open and reminder.state=="yesno"
        and (stop or reminder._silverGiveUp)and input:wasPressed("b")
        and not input:wasPressed("a")and not input:wasPressed("up")and not input:wasPressed("down")
      if input:wasPressed("a")or input:wasPressed("b")then reminder._silverGiveUp=nil end
      if cancel then
        reminder.yesNoCursor=1
        local proxy=setmetatable({wasPressed=function(_,key)
          if key=="a"then return true elseif key=="b"then return false end
          return input:wasPressed(key)
        end},{__index=input})
        return handle(proxy,...)
      end
      return handle(input,...)
    end
  end
  return
end
local Text=require("src.render.TextBox")
local Choice=require("src.ui.ChoiceBox")
if S.generation==1 then
  local List=require("src.ui.MoveLearnMenu")
  local abandon=List.confirmAbandon
  List.confirmAbandon=function(self,...)
    local result=abandon(self,...)
    local text=self.game.stack:top()
    if getmetatable(text)==Text and text.choice then text._silverStopLearning=true end
    return result
  end
else
  local Game=require("src.core.Game2")
  local Strings=require("src.core.Strings")
  local contexts=setmetatable({},{__mode="k"})
  local learn,new=Game.learnMoveOn,Text.new
  Game.learnMoveOn=function(self,mon,id,done,...)
    local def=(self.data.moves or{})[id]
    local ctx={text=Strings("Stop learning\n%s?",def and def.name or id)}
    contexts[self]=ctx
    local ok,result=pcall(learn,self,mon,id,function(...)
      if contexts[self]==ctx then contexts[self]=nil end
      if done then return done(...)end
    end,...)
    if not ok then
      if contexts[self]==ctx then contexts[self]=nil end
      error(result,0)
    end
    return result
  end
  Text.new=function(game,text,done,opts,...)
    local box=new(game,text,done,opts,...)
    local ctx=contexts[game]
    if ctx and ctx.text==text and opts and opts.choice then box._silverStopLearning=true end
    return box
  end
end
local new,update=Choice.new,Choice.update
Choice.new=function(game,...)
  local parent=game.stack:top()
  local choice=new(game,...)
  choice._silverStopLearning=getmetatable(parent)==Text and parent._silverStopLearning
  return choice
end
Choice.update=function(self,...)
  local input=self.game.input
  local cancel=self._silverStopLearning and self.pending==nil
    and input:wasPressed("b")and not input:wasPressed("a")
    and not input:wasPressed("up")and not input:wasPressed("down")
  local result=update(self,...)
  if cancel and self.pending==false then
    -- Keep the native sound and answer delay, but highlight/answer YES.
    self.index=1;self.pending=true
  end
  return result
end
