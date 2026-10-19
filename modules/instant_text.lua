-- Reveal the current page only. Script pauses, choices and page advances
-- remain native; never use TextBox.instant, which jumps to the LAST page.
local mod,shared=...
local function enabled()return shared.bool("instant_text",true)end
if shared.generation==3 then
  local Message=require("src.ui.game3.message")
  local tick=Message.tick
  Message.tick=function(...)
    if enabled() and Message.isTyping()then Message.skipReveal()end
    return tick(...)
  end
  local show=Message.show
  Message.show=function(text,opts)
    if enabled()then
      if type(opts)=="function"then opts={done=opts}end
      if type(opts)~="table"then opts={}end
      local copy={};for k,v in pairs(opts or {})do copy[k]=v end
      copy.speed=0;opts=copy
    end
    return show(text,opts)
  end
  -- Ruby/Sapphire's explicit auto-scroll printer has native pause controls.
  -- Accelerate only successive glyph delays, never its wait/pause states.
  local Rs=require("src.ui.game3.rs.field_auto_scroll_message")
  local prepare,rsTick=Rs.prepare,Rs.tick
  local state
  Rs.prepare=function(...)
    local result=prepare(...);state=result;return result
  end
  Rs.tick=function(...)
    rsTick(...)
    if enabled() and state then
      for _=1,256 do
        if state.printer~="char_delay" or not Rs.isPrinting()then break end
        state.delay=0;rsTick(...)
      end
    end
  end
else
  local TextBox=require("src.render.TextBox")
  local update=TextBox.update
  TextBox.update=function(self,...)
    local original=self.noLetterDelay
    if enabled()then self.noLetterDelay=true end
    local result=update(self,...)
    self.noLetterDelay=original
    return result
  end
  if shared.generation==2 then
    local Typer=require("src.ui.gen2.Typer")
    local delay=Typer.delay
    Typer.delay=function(self,...)if enabled()then return 0 end return delay(self,...)end
  else
    local Battle=require("src.battle.BattleState")
    local updateQueue=Battle.updateQueue
    Battle.updateQueue=function(self,...)
      if enabled()then self.charTimer=4096 end
      return updateQueue(self,...)
    end
  end
end
