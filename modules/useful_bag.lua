-- Clean SilverShadow implementation informed by Useful Bag's public behavior.
-- The flat save.inventory model remains authoritative; pockets are projections.
local mod, shared = ...
local ITEM_EDITOR_SCREEN = "SilverShadowItemEditor"

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
local EDITABLE_POCKETS = {
  { id = "items", label = "ITEMS" },
  { id = "medicine", label = "MEDICINE" },
  { id = "balls", label = "POKE BALLS" },
  { id = "battle", label = "BATTLE ITEMS" },
}
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

-- Only real, ordinary inventory items are safe to create or edit. The live
-- item registry is authoritative across Red, Blue, Yellow, and other mods;
-- placeholder ROM slots are deliberately not exposed as usable items.
local function editable(data, id)
  local def = data and data.items and data.items[id]
  if type(def) ~= "table" or Bag.isBadge(id) then return false end
  if def.keyItem or def.machine then return false end
  if id:match("^TM_") or id:match("^TM%d") or id:match("^HM_")
      or id:match("^HM%d") then return false end
  if id == "NO_ITEM" or id == "ITEM_NONE" or id:match("^ITEM_%x+$") then
    return false
  end
  return type(def.name) == "string" and def.name ~= ""
end

-- Item records retain their ROM index. That is the game's native catalogue
-- order and is stable across versions; mod-added records without an index
-- follow the native set in deterministic id order.
local function catalogIds(game, pocket)
  local ids = {}
  for id in pairs((game.data and game.data.items) or {}) do
    if editable(game.data, id) and classify(game.data, id) == pocket then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids, function(a, b)
    local ai = tonumber(game.data.items[a].index)
    local bi = tonumber(game.data.items[b].index)
    if ai and bi and ai ~= bi then return ai < bi end
    if ai ~= nil and bi == nil then return true end
    if ai == nil and bi ~= nil then return false end
    return a < b
  end)
  return ids
end

local function machineLabel(game, id)
  local def = game.data.items and game.data.items[id]
  local base = def and def.name or id
  if not (def and def.machine) then return base end
  local move = game.data.moves and game.data.moves[def.machine.move]
  return base .. " " .. (move and move.name or def.machine.move or "")
end

local function makeRow(game, id, store)
  store = store or game.save.inventory
  return { value = id, label = machineLabel(game, id),
    right = "x" .. tostring(store[id] or 0) }
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

local function countStacks(store)
  local count = 0
  for _ in pairs(store or {}) do count = count + 1 end
  return count
end

local function storeFor(game, kind)
  if kind == "pc" then
    game.save.pcItems = game.save.pcItems or {}
    return game.save.pcItems, pcOrder(game.save)
  end
  game.save.inventory = game.save.inventory or {}
  return game.save.inventory, Bag.order(game.save)
end

