-- One readable palette for battle moves and every generation's move editor.
local _, shared = ...
local colors = {
  NORMAL={.35,.35,.30,1}, FIRE={.74,.23,.10,1}, WATER={.13,.35,.72,1},
  GRASS={.21,.48,.15,1}, ELECTRIC={.57,.43,.02,1}, ICE={.10,.47,.50,1},
  FIGHTING={.65,.18,.15,1}, POISON={.51,.23,.60,1}, GROUND={.55,.35,.12,1},
  FLYING={.40,.32,.69,1}, PSYCHIC={.70,.20,.46,1}, BUG={.36,.46,.07,1},
  ROCK={.49,.40,.17,1}, GHOST={.36,.25,.52,1}, DRAGON={.36,.20,.73,1},
  DARK={.32,.24,.20,1}, STEEL={.28,.44,.58,1},
}
local ids = {[0]='NORMAL','FIGHTING','FLYING','POISON','GROUND','ROCK','BUG',
  'GHOST','STEEL','UNKNOWN','FIRE','WATER','GRASS','ELECTRIC','PSYCHIC','ICE','DRAGON','DARK'}
shared.typeColors = colors
shared.moveTypeColor = function(typ)
  local name = type(typ)=='number' and ids[typ] or tostring(typ):upper():gsub('_TYPE$', '')
  return colors[name]
end
