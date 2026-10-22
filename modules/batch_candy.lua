-- Always-on item UI: a batch is sequential native level gains, including
-- learning/evolution at each level. Inventory is charged only after success.
local mod,S=...
local gen=S.generation
local C={};S.batchCandy=C
function C.snapshot(mon)
  local st=mon.stats or mon
  return {level=mon.level,hp=mon.hp,maxHp=gen==3 and mon.maxHp or st.hp or mon.maxHp,
    attack=st.attack,defense=st.defense,speed=st.speed,
    special=st.special,spAttack=st.specialAttack or st.spAttack or st.spAtk,spDefense=st.specialDefense or st.spDefense or st.spDef}
end
function C.limit(mon,count)
  if not mon or mon.isEgg then return 0 end
  local cap=gen==1 and S.extendedLevels and S.extendedLevels.max or 100
  if gen==3 and (mon.hp or 0)<=0 then return 0 end
  return math.max(0,math.min(math.floor(count or 0),cap-(mon.level or 1)))
end
-- The picker is deliberately separate from cheats/settings and Mod Deck.
function C.quantity(game,mon,count,done)
  local max=C.limit(mon,count);if max<1 then return false end
  local q={qty=1,max=max,screenId="SilverCandyQuantity",isOpaque=false,isMenu=true}
  local close
  if gen==3 then
    local Stack=require("src.ui.game3.stack")
    close=function()Stack.pop("silver_candy_quantity")end
    Stack.push("silver_candy_quantity",q,{hideBelow=false,drawUnder=true})
  else
    close=function()if game.stack:top()==q then game.stack:pop()end end
    game.stack:push(q)
  end
  local function input(i)
    local delta=i:wasPressed("up")and 1 or i:wasPressed("down")and -1
      or i:wasPressed("right")and 10 or i:wasPressed("left")and -10
    if delta then q.qty=math.max(1,math.min(q.max,q.qty+delta))
    elseif i:wasPressed("b")then close();done(nil)
    elseif i:wasPressed("a")then close();done(q.qty)end
  end
  q.handleInput=input
  q.update=function()if gen~=3 then input(game.input)end end
  q.draw=function()
    local g=love.graphics;g.push("all");g.setShader()
    if gen==3 then
      local Font=require("src.ui.game3.frlg_font")
      g.setColor(.14,.23,.33,1);g.rectangle("fill",16,30,208,100)
      g.setColor(1,1,1,1);g.rectangle("fill",18,32,204,96)
      Font.draw("How many RARE CANDIES?",26,38)
      Font.draw("Quantity: "..q.qty.." / "..q.max,26,58)
      Font.draw("Lv "..mon.level.." TO "..(mon.level+q.qty),26,78)
      Font.draw("UP/DOWN: 1   LEFT/RIGHT: 10",26,98)
      Font.draw("A: GIVE   B: CANCEL",26,114)
    else
      local Font=require("src.render.Font")
      Font.drawBox(0,3,20,11);g.setColor(0,0,0,1)
      Font.draw("RARE CANDIES?",8,32)
      Font.draw(q.qty.." / "..q.max,8,48)
      Font.draw("Lv "..mon.level.." TO "..(mon.level+q.qty),8,64)
      Font.draw("UP/DN:1 L/R:10",8,80)
      Font.draw("A:GIVE B:CANCEL",8,96)
    end
    g.pop()
  end
  return q
end
-- Public for native-engine regression drivers; adapters below own UI/inventory.
function C.run(mon,qty,adapter,done)
  local before=C.snapshot(mon)
  local count=math.min(math.max(0,math.floor(qty or 0)),C.limit(mon,adapter.count()))
  local used=0
  local function finish()
    local result={before=before,after=C.snapshot(mon),used=used,mon=mon}
    C.lastResult=result
    done(result)
  end
  local step
  step=function()
    if adapter.current then mon=adapter.current()end
    if used>=count or C.limit(mon,adapter.count())<1 or not S.gameplayAllowed()then return finish()end
    local level=mon.level
    local ok,result=adapter.apply()
    if not ok then return finish()end
    assert(mon.level==level+1,"Rare Candy must advance exactly one level")
    adapter.consume();used=used+1
    adapter.after(result,step)
  end
  step()
