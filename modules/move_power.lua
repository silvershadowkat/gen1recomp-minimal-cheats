-- Comparison value only: base power x STAB x type effectiveness.
-- Does not simulate a hit, consume RNG, or include stats/crit/weather/cheats.
local _,S=...
function S.adjustedMovePower(power,stab,multiplier)
  power=tonumber(power)or 0
  if power<=1 then return "--"end -- status/fixed/variable-power sentinel
  if multiplier==nil then return "?"end -- no selected target / mixed targets
  local value=power*(stab and 1.5 or 1)*multiplier
  -- Preserve fractional comparison values; damage's per-step integer floors
  -- belong to the native battle calculation, not this displayed power.
  return ("%g"):format(value)
end
