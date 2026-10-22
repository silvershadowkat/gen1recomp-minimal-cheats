local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    game.writeSave=function()end
    love.window.setMode(1280,960,{resizable=false})
    game:startNewGame({intro=false});U.wait(20)
    local S=game.mods.exports.minimal_cheats.silvershadow
    S.set("modern_battle_hud",true)
    local Mon=require("src.pokemon.Pokemon")
    local Bag=require("src.inventory.Bag")
    local Menu=require("src.ui.BagMenu")
    local Text=require("src.render.TextBox")
    local Choice=require("src.ui.ChoiceBox")
    game.save.party={Mon.new(game.data,"CHARMANDER",20)}
    game.save.inventory={};game.save.bagOrder={};game.save.bagStacks=nil
    local machine
    for id,def in pairs(game.data.items)do
      if def.machine and def.machine.move=="MEGA_PUNCH"then machine=id;break end
    end
    assert(machine,"native Mega Punch TM not found")
    for _,id in ipairs({"POKE_BALL","POTION","MOON_STONE","ANTIDOTE",machine,"TOWN_MAP"})do
      assert(Bag.add(game.save,id,3,game.data),id)
    end
    local start=require("src.ui.StartMenu").new(game)
    local summon,mods
    for i,row in ipairs(start.items)do
      if row.label=="SUMMON"then summon=i elseif row.label=="MODS"then mods=i end
    end
    assert(summon and mods and summon==mods-1,"SUMMON not immediately above MODS")
    game.stack:push(start)
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/blue-start-summon.png"))
    game.stack:pop()
    local list=Menu.new(game);game.stack:push(list)
    assert(list.pocketId=="items" and list.items[1].value=="MOON_STONE")
    U.tap(game,"right")
    assert(list.pocketId=="medicine"and #list.items==3)
    local a,b=list.items[1],list.items[2]
    assert(a.nativeIndex~=1,"test must exercise filtered slot")
    local native=Bag.order(game.save,game.data)
    local ballSlot
    for i,id in ipairs(native)do if id=="POKE_BALL"then ballSlot=i end end
    list.index=1;U.tap(game,"select");U.tap(game,"down");U.tap(game,"a")
    assert(list.items[1].value==b.value and list.items[2].value==a.value,"filtered swap wrong")
    assert(Bag.order(game.save,game.data)[ballSlot]=="POKE_BALL","swap touched another pouch")
    -- Toss through the actual native quantity and confirmation screens.
    list.index=2;local tossId=list.items[2].value;local before=game.save.inventory[tossId]
    U.tap(game,"a");U.tap(game,"down");U.tap(game,"a")
    assert(getmetatable(game.stack:top())==require("src.ui.QuantityBox"),"TOSS quantity lost")
    U.tap(game,"a")
    for _=1,80 do if getmetatable(game.stack:top())==Choice then break end;U.tap(game,"a");U.wait(1)end
    assert(getmetatable(game.stack:top())==Choice,"TOSS confirmation lost")
    U.tap(game,"a");U.wait(20)
    for _=1,80 do if game.stack:top()==list then break end;U.tap(game,"a")end
    assert(game.stack:top()==list and game.save.inventory[tossId]==before-1,"wrong item tossed")
    assert(list.pocketId=="medicine"and #list.items==3,"native refresh lost pocket")
    -- Duplicate stacks use a per-species slot for consumption, not the
    -- inventory-wide index used for swaps or this pouch's displayed index.
    local rows=Bag.rows(game.save,game.data)
    rows[#rows+1]={id="POTION",count=5}
    game.save.bagStacks=game.save.bagStacks or{}
    Bag.setRows(game.save.inventory,game.save.bagOrder,rows,game.data,game.save.bagStacks)
    U.wait(2)
    local firstCount
    for i,row in ipairs(list.items)do
      if row.value=="POTION"and row.slot==1 then firstCount=row.count end
      if row.value=="POTION"and row.slot==2 then list.index=i end
    end
    assert(firstCount and list.items[list.index].slot==2,"second stack setup failed")
    U.tap(game,"a");U.tap(game,"down");U.tap(game,"a");U.tap(game,"a")
    for _=1,80 do if getmetatable(game.stack:top())==Choice then break end;U.tap(game,"a")end
    assert(getmetatable(game.stack:top())==Choice)
    U.tap(game,"a");U.wait(20)
    for _=1,80 do if game.stack:top()==list then break end;U.tap(game,"a")end
    for _,row in ipairs(Bag.rows(game.save,game.data))do
      if row.id=="POTION"then assert(row.count==(row.slot==1 and firstCount or 4),"wrong duplicate stack consumed")end
    end
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/blue-field-pouch.png"))
    U.tap(game,"right");U.tap(game,"right")
    assert(list.pocketId=="machines")
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/blue-machine-pouch.png"))
    U.tap(game,"right")
    assert(list.pocketId=="battle"and #list.items==1 and list.items[1].cancel)
    U.tap(game,"a");assert(game.stack:top()~=list,"empty pouch CANCEL broken")
    local B=require("src.battle.BattleState")
    local battle=B.newWild(game,"RATTATA",15)
    battle.onFinish=function()end;game.overworld:pushBattle(battle)
    for _=1,600 do if battle.phase=="menu"then break end;U.tap(game,"a");U.wait(1)end
    assert(battle.phase=="menu")
    battle.menuIndex=3;U.tap(game,"a");U.wait(40)
    list=game.stack:top()
    assert(list.kind=="bag"and list.pocketId=="balls","battle did not open balls pouch")
    U.tap(game,"left");U.tap(game,"left")
    assert(list.pocketId=="items"and list.items[1].value=="MOON_STONE")
    local count=game.save.inventory.MOON_STONE
    U.tap(game,"a");U.wait(15)
    local text=game.stack:top()
    assert(getmetatable(text)==Text,"Moon Stone message missing")
    assert(S.modernBattleEnabled()and text:isWideBattleLayout(),"item message reverted battle")
    local w,h=text:uiSize();assert(w==256 and h==192,"message resized canvas")
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/blue-moon-stone-message.png"))
    for _=1,80 do if game.stack:top()==list then break end;U.tap(game,"a")end
    assert(game.stack:top()==list and game.save.inventory.MOON_STONE==count,"invalid use consumed item/turn")
    U.tap(game,"right");U.tap(game,"right")
    assert(list.pocketId=="balls" and list.items[1].value=="POKE_BALL")
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/blue-battle-pouch.png"))
    U.tap(game,"b");assert(game.stack:top()==battle,"battle bag B broken")
    -- Modern HUD off keeps the engine's ordinary text geometry.
    S.set("modern_battle_hud",false)
    list=Menu.new(game,{battle=battle});game.stack:push(list)
    U.tap(game,"left");U.tap(game,"left");U.tap(game,"a")
    text=game.stack:top()
    assert(getmetatable(text)==Text and not text:isWideBattleLayout(),"disabled fallback broken")
    print("BAG POCKETS PASS: Start order, six pouches, native swap/toss, empty CANCEL, battle Moon Stone, unchanged inventory, disabled fallback")
  end,debug.traceback)
  if not ok then print(err)end
  love.event.quit(ok and 0 or 1)
end