end
if gen==3 then return end
local Screens=require("src.ui.Screens")
local function summary(game,result,done)
  local screen={isOpaque=true,screenId="SilverCandyGrowth",result=result}
  screen.update=function()
    if game.input:wasPressed("a")or game.input:wasPressed("b")then
      game.stack:pop();done()
    end
  end
  screen.draw=function()
    local Font=require("src.render.Font");local g=love.graphics
    g.push("all");g.setShader();Font.drawBox(0,0,20,18);g.setColor(0,0,0,1)
    Font.draw("USED "..result.used.." CANDIES",8,8)
    Font.draw("Lv "..result.before.level.." TO "..result.after.level,8,24)
    local rows={{"MAX HP","maxHp"},{"ATTACK","attack"},{"DEFENSE","defense"},{"SPEED","speed"}}
    if gen==1 then rows[#rows+1]={"SPECIAL","special"}
    else rows[#rows+1]={"SP.ATK","spAttack"};rows[#rows+1]={"SP.DEF","spDefense"}end
    for i,row in ipairs(rows)do
      local v=result.after[row[2]]or 0;local old=result.before[row[2]]or 0
      local y=32+i*12;local delta=tostring(math.abs(v-old))
      Font.draw(row[1],8,y);Font.draw(tostring(v),112-Font.width(tostring(v)),y)
      local x=152-Font.width(delta);Font.draw(delta,x,y)
      -- The native GB font has no plus glyph; draw its sign on the pixel grid.
      g.rectangle("fill",x-7,y+3,5,1)
      if v>=old then g.rectangle("fill",x-5,y+1,1,5)end
    end
    Font.draw("HP "..result.before.hp.." TO "..result.after.hp,8,116)
    Font.draw("A/B: CONTINUE",8,128);g.pop()
  end
  game.stack:push(screen)
end
local function adapter(game,mon,list)
  local bag=gen==1 and require("src.inventory.Bag")
  local row=list and list.items[list.index]
  local slot=row and row.value=="RARE_CANDY"and row.slot
  local index
  for i,member in ipairs(game.save.party or{})do if member==mon then index=i;break end end
  local a={count=function()return (game.save.inventory or{}).RARE_CANDY or 0 end,
    current=function()
      -- Gen 2 evolution replaces the party record rather than mutating it.
      mon=index and game.save.party[index]or mon
      return mon
    end}
  a.consume=function()
    if gen==1 then bag.remove(game.save,"RARE_CANDY",1,game.data,slot)
    else game:consumeItem("RARE_CANDY")end
  end
  a.apply=function()
    if gen==2 then
      local result=require("src.core.gen2.ItemEffects").useOnMon("RARE_CANDY",mon,game.data)
      return result.used,result
    end
    local status,_,extra=require("src.inventory.ItemEffects").use(game.data,game.save,"RARE_CANDY",mon)
    return status=="consumed",extra
  end
  a.after=function(result,done)
    if gen==2 then return game:afterRareCandy(mon,result,done)end
    local Evolution=require("src.pokemon.Evolution")
    -- Same per-level learning routine used by the native evolution flow.
    Evolution.learnEvolutionMoves(game,mon,function()
      local target,evo=Evolution.pendingFor(game,mon,{kind="levelup"})
      if target then Evolution.evolve(game,mon,target,done,evo and evo.method)
      else done()end
    end)
  end
  return a
end
C.adapter=adapter
if gen==1 then
  mod.hooks:wrap("item.use",function(next,game,battle,id,mon,list,moveIndex,picker)
    if id~="RARE_CANDY"or battle or not mon or not S.gameplayAllowed()then
      return next(game,battle,id,mon,list,moveIndex,picker)
    end
    local a=adapter(game,mon,list)
    if not C.quantity(game,mon,a.count(),function(qty)
      if not qty then return end
      if qty==1 then return next(game,battle,id,mon,list,moveIndex,picker)end
      C.run(mon,qty,a,function(result)
        summary(game,result,function()
          if picker and game.stack:top()==picker then game.stack:pop()end
        end)
      end)
    end)then return next(game,battle,id,mon,list,moveIndex,picker)end
  end)
else
  local Game=require("src.core.Game2")
  local original=Game.usePartyItem
  Game.usePartyItem=function(game,id,...)
    if id~="RARE_CANDY"or not S.gameplayAllowed()then return original(game,id,...)end
    if #(game.save.party or{})==0 then return original(game,id,...)end
    local picker
    picker=Screens.push(game,"Gen2PartyMenu",{prompt="useItem",
      onCancel=function()game.stack:pop()end,
      onChoose=function(_,mon)
        local a=adapter(game,mon)
        if not C.quantity(game,mon,a.count(),function(qty)
          if not qty then return end
          C.run(mon,qty,a,function(result)
            summary(game,result,function()if game.stack:top()==picker then game.stack:pop()end end)
          end)
        end)then game:say("It won't have\nany effect.")end
      end})
  end
end
