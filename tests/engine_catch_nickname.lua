local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    game.writeSave=function()end
    love.window.setMode(1280,960,{resizable=false})
    game:startNewGame({intro=false});U.wait(20)
    local S=game.mods.exports.minimal_cheats.silvershadow
    S.set("modern_battle_hud",true)
    local Mon=require("src.pokemon.Pokemon")
    local B=require("src.battle.BattleState")
    local Bag=require("src.inventory.Bag")
    local Text=require("src.render.TextBox")
    local Choice=require("src.ui.ChoiceBox")
    local Naming=require("src.ui.NamingScreen")
    game.save.party={Mon.new(game.data,"CHARMANDER",20)}
    assert(Bag.add(game.save,"MASTER_BALL",2,game.data))
    for n,species in ipairs({"RATTATA","PIDGEY"})do
      game.save.pokedex.owned[species]=nil
      local b=B.newWild(game,species,3)
      game.overworld:pushBattle(b)
      for _=1,600 do if b.phase=="menu"then break end;U.tap(game,"a");U.wait(1)end
      assert(b.phase=="menu","battle menu missing")
      b.menuIndex=3;U.tap(game,"a");U.wait(40)
      local list=game.stack:top()
      assert(list.kind=="bag")
      for i,row in ipairs(list.items)do if row.value=="MASTER_BALL"then list.index=i end end
      assert(list.items[list.index].value=="MASTER_BALL")
      U.tap(game,"a")
      for _=1,1200 do
        if getmetatable(game.stack:top())==Choice then break end
        U.tap(game,"a");U.wait(1)
      end
      local choice=game.stack:top()
      assert(getmetatable(choice)==Choice and b.blankForAskName,"nickname choice missing")
      local states=game.stack.states;local text=states[#states-1]
      assert(getmetatable(text)==Text,"nickname textbox missing")
      assert(game.save.pokedex.owned[species]and #game.save.party==n+1,"catch not stored")
      local suffix=os.getenv("SILVERSHADOW_NICKNAME_BEFORE")and "before"or tostring(n)
      assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/blue-catch-nickname-"..suffix..".png"))
      assert(S.modernBattleEnabled()and choice:isWideBattleLayout(),"nickname YES/NO reverted battle layout")
      local w,h=choice:uiSize();assert(w==256 and h==192,"choice resized canvas")
      assert(text:isWideBattleLayout(),"nickname text reverted canvas")
      if n==1 then
        U.tap(game,"b");U.wait(20)
        assert(not game.save.party[2].nickname,"NO changed caught Pokemon name")
      else
        U.tap(game,"a");U.wait(20)
        assert(getmetatable(game.stack:top())==Naming,"YES did not open name entry")
        assert(not S.modernBattleEnabled(),"native name entry wrongly forced wide")
        U.tap(game,"a");U.tap(game,"start");U.wait(20)
        assert(game.save.party[3].nickname=="A","name entry callback lost")
      end
      for _=1,240 do
        local alive=false
        for _,state in ipairs(game.stack.states)do if state==b then alive=true end end
        if not alive then break end
        U.tap(game,"a");U.wait(1)
      end
    end
    assert(not game.save.inventory.MASTER_BALL,"native catch item consumption changed")
    print("CATCH NICKNAME PASS: actual new-species captures, Dex entries, modern prompt, NO, YES, native name entry and ball consumption")
  end,debug.traceback)
  if not ok then print(err)end
  love.event.quit(ok and 0 or 1)
end
