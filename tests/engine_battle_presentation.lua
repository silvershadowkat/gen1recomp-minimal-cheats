local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    local V=require("src.core.GameVersion");local version=V.get();local gen2=V.generation()==2
    local S=assert(game.mods.exports.minimal_cheats).silvershadow
    local out=os.getenv("SILVERSHADOW_SHOTS")
    game.writeSave=function()end
    love.window.setMode(800,600,{resizable=false})
    S.set("modern_battle_hud",true)
    S.set("infinite_hp",true);S.set("infinite_pp",true);S.set("damage_multiplier",1)
    local battle
    if gen2 then
      local save=require("src.core.gen2.Save").newGame({playerName="TEST"})
      game:continueGame(save);U.wait(30)
      local Mon=require("src.battle.gen2.Mon")
      local player=Mon.new(game.data,"BUTTERFREE",20)
      player.moves={{id="CONFUSION",pp=25,maxPp=25},{id="TACKLE",pp=35,maxPp=35}}
      game.save.party={player}
      assert(game.world:startBattle({wild=Mon.new(game.data,"SLOWPOKE",25)}))
      for _=1,600 do
        battle=game.stack:top()
        if battle and battle.screenId=="Gen2BattleState" and battle.battle then break end
        U.wait(1)
      end
      assert(battle and battle.battle,"Gen2 battle missing")
    else
      game:startNewGame({intro=false});U.wait(20)
      local P=require("src.pokemon.Pokemon")
      local B=require("src.battle.BattleState")
      local player=P.new(game.data,"BUTTERFREE",20)
      player.moves={{id="CONFUSION",pp=25},{id="TACKLE",pp=35}}
      game.save.party={player}
      if version=="yellow" then
        local PF=require("src.world.PikachuFollower")
        local pika=P.new(game.data,"PIKACHU",20);B.stampOT(game.save,pika)
        game.save.party={player,pika}
        game.save.flags.EVENT_GOT_STARTER=true
        game.save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB=true
        game.save.pikachuInBall=false
        S.set("follower_count",3);S.set("follower_mode","trainer")
        U.teleport(game,"ROUTE_1",5,5,"down");U.wait(30)
        assert(PF.starterInParty(game.save,true)==pika,"Yellow identity was hijacked")
        assert(PF.current(game.overworld),"Yellow native companion missing")
        local happiness=game.save.pikachuHappiness or 90
        PF.modifyHappiness(game.save,"WALKING")
        assert(game.save.pikachuHappiness>happiness,"Yellow happiness not updated")
        pika.hp=0;assert(PF.starterInParty(game.save,true)==nil,"fainted starter accepted")
        pika.hp=pika.stats.hp
        game.save.party={player};assert(PF.starterInParty(game.save,true)==nil,"Butterfree counted as Pikachu")
        game.save.party={player,pika};U.wait(10)
        assert(U.shot(game,out.."/yellow-native-companion.png"))
        print("PASS Yellow original Pikachu identity, happiness, faint and absent gates")
      else U.teleport(game,"ROUTE_1",5,5,"down") end
      battle=B.newWild(game,"SLOWPOKE",25);battle.onFinish=function()end
      game.overworld:pushBattle(battle)
    end
    U.wait(120)
    assert(U.shot(game,out.."/"..version.."-modern-intro.png"))
    local function menu()
      for _=1,1200 do
        if battle.phase=="menu" then return end
        U.tap(game,"a");U.wait(2)
      end
      error("menu never settled "..tostring(battle.phase))
    end
    menu();U.wait(10)
    if gen2 then battle.caughtMark=true
    else game.save.pokedex.owned.SLOWPOKE=true end
    assert(U.shot(game,out.."/"..version.."-modern-battle.png"))
    U.tap(game,"a");U.wait(10)
    assert(battle.phase==(gen2 and "moves" or "moveSelect"),"native fight control failed")
    local _,_,effect=S.battleMoveInfo(battle,{id="CONFUSION"})
    assert(effect=="TYPE 1/2x","Psychic matchup did not use native type chart: "..effect)
    local _,_,status=S.battleMoveInfo(battle,{id="STRING_SHOT"})
    assert(status=="STATUS","status move presented as damage")
    U.tap(game,"right");U.wait(2);assert(battle.moveIndex==2,"2x2 move grid right navigation")
    U.tap(game,"left");U.wait(2);assert(battle.moveIndex==1,"2x2 move grid left navigation")
    assert(U.shot(game,out.."/"..version.."-modern-moves.png"))
    U.tap(game,"a");U.wait(30)
    assert(U.shot(game,out.."/"..version.."-modern-animation.png"))
    menu();S.set("modern_battle_hud",false);U.wait(4)
    assert(U.shot(game,out.."/"..version.."-native-battle.png"))
    S.set("modern_battle_hud",true);U.wait(4)
    assert(#game.mods.errors==0,"mod load error")
    print("SILVERSHADOW BATTLE PASS "..version..": menu, move selection, turn animation, toggle")
  end,debug.traceback)
  if not ok then print("FAIL "..tostring(err))end
  love.event.quit(ok and 0 or 1)
end
