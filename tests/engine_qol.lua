local U=require("tests.drivers.util")
return function(game)
 local ok,err=xpcall(function()
  local V=require("src.core.GameVersion");local gen=V.generation();local version=V.get()
  local S=assert(game.mods.exports.minimal_cheats).silvershadow
  game.writeSave=function()end
  S.set("hm_device",true);S.set("reusable_tms",true);S.set("instant_text",true)
  if gen==3 then
   assert(S.battlePresentation==nil,"Gen 3 native battle presentation was replaced")
   local fr=version=="firered"or version=="leafgreen"
   local prefix=version=="emerald"and"EM_"or version=="ruby"and"RU_"or"SA_"
   game:_handleBootAction({action="new_game",name="TEST",gender=0,start={map=fr and"FR_PALLET_TOWN"or prefix.."OLDALE_TOWN",x=8,y=8,facing="down"}})
   U.wait(50)
   local s=game.session
   local P=require("src.core.game3.pokemon");local Party=require("src.core.game3.party")
   local Bag=require("src.core.game3.bag");local Items=require("src.core.game3.items_data")
   local Use=require("src.core.game3.item_use");local FM=require("src.core.game3.field_moves")
   local Space=require("src.core.game3.scripting.space");local Flags=require("src.core.game3.scripting.flags")
   local Stack=require("src.ui.game3.stack");local Message=require("src.ui.game3.message")
   Stack.clear();Message.close();s.party={}
   Party.giveMonToPlayer(s,P.speciesFromNational(10),20)
   local caterpie=s.party[1];caterpie.moves={1};caterpie.pp={35}
   assert(not FM.partyMoveUser(s.party,"SURF"),"Surf available without HM/knowledge")
   local n=0
   for item=Items.FIRST_HM,Items.LAST_HM do
    local move=P.moveFromTmItem(item)
    if move and move>0 then
     assert(Bag.add(s.bag,item,1));assert(S.ownsGen3HM(move));
     local mon,slot=FM.partyMoveUser(s.party,move)
     assert(mon==caterpie and slot==0,"HM device did not select healthy helper")
     n=n+1
    end
   end
   assert(n>=7 and #caterpie.moves==1 and caterpie.moves[1]==1,"HM device changed moves")
   local Ctx=require("src.core.game3.scripting.ctx")
   local vm={ctx=Ctx.new(),store=Space.store}
   require("src.core.game3.scripting.ops_a").dispatch(vm,{op="checkpartymove",57})
   assert(Flags.getVar(vm.store,vm.ctx,Ctx.VAR_RESULT)==0,"scripted HM prompt still requires learned move")
   require("src.core.game3.scripting.ops_a").dispatch(vm,{op="checkpartymove",323})
   assert(Flags.getVar(vm.store,vm.ctx,Ctx.VAR_RESULT)==6,"HM device invented a non-HM move")
   local ctx={session=s,store=Space.store,party=s.party,isFacingWater=true}
   assert(not FM.trySurfOW(ctx).ok,"Surf badge bypassed")
   Flags.setFlag(Space.store,nil,FM.badgeFlag("SURF"),true)
   assert(FM.trySurfOW(ctx).ok,"Unlocked Surf still needs taught move")
   S.set("hm_device",false);assert(not FM.partyMoveUser(s.party,"SURF"));S.set("hm_device",true)
   local style=S.gen3Followers.style
   assert(style(caterpie,true,false)==nil,"HM helper made Caterpie a swimmer")
   caterpie.moves={57};assert(style(caterpie,true,false)=="surf")
   caterpie.moves={19};assert(style(caterpie,true,true)=="air")
   caterpie.moves={1}
   local temp={party={},version=s.version,map=s.map}
   local _,_,squirtle=Party.giveMon(temp,P.speciesFromNational(7),20)
   squirtle.moves={1};assert(style(squirtle,true,false)=="surf","Water type cannot swim")
   S.ensureGen3DexNav();assert(Bag.has(s.bag,S.gen3DexNavItem,1))
   assert(Items.info(S.gen3DexNavItem).registrability==1)
   local Menu=require("src.ui.game3.bag_menu")
   Menu.show(s.bag,{session=s,pocket="KEY_ITEMS"});U.wait(60)
   for i,row in ipairs(Menu.list("KEY_ITEMS"))do if row.id==S.gen3DexNavItem then Menu.cursor=i end end
   if version=="ruby"or version=="sapphire"then
    -- RS SELECT reorders items; REGISTER sits in the right action column.
    U.tap(game,"a");U.wait(4);U.tap(game,"right");U.tap(game,"a");U.wait(4)
   else U.tap(game,"select");U.wait(3)end
   assert(s.registeredItem==S.gen3DexNavItem,"Native bag DexNav registration failed")
   Menu.close();Stack.clear();Message.close()
   local invoked=false;local before=Use.useField
   Use.useField=function(...)
    local args={...};if args[3]==S.gen3DexNavItem then invoked=true end
    return before(...)
   end
   U.tap(game,"select");U.wait(3);Use.useField=before
   assert(invoked,"SELECT did not dispatch native registered DexNav")
   Message.close();Stack.clear()
   S.set("no_encounters",true)
   local R=require("src.mods.Runtime");local encounter={species="RATTATA",speciesId=P.speciesFromNational(19),level=8}
   S.gen3DexNav(nil,true)
   assert(R.call("encounter.roll",function()return encounter end,{},{})==nil)
   S.gen3DexNav(P.speciesFromNational(386),true)
   assert(R.call("encounter.roll",function()return encounter end,{},{})==encounter,"No Wilds blocked deliberate DexNav search")
   local selected=R.call("encounter.species",function(e)return e end,encounter,{})
   assert(selected.speciesId==P.speciesFromNational(386)and selected.level==8)
   assert(R.call("encounter.roll",function()return encounter end,{},{})==nil,"No Wilds not restored after search")
   S.set("no_encounters",false)
   s.party={};Party.giveMonToPlayer(s,P.speciesFromNational(1),20)
   local mon=s.party[1];mon.moves={33};mon.pp={35}
   assert(Bag.add(s.bag,294,2)) -- TM06 Toxic
   assert(Use.useTm(s,s.bag,294,1),"native TM teaching failed")
   assert(Bag.get(s.bag,294)==2,"TM consumed after successful teaching")
   Bag.remove(s.bag,294,1);assert(Bag.get(s.bag,294)==1,"ordinary bag removal blocked")
   local Learn=require("src.core.game3.battle.learn_move")
   local PartyMenu=require("src.ui.game3.party_menu")
   mon.moves={33};mon.pp={35}
   PartyMenu.show(s.party,s.moveOverlay,{session=s,bag=s.bag,item=294,mode="use"})
   U.wait(60);U.tap(game,"a");U.wait(3)
   assert(P.knowsMove(mon,92)and Bag.get(s.bag,294)==1,"native party TM UI consumed item")
   PartyMenu.close();Stack.clear();Message.close()
   mon.moves={33,45,22,73};mon.pp={35,40,25,10}
   PartyMenu.show(s.party,s.moveOverlay,{session=s,bag=s.bag,item=294,mode="use"})
   U.wait(60);U.tap(game,"a");U.wait(3)
   assert(Learn._onDone,"native replacement callback missing")
   local finished=Learn._onDone
   finished(false);assert(Bag.get(s.bag,294)==1,"cancel consumed TM")
   finished(true);assert(Bag.get(s.bag,294)==1,"replacement consumed TM")
   Learn.reset();PartyMenu.close();Message.close();Stack.clear()
   local done=false
   Message.show("First page.\fSecond page.",function()done=true end)
   assert(Message._page==1 and Message.isWaiting()and not done,"instant text skipped first page")
   Message.advance();Message.tick()
   assert(Message._page==2 and Message.isWaiting()and not done,"second page was skipped")
   Message.advance();assert(done,"message completion lost")
   print("PASS HM ownership/badges, independent travel, registered DexNav, reusable TMs, instant pages")
  else
   if gen==2 then
    game:continueGame(require("src.core.gen2.Save").newGame({playerName="TEST"}));U.wait(30)
    local Mon=require("src.battle.gen2.Mon");local FM=require("src.world.gen2.FieldMoves")
    local mon=Mon.new(game.data,"CATERPIE",20);mon.moves={{id="TACKLE",pp=35}}
    game.save.party={mon}
    assert(not FM.partyMoveUser(game.save.party,"SURF",game.world:fieldContext()))
    local count=0
    for id,def in pairs(game.data.items)do
     if type(def)=="table"and def.teaches and (id:match("^HM_")or def.teaches=="ROCK_SMASH")then
      game.save.inventory[id]=1
      assert(S.ownsFieldMachine(game,def.teaches));count=count+1
      local m,slot=FM.partyMoveUser(game.save.party,def.teaches,game.world:fieldContext())
      assert(m==mon and slot==1,"HM device helper missing")
     end
    end
    assert(count>=8 and #mon.moves==1)
    assert(not FM.surfFromMenu({save=game.save,isFacingWater=true}).ok,"badge bypass")
    local tm;for id,d in pairs(game.data.items)do if id:match("^TM_")and d.teaches then tm=id;break end end
    game.save.inventory[tm]=2;game:consumeItem(tm);assert(game.save.inventory[tm]==2)
    require("src.inventory.Bag").remove(game.save,tm,1);assert(game.save.inventory[tm]==1)
    local travel=game.mods.exports.minimal_cheats.freeFly
    assert(travel.classify(game,mon,"surf",true)==nil)
    mon.moves={{id="SURF",pp=15}};assert(travel.classify(game,mon,"surf",true)=="surf")
    mon.moves={{id="FLY",pp=15}};assert(travel.classify(game,mon,"fly",true)=="air")
    local Typer=require("src.ui.gen2.Typer")
    local t=Typer.new(game);t:start("Instant page");t:tick();assert(t:done())
    assert(game.data.items.DEXNAV.canSelect,"DexNav not registerable")
    print("PASS Gen 2 HM device/badge, TM inventory semantics, travel and instant typer")
   else
    game:startNewGame({intro=false});U.wait(20)
   end
   local TB=require("src.render.TextBox")
   local text=TB.new(game,"First page.\fSecond page.",function()error("page advanced without input")end)
   game.stack:push(text);U.wait(45)
   assert(text.pageIndex==1 and text.waiting,"instant text skipped first page")
   assert(text.noLetterDelay==nil,"temporary text flag leaked")
   game.stack:pop()
   if S.battleTerrain then
    local b={game=game,oppClass="OPP_LORELEI"};assert(S.battleTerrain(b)=="lorelei")
    b.oppClass="OPP_BROCK";assert(S.battleTerrain(b)=="leader")
   end
  end
  assert(#game.mods.errors==0,"mod load error")
  print("SILVERSHADOW QOL PASS "..version)
 end,debug.traceback)
 if not ok then print("FAIL "..tostring(err))end
 love.event.quit(ok and 0 or 1)
end
