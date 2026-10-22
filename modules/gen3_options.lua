local mod, shared = ...
local List = require("src.ui.game3.list_menu")
local Window = require("src.ui.game3.window")
local Font = require("src.ui.game3.frlg_font")
local Stack = require("src.ui.game3.stack")
local id="silvershadow_gen3"
local menu={isMenu=true}
local pages={}
local function toggle(label,key,default)
  return {text=label,key=key,kind="toggle",default=default,value=function() return shared.bool(key,default) and "ON" or "OFF" end,
    run=function() shared.set(key,not shared.bool(key,default)) end}
end
local function choice(label,key,values,default)
  return {text=label,key=key,kind="choice",values=values,default=default,value=function() return tostring(shared.allowed(key,values,default)):upper() end,
    run=function() shared.cycle(key,values,default) end}
end
local function action(label,fn) return {text=label,run=fn} end
local function typedAction(label,fn,typ)
  local row=action(label,fn)
  local color=shared.moveTypeColor(typ)
  if color then
    row.colors={}
    for k,v in pairs(Font.COLOR.NORMAL)do row.colors[k]=v end
    row.colors.fg=color
  end
  return row
end
local show
local function submenu(label,fn) return action(label,function() show(label,fn()) end) end
local function refresh()
  for _,row in ipairs(menu.list.items) do row.label=row.text .. (row.value and (": "..row.value()) or "") end
