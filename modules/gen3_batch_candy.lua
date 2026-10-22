local _,S=...
if S.generation~=3 then return end
local C=S.batchCandy
local P=require("src.core.game3.pokemon")
local Party=require("src.ui.game3.party_menu")
local Bag=require("src.core.game3.bag")
local Items=require("src.core.game3.items_data")
local ItemUse=require("src.core.game3.item_use")
local Learn=require("src.core.game3.battle.learn_move")
local Evolution=require("src.core.game3.evolution")
local Scene=require("src.ui.game3.evolution_scene")
-- Ruby/Sapphire do not provide the FRLG stat-name table used by the common
-- party growth painter. Give batches one explicit, bounded layout in all five
-- games, retaining the native two-page input and each game's imported font.
local draw=Party.draw
Party.draw=function(...)
  local result=Party._silverCandyGrowth
  if Party.mode~="stat_growth"or not result then return draw(...)end
  Party.mode="silver_candy_busy"
  local ok,err=pcall(draw,...)
  Party.mode="stat_growth"
  if not ok then error(err,0)end
  local g=love.graphics
  local Window=require("src.ui.game3.window")
  local Font=require("src.ui.game3.frlg_font")
  g.push("all")
  Window.stdFrame(Window.template(17,1,12,11))
  local rows={{"MAX HP","maxHp"},{"ATTACK","atk"},{"DEFENSE","def"},
    {"SP. ATK","spa"},{"SP. DEF","spd"},{"SPEED","spe"}}
  for i,row in ipairs(rows)do
    local value=(Party._statGrowthNew or{})[row[2]]or 0
    if Party._statGrowthPage==1 then value=value-((Party._statGrowthOld or{})[row[2]]or 0)end
    local text=Party._statGrowthPage==1 and string.format("%+d",value)or tostring(value)
    Font.draw(row[1],138,10+(i-1)*14)
    Font.draw(text,230-Font.measure(text),10+(i-1)*14)
  end
  Window.stdFrame(Window.template(1,15,28,4))
  Font.draw(Font.wrap(Party._messageText or"",216),14,124,{maxWidth=216,linePitch=15})
  g.pop()
end
local function statValues(mon)
  return {maxHp=mon.maxHp,atk=mon.attack,def=mon.defense,spe=mon.speed,spa=mon.spAtk,spd=mon.spDef}
end
local function adapter(mon,session,bag)
  return {
    count=function()return Bag.get(bag,"RARE_CANDY")end,
    apply=function()
      local ok=ItemUse.useRareCandy(session,mon)
      if ok then
        -- Candy sets experience to the new level's threshold, like the ROM.
        mon.exp=require("src.core.game3.battle.experience").expForLevel(mon,mon.level)
        require("src.core.game3.quest_log_recorder").event(session,"UsedItemOnMonAtThisLocation",
          {Items.displayName("RARE_CANDY"),P.displayMonName(mon)})
      end
      return ok
    end,
    consume=function()assert(Bag.remove(bag,"RARE_CANDY",1),"Rare Candy disappeared")end,
    after=function(_,done)
      local function evolve()
        local target=Evolution.levelTarget(mon,session)
        if not target then return done()end
        Scene.start(mon,target,{session=session,bag=bag,canStop=true,
          savedSong=require("src.core.game3.audio")._mapSong,
          onDone=function()
            Party.reloadSprites();Party.mode="silver_candy_busy";done()
          end})
      end
      -- The engine queue includes the current species' moves at this exact
      -- level. Evolving now changes which learnset the next candy reads.
      Learn.beginQueue(mon,{mon.level},{displayName=P.displayMonName(mon),
        pushMsg=function(text,cb)Party.showMessage(text,cb)end,
        askYesNo=function(a,b)
          local cb=type(a)=="function"and a or b
          Party.showYesNo(type(a)=="string"and a or Party._messageText or"",cb)
        end,
        askForget=function(names,cb)
          Party.showForgetPrompt("Which move should be forgotten?",names,cb)
        end,
        onDone=evolve})
    end,
  }
end
C.gen3Adapter=adapter
local input=Party.handleInput
Party.handleInput=function(i)
  if Party.mode~="use"or Party._onSelect or Party.isPokedude()
      or Items.toNumericId(Party._item)~=68 or not i:wasPressed("a")
      or not S.gameplayAllowed()then return input(i)end
  local mon=(Party._party or{})[Party.cursor]
  local bag,session=Party._bag,Party._session
  if C.limit(mon,Bag.get(bag,"RARE_CANDY"))<1 then return input(i)end
  local slot=Party.cursor
  C.quantity(S.game,mon,Bag.get(bag,"RARE_CANDY"),function(qty)
    if not qty then return end
    local old=statValues(mon)
    Party.mode="silver_candy_busy"
    C.run(mon,qty,adapter(mon,session,bag),function(result)
      local current=statValues(mon)
      local text=P.displayMonName(mon).." grew from Lv "..result.before.level.." to Lv "..mon.level.."!\n"
        .."Used "..result.used.." RARE CANDIES.\nHP: "..result.before.hp.." -> "..mon.hp
      local function finish()
        Party._silverCandyGrowth=nil
        if Bag.get(bag,"RARE_CANDY")>0 then Party.mode="use"else Party.close()end
      end
      local function growth()
        Party.showMessage(text,function()
          Party._messageText=result.used.." RARE CANDIES: Lv "..result.before.level.." to "..mon.level.."."
          Party._silverCandyGrowth=result
          Party.showStatGrowth(mon,old,current,finish)
        end)
      end
      if mon.hp~=result.before.hp then Party.startHpAnim(slot,result.before.hp,mon.hp,mon.maxHp,growth)
      else growth()end
    end)
  end)
end
