local mod,shared=...
local FM=require("src.world.gen2.FieldMoves")
local Game=require("src.core.Game2")
local supported={CUT=true,FLY=true,SURF=true,STRENGTH=true,FLASH=true,
  WHIRLPOOL=true,WATERFALL=true,ROCK_SMASH=true}
local function owns(game,move)
  if not supported[move]or not(game and game.save and game.data)then return false end
  for id,n in pairs(game.save.inventory or {})do
    local def=game.data.items[id]
    if tonumber(n)and n>0 and type(def)=="table"and def.teaches==move then return true end
  end
  return false
end
shared.ownsFieldMachine=owns
mod.hooks:wrap("fieldmove.eligibility",function(next,move,ctx)
  local mon,index=next(move,ctx)
  if mon or not shared.gameplayAllowed()or not shared.bool("hm_device",true)or not owns(shared.game,move)then return mon,index end
  for i,m in ipairs(ctx and ctx.party or {})do
    if not m.egg and(m.hp or 0)>0 then return m,i end
  end
end)
local consume=Game.consumeItem
Game.consumeItem=function(self,id,...)
  local d=self.data and self.data.items[id]
  if shared.gameplayAllowed()and shared.bool("reusable_tms",true)and tostring(id):match("^TM_")and d and d.teaches then return end
  return consume(self,id,...)
end
shared.registerStartItem("hm_device",15,function(game)
  if not shared.gameplayAllowed()or not shared.bool("hm_device",true)then return end
  return {label="HM TOOLS",onSelect=function()
    local rows={}
    for _,move in ipairs({"FLASH","FLY","CUT","SURF","STRENGTH","ROCK_SMASH","WHIRLPOOL","WATERFALL"})do
      if owns(game,move)then rows[#rows+1]={label=move,move=move}end
    end
    if #rows==0 then rows={{label="NO FIELD MACHINES"}}end
    game.stack:push(mod.ui.ListMenu.new(game,"HM TOOLS",rows,{rows=6,onChoose=function(row)
      if not row.move then return end
      local world=game.world
      while game.stack:top()and game.stack:top()~=world do game.stack:pop()end
      world:useFieldMove(row.move,FM.partyMoveUser(game.save.party,row.move,world:fieldContext()))
    end}))
  end}
end)
