local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    game.writeSave=function()end
    love.window.setMode(800,600,{resizable=false})
    local V=require("src.core.GameVersion");local gen,version=V.generation(),V.get()
    local S=game.mods.exports.minimal_cheats.silvershadow
    local C=assert(S.batchCandy)
    if gen==3 then
      local prefix=({firered="FR_",leafgreen="LG_",ruby="RU_",sapphire="SA_",emerald="EM_"})[version]
      game:_handleBootAction({action="new_game",name="TEST",gender=0,
        start={map=prefix..((version=="firered"or version=="leafgreen")and"ROUTE1"or"ROUTE101"),x=5,y=5,facing="down"}})
      U.wait(60);require("src.ui.game3.stack").clear();require("src.ui.game3.message").close()
    elseif gen==2 then game:continueGame(require("src.core.gen2.Save").newGame({playerName="TEST"}))
    else game:startNewGame({intro=false})end
    U.wait(20)
    S.set("instant_text",true);S.set("heal_map_change",false);S.set("infinite_hp",false)
    local mon,bag,list,party
    local function count()
      if gen==3 then return require("src.core.game3.bag").get(bag,"RARE_CANDY")end
      return game.save.inventory.RARE_CANDY or 0
    end
    if gen==3 then
      local P=require("src.core.game3.pokemon");game.session.party={}
      require("src.core.game3.party").giveMonToPlayer(game.session,P.speciesFromNational(10),5)
      mon=game.session.party[1];bag=game.session.bag
      require("src.core.game3.bag").add(bag,"RARE_CANDY",20)
      party=require("src.ui.game3.party_menu")
      party.show(game.session.party,nil,{session=game.session,bag=bag,item="RARE_CANDY",mode="use"})
    else
      mon=require(gen==2 and"src.battle.gen2.Mon"or"src.pokemon.Pokemon").new(game.data,"CATERPIE",5)
      game.save.party={mon};game.save.inventory={RARE_CANDY=20};game.save.bagOrder={"RARE_CANDY"};game.save.bagStacks=nil
      if gen==2 then game:usePartyItem("RARE_CANDY");party=game.stack:top()
      else
        list=require("src.ui.BagMenu").new(game);game.stack:push(list)
        for _=1,6 do
          local found
          for i,row in ipairs(list.items)do if row.value=="RARE_CANDY"then list.index=i;found=true end end
          if found then break end;U.tap(game,"right")
        end
        assert(list.items[list.index].value=="RARE_CANDY")
        U.tap(game,"a");U.tap(game,"a");party=game.stack:top()
      end
    end
    mon.hp=math.max(1,mon.hp-3)
    local original=C.snapshot(mon);local initial=count()
    local function picker()
      if gen==3 then local top=require("src.ui.game3.stack").top();return top and top.mod end
      return game.stack:top()
    end
    U.tap(game,"a");U.wait(2)
    local q=picker();assert(q and q.screenId=="SilverCandyQuantity","quantity did not open")
    assert(q.qty==1 and q.max==20,"wrong quantity limits")
    U.tap(game,"b");assert(mon.level==5 and count()==initial,"cancel changed mon/bag")
    U.tap(game,"a");U.tap(game,"right")
    assert(picker().qty==11,"right must add ten")
    U.tap(game,"left");assert(picker().qty==1)
    for _=1,7 do U.tap(game,"up")end
    assert(picker().qty==8)
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/"..version.."-candy-quantity.png"))
    C.lastResult=nil;U.tap(game,"a")
    for _=1,2400 do
      if C.lastResult then break end
      U.tap(game,"a");U.wait(1)
    end
    if not C.lastResult then
      local top=gen==3 and party or game.stack:top()
      print("STUCK",mon.level,count(),top and top.screenId,top and top.phase,top and top.mode,top and top.text)
      U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/"..version.."-candy-stuck.png")
    end
    local result=assert(C.lastResult,"batch never completed")
    mon=result.mon
    assert(result.used==8 and result.before.level==5 and mon.level==13,"wrong total levels/candies")
    assert(count()==initial-8,"wrong candy consumption")
    local species=gen==3 and require("src.core.game3.pokemon").speciesOf(mon)or mon.species
    assert(species=="BUTTERFREE"or gen==3 and species==require("src.core.game3.pokemon").speciesFromNational(12),"intermediate evolution skipped: "..tostring(species))
    local moves={}
    for _,mv in ipairs(mon.moves)do moves[type(mv)=="table"and mv.id or mv]=true end
    if gen~=1 then assert(moves.HARDEN or moves[106],"missed Metapod Harden")end
    assert(moves.CONFUSION or moves[93],"missed Butterfree Confusion")
    assert(result.before.hp==original.hp and result.after.hp==mon.hp,"wrong aggregate HP")
    assert(mon.hp==(gen==3 and mon.maxHp or mon.stats.hp)-3,"lost prior HP deficit")
    if gen==3 then
      for _=1,180 do if party.mode=="stat_growth"then break end;U.tap(game,"a");U.wait(1)end
      assert(party.mode=="stat_growth","total stat screen missing")
      assert(party._statGrowthOld.maxHp==original.maxHp and party._statGrowthNew.maxHp==mon.maxHp,"stats show only last candy")
    else
      assert(game.stack:top().screenId=="SilverCandyGrowth","growth summary missing")
      assert(result.after.attack==mon.stats.attack and (gen==1 or result.after.spAttack==mon.stats.specialAttack))
    end
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/"..version.."-candy-growth.png"))
    if gen==3 then U.tap(game,"a");U.tap(game,"a")else U.tap(game,"a")end
    -- Choosing the default one through the real picker still applies one
    -- candy and returns through the normal item/party flow.
    if gen==1 then
      assert(game.stack:top()==list,"batch did not return to native bag")
      U.tap(game,"a");U.tap(game,"a")
    elseif gen==2 then game:usePartyItem("RARE_CANDY")end
    U.tap(game,"a");assert(picker().screenId=="SilverCandyQuantity"and picker().qty==1)
    local oneLevel,oneCount=mon.level,count()
    U.tap(game,"a")
    for _=1,500 do
      local ready=gen==3 and party.mode=="stat_growth"or gen~=3 and game.stack:top().screenId=="SilverCandyGrowth"
        or gen==1 and game.stack:top()==list
      if ready then break end
      U.tap(game,"a");U.wait(1)
    end
    assert(mon.level==oneLevel+1 and count()==oneCount-1,"single candy changed wrong amount")
    if gen==3 then U.tap(game,"a");U.tap(game,"a")
    elseif gen==2 then U.tap(game,"a")end
    -- Boundary conditions: quantity cannot exceed inventory or level cap;
    -- eggs refuse, and Gen 3 retains its native fainted-mon restriction.
    local ceiling=gen==1 and S.extendedLevels.max or 100
    assert(C.limit({level=ceiling-2,hp=1},90)==2)
    assert(C.limit({level=ceiling,hp=1},90)==0)
    assert(C.limit({level=5,hp=1},2)==2)
    assert(C.limit({level=5,hp=1,isEgg=true},20)==0)
    if gen==3 then assert(C.limit({level=5,hp=0},20)==0)end
    -- A full moveset must still let repeated B decline learning and finish
    -- the batch; never discard a known move silently or loop on abandon.
    local function trialMon(level)
      if gen==3 then
        local P=require("src.core.game3.pokemon")
        game.session.party={};require("src.core.game3.party").giveMonToPlayer(game.session,P.speciesFromNational(12),level)
        local m=game.session.party[1]
        party.show(game.session.party,nil,{session=game.session,bag=bag,item="RARE_CANDY",mode="use"})
        return m,C.gen3Adapter(m,game.session,bag)
      end
      local m=require(gen==2 and"src.battle.gen2.Mon"or"src.pokemon.Pokemon").new(game.data,"BUTTERFREE",level)
      game.save.party={m}
      return m,C.adapter(game,m)
    end
    local full,a=trialMon(gen==1 and 11 or 9)
    full.moves=gen==3 and {10,45,33,43}or{{id="SCRATCH",pp=9},{id="GROWL",pp=8},{id="TACKLE",pp=7},{id="LEER",pp=6}}
    if gen==3 then full.pp={9,8,7,6}end
    local completed
    C.run(full,2,a,function(r)completed=r end)
    for _=1,300 do if completed then break end;U.tap(game,"b");U.wait(1)end
    assert(completed and completed.used==2,"B stuck in stop-learning prompt")
    assert(gen==3 and full.moves[1]==10 and full.pp[1]==9 or gen~=3 and full.moves[1].id=="SCRATCH"and full.moves[1].pp==9,
      "declining replaced a move or reset PP")
    local capped,ca=trialMon(ceiling-2)
    local beforeCount=count();local capResult
    C.run(capped,99,ca,function(r)capResult=r end)
    for _=1,300 do if capResult then break end;U.tap(game,"b");U.wait(1)end
    assert(capResult and capResult.used==2 and capped.level==ceiling and count()==beforeCount-2,"level cap overspent candies")
    local atCap=count();C.run(capped,5,ca,function(r)assert(r.used==0)end)
    assert(count()==atCap,"candy spent at cap")
    local emptyCalls=0
    C.run(capped,5,{count=function()return 0 end,apply=function()emptyCalls=emptyCalls+1 end},function(r)assert(r.used==0)end)
    assert(emptyCalls==0,"empty inventory applied a candy")
    if gen==3 then
      assert(capped.exp==require("src.core.game3.battle.experience").expForLevel(capped,ceiling),"candy experience inconsistent")
    end
    assert(#game.mods.errors==0,"mod runtime error")
    print("CANDY PASS "..version..": native item UI, cancel, quantity keys, eight levels, two evolutions, intermediate moves, inventory, HP/total stats, B cancellation, exact cap consumption")
  end,debug.traceback)
  if not ok then print("FAIL "..tostring(err))end
  love.event.quit(ok and 0 or 1)
end
