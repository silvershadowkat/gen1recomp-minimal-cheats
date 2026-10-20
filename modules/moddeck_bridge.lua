-- A data-only mailbox in this mod's own cache. The running game owns settings;
-- Mod Deck sends one validated compare-and-set request, never save edits/code.
local mod,S=...
if not(mod.cache and mod.cache.read and mod.cache.write)then return end
local Json=require("src.link.Json")
local cache=mod.cache
local STATUS,REQUEST="moddeck/state.json","moddeck/request.json"
local titles={red="Red",blue="Blue",yellow="Yellow",gold="Gold",silver="Silver",
  crystal="Crystal",firered="FireRed",leafgreen="LeafGreen",ruby="Ruby",sapphire="Sapphire",emerald="Emerald"}
local allowed={infinite_hp=true,infinite_pp=true,no_move_drawbacks=true,exp_multiplier=true,
  damage_multiplier=true,always_hit=true,always_crit=true,always_first=true,always_escape=true,
  guaranteed_catch=true,unlimited_balls=true,catch_heal=true,perfect_dvs=true,no_encounters=true,
  lights_on=true,poison_save=true,heal_map_change=true,heal_battle=true,pc_rare_candy=true,
  hm_device=true,reusable_tms=true,all_251_catchable=true,gen3_dex_hunt=true,gen3_no_trade=true,
  instant_text=true,move_boost=true,foot_boost=true,bike_boost=true,surf_boost=true,fly_boost=true,
  fly_trainer_sight=true,fly_story_gates=true,fly_badge_checks=true,fly_badge_check=true}
local categories={"battle","capture","world","pokemon","healing","supplies","movement"}
local previous=Json.decode(cache:read(STATUS)or"",32768)
local serial=type(previous)=="table"and tonumber(previous.serial)or 0
serial=math.floor(math.max(0,math.min(serial or 0,1e12)))
local scope,session,ack,revision=nil,"",nil,0
local checkTime,publishTime=0,0
local definitions,ordered={},{}
for _,category in ipairs(categories)do
  local factory=(S.modDeckMenus or{})[category]
  for _,item in ipairs(factory and factory()or{})do
    if allowed[item.key]and not definitions[item.key]
        and(item.kind=="toggle"or item.kind=="choice")then
      item._modDeckCategory=category
      definitions[item.key]=item;ordered[#ordered+1]=item
    end
  end
end
local function value(item)
  if item.kind=="toggle"then return S.bool(item.key,item.default)end
  return S.allowed(item.key,item.values,item.default)
end
local function activeScope(game)
  if not game then return nil end
  if S.generation==3 then return game.phase=="field"and game.session or nil end
  if not(game.save and (game.overworld or game.world))then return nil end
  for _,state in ipairs(game.stack and game.stack.states or{})do
    if state.screenId=="TitleState"or state.screenId=="Gen2TitleState"then return nil end
  end
  return game.save
end
local function refreshMenus(game)
  for _,state in ipairs(game.stack and game.stack.states or{})do
    for _,row in ipairs(state.items or{})do
      local item=row._silver
      if item and definitions[item.key]then row.right=type(item.right)=="function"and item.right()or item.right end
    end
  end
  if S.refreshModDeckOptions then S.refreshModDeckOptions()end
end
local function apply(game,req)
  if type(req)~="table"or req.schema~=1 or type(req.id)~="string"
      or #req.id>80 or not req.id:match("^[%w%-]+$")then return nil end
  if ack and ack.id==req.id then return false end
  local result={id=req.id,status="rejected",reason="Unknown setting"}
  local item=definitions[req.key]
  if not scope then result.reason="Load a game first"
  elseif req.session~=session or req.game~=S.gameVersion then result.reason="Game or save changed"
  elseif not S.gameplayAllowed()then result.reason="Unavailable during link play"
  elseif item then
    local valid=item.kind=="toggle"and type(req.value)=="boolean"
    if item.kind=="choice"then for _,v in ipairs(item.values)do if v==req.value then valid=true end end end
    if not valid then result.reason="Unsupported value"
    elseif value(item)~=req.expected then result.reason="Setting changed in game; try again"
    else
      S.set(item.key,req.value)
      if item.after then item.after(game,req.value,{footer=""})end
      refreshMenus(game)
      result.status,result.reason="applied",nil
    end
  end
  ack=result
  return true
end
local lastValues={}
local function publish(game)
  local rows={}
  for _,item in ipairs(ordered)do
    local v=value(item)
    if lastValues[item.key]~=v then revision=revision+1;lastValues[item.key]=v end
    rows[#rows+1]={key=item.key,label=item.label or item.text,kind=item.kind,
      category=item._modDeckCategory,value=v,values=item.values}
  end
  local payload={schema=1,modVersion=S.version,serial=serial,session=session,
    game=S.gameVersion,title="Pokémon "..(titles[S.gameVersion]or S.gameVersion),generation=S.generation,
    active=scope~=nil,blocked=scope~=nil and not S.gameplayAllowed(),revision=revision,settings=rows,ack=ack}
  return cache:write(STATUS,Json.encode(payload))
end
local function tick(game,dt,force)
  checkTime=checkTime+(tonumber(dt)or 0)
  publishTime=publishTime+(tonumber(dt)or 0)
  if not force and checkTime<.2 then return end
  checkTime=0
  local current=activeScope(game)
  if current~=scope or session==""then
    scope=current;serial=serial+1;session=S.gameVersion..":"..serial
    ack=nil;lastValues={};revision=0;publishTime=2
  end
  local info=cache:info(REQUEST)
  if info and info.size and info.size<=4096 then
    local request=Json.decode(cache:read(REQUEST)or"",4096)
    if apply(game,request)then publishTime=2 end
    cache:delete(REQUEST)
  elseif info then cache:delete(REQUEST)end
  -- Read current menu values, including changes made outside the overlay.
  for _,item in ipairs(ordered)do if lastValues[item.key]~=value(item)then publishTime=2;break end end
  if force or publishTime>=2 then publish(game);publishTime=0 end
end
S.modDeck={tick=tick,definitions=definitions,statePath=STATUS,requestPath=REQUEST}
local Game=require(S.generation==3 and "src.core.Game3"or S.generation==2 and "src.core.Game2"or"src.core.Game")
local update=Game.update
local failures=0
Game.update=function(self,dt,...)
  if failures<3 then
    local ok,err=pcall(tick,self,dt)
    if not ok then
      failures=failures+1
      mod.log:warn("Mod Deck bridge: %s",tostring(err))
    else failures=0 end
  end
  return update(self,dt,...)
end
