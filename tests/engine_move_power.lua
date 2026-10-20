local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    game.writeSave=function()end
    love.window.setMode(1280,960,{resizable=false})
    local V=require("src.core.GameVersion")
    local version,gen=V.get(),V.generation()
    local S=game.mods.exports.minimal_cheats.silvershadow
    local battle,ui
    if gen==3 then
      local prefix=({firered="FR_",leafgreen="LG_",ruby="RU_",sapphire="SA_",emerald="EM_"})[version]
      local frlg=version=="firered"or version=="leafgreen"
      game:_handleBootAction({action="new_game",name="TEST",gender=0,
        start={map=prefix..(frlg and "ROUTE1"or"ROUTE101"),x=5,y=5,facing="down"}})
      U.wait(60)
      require("src.ui.game3.stack").clear();require("src.ui.game3.message").close()
      local P=require("src.core.game3.pokemon")
      game.session.party={}
      require("src.core.game3.party").giveMonToPlayer(game.session,P.speciesFromNational(4),20)
      local mon=game.session.party[1]
      mon.moves={52,10,45,232};mon.pp={25,35,40,35};mon.maxPp={25,35,40,35}
      local Runtime=require("src.core.game3.runtime")
      assert(require("src.core.game3.battle_bridge").startWild(Runtime._mod,game,
        {species=P.speciesFromNational(1),level=18},{}))
      ui=require("src.core.game3.battle.ui")
    else
      if gen==2 then
        game:continueGame(require("src.core.gen2.Save").newGame({playerName="TEST"}))
      else game:startNewGame({intro=false})end
      U.wait(20)
      local Mon=gen==2 and require("src.battle.gen2.Mon")or require("src.pokemon.Pokemon")
      local mon=Mon.new(game.data,"CHARMANDER",20)
      mon.moves={{id="EMBER",pp=25},{id="SCRATCH",pp=35},{id="GROWL",pp=40},{id="CUT",pp=30}}
      game.save.party={mon}
      if gen==2 then
        assert(game.world:startBattle({wild=Mon.new(game.data,"BULBASAUR",18)}))
        for _=1,300 do
          local top=game.stack:top()
          if top.screenId=="Gen2BattleState"then battle=top;break end
          U.wait(1)
        end
      else
        battle=require("src.battle.BattleState").newWild(game,"BULBASAUR",18)
        battle.onFinish=function()end
        game.overworld:pushBattle(battle)
      end
    end
    S.set("modern_battle_hud",true);S.set("battle_move_info",true)
    for _=1,600 do
      if (ui and ui._mode=="menu")or(battle and battle.phase=="menu")then break end
      U.tap(game,"a");U.wait(1)
    end
    assert((ui and ui._mode=="menu")or(battle and battle.phase=="menu"),"battle menu missing")
    U.tap(game,"a");U.wait(5)
    if gen==3 then
      assert(ui._mode=="moves","move menu missing")
      local st=require("src.core.game3.battle").getState()
      local info=S.gen3MoveInfo(st,ui.activeBattlerObject(st),1)
      assert(info.power=="120","Fire STAB/weakness power wrong: "..tostring(info.power))
    else
      assert(battle.phase==(gen==2 and "moves"or"moveSelect"),"move menu missing")
      local _,_,_,power=S.battleMoveInfo(battle,{id="EMBER"})
      assert(power=="120","Fire STAB/weakness power wrong: "..tostring(power))
      local _,_,_,status=S.battleMoveInfo(battle,{id="GROWL"})
      assert(status=="--","status move power wrong")
    end
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/"..version.."-move-power.png"))
    print("MOVE POWER PASS "..version..": Ember 40 x STAB 1.5 x weakness 2 = 120")
  end,debug.traceback)
  if not ok then print(err)end
  love.event.quit(ok and 0 or 1)
end
