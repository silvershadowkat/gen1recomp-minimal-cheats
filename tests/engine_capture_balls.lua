local U=require("tests.drivers.util")
return function(game)
  local ok,err=xpcall(function()
    local V=require("src.core.GameVersion")
    local gen2=V.generation()==2
    local S=assert(game.mods.exports.minimal_cheats).silvershadow
    game.writeSave=function()end
    love.window.setMode(800,600,{resizable=false})
    S.set("modern_battle_hud",true)
    S.set("guaranteed_catch",true)
    S.set("infinite_hp",true)
    local b
    if gen2 then
      game:continueGame(require("src.core.gen2.Save").newGame({playerName="TEST"}));U.wait(20)
      local Mon=require("src.battle.gen2.Mon")
      game.save.party={Mon.new(game.data,"BUTTERFREE",20)}
      assert(game.world:startBattle({wild=Mon.new(game.data,"RATTATA",3)}))
      for _=1,600 do
        b=game.stack:top()
        if b and b.screenId=="Gen2BattleState"and b.battle then break end
        U.wait(1)
      end
    else
      game:startNewGame({intro=false});U.wait(20)
      game.save.party={require("src.pokemon.Pokemon").new(game.data,"BUTTERFREE",20)}
      b=require("src.battle.BattleState").newWild(game,"RATTATA",3)
      b.onFinish=function()end
      game.overworld:pushBattle(b)
    end
    assert(b,"battle missing")
    for _=1,600 do
      if b.phase=="menu"then break end
      U.tap(game,"a");U.wait(1)
    end
    assert(b.phase=="menu","battle did not settle")
    -- Verify each imported ball column, and preserve Gen 2 exclusive balls.
    for i,item in ipairs({"POKE_BALL","GREAT_BALL","SAFARI_BALL","ULTRA_BALL","MASTER_BALL"})do
      local img,q=S.battleAssets.captureBall(item,0)
      assert(img and q,"missing ball art "..item)
      local x,y,w,h=q:getViewport()
      assert(x==(i-1)*16 and y==0 and w==16 and h==16,"wrong ball column")
    end
    assert(S.battleAssets.captureBall("LOVE_BALL",0)==nil,"invented Gen 3 Love Ball")
    local selected=os.getenv("SILVERSHADOW_TEST_BALL")or"GREAT_BALL"
    local seen={}
    local count,last=0
    local draw=S.captureBalls.draw
    S.captureBalls.draw=function(item,p)
      assert(item==selected,"wrong selected ball")
      count=count+1;last={x=p.x,y=p.y,frame=p.frame,tilt=p.tilt};seen[p.tilt]=true
      return draw(item,p)
    end
    S.set("guaranteed_catch",true)
    if gen2 then
      b:useItem(selected)
      assert(b.ballThrow and b.ballThrow.caught,"test catch was not guaranteed")
    else
      b.phase="messages";b.afterQueue="menu"
      b:throwBall(selected)
    end
    for _=1,600 do
      U.wait(1)
      if count>0 then break end
      if not b.anim and not(gen2 and b.anim or b.animPlayer and b.animPlayer.active)then U.tap(game,"a")end
    end
    assert(count>0,"native throw never used colored artwork")
    -- Let the actual shake chain reach its held caught pose before taking
    -- the screenshot; the throw frame alone hid the original outline defect.
    for _=1,900 do
      if (gen2 and b.ballThrow and b.ballThrow.wobble>=4 and (not b.anim or b.anim:done()))
          or (not gen2 and b.lockedBall)then break end
      U.wait(1)
    end
    if not gen2 then assert(b.lockedBall,"caught ball was not retained")end
    assert(U.still(game,os.getenv("SILVERSHADOW_SHOTS").."/"..V.get().."-caught-"..selected:lower()..".png"))
    assert(last and last.x and last.y,"native OAM position missing")
    if gen2 then
      for _=1,900 do if not b.anim or b.anim:done()then break end;U.wait(1)end
      assert((not b.anim or b.anim:done())and b.ballThrow.wobble>=4,"native caught shake sequence did not finish: anim="
        ..tostring(b.anim~=nil)..", wobble="..tostring(b.ballThrow.wobble)..", phase="..tostring(b.phase))
    end
    for _=1,900 do
      if #game.save.party>1 then break end
      U.tap(game,"a");U.wait(1)
    end
    assert(#game.save.party==2,"native capture did not add caught Pokemon: "..tostring(b.phase).." / "..tostring(b.result))
    assert(#game.mods.errors==0,"mod runtime error")
    print("CAPTURE PASS "..V.get().." "..selected..": held caught pose; native catch completes; tilts="
      ..tostring(seen[-1]).."/"..tostring(seen[0]).."/"..tostring(seen[1]))
  end,debug.traceback)
  if not ok then print("FAIL "..tostring(err))end
  love.event.quit(ok and 0 or 1)
end
