-- Clean SilverShadow implementation informed by Useful Bag's public behavior.
-- The flat save.inventory model remains authoritative; pockets are projections.
local mod, shared = ...

local Bag = require("src.inventory.Bag")
local POCKETS = {
  { id = "items", label = "ITEMS" },
  { id = "medicine", label = "MEDICINE" },
  { id = "balls", label = "POKE BALLS" },
  { id = "machines", label = "TMs / HMs" },
  { id = "battle", label = "BATTLE ITEMS" },
  { id = "key", label = "KEY ITEMS" },
}
local BATTLE_POCKETS = { battle = true, balls = true, medicine = true, items = true }
local MEDICINE = {
  POTION=true, SUPER_POTION=true, HYPER_POTION=true, MAX_POTION=true,
  FRESH_WATER=true, SODA_POP=true, LEMONADE=true, ANTIDOTE=true,
  BURN_HEAL=true, ICE_HEAL=true, AWAKENING=true, PARLYZ_HEAL=true,
  FULL_HEAL=true, FULL_RESTORE=true, REVIVE=true, MAX_REVIVE=true,
  RARE_CANDY=true, HP_UP=true, PROTEIN=true, IRON=true, CARBOS=true,
  CALCIUM=true, ETHER=true, MAX_ETHER=true, ELIXER=true, MAX_ELIXER=true,
  PP_UP=true,
}
local BATTLE_ITEMS = {
  X_ATTACK=true, X_DEFEND=true, X_SPEED=true, X_SPECIAL=true,
  X_ACCURACY=true, DIRE_HIT=true, GUARD_SPEC=true, POKE_DOLL=true,
}
local BALLS = { POKE_BALL=true, GREAT_BALL=true, ULTRA_BALL=true,
  MASTER_BALL=true, SAFARI_BALL=true }
local KEY_FALLBACK = {
  TOWN_MAP=true, BICYCLE=true, SURFBOARD=true, POKEDEX=true,
  OLD_AMBER=true, DOME_FOSSIL=true, HELIX_FOSSIL=true, SECRET_KEY=true,
  BIKE_VOUCHER=true, CARD_KEY=true, S_S_TICKET=true, GOLD_TEETH=true,
  COIN_CASE=true, OAKS_PARCEL=true, ITEMFINDER=true, SILPH_SCOPE=true,
  POKE_FLUTE=true, LIFT_KEY=true, OLD_ROD=true, GOOD_ROD=true, SUPER_ROD=true,
}

local function classify(data, id)
  local def = data and data.items and data.items[id]
  if (def and def.keyItem) or KEY_FALLBACK[id] then return "key" end
  if (def and def.machine) or id:match("^TM") or id:match("^HM") then
    return "machines"
  end
  if (def and def.ball) or BALLS[id] then return "balls" end
  if MEDICINE[id] then return "medicine" end
  if BATTLE_ITEMS[id] then return "battle" end
  return "items"
end

local function machineLabel(game, id)
  local def = game.data.items and game.data.items[id]
  local base = def and def.name or id
  if not (def and def.machine) then return base end
  local move = game.data.moves and game.data.moves[def.machine.move]
  return base .. " " .. (move and move.name or def.machine.move or "")
end

local function makeRow(game, id)
  return { value = id, label = machineLabel(game, id),
    right = "x" .. tostring(game.save.inventory[id] or 0) }
end

