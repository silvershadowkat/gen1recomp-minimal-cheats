-- Gen 2 Area DexNav as a native, registerable Key Item.
local mod, shared = ...

local ITEM_ID = "DEXNAV"
local PATCH_KEY = "__silvershadow_gen2_dexnav_v1"
local GRASS_WEIGHTS = { 30, 30, 20, 10, 5, 4, 1 }
local WATER_WEIGHTS = { 60, 30, 10 }

mod.content.items:register(ITEM_ID, {
  id = ITEM_ID,
  name = "DEXNAV",
  price = 0,
  pocket = "KEY_ITEM",
  fieldMenu = "ITEMMENU_CURRENT",
  battleMenu = "ITEMMENU_NOUSE",
  canSelect = true,
  canToss = false,
  description = "Finds an uncaught<NEXT>area POKEMON.",
})

local function ensureItem(game)
  local save = game and game.save
  if not (save and game.data) then return false end
  save.inventory = save.inventory or {}
  if not save.inventory[ITEM_ID] then save.inventory[ITEM_ID] = 1 end
  require("src.inventory.Bag").order(save, game.data)
  return true
end

local function healthyParty(game)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if (tonumber(mon.hp) or 0) > 0 then return true end
  end
  return false
end

local function currentSlots(game, world)
  local mapId = world and world.map and world.map.id
  local tables = world and world.wildTables and world:wildTables()
    or (game and game.data and game.data.gen2Encounters)
  if not (mapId and tables) then return nil, nil, mapId end

  if world.player and world.player.surfing then
    local entry = tables.water and tables.water[mapId]
    if not entry or (tonumber(entry.rate) or 0) <= 0 then
      return nil, WATER_WEIGHTS, mapId
    end
    return entry.slots, WATER_WEIGHTS, mapId
  end

  local entry = tables.grass and tables.grass[mapId]
  if not entry then return nil, GRASS_WEIGHTS, mapId end
  local tod = world.tod == "DARK" and "NITE" or (world.tod or "DAY")
  local rate = entry.rates and (entry.rates[tod] or entry.rates.DAY) or 0
  if (tonumber(rate) or 0) <= 0 then return nil, GRASS_WEIGHTS, mapId end
  local slots = entry.slots and (entry.slots[tod] or entry.slots.DAY)
  return slots, GRASS_WEIGHTS, mapId
end

local function candidates(game, world)
  local slots, weights, mapId = currentSlots(game, world)
  if not slots then return {}, mapId, "no_encounters" end
  local caught = game.save and game.save.pokedex and game.save.pokedex.caught or {}
  local rows = {}
  for index, slot in ipairs(slots) do
    local species = type(slot) == "table" and slot.species or nil
    local level = type(slot) == "table" and tonumber(slot.level) or nil
    if species and level and game.data.pokemon[species] and not caught[species] then
      rows[#rows + 1] = {
        species = species,
        level = math.max(1, math.floor(level)),
        weight = weights[index] or 1,
      }
    end
  end
  if #rows == 0 then return rows, mapId, "complete" end
  return rows, mapId
end

local function pickTarget(game, world, rng)
  local rows, mapId, reason = candidates(game, world)
  if #rows == 0 then return nil, mapId, reason end
  local total = 0
  for _, row in ipairs(rows) do total = total + row.weight end
  rng = rng or (love and love.math and love.math.random) or math.random
  local roll = rng(1, total)
  for _, row in ipairs(rows) do
    roll = roll - row.weight
    if roll <= 0 then return row, mapId end
  end
  return rows[#rows], mapId
end

local function queueText(text)
  if not mod.world then return nil, "world API unavailable" end
  return mod.world:queueScript({ { "text", text } })
end

local function activate(game, world)
  if not healthyParty(game) then
    return queueText("Your party cannot\nbattle.")
  end
  local target, _, reason = pickTarget(game, world)
  if not target then
    if reason == "complete" then
      return queueText("All POKEMON in\nthis area are caught!")
    end
    return queueText("No wild POKEMON\nfound here.")
  end
  return mod.world:queueScript({
    { "start_battle", "wild", target.species, target.level },
  })
end

local function install(game)
  local world = game and game.world
  if type(world) ~= "table" or type(world.useFieldItem) ~= "function"
      or type(world.step) ~= "function" then return false end

  local patch = rawget(world, PATCH_KEY)
  if not patch then
    patch = {
      originalUse = world.useFieldItem,
      originalStep = world.step,
      handlers = {},
      pending = {},
    }
    rawset(world, PATCH_KEY, patch)
    world.useFieldItem = function(self, itemId, ...)
      local live = rawget(self, PATCH_KEY)
      if live then
        for _, entry in pairs(live.handlers) do
          local result = entry.use(self, itemId)
          if result ~= nil then return result end
        end
        return live.originalUse(self, itemId, ...)
      end
    end
    world.step = function(self, ...)
      local live = rawget(self, PATCH_KEY)
      if not live then return end
      ensureItem(game)
      local result = live.originalStep(self, ...)
      for id in pairs(live.pending) do
        live.pending[id] = nil
        local entry = live.handlers[id]
        if entry then
          local ok, err = pcall(entry.activate, game, self)
          if not ok then mod.log:error("DEXNAV failed: %s", tostring(err)) end
        end
      end
      return result
    end
  end

  patch.handlers[mod.id] = {
    use = function(self, itemId)
      if itemId ~= ITEM_ID then return nil end
      if self.battleActive or (self.busy and self:busy()) then return "nowhere" end
      patch.pending[mod.id] = true
      return "dexnav"
    end,
    activate = activate,
  }
  ensureItem(game)
  return true
end

mod.events:on("game.ready", function(event)
  local game = event and event.game
  -- game.ready intentionally precedes Gold's boot cinema and World creation.
  -- Grant the item now, then attach its field behavior once an overworld is
  -- actually standing.
  if game then ensureItem(game) end
  if game and game.world and not install(game) then
    mod.log:warn("DEXNAV item could not attach to the Gen 2 overworld")
  end
end)

mod.events:on("save.loaded", function()
  local game = shared.game
  if game then
    ensureItem(game)
    install(game)
  end
end)

-- This factory deliberately returns no Start-menu row.  Opening START is a
-- guaranteed post-boot point before PACK can be chosen, so it also repairs a
-- fresh/new-game world whose game.ready event happened before World existed.
shared.registerStartItem("gen2_dexnav_ready", 1, function(game)
  ensureItem(game)
  install(game)
  return nil
end)

mod.exports.gen2DexNav = {
  itemId = ITEM_ID,
  ensureItem = ensureItem,
  candidates = candidates,
  pickTarget = pickTarget,
  activate = activate,
  install = install,
}
