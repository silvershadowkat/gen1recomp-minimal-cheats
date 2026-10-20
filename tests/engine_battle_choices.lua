local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    game.writeSave=function()end
    love.window.setMode(800,600,{resizable=false})
    game:startNewGame({intro=false});U.wait(20)
    local S=game.mods.exports.minimal_cheats.silvershadow
    S.set("modern_battle_hud",true)
    local Mon=require("src.pokemon.Pokemon")
    game.save.party={Mon.new(game.data,"CHARMANDER",12),Mon.new(game.data,"PIDGEY",10)}
    local B=require("src.battle.BattleState")
    local Choice=require("src.ui.ChoiceBox")
    local b=B.newWild(game,"RATTATA",3)
    b.onFinish=function()end
    game.overworld:pushBattle(b)
    for _=1,600 do
      if b.phase=="menu"then break end
      U.tap(game,"a");U.wait(1)
    end
    assert(b.phase=="menu")
    for n,text in ipairs({"Will RED\nchange POKéMON?","Use next POKéMON?"})do
      local result
      b.phase="messages";b.afterQueue="menu"
      b:sayChoice(text,function(yes)result=yes end)
      for _=1,240 do
        if getmetatable(game.stack:top())==Choice then break end
        U.tap(game,"a");U.wait(1)
      end
      local choice=game.stack:top()
      assert(getmetatable(choice)==Choice,"missing native choice")
      assert(S.modernBattleEnabled()and b:isWideBattleLayout(),"choice reverted battle")
      assert(choice:isWideBattleLayout(),"choice placed on classic canvas")
      local w,h=choice:uiSize()
      assert(w==256 and h==192,"choice changed battle canvas dimensions")
      assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/blue-battle-choice-"..n..".png"))
      U.tap(game,n==1 and "b"or "a");U.wait(30)
      assert(result==(n==2),"native YES/NO behavior changed")
    end
    b:openReplacementMenu()
    for _=1,120 do
      if game.stack:top()~=b then break end
      U.tap(game,"a");U.wait(1)
    end
    assert(game.stack:top()~=b,"replacement party did not open")
    assert(not S.modernBattleEnabled(),"party menu lost native layout")
    game.stack:pop()
    assert(S.modernBattleEnabled(),"modern background did not return")
    S.set("modern_battle_hud",false)
    local c=Choice.new(game,function()end);game.stack:push(c)
    assert(not c:isWideBattleLayout(),"disabled mod changed native choice")
    U.log("PASS battle choice backdrop, YES/NO, forced replacement and disabled fallback")
  end,debug.traceback)
  if not ok then print(err)end
  love.event.quit(ok and 0 or 1)
end