local function ensureOrdered(order, id)
  for _, existing in ipairs(order or {}) do
    if existing == id then return end
  end
  order[#order + 1] = id
end

local function addQuantity(game, kind, id, qty)
  if not shared.gameplayAllowed() then return false, "link" end
  if not editable(game.data, id) then return false, "excluded" end
  qty = math.floor(tonumber(qty) or 0)
  if qty < 1 then return false, "quantity" end
  local store, order = storeFor(game, kind)
  local owned = tonumber(store[id]) or 0
  if owned + qty > 99 then return false, "stack" end
  if kind == "bag" then
    if not Bag.add(game.save, id, qty, game.data) then return false, "full" end
  else
    local cap = (game.data.field and game.data.field.pcItemCap) or 50
    if owned == 0 and countStacks(store) >= cap then return false, "full" end
    store[id] = owned + qty
    ensureOrdered(order, id)
  end
  return true
end

local function setQuantity(game, kind, id, qty)
  if not shared.gameplayAllowed() then return false, "link" end
  if not editable(game.data, id) then return false, "excluded" end
  qty = math.floor(tonumber(qty) or 0)
  if qty < 1 or qty > 99 then return false, "quantity" end
  local store, order = storeFor(game, kind)
  if not store[id] then return false, "missing" end
  store[id] = qty
  ensureOrdered(order, id)
  return true
end

local function openQuantity(game, kind, id, refresh)
  local QuantityBox = require("src.ui.QuantityBox")
  local store = storeFor(game, kind)
  game.stack:push(QuantityBox.new(game, {
    max = 99,
    start = store[id] or 1,
    onDone = function(qty)
      if qty and setQuantity(game, kind, id, qty) and refresh then refresh() end
    end,
  }))
end

local function refreshCatalogRows(game, kind, rows)
  local store = storeFor(game, kind)
  for _, row in ipairs(rows or {}) do
    local owned = tonumber(store[row.value]) or 0
    row.right = owned > 0 and ("x" .. owned) or nil
  end
end

local function openCatalog(game, pocket, kind, refreshParent)
  local ChoiceBox = require("src.ui.ChoiceBox")
  local ListMenu = require("src.ui.ListMenu")
  local QuantityBox = require("src.ui.QuantityBox")
  local rows = {}
  for _, id in ipairs(catalogIds(game, pocket.id)) do
    rows[#rows + 1] = {
      value = id,
      label = machineLabel(game, id),
    }
  end
  refreshCatalogRows(game, kind, rows)

  local greeting = "FREE  A:ADD  B:BACK"
  local list
  list = ListMenu.new(game, "ADD " .. pocket.label, rows, {
    wrap = shared.bool("cursor_wrap", true),
    pageJump = true,
    keyRepeat = true,
    rows = 6,
    footer = greeting,
    onChoose = function(item)
      if not item or not shared.gameplayAllowed() then
        list.footer = "Unavailable during\na link session."
        return
      end
      local store = storeFor(game, kind)
      local owned = tonumber(store[item.value]) or 0
      if owned >= 99 then
        list.footer = "Already x99. Use\nQUANTITY to edit."
        return
      end
      game.stack:push(QuantityBox.new(game, {
        max = 99 - owned,
        unitPrice = 0,
        onDone = function(qty)
          if not qty then list.footer = greeting; return end
          local def = game.data.items[item.value]
          list.footer = ("%s x%d?\nNo charge. OK?"):format(
            def and def.name or item.value, qty)
          game.stack:push(ChoiceBox.new(game, function(yes)
            if not yes then list.footer = greeting; return end
            local ok, reason = addQuantity(game, kind, item.value, qty)
            if not ok then
              list.footer = reason == "stack" and "That stack is full."
                or "No room for that\nitem."
              return
            end
            refreshCatalogRows(game, kind, rows)
            if refreshParent then refreshParent() end
            list.footer = ("%s x%d added."):format(
              def and def.name or item.value, qty)
          end))
        end,
      }))
    end,
  })
  game.stack:push(list)
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
    list.footer = battle and "L/R:POCKET START:SORT"
      or "L/R SEL:ADD ST:SORT"
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
    if not battle and input:wasPressed("select") then
      local pocket = POCKETS[pocketIndex]
      if not shared.gameplayAllowed() then
        self.footer = "Unavailable in link play."
      elseif pocket.id == "machines" or pocket.id == "key" then
        self.footer = "TM/HM & KEY excluded."
      else
        openCatalog(game, pocket, "bag", project)
      end
      return
    end
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

  -- Keep the engine's complete USE/TOSS behavior, then add one isolated
  -- action to its submenu for ordinary items. Battle and link menus never
  -- receive an editor action.
  local baseChoose = list.onChoose
  list.onChoose = function(item, current)
    baseChoose(item, current)
    if battle or not item or current.swapIndex
        or not shared.gameplayAllowed()
        or not editable(game.data, item.value) then return end
    local menu = game.stack:top()
    if not menu or menu == current or type(menu.items) ~= "table" then return end
    local use, toss = false, false
    for _, row in ipairs(menu.items) do
      use = use or row.label == "USE"
      toss = toss or row.label == "TOSS"
    end
    if not (use and toss) then return end
    menu.items[#menu.items + 1] = {
      label = "QUANTITY",
      onSelect = function() openQuantity(game, "bag", item.value, project) end,
    }
    menu.th = math.max(menu.th or 0, 7)
  end
  project()
  return list
end

local function removeFromOrder(order, id)
  for index, existing in ipairs(order or {}) do
    if existing == id then table.remove(order, index); return end
  end
end

local function itemEditor(game, opts)
  opts = opts or {}
  local kind = opts.store == "bag" and "bag" or "pc"
  local pocketIndex = 1
  local ListMenu = require("src.ui.ListMenu")
  local list = ListMenu.new(game, "PC ITEMS", {}, {
    wrap = shared.bool("cursor_wrap", true),
  })

  local function project()
    local selected = list.items[list.index] and list.items[list.index].value
    local store, order = storeFor(game, kind)
    local rows = {}
    for _, id in ipairs(order) do
      if store[id] and editable(game.data, id)
          and classify(game.data, id) == EDITABLE_POCKETS[pocketIndex].id then
        rows[#rows + 1] = makeRow(game, id, store)
      end
    end
    list.items = rows
    list.title = (kind == "pc" and "PC " or "") .. EDITABLE_POCKETS[pocketIndex].label
    list.footer = "L/R:POCKET SEL:ADD"
    list.index, list.scroll = 1, 0
    if selected then
      for index, row in ipairs(rows) do
        if row.value == selected then list.index = index; break end
      end
    end
  end

  local function switch(delta)
    pocketIndex = ((pocketIndex - 1 + delta) % #EDITABLE_POCKETS) + 1
    project()
  end

  local baseUpdate = list.update
  list.update = function(self, dt)
    local input = game.input
    if input:wasPressed("left") then switch(-1); return end
    if input:wasPressed("right") then switch(1); return end
    if input:wasPressed("select") then
      if shared.gameplayAllowed() then
        openCatalog(game, EDITABLE_POCKETS[pocketIndex], kind, project)
      else
        self.footer = "Unavailable in link play."
      end
      return
    end
    return baseUpdate(self, dt)
  end

  list.onChoose = function(item)
    if not item or not shared.gameplayAllowed()
        or not editable(game.data, item.value) then return end
    local Menu = require("src.ui.Menu")
    game.stack:push(Menu.new(game, {
      {
        label = "QUANTITY",
        onSelect = function() openQuantity(game, kind, item.value, project) end,
      },
      {
        label = "REMOVE",
        onSelect = function()
          local ChoiceBox = require("src.ui.ChoiceBox")
          game.stack:push(ChoiceBox.new(game, function(yes)
            if not yes then return end
            local store, order = storeFor(game, kind)
            store[item.value] = nil
            removeFromOrder(order, item.value)
            project()
          end))
        end,
      },
    }, { tx = 9, ty = 9 }))
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
  mod.content.screens:register(ITEM_EDITOR_SCREEN, { new = itemEditor })

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
    editable = editable,
    catalogIds = catalogIds,
    addQuantity = addQuantity,
    setQuantity = setQuantity,
    pocketIds = pocketIds,
    pcOrder = pcOrder,
    perItemCap = 99,
    itemEditorScreen = ITEM_EDITOR_SCREEN,
  }
  shared.itemEditorScreen = ITEM_EDITOR_SCREEN
end
