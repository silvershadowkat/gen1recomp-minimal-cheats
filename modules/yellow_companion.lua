local mod,shared=...
if shared.gameVersion~="yellow" then return end
local P=require("src.world.PikachuFollower")
-- PokéPC broadens this function to mean any selected follower. Yellow's
-- happiness and story scripts use it specifically for the original Pikachu.
P.starterInParty=function(save,healthy)
  for _,mon in ipairs(save and save.party or {})do
    if P.isStarterPikachu(save,mon)then
      if healthy and (mon.hp or 0)<=0 then return nil end
      return mon
    end
  end
end
local function gated(delegate)
  return function(game,ow)
    local s=game and game.save
    if not s or not s.flags or not s.flags.EVENT_GOT_STARTER then return false end
    if s.pikachuInBall==nil then
      if not s.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB then return false end
    elseif s.pikachuInBall then return false end
    if s.onBike or (ow and ow.player and ow.player.surfing)then return false end
    if not P.starterInParty(s,true)then return false end
    return delegate(game,ow)
  end
end
local setter=P.setShouldSpawn
local previous=setter(function()return false end)
setter(gated(previous))
P.setShouldSpawn=function(fn)return setter(fn and gated(fn) or fn)end
