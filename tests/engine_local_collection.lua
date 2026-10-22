local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    local V=require("src.core.GameVersion")
    local version=V.get()
    local S=assert(game.mods.exports.minimal_cheats).silvershadow
    game.writeSave=function()end
    if V.generation()==2 then
      game:continueGame(require("src.core.gen2.Save").newGame({playerName="TEST"}));U.wait(20)
      local Mon=require("src.battle.gen2.Mon")
      game.save.party={Mon.new(game.data,"CYNDAQUIL",12)}
      local rows=require("src.mods.Runtime").call("ui.start_menu.items",function(_,r)return r end,game,{})
      local summon
      for _,r in ipairs(rows)do if r.label=="SUMMON"then summon=r end end
      assert(summon,"SUMMON menu missing")
      summon.onSelect();U.wait(5)
      local list=game.stack:top()
      assert(list and #list.items==251,"species list incomplete")
      -- Exercise the public action through its native screen selection.
      local target
      for i,r in ipairs(list.items)do if r.species=="HOOTHOOT"then target=i;break end end
      assert(target,"Hoothoot missing from list")
      list.index=target
      U.tap(game,"a")
      local b
      for _=1,300 do
        b=game.stack:top()
        if b and b.screenId=="Gen2BattleState"then break end
        U.wait(1)
      end
      assert(b and b.battle and b.battle.enemy.species=="HOOTHOOT","Summon did not start chosen wild battle")
      assert(#game.save.party==1,"Summon granted instead of encountering")
      print("LOCAL COLLECTION PASS "..version..": 251-species Summon menu starts native wild battle")
      return
    end
    local frlg=version=="firered"or version=="leafgreen"
    local prefix=version=="emerald"and"EM_"or version=="ruby"and"RU_"or"SA_"
    local spot={map=frlg and"FR_ROUTE1"or(prefix.."ROUTE101"),x=5,y=5,facing="down"}
    game:_handleBootAction({action="new_game",name="TEST",gender=0,start=spot})
    U.wait(80)
    local s=assert(game.session)
    local P=require("src.core.game3.pokemon")
    local Party=require("src.core.game3.party")
    local Dex=require("src.core.game3.dex")
    local Stack=require("src.ui.game3.stack")
    local Message=require("src.ui.game3.message")
    Stack.clear();Message.close()
    s.party={};Party.giveMonToPlayer(s,P.speciesFromNational(4),12)
    S.set("follower_count",0)
    if frlg then
      assert(S.gen3CollectionLimit()==151,"pre-National limit wrong")
      for _,r in ipairs(S.gen3AreaRows())do assert(P.national(r.species)<=151,"pre-National leak")end
      local Flags=require("src.core.game3.scripting.flags")
      local Space=require("src.core.game3.scripting.space")
      Flags.setFlag(Space.store,nil,0x840,true)
      Flags.setVar(Space.store,nil,0x404E,0x6258)
      assert(S.gen3CollectionLimit()==386,"native story flags did not unlock roster")
      for n=1,386 do if n~=163 then Dex.setCaught(s.dex,P.speciesFromNational(n))end end
      local found=false
      for _,r in ipairs(S.gen3AreaRows())do if P.national(r.species)==163 then found=true end end
      assert(found,"Hoothoot missing on Route 1")
      S.ensureGen3DexNav();s.registeredItem=S.gen3DexNavItem
      U.tap(game,"select")
    else
      S.openGen3Options();S.gen3Menu.list.items[7].run()
      assert(#S.gen3Menu.list.items==386,"Summon list incomplete")
      S.gen3Menu.list.items[163].run()
    end
    local Battle=require("src.core.game3.battle")
    for _=1,600 do if Battle.isActive()then break end;U.wait(1)end
    assert(Battle.isActive(),"native wild battle did not start")
    U.wait(60)
    local st=assert(Battle.getState())
    assert(P.speciesOf(st.enemy.mon)==P.speciesFromNational(163),"wrong encountered species")
    assert(#s.party==1,"species was granted directly")
    assert(U.shot(game,os.getenv("SILVERSHADOW_SHOTS").."/"..version.."-area-collection.png"))
    assert(#game.mods.errors==0,"runtime mod error")
    print("LOCAL COLLECTION PASS "..version..": native National gate; fixed local habitat; immediate encounter; party unchanged")
  end,debug.traceback)
  if not ok then print("FAIL "..tostring(err))end
  love.event.quit(ok and 0 or 1)
end
