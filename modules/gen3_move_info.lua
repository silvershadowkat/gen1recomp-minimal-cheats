local mod,shared=...
local Types=require('src.core.game3.battle.types')
local Moves=require('src.core.game3.battle.moves')
local Damage=require('src.core.game3.battle.damage')
local Rules=require('src.core.game3.battle.rules')
local Abilities=require('src.core.game3.battle.adapter').ABILITY_BY_ID
local colors={
 [0]={.35,.35,.30,1},[1]={.65,.18,.15,1},[2]={.40,.32,.69,1},
 [3]={.51,.23,.60,1},[4]={.55,.35,.12,1},[5]={.49,.40,.17,1},
 [6]={.36,.46,.07,1},[7]={.36,.25,.52,1},[8]={.28,.44,.58,1},
 [10]={.74,.23,.10,1},[11]={.13,.35,.72,1},[12]={.21,.48,.15,1},
 [13]={.57,.43,.02,1},[14]={.70,.20,.46,1},[15]={.10,.47,.50,1},
 [16]={.36,.20,.73,1},[17]={.32,.24,.20,1},
}
local function ability(b)
  local a=b and (b.ability or b.mon and (b.mon.ability or b.mon.abilityId))
  return Abilities[tonumber(a)]or a
end
local function info(st,attacker,slot,target)
  local mon=attacker and attacker.mon
  local mv=mon and mon.moves and mon.moves[slot]
  if not mv or mv==0 or mv==''then return end
  local def=Moves.get(mv)
  local typ=mon.moveTypes and mon.moveTypes[slot]or def.type
  if not(mon.moveTypes and mon.moveTypes[slot]~=nil)then
    if def.id=='HIDDEN_POWER'then local p;p,typ=Damage.hiddenPower(mon)
    elseif def.id=='WEATHER_BALL'then
      local weather=Rules.weather.kind(st and st.weather)
      for _,b in pairs(st and st.battlers or {attacker,st and st.enemy})do
        local a=ability(b);if a=='CLOUD_NINE'or a=='AIR_LOCK'then weather=nil end
      end
      typ=({RAIN=11,SAND=5,SUN=10,HAIL=15})[weather]or 0
    end
  end
  local effect
  if (def.power or 0)==0 then effect='STATUS'
  elseif def.id=='SEISMIC_TOSS'or def.id=='NIGHT_SHADE'or def.id=='DRAGON_RAGE'
    or def.id=='SONICBOOM'or def.id=='SUPER_FANG'or def.id=='PSYWAVE'
    or def.id=='COUNTER'or def.id=='MIRROR_COAT'or def.id=='BIDE'
    or def.id=='FISSURE'or def.id=='GUILLOTINE'or def.id=='HORN_DRILL'or def.id=='SHEER_COLD'
    then effect='SPECIAL'
  end
  local function matchup(b)
    if not b then return end
    local t=b.expTransform or b
    local _,_,n=Types.typeCalc(typ,t.type1 or b.type1,t.type2 or b.type2,nil,b.expIdentified)
    local a=ability(b)
    if a=='LEVITATE'and typ==4 or a=='FLASH_FIRE'and typ==10
      or a=='WATER_ABSORB'and typ==11 or a=='VOLT_ABSORB'and typ==13
      or a=='WONDER_GUARD'and n<=1 then return 'IMMUNE'end
    return 'TYPE '..(n==.25 and '1/4'or n==.5 and '1/2'or tostring(n):gsub('%.0$',''))..'x'
  end
  if not effect then
    if not(st and st.double)then effect=matchup(st and st.enemy)
    elseif target~=nil then effect=matchup(st.battlers and st.battlers[target])
    elseif def.target==8 or def.target==32 or def.target==4 then
      for _,id in ipairs(def.target==32 and {0,1,2,3}or {1,3})do
        local b=st.battlers and st.battlers[id]
        if b and b~=attacker and not(st.absent and st.absent[id])and(b.mon.hp or 0)>0 then
          local e=matchup(b)
          if effect and effect~=e then effect='VARIES';break end
          effect=e
        end
      end
    else effect='PICK FOE'end
  end
  return {type=typ,color=colors[typ]or colors[0],effect=effect or 'TYPE ?',def=def,
    pp=mon.pp and mon.pp[slot]or 0,maxPp=mon.maxPp and mon.maxPp[slot]or def.pp or 0}
end
shared.gen3MoveInfo=info
if not(love and love.graphics and love.graphics.newCanvas)then return end
local Ui=require('src.core.game3.battle.ui')
local Font=require('src.ui.game3.frlg_font')
local Chrome=require('src.ui.game3.battle_chrome')
local drawing,pending,moveColors=false,false,{}
local frames=Ui.drawMenuFrames
Ui.drawMenuFrames=function(...)
  local result=frames(...)
  -- Healthbox fonts can use offscreen atlas coordinates that look like
  -- footer coordinates. Restrict recoloring/replacement to the menu pass.
  drawing=pending
  return result
end
local fontDraw=Font.draw
Font.draw=function(text,x,y,opts)
  if drawing and y>=112 then
    if x>=164 and not Ui._swap then return end
    local color=moveColors[text]
    if color and x<164 then
      local o={};for k,v in pairs(opts or {})do o[k]=v end
      local c={};for k,v in pairs(o.colors or Font.COLOR.NORMAL)do c[k]=v end
      c.fg=color;o.colors=c;opts=o
      if Chrome.layout()=='rs'then o.font='native_4';o.small=true;y=y-4 end
    end
  end
  return fontDraw(text,x,y,opts)
end
local draw=Ui.draw
Ui.draw=function(...)
  local show=shared.bool('battle_move_info',true)and(Ui._mode=='moves'or Ui._mode=='target')
    and not(shared.gen3BattleMenuOpen and shared.gen3BattleMenuOpen())
  local st=Ui._st
  local attacker=st and Ui.activeBattlerObject(st)
  local selected
  if show and attacker and attacker.mon then
    moveColors={}
    for slot=1,4 do
      local row=info(st,attacker,slot,Ui._target and Ui._target.cursor)
      if row then moveColors[Moves.displayName(attacker.mon.moves[slot])]=row.color end
      if slot==Ui._moveIndex then selected=row end
    end
  end
  pending=show and selected~=nil;drawing=false
  local ok,result=pcall(draw,...);drawing=false;pending=false
  if not ok then error(result,0)end
  if show and selected and not Ui._swap then
    local bg={0,0,0,0};local shadow=Font.COLOR.NORMAL.shadow
    local function line(s,y,color)
      local rs=Chrome.layout()=='rs'
      fontDraw(s,rs and 188 or 176,rs and y-6 or y,
        {small=true,colors={fg=color or Font.COLOR.NORMAL.fg,shadow=shadow,bg=bg}})
    end
    line(('PP %d/%d'):format(selected.pp,selected.maxPp),117)
    line(Types.name(selected.type),129,selected.color)
    line(selected.effect,141)
  end
  return result
end
