local mod, shared = ...

-- Gen 2's held-item trades keep their original item and become level-up
-- evolutions. The item is consumed when the evolution succeeds, matching a
-- real trade evolution while keeping split families player-selectable.
local LEVEL_ITEM = "SILVERSHADOW_LEVEL_ITEM"

mod.content.evolution_methods:register(LEVEL_ITEM, {
  check = function(entry, mon, _)
    if not mon or (mon.level or 1) < (entry.level or 1) then
      return false, "level"
    end
    if mon.item ~= entry.item then return false, "wrong item" end
    return true, nil, true
  end,
  describe = function(entry)
    return "LEVEL " .. tostring(entry.level or 1)
      .. " HOLDING " .. tostring(entry.item or "ITEM")
  end,
})

-- Gen2 Evolution.apply only clears items for the built-in EVOLVE_TRADE
-- method.  A custom method's third `check` return is retained in the engine's
-- plan for compatibility, but the current animation path does not forward it
-- to apply.  Clear the item on the shared success event instead; the event's
-- `mon` is the newly built party record, before it is written back.
mod.events:on("pokemon.evolved", function(event)
  if event and event.via == LEVEL_ITEM and event.mon then
    event.mon.item = nil
  end
end)

local function levelEvolution(level, into)
  return { method = "EVOLVE_LEVEL", level = level, into = into }
end

local function heldEvolution(item, into)
  return { method = LEVEL_ITEM, level = 40, item = item, into = into }
end

-- The original four any-trade evolutions use the same levels as the Gen 1
-- SilverShadow catch-all module.
mod.content.pokemon:patch("KADABRA", {
  evolutions = { levelEvolution(42, "ALAKAZAM") },
})
mod.content.pokemon:patch("GRAVELER", {
  evolutions = { levelEvolution(42, "GOLEM") },
})
mod.content.pokemon:patch("HAUNTER", {
  evolutions = { levelEvolution(42, "GENGAR") },
})
mod.content.pokemon:patch("MACHOKE", {
  evolutions = { levelEvolution(45, "MACHAMP") },
})

-- Preserve both branches for species that already have a non-trade choice.
mod.content.pokemon:patch("POLIWHIRL", {
  evolutions = {
    { method = "EVOLVE_ITEM", item = "WATER_STONE", into = "POLIWRATH" },
    heldEvolution("KINGS_ROCK", "POLITOED"),
  },
})
mod.content.pokemon:patch("SLOWPOKE", {
  evolutions = {
    levelEvolution(37, "SLOWBRO"),
    heldEvolution("KINGS_ROCK", "SLOWKING"),
  },
})

mod.content.pokemon:patch("ONIX", {
  evolutions = { heldEvolution("METAL_COAT", "STEELIX") },
})
mod.content.pokemon:patch("SCYTHER", {
  evolutions = { heldEvolution("METAL_COAT", "SCIZOR") },
})
mod.content.pokemon:patch("SEADRA", {
  evolutions = { heldEvolution("DRAGON_SCALE", "KINGDRA") },
})
mod.content.pokemon:patch("PORYGON", {
  evolutions = { heldEvolution("UP_GRADE", "PORYGON2") },
})

-- Fixed local additions; no global species rotation or encounter timer.
mod.hooks:wrap("encounter.species",function(next,encounter,ctx)
  local out=next(encounter,ctx)
  local game=shared.game
  if type(out)~="table"or out.roamer or not ctx or ctx.kind~="wild"
      or not game or shared.online()or not shared.gen2AreaRows then return out end
  local world=game.world
  if not world or not world.map then return out end
  local rng=ctx.rng or math.random
  local row
  if shared.bool("all_251_catchable",true)then row=shared.gen2DexNavPick(game,world,rng)end
  if not row and rng(1,100)<=30 then
    local added={}
    for _,r in ipairs(shared.gen2AreaRows(game,world))do
      if r.added then added[#added+1]=r end
    end
    if #added>0 then row=added[rng(1,#added)]end
  end
  return row and {species=row.species,level=row.level}or out
end)

mod.log:info("Gen 2 single-player evolutions and local catchable 251 loaded")
