local mod,S=...
local SCREEN="SilverShadowGen2Summon"
local function level(game)
  for _,mon in ipairs(game.save and game.save.party or {})do
    if (tonumber(mon.hp)or 0)>0 and not mon.isEgg then
      return math.max(1,math.min(100,tonumber(mon.level)or 5))
    end
  end
end
function S.gen2Summon(game,species)
  local def=game.data and game.data.pokemon and game.data.pokemon[species]
  local lv=level(game)
  if not def or not def.dex or def.dex>251 or not lv or not S.gameplayAllowed()
      or not game.world or game.world.battleActive
      or (mod.exports.freeFly and mod.exports.freeFly.isFlying())then return false end
  return mod.world:queueScript({{"start_battle","wild",species,lv}})
end
mod.content.screens:register(SCREEN,{
  new=function(game)
    local rows={}
    for species,def in pairs(game.data.pokemon or {})do
      if def.dex and def.dex>=1 and def.dex<=251 then
        rows[#rows+1]={label=string.format("%03d %s",def.dex,def.name or species),
          species=species,dex=def.dex}
      end
    end
    table.sort(rows,function(a,b)return a.dex<b.dex end)
    return mod.ui.ListMenu.new(game,"SUMMON POKEMON",rows,{
      rows=6,wrap=true,footer="A:BATTLE  B:BACK",
      onChoose=function(row)
        if not level(game)then return end
        game.stack:pop()
        local top=game.stack:top()
        if top and getmetatable(top)==require("src.ui.gen2.StartMenu")then top:close()end
        local ok=S.gen2Summon(game,row.species)
        if not ok then mod.world:queueScript({{"text","Cannot summon here."}})end
      end,
    })
  end,
})
S.registerStartItem("summon",20,function(game)
  return {label="SUMMON",onSelect=function()mod.ui.push(game,SCREEN)end}
end)
