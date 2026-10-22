local U=require("tests.drivers.util")
local Json=require("src.link.Json")
return function(game)
  local ok,err=xpcall(function()
    game.writeSave=function()end
    love.window.setMode(800,600,{resizable=false})
    local V=require("src.core.GameVersion");local gen,version=V.generation(),V.get()
    if gen==3 then
      local prefix=({firered="FR_",leafgreen="LG_",ruby="RU_",sapphire="SA_",emerald="EM_"})[version]
      game:_handleBootAction({action="new_game",name="TEST",gender=0,
        start={map=prefix..((gen==3 and(version=="firered"or version=="leafgreen"))and"ROUTE1"or"ROUTE101"),x=5,y=5,facing="down"}})
      U.wait(60);require("src.ui.game3.stack").clear();require("src.ui.game3.message").close()
    elseif gen==2 then game:continueGame(require("src.core.gen2.Save").newGame({playerName="TEST"}))
    else game:startNewGame({intro=false})end
    U.wait(25)
    local S=game.mods.exports.minimal_cheats.silvershadow
    assert(S.modDeck,"bridge missing")
    local root="mod_cache/minimal_cheats/"
    local fs=require("src.core.SaveData").persistenceFs()
    local function state()return assert(Json.decode(assert(fs.read(root..S.modDeck.statePath))))end
    local function tick()S.modDeck.tick(game,0,true)end
    local function row(s,key)for _,r in ipairs(s.settings)do if r.key==key then return r end end end
    tick();local s=state();assert(s.active and s.game==version and #s.settings>15,"active game discovery failed")
    for _,r in ipairs(s.settings)do assert(r.kind=="toggle"or r.kind=="choice");assert(not r.key:find("follower")and not r.key:find("summon"))end
    local n=0
    local function send(key,value,expected,session,gameId)
      n=n+1
      local req={schema=1,id="test-"..n,session=session or state().session,game=gameId or version,key=key,value=value,expected=expected}
      assert(fs.write(root..S.modDeck.requestPath,Json.encode(req)))
      tick();return state()
    end
    s=send("infinite_hp",true,row(s,"infinite_hp").value)
    assert(s.ack.status=="applied"and S.bool("infinite_hp"),"toggle did not apply")
    -- Simulate an ordinary in-game menu change and a stale overlay click.
    S.set("infinite_hp",false);tick();s=state();assert(not row(s,"infinite_hp").value,"reverse sync failed")
    -- An already open native options menu must refresh too, not only on reopen.
    local menu,hp
    if gen==3 then
      S.openGen3Options();S.gen3Menu.list.items[1].run();menu=S.gen3Menu.list
      for _,r in ipairs(menu.items)do if r.key=="infinite_hp"then hp=r end end
    else
      require("src.ui.Screens").push(game,gen==2 and "SilverShadowGen2Battle"or"SilverShadowBattle")
      menu=game.stack:top()
      for _,r in ipairs(menu.items)do if r._silver and r._silver.key=="infinite_hp"then hp=r end end
    end
    assert(hp,"in-game option missing")
    s=send("infinite_hp",true,false)
    assert(gen==3 and hp.label:find(": ON",1,true)or gen~=3 and hp.right=="ON","open menu not refreshed")
    if gen==3 then menu.onSelect(hp);require("src.ui.game3.stack").clear()
    else menu.onChoose(hp,menu);game.stack:pop()end
    tick();assert(not row(state(),"infinite_hp").value,"native option change not published")
    s=send("infinite_hp",false,true);assert(s.ack.status=="rejected"and not S.bool("infinite_hp"),"stale value accepted")
    s=send("damage_multiplier","OHKO",row(s,"damage_multiplier").value)
    assert(s.ack.status=="applied"and S.get("damage_multiplier")=="OHKO","enum failed")
    s=send("damage_multiplier",999,"OHKO");assert(s.ack.status=="rejected"and S.get("damage_multiplier")=="OHKO")
    s=send("summon",true,false);assert(s.ack.status=="rejected","tool exposed")
    s=send("infinite_hp",true,false,"stale:1");assert(s.ack.status=="rejected"and not S.bool("infinite_hp"))
    s=send("infinite_hp",true,false,nil,version=="blue"and"red"or"blue");assert(s.ack.status=="rejected")
    S.linkBattleActive=true;s=send("infinite_hp",true,false);assert(s.blocked and s.ack.status=="rejected");S.linkBattleActive=false
    assert(fs.write(root..S.modDeck.requestPath,"{broken"));tick()
    assert(fs.write(root..S.modDeck.requestPath,string.rep("x",5000)));tick()
    -- Exercise the same mailbox while a real native battle is running.
    local battle,ui
    if gen==3 then
      local P=require("src.core.game3.pokemon");game.session.party={}
      require("src.core.game3.party").giveMonToPlayer(game.session,P.speciesFromNational(4),20)
      assert(require("src.core.game3.battle_bridge").startWild(require("src.core.game3.runtime")._mod,game,{species=P.speciesFromNational(1),level=10},{}))
      ui=require("src.core.game3.battle.ui")
    else
      local Mon=require(gen==2 and"src.battle.gen2.Mon"or"src.pokemon.Pokemon")
      game.save.party={Mon.new(game.data,"CHARMANDER",20)}
      if gen==2 then
        assert(game.world:startBattle({wild=Mon.new(game.data,"BULBASAUR",10)}))
        for _=1,300 do local top=game.stack:top();if top.screenId=="Gen2BattleState"then battle=top;break end;U.wait(1)end
      else battle=require("src.battle.BattleState").newWild(game,"BULBASAUR",10);game.overworld:pushBattle(battle)end
    end
    for _=1,600 do if(ui and ui._mode=="menu")or(battle and battle.phase=="menu")then break end;U.tap(game,"a");U.wait(1)end
    assert((ui and ui._mode=="menu")or(battle and battle.phase=="menu"),"battle menu missing")
    tick();s=send("guaranteed_catch",true,row(state(),"guaranteed_catch").value)
    assert(s.active and s.ack.status=="applied"and S.bool("guaranteed_catch"),"battle toggle failed")
    s=send("exp_multiplier",4,row(state(),"exp_multiplier").value)
    assert(s.ack.status=="applied"and S.get("exp_multiplier")==4,"battle multiplier failed")
    -- A changed save identity must invalidate requests from the old context.
    local old=state().session
    if gen==3 then local original=game.session;game.session={};tick();game.session=original;tick()
    else local original=game.save;game.save={};tick();game.save=original;tick()end
    s=send("infinite_hp",true,false,old);assert(s.ack.status=="rejected","previous save request accepted")
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/"..version.."-moddeck-battle.png"))
    print("MODDECK PASS "..version..": discovery, two-way settings, live battle, enums, stale values/sessions, link block, malformed requests, no tools")
  end,debug.traceback)
  if not ok then print(err)end
  love.event.quit(ok and 0 or 1)
end