end
local function back()
  table.remove(pages)
  if #pages==0 then Stack.pop(id); return end
  menu.list=pages[#pages].list; refresh()
end
show=function(title,rows,opts)
  local list=List.new({template=Window.template(1,3,28,14),items=rows,maxShowed=7,
    rowHeight=16,scrollMultiple="lr",onSelect=function(row) row.run(); refresh() end,onCancel=back})
  pages[#pages+1]={title=title,list=list,opts=opts}; menu.list=list; refresh()
  Stack.push(id,menu,{hideBelow=true,fullscreen=true})
end
function menu.handleInput(input)
  local page=pages[#pages]
  if page and page.opts and page.opts.switch and input:wasPressed("select") then page.opts.switch();return end
  menu.list:handleInput(input)
end
function menu.update(dt) menu.list:update(dt) end
function menu.draw()
  love.graphics.clear(0.08,0.12,0.18,1)
  Font.draw(pages[#pages].title,12,2)
  menu.list:draw()
  Font.draw(pages[#pages].opts and "SELECT: POOL / ALL  B: BACK" or "A: CHANGE / OPEN   B: BACK",8,144)
end
local function battle()
  return {
    toggle("INSTANT TEXT","instant_text",true),
    toggle("4:3 BATTLE VIEW","modern_battle_hud",true),
    toggle("MOVE TYPE INFO","battle_move_info",true),
    choice("EXP MULT", "exp_multiplier",shared.EXP_MULTIPLIERS,1),
    choice("DAMAGE", "damage_multiplier",shared.DAMAGE_MODES,1),
    toggle("INFINITE HP","infinite_hp",false),toggle("INFINITE PP","infinite_pp",false),
    toggle("NO BALL LOSS","unlimited_balls",false),toggle("ALWAYS HIT","always_hit",false),
    toggle("ALWAYS CRIT","always_crit",false),toggle("MOVE FIRST","always_first",false),
    toggle("ALWAYS ESCAPE","always_escape",false),toggle("GUARANTEED CATCH","guaranteed_catch",false),
    toggle("NO WILD ENCOUNTERS","no_encounters",false),
  }
end
local function healing()
  return {action("HEAL PARTY NOW",shared.healParty),
    toggle("HEAL AFTER BATTLE","heal_battle",false),toggle("HEAL ON MAP CHANGE","heal_map_change",false),
    toggle("HEAL NEW CATCHES","catch_heal",false),toggle("CATCH PERFECT IVS","perfect_dvs",false),
    action("99 RARE CANDIES",shared.gen3Candy),action("MAX MONEY",shared.gen3MaxMoney),action("MAX COINS",shared.maxCoins),
    action("PERFECT PARTY IVS",function()
      local s=shared.gen3Session(); for _,mon in ipairs(s and s.party or {}) do shared.gen3Perfect(mon) end
    end)}
end
local function movement()
  return {action("TAKE OFF / LAND",shared.gen3ToggleFly),action("RETURN TO GROUND",shared.gen3ReturnToGround),
    toggle("HM DEVICE","hm_device",true),
    toggle("BADGE / FLY CHECK","fly_badge_check",true),toggle("STORY GATES","fly_story_gates",true),
    choice("SPEED MULT","move_boost",shared.MOVE_MULTIPLIERS,2),
    choice("FOOT BOOST","foot_boost",shared.BOOST_STATES,"ON"),
    choice("BIKE BOOST","bike_boost",shared.BOOST_STATES,"OFF"),
    choice("SURF BOOST","surf_boost",shared.BOOST_STATES,"OFF"),
    choice("FLY HEIGHT","fly_height",shared.FLY_HEIGHTS,"MED")}
end
local function fieldTools()
  local rows={toggle("HM DEVICE","hm_device",true),toggle("REUSABLE TMS","reusable_tms",true)}
  for _,move in ipairs({"FLASH","FLY"})do
    if shared.ownsGen3HM(move)then rows[#rows+1]=action(move,function()
      local ok,msg=shared.gen3UseHM(move);if not ok then shared.gen3Message(msg)end
    end)end
  end
  rows[#rows+1]=action("REGISTER DEXNAV ON SELECT",function()
    shared.ensureGen3DexNav();shared.gen3Session().registeredItem=shared.gen3DexNavItem
  end)
  return rows
end
local function followers()
  return {choice("MODE","follower_mode",{"trainer","pokemon"},"trainer"),
    choice("FOLLOWERS","follower_count",{0,1,2,3,4,5,6},1),
    toggle("TRAINER FOLLOWS","trainer_follows",false)}
end
local Pokemon=require("src.core.game3.pokemon")
local Party=require("src.core.game3.party")
local Experience=require("src.core.game3.battle.experience")
local function editNumber(label,get,set,values)
  return {text=label,value=function()return tostring(get())end,run=function()
    if not shared.gameplayAllowed() then return end
    local old=get();local new=values[1]
    for i,v in ipairs(values) do if v==old then new=values[i%#values+1];break end end
    set(new)
  end}
end
local function stats(mon,kind)
  local rows={}
  for _,key in ipairs({"hp","atk","def","spe","spa","spd"}) do
    rows[#rows+1]=editNumber(key:upper(),function()return (mon[kind] or {})[key] or 0 end,function(value)
      mon[kind]=mon[kind] or {}
      if kind=="evs" then
        local used=0;for _,k in ipairs({"hp","atk","def","spe","spa","spd"}) do
          if k~=key then used=used+(tonumber(mon.evs[k]) or 0) end
        end
        value=math.min(value,math.max(0,510-used))
      end
      mon[kind][key]=value;Pokemon.applyStats(mon,shared.gen3Session())
    end,kind=="ivs" and {0,15,30,31} or {0,6,128,252,255})
  end
  return rows
end
local function openMovePicker(mon,slot)
  local base=#pages
  local tools=shared.gen3Moves
  local openPool,openAll,opts
  local function reset() while #pages>base do table.remove(pages)end end
  local function rowsFor(ids)
    local rows={}
    for _,num in ipairs(ids)do
      local move=num
      local moveDef=Pokemon.battleMove(move)
      rows[#rows+1]=typedAction(Pokemon.moveName(move),function()
        local def=Pokemon.battleMove(move)
        local branch,group=tools.branch(move)
        show(Pokemon.moveName(move),{
          typedAction(branch:upper().." / "..group,function()end,def.type),
          action("POWER "..tostring(def.power).."  ACC "..tostring(def.accuracy),function()end),
          action("PP "..tostring(def.pp),function()end),
          action("TEACH TO SLOT "..slot,function()
            if tools.teach(mon,slot,move)then
              reset();menu.list=pages[#pages].list;refresh()
            end
          end)},opts)
      end,moveDef and moveDef.type)
    end
    if #rows==0 then rows[1]=action("NO MOVES IN THIS GROUP",function()end)end
    return rows
  end
  openPool=function()
    reset();opts={switch=function()openAll()end}
    show("ELIGIBLE THROUGH LV "..mon.level,rowsFor(tools.eligible(mon)),opts)
  end
  openAll=function()
    reset();opts={switch=function()openPool()end}
    local sections={}
    for _,section in ipairs({"physical","special","status"})do
      local key=section
      sections[#sections+1]=action(section:upper(),function()
        local groups={}
        for _,group in ipairs(tools.groups[key])do
          local name=group
          groups[#groups+1]=typedAction(name,function()show(name,rowsFor(tools.catalog(key,name)),opts)end,name)
        end
        show(key:upper(),groups,opts)
      end)
    end
    show("ALL MOVES: CATEGORIES",sections,opts)
  end
  openPool()
end
local function pokemonEditor(mon)
  local rows={editNumber("LEVEL",function()return mon.level end,function(level)
    mon.level=level;mon.exp=Experience.expForLevel(mon,level)
    Pokemon.applyStats(mon,shared.gen3Session());Party.healAll({mon})
  end,{5,10,20,30,40,50,60,70,80,90,100}),
    action("HEAL",function()if shared.gameplayAllowed()then Party.healAll({mon})end end),
    action("PERFECT IVS",function()shared.gen3Perfect(mon)end),
    submenu("IV EDITOR",function()return stats(mon,"ivs")end),
    submenu("EV EDITOR",function()return stats(mon,"evs")end)}
  for slot=1,4 do
    rows[#rows+1]=action("MOVE SLOT "..slot,function()openMovePicker(mon,slot)end)
  end
  return rows
end
local function partyEditor()
  local rows={};local s=shared.gen3Session()
  for i,mon in ipairs(s and s.party or {}) do
    rows[#rows+1]=submenu(i.." "..Pokemon.name(Pokemon.speciesOf(mon)),function()return pokemonEditor(mon)end)
  end
  return rows
end
local function summon()
  local rows={}
  for nat=1,shared.gen3CollectionLimit() do
    local species=Pokemon.speciesFromNational(nat)
    if species then rows[#rows+1]=action(string.format("%03d %s",nat,Pokemon.name(species)),function()
      if not shared.gameplayAllowed() or not shared.gen3CollectionAllows(species) then return end
      if shared.gen3Summon(species)then pages={}end
    end)end
  end
  return rows
end
local function itemPicker()
  local Items=require("src.core.game3.items_data");local Bag=require("src.core.game3.bag")
  Items.ensureLoaded();local rows={}
  for n=1,376 do
    local info=Items.info(n)
    if info and info.name and info.pocket~="KEY_ITEMS" then
      local num=n
      rows[#rows+1]=action(info.name,function()
        if not shared.gameplayAllowed() then return end
        local s=shared.gen3Session();local needed=math.max(0,99-Bag.get(s.bag,num))
        if needed>0 and not Bag.add(s.bag,num,needed) then shared.gen3Message("No room in this bag pocket.")end
      end)
    end
  end
  return rows
end
local function dexPicker(species)
  local rows={}
  for _,num in ipairs(species) do
    local target=num
    rows[#rows+1]=action((shared.gen3Owned(target) and "* " or "  ")..Pokemon.name(target),function()
      if shared.gen3DexNav(target) then pages={};Stack.pop(id) end
    end)
  end
  if #rows==0 then rows[1]=action("NO MATCHING POKEMON",function()end) end
  return rows
end
local function collection()
  return {toggle("PREFER UNCAUGHT AREA","gen3_dex_hunt",true),
    toggle("NO TRADE EVOLUTIONS","gen3_no_trade",true),
    submenu("AREA DEXNAV",function()return dexPicker(shared.gen3LocalSpecies())end),
    submenu("UNCAUGHT AREA",function()return dexPicker(shared.gen3LocalSpecies(true))end)}
end
shared.modDeckMenus={battle=battle,healing=healing,movement=movement,pokemon=fieldTools,capture=collection}
shared.refreshModDeckOptions=function()if menu.list then refresh()end end
function shared.openGen3Options()
  shared.ensureGen3DexNav()
  pages={}
  show("SILVERSHADOW",{submenu("BATTLE CHEATS",battle),submenu("HEALING / ITEMS",healing),
    submenu("MOVEMENT / FREE FLY",movement),submenu("FOLLOWERS",followers),submenu("DEXNAV / COLLECTION",collection),
    submenu("PARTY EDITOR",partyEditor),submenu("SUMMON POKEMON",summon),
    submenu("ITEMS / TMS",itemPicker),action("POKEMON PC",function()
      if shared.gameplayAllowed() then require("src.ui.game3.pc_menu").show({
        session=shared.gen3Session(),game=shared.game,startMode="storage"}) end
    end),submenu("FIELD TOOLS / QOL",fieldTools)})
end
mod.hooks:wrap("ui.start_menu.items",function(next,game,items,...)
  items=next(game,items,...)
  table.insert(items,1,{id="silvershadow",label="SILVERSHADOW",onSelect=shared.openGen3Options})
  return items
end)
shared.gen3Menu=menu
