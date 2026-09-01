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

-- Gold, Silver and Crystal have different tables, time slots and exclusives.
-- A shared encounter hook is more robust than replacing all three ROMs' map
-- tables: every Nth ordinary wild encounter becomes a species the current
-- save has not caught yet. Scripted, fishing-special, contest and roaming
-- encounters retain their vanilla behavior.
local encounterCount = 0
local dexCursor = 1

local function uncaughtDex(data, caught)
  local rows = {}
  for id, def in pairs((data and data.pokemon) or {}) do
    local dex = tonumber(def.dex)
    if dex and dex >= 1 and dex <= 251 and not caught[id] then
      rows[#rows + 1] = { id = id, dex = dex }
    end
  end
  table.sort(rows, function(a, b)
    if a.dex == b.dex then return a.id < b.id end
    return a.dex < b.dex
  end)
  return rows
end

mod.hooks:wrap("encounter.species", function(next, encounter, ctx)
  local out = next(encounter, ctx)
  if type(out) ~= "table" or not ctx or ctx.kind ~= "wild" then return out end
  if not shared.bool("all_251_catchable", true) then return out end
  if not shared.game or shared.online() then return out end

  encounterCount = encounterCount + 1
  local interval = shared.allowed("catch_all_interval", { 10, 20, 50 }, 20)
  if encounterCount < interval then return out end
  encounterCount = 0

  local save = shared.game.save or {}
  local caught = save.pokedex and save.pokedex.caught or {}
  local missing = uncaughtDex(ctx.data or shared.game.data, caught)
  if #missing == 0 then return out end

  if dexCursor > #missing then dexCursor = 1 end
  local replacement = missing[dexCursor]
  dexCursor = (dexCursor % #missing) + 1
  return { species = replacement.id, level = out.level }
end)

mod.log:info("Gen 2 single-player evolutions and catchable 251 loaded")
