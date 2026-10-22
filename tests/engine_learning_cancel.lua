local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    game.writeSave=function()end
    local V=require("src.core.GameVersion")
    local gen=V.generation()
    local S=game.mods.exports.minimal_cheats.silvershadow
    if gen==3 then
      local Learn=require("src.core.game3.battle.learn_move")
      local Choice=require("src.ui.game3.choice")
      local P=require("src.core.game3.pokemon")
      local function trial(battle,relearner,mode)
        Learn.reset();Choice.reset()
        local mon={species=P.speciesFromNational(4),nickname="TEST",level=20,
          moves={10,45,52,108},pp={9,8,7,6}}
        local calls,result=0,nil
        Learn.begin({mon=mon,moveId=99,battleText=battle,relearner=relearner,
          pushMsg=function(_,done)if done then done()end end,
          askYesNo=function(_,done)Choice.yesNo(done)end,
          askForget=function(_,done)done(mode=="learn"and 0 or -1)end,
          onDone=function(learned)calls=calls+1;result=learned end})
        assert(Choice.isOpen(),"initial learning choice missing")
        if mode=="list"or mode=="learn"then Choice.confirm()else Choice.cancel()end
        if mode=="resume"then
          Choice.cursor=2;Choice.confirm()
          assert(calls==0 and Learn.busy(),"A on NO must resume learning")
          Choice.cancel()
        end
        if mode~="learn"then
          Choice.cancel();Choice.cancel()
          assert(calls==1 and result==false and not Learn.busy(),"B did not end learning once")
          assert(mon.moves[1]==10 and mon.moves[2]==45 and mon.moves[3]==52
            and mon.moves[4]==108 and mon.pp[1]==9,"decline changed moves/PP")
        else
          assert(calls==1 and result==true and P.knowsMove(mon,99),"normal learning changed")
        end
      end
      local kinds={{true,false},{false,false}}
      if V.get()~="ruby"and V.get()~="sapphire"then kinds[#kinds+1]={false,true}end
      for _,kind in ipairs(kinds)do
        for _,mode in ipairs({"decline","list","resume","learn"})do trial(kind[1],kind[2],mode)end
      end
      local unrelated
      Choice.yesNo(function(yes)unrelated=yes end);Choice.cancel()
      assert(unrelated==false,"unrelated B answer changed")
      Learn.reset()
      local frlg=V.get()=="firered"or V.get()=="leafgreen"
      local rs=V.get()=="ruby"or V.get()=="sapphire"
      local Reminder=require(frlg and "src.ui.game3.move_relearner"or"src.ui.game3.rse.move_relearner")
      local show=rs and require("src.ui.game3.rs.move_relearner").show or Reminder.show
      local mon={species=P.speciesFromNational(4),nickname="TEST",level=30,
        moves={10,45,52,108},pp={9,8,7,6}}
      local completed,result=0,nil
      show(mon,{onDone=function(learned)completed=completed+1;result=learned end})
      assert(#Reminder.moves()>0,"no actual reminder moves available")
      local function press(key)
        Reminder.handleInput({wasPressed=function(_,k)return k==key end})
      end
      press("a");press("a") -- select move and accept teaching
      for _=1,20 do
        if Reminder.state=="yesno"then break end
        press("b")
      end
      assert(Reminder.state=="yesno","reminder delete prompt missing")
      press("b") -- decline replacement -> stop learning
      for _=1,30 do
        if not Reminder.open then break end
        press("b")
      end
      assert(not Reminder.open and completed==1 and result==false,"B loop in actual Move Reminder")
      assert(mon.moves[1]==10 and mon.pp[1]==9,"reminder cancel changed moves")
    else
      if gen==2 then
        game:continueGame(require("src.core.gen2.Save").newGame({playerName="TEST"}))
      else game:startNewGame({intro=false})end
      U.wait(20);S.set("instant_text",true)
      local Choice=require("src.ui.ChoiceBox")
      local List=require("src.ui.MoveLearnMenu")
      local function untilState(predicate,button)
        for _=1,480 do
          if predicate()then return end
          U.tap(game,button);U.wait(1)
        end
        error("learning flow did not settle")
      end
      for _,mode in ipairs({"decline","list","resume"})do
        S.set("modern_evolution_screen",mode~="list")
        local mon=(gen==2 and require("src.battle.gen2.Mon")or require("src.pokemon.Pokemon"))
          .new(game.data,"CHARMANDER",20)
        mon.moves={{id="SCRATCH",pp=9},{id="GROWL",pp=8},{id="EMBER",pp=7},{id="CUT",pp=6}}
        game.save.party={mon}
        local calls,result=0,nil
        local function done(learned)calls=calls+1;result=learned end
        if gen==2 then game:learnMoveOn(mon,"BITE",done)
        else game.stack:push(List.new(game,mon,"BITE",done))end
        if mode=="list"then
          untilState(function()
            local top=game.stack:top()
            return gen==2 and top.screenId=="Gen2MoveDeleter"or gen==1 and top.selecting
          end,"a")
        elseif mode=="resume"then
          untilState(function()return game.stack:top()._silverStopLearning
            and getmetatable(game.stack:top())==Choice end,"b")
          local choice=game.stack:top()
          choice.index=2;U.tap(game,"a");U.wait(20)
          assert(calls==0,"A on NO must keep learning active")
        end
        untilState(function()return calls>0 end,"b")
        assert(calls==1 and result==false,"decline callback incorrect")
        for i,id in ipairs({"SCRATCH","GROWL","EMBER","CUT"})do
          assert(mon.moves[i].id==id and mon.moves[i].pp==10-i,"decline changed moves/PP")
        end
        U.wait(20);assert(calls==1,"duplicate completion")
      end
      local result
      game.stack:push(Choice.new(game,function(yes)result=yes end))
      U.tap(game,"b");U.wait(20)
      assert(result==false,"unrelated B answer changed")
    end
    print("LEARNING CANCEL PASS "..V.get()..": repeated B, forget-list cancel, explicit NO resume, unchanged moves and unrelated choices")
  end,debug.traceback)
  if not ok then print(err)end
  love.event.quit(ok and 0 or 1)
end