local function pocketIds(game, pocket)
  local ids = {}
  for _, id in ipairs(Bag.order(game.save)) do
    if game.save.inventory[id] and classify(game.data, id) == pocket then
      ids[#ids + 1] = id
    end
  end
  return ids
end

local function swapById(order, a, b)
  local ai, bi
  for index, id in ipairs(order or {}) do
    if id == a then ai = index elseif id == b then bi = index end
  end
  if ai and bi then order[ai], order[bi] = order[bi], order[ai] end
end

local function sortBag(game, mode)
  local order = Bag.order(game.save)
  table.sort(order, function(a, b)
    if mode == "count" then
      local ac, bc = game.save.inventory[a] or 0, game.save.inventory[b] or 0
      if ac ~= bc then return ac > bc end
    end
    local an, bn = machineLabel(game, a), machineLabel(game, b)
    if an == bn then return a < b end
    return an < bn
  end)
end

local function pcOrder(save)
  save.pcOrder = save.pcOrder or {}
  local seen = {}
  for index = #save.pcOrder, 1, -1 do
    local id = save.pcOrder[index]
    if not (save.pcItems and save.pcItems[id]) or seen[id] then
      table.remove(save.pcOrder, index)
    else
      seen[id] = true
    end
  end
  for id in pairs(save.pcItems or {}) do
    if not seen[id] then save.pcOrder[#save.pcOrder + 1] = id end
  end
  return save.pcOrder
end

local function openSort(game, list, project)
  local Menu = require("src.ui.Menu")
  game.stack:push(Menu.new(game, {
    { label = "SORT BY NAME", onSelect = function()
        sortBag(game, "name"); project()
      end },
    { label = "SORT BY COUNT", onSelect = function()
        sortBag(game, "count"); project()
      end },
  }, { tx = 9, ty = 9 }))
end

local function decorateBag(list, game, opts)
  local battle = opts and opts.battle
  local pocketIndex = 1
  if battle then
    for i, p in ipairs(POCKETS) do
      if p.id == "battle" and #pocketIds(game, p.id) > 0 then pocketIndex = i end
    end
  end

  local function usable(index)
    return not battle or BATTLE_POCKETS[POCKETS[index].id]
  end

  local function project()
    local selected = list.items[list.index] and list.items[list.index].value
    local rows = {}
    for _, id in ipairs(pocketIds(game, POCKETS[pocketIndex].id)) do
      rows[#rows + 1] = makeRow(game, id)
    end
    list.items, list.title = rows, POCKETS[pocketIndex].label
    list.wrap = shared.bool("cursor_wrap", true)
    list.footer = ("L/R:POCKET START:SORT  Y%d"):format(game.save.money or 0)
    list.index, list.scroll = 1, 0
    if selected then
      for index, row in ipairs(rows) do if row.value == selected then list.index = index end end
    end
  end

  local function switch(delta)
    local original = pocketIndex
    repeat
      pocketIndex = ((pocketIndex - 1 + delta) % #POCKETS) + 1
    until usable(pocketIndex) or pocketIndex == original
    list.swapIndex = nil
    project()
  end

  local baseUpdate = list.update
  list.update = function(self, dt)
    local input = game.input
    if input:wasPressed("left") then switch(-1); return end
    if input:wasPressed("right") then switch(1); return end
    if input:wasPressed("start") then openSort(game, self, project); return end
    return baseUpdate(self, dt)
  end

  list.onSelectKey = function(item, current)
    if not item then return end
    if not current.swapIndex then current.swapIndex = current.index; return end
    local first = current.items[current.swapIndex]
    if first then swapById(Bag.order(game.save), first.value, item.value) end
    current.swapIndex = nil
    project()
  end
  project()
  return list
end

local function decoratePcList(list, game)
  local title = tostring(list.title or "")
  if title ~= "WITHDRAW ITEM" and title ~= "TOSS ITEM" and title ~= "DEPOSIT ITEM" then
    return list
  end
  local order = title == "DEPOSIT ITEM" and Bag.order(game.save) or pcOrder(game.save)
  local rank = {}; for index, id in ipairs(order) do rank[id] = index end
  table.sort(list.items, function(a, b)
    return (rank[a.value] or math.huge) < (rank[b.value] or math.huge)
  end)
  for _, row in ipairs(list.items) do row.label = machineLabel(game, row.value) end
  list.wrap = shared.bool("cursor_wrap", true)
  list.onSelectKey = function(item, current)
    if not item then return end
    if not current.swapIndex then current.swapIndex = current.index; return end
    local first = current.items[current.swapIndex]
    if first then swapById(order, first.value, item.value) end
    current.swapIndex = nil
    rank = {}; for index, id in ipairs(order) do rank[id] = index end
    table.sort(current.items, function(a, b)
      return (rank[a.value] or math.huge) < (rank[b.value] or math.huge)
    end)
  end
  return list
end

return function()
  mod.content.constants:patch("bagSize", 999)
  mod.content.field:patch("pcItemCap", 999)

  mod.content.screens:register("BagMenu", { new = function(game, opts)
    return decorateBag(require("src.ui.BagMenu").new(game, opts), game, opts)
  end })

  mod.events:on("game.ready", function()
    local ListMenu = require("src.ui.ListMenu")
    if ListMenu._silverShadowPcLists then return end
    ListMenu._silverShadowPcLists = true
    local baseNew = ListMenu.new
    ListMenu.new = function(game, title, items, opts)
      return decoratePcList(baseNew(game, title, items, opts), game)
    end
  end)

  mod.exports.usefulBag = {
    classify = classify,
    pocketIds = pocketIds,
    pcOrder = pcOrder,
    perItemCap = 99,
  }
end
