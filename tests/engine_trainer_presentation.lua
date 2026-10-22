local U=require("tests.drivers.util")
return function(game)
 local ok,err=xpcall(function()
  local V=require("src.core.GameVersion");local v=V.get();local gen2=V.generation()==2
  local S=game.mods.exports.minimal_cheats.silvershadow
  game.writeSave=function()end
  love.window.setMode(800,600,{resizable=false})
  S.set("modern_battle_hud",true);S.set("follower_mode","trainer")
  local b
  if gen2 then
   game:continueGame(require("src.core.gen2.Save").newGame({playerName="TEST"}));U.wait(30)
   local Mon=require("src.battle.gen2.Mon")
   game.save.party={Mon.new(game.data,"BUTTERFREE",20)}
   assert(game.world:startBattle({trainer={class=1,classId="YOUNGSTER",memberId="JOEY",name="YOUNGSTER JOEY",trainerName="JOEY",className="YOUNGSTER",party={Mon.new(game.data,"RATTATA",4)},baseMoney=12}}))
   for _=1,1500 do
    b=game.stack:top()
    if b and b.screenId=="Gen2BattleState"and b.battle and b.showEnemyTrainer and b.slideFrame>=72 then break end
    U.wait(1)
   end
   assert(b and b.showEnemyTrainer,"trainer intro missing")
   assert(S.battleAssets.trainer(b.enemyTrainerClass,false),"shared trainer mapping missing")
   assert(not S.battleAssets.trainer("RIVAL1",false),"Silver substituted with Blue")
  else
   game:startNewGame({intro=false});U.wait(20)
   game.save.party={require("src.pokemon.Pokemon").new(game.data,"BUTTERFREE",20)}
   b=require("src.battle.BattleState").newTrainer(game,"OPP_YOUNGSTER",1)
   b.onFinish=function()end;game.stack:push(b)
   for _=1,600 do if b.msgPrompt then break end U.wait(1)end
   assert(b.showPlayerBack and b.showEnemyTrainer,"trainer intro missing")
   assert(S.battleAssets.trainer(b.oppClass,false),"trainer mapping missing")
  end
  assert(U.shot(game,os.getenv("SILVERSHADOW_SHOTS").."/"..v.."-trainer-intro.png"))
  if not gen2 then
   for _,line in ipairs(b.shown or {})do
    assert(not S.battleDecodeText(b,line):find("[\128-\255]"),"Latin intro decoded as Japanese aliases")
   end
  end
  local original=b.enemyTrainerTrueColor
  for _=1,1200 do
   if b.phase=="menu"then break end
   U.tap(game,"a");U.wait(2)
  end
  assert(b.phase=="menu","trainer intro did not reach menu")
  assert(b.enemyTrainerTrueColor==original,"draw mutated original trainer palette state")
  assert(U.shot(game,os.getenv("SILVERSHADOW_SHOTS").."/"..v.."-trainer-menu.png"))
  print("SILVERSHADOW TRAINER PASS "..v)
 end,debug.traceback)
 if not ok then print("FAIL "..tostring(err))end
 love.event.quit(ok and 0 or 1)
end
