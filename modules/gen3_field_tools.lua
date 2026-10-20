local mod,shared=...
local FM=require("src.core.game3.field_moves")
local P=require("src.core.game3.pokemon")
local Bag=require("src.core.game3.bag")
local Items=require("src.core.game3.items_data")
local Use=require("src.core.game3.item_use")
local Field=require("src.core.game3.field")
local Player=require("src.core.game3.player")
local function owns(move)
  local s=shared.gen3Session();local id=FM.normalizeMoveId(move)
  if not(s and s.bag and id)then return false end
  for item=Items.FIRST_HM,Items.LAST_HM do
    if P.moveFromTmItem(item)==id and Bag.has(s.bag,item,1)then return true end
  end
  return false
end
shared.ownsGen3HM=owns
local user=FM.partyMoveUser
FM.partyMoveUser=function(party,move)
  local mon,index=user(party,move)
  if mon or not shared.gameplayAllowed()or not shared.bool("hm_device",true)or not owns(move)then return mon,index end
  for i,m in ipairs(party or {})do
    if not P.isEgg(m)and(tonumber(m.hp)or 0)>0 then return m,i-1 end
  end
  return nil,6
end
-- RSE's scripted Dive/obstacle prompts query the script VM rather than the
-- contextual FieldMoves helper. Supply the same helper slot after the native
-- check fails; leave learned moves and every subsequent story check intact.
mod.hooks:wrap("script.command",function(next,ctx,op,row)
  local result=next(ctx,op,row)
  if op=="checkpartymove"and shared.gameplayAllowed()and shared.bool("hm_device",true)and owns(row[1])then
    local vm=ctx and ctx.runner
    local Flags=require("src.core.game3.scripting.flags")
    local Ctx=require("src.core.game3.scripting.ctx")
    if vm and Flags.getVar(vm.store,vm.ctx,Ctx.VAR_RESULT)==6 then
      local s=shared.gen3Session();local mon,slot=FM.partyMoveUser(s.party,row[1])
      if mon then
        Flags.setVar(vm.store,vm.ctx,Ctx.VAR_RESULT,slot)
        Flags.setVar(vm.store,vm.ctx,0x8004,P.speciesOf(mon))
      end
    end
  end
  return result
end)
-- Suppress consumption only inside successful TM-teaching callbacks.
-- Ordinary Bag.remove, tossing, giving and PC transfers keep their semantics.
local teaching=0
local function during(fn,...)
  teaching=teaching+1
  local result={pcall(fn,...)};teaching=teaching-1
  if not result[1]then error(result[2],0)end
  return unpack(result,2)
end
local remove,useTm=Bag.remove,Use.useTm
Bag.remove=function(bag,id,n,...)
  if teaching>0 and shared.gameplayAllowed()and shared.bool("reusable_tms",true)
    and Items.isTm(id)and not Items.isHm(id)then return true end
  return remove(bag,id,n,...)
end
Use.useTm=function(...)return during(useTm,...)end
local PartyMenu=require("src.ui.game3.party_menu")
local partyInput=PartyMenu.handleInput
PartyMenu.handleInput=function(...)
  if PartyMenu.mode=="use"and Items.isTm(PartyMenu._item)then return during(partyInput,...)end
  return partyInput(...)
end
local Learn=require("src.core.game3.battle.learn_move")
local begin=Learn.begin
Learn.begin=function(opts,...)
  if teaching>0 and opts and opts.onDone then
    local copy={};for k,v in pairs(opts)do copy[k]=v end
    local done=opts.onDone;copy.onDone=function(...)return during(done,...)end;opts=copy
  end
  return begin(opts,...)
end
function shared.gen3UseHM(move)
  if not shared.bool("hm_device",true)then return false,"HM device is off."end
  if not shared.gameplayAllowed()or not owns(move)then return false,"Obtain this HM first."end
  local s=shared.gen3Session()
  local map=require("src.core.game3.map").currentDef()
  local Space=require("src.core.game3.scripting.space")
  local ctx={party=s.party,session=s,store=Space.store,mapType=map and map.mapType,
    isCave=map and(map.cave==true or map.cave==1),isSurfing=Player.surfing==true}
  local result=FM.fromMenu(move,ctx)
  if not result or not result.ok then return false,result and result.text or "Cannot use that here."end
  require("src.ui.game3.stack").pop("silvershadow_gen3")
  Use.exitMenusToField()
  Field.executeFieldMove(result)
  return true
end
-- Use an additive key item and the engine's normal registration slot.
local dex="SILVERSHADOW_DEXNAV"
local info=Items.info
Items.info=function(id)
  if id==dex then return {id=dex,name="DEXNAV",pocket="KEY_ITEMS",fieldUse="dexnav",
    description="Find an uncaught area Pokemon. Register for SELECT.",registrability=1,importance=2,fieldUseFunc=1,price=0}end
  return info(id)
end
function shared.ensureGen3DexNav()
  local s=shared.gen3Session()
  if s and s.bag and not Bag.has(s.bag,dex,1)then Bag.add(s.bag,dex,1)end
end
local useField=Use.useField
Use.useField=function(s,bag,id,...)
  if id~=dex then return useField(s,bag,id,...)end
  if not shared.gameplayAllowed()or shared.gen3Flying then return false,"dexnav","Cannot use DexNav here."end
  local candidates=shared.gen3LocalSpecies(true)
  if #candidates==0 then
    return false,"dexnav",#shared.gen3LocalSpecies()>0 and "All Pokemon in this area are caught."or"No wild Pokemon found here."
  end
  -- From the Bag, wait for its normal fade/field callback. A registered SELECT
  -- use is already on the field and can begin the native battle immediately.
  if Use.setUpOnFieldCallback(function()shared.gen3DexNav(nil)end)then return true,"on_field",nil end
  if shared.gen3DexNav(nil)then return true,"on_field",nil end
  return false,"dexnav","Cannot use DexNav here."
end
shared.gen3DexNavItem=dex
-- Ruby/Sapphire's SET path normally coerces every item to a ROM number.
-- Keep this mod-owned string key in the same native registration slot.
local RsBag=require("src.ui.game3.rs.bag_menu")
local beforeAction=RsBag.beforeAction
RsBag.beforeAction=function(menu,action,row,...)
  if action=="SET"and row and row.id==dex then
    if menu._session then menu._session.registeredItem=menu._session.registeredItem==dex and 0 or dex end
    menu.mode="list";return true
  end
  return beforeAction(menu,action,row,...)
end
local rsDraw=RsBag.draw
RsBag.draw=function(menu,...)
  local s=menu._session;local unset=s and s.registeredItem==nil
  -- Native RS compares numeric IDs; nil == nil must not mark a custom item
  -- as registered when the registration slot is empty.
  if unset then s.registeredItem=0 end
  local result={pcall(rsDraw,menu,...)}
  if unset then s.registeredItem=nil end
  if not result[1]then error(result[2],0)end
  return unpack(result,2)
end
mod.events:on("map.entered",shared.ensureGen3DexNav)
mod.events:on("save.loaded",shared.ensureGen3DexNav)
