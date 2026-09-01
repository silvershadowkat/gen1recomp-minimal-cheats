local mod, shared = ...

local Bag = require("src.inventory.Bag")
local PackMenu = require("src.ui.gen2.PackMenu")

local EDITABLE = { ITEM = true, BALL = true, TM_HM = true }
local BALL_ORDER = {
  POKE_BALL = 1, GREAT_BALL = 2, ULTRA_BALL = 3, MASTER_BALL = 4,
  FAST_BALL = 10, LEVEL_BALL = 11, LURE_BALL = 12, HEAVY_BALL = 13,
  LOVE_BALL = 14, FRIEND_BALL = 15, MOON_BALL = 16, PARK_BALL = 17,
}

-- Families with an objectively weaker-to-stronger ladder. Everything else
-- follows its stable ROM index after these families.
local ITEM_STRENGTH = {}
local function family(group, ...)
  for rank, id in ipairs({ ... }) do ITEM_STRENGTH[id] = { group, rank } end
end
family(1, "BERRY", "GOLD_BERRY", "POTION", "FRESH_WATER", "SODA_POP",
  "SUPER_POTION", "LEMONADE", "HYPER_POTION", "MAX_POTION", "FULL_RESTORE")
family(2, "ANTIDOTE", "BURN_HEAL", "ICE_HEAL", "AWAKENING",
  "PARLYZ_HEAL", "FULL_HEAL")
family(3, "REVIVE", "MAX_REVIVE")
family(4, "ETHER", "MAX_ETHER", "ELIXER", "MAX_ELIXER")
family(5, "REPEL", "SUPER_REPEL", "MAX_REPEL")

local function validRecord(id, def)
  if type(def) ~= "table" or type(def.name) ~= "string" or def.name == "" then
    return false
  end
  if Bag.isBadge(id) or id == "NO_ITEM" or id == "ITEM_NONE"
      or id:match("^ITEM_%x+$") then return false end
  return true
end

local function isHM(id, def)
  local label = tostring((def and (def.tmLabel or def.name)) or id):upper()
  return tostring(id):upper():match("^HM[_%d]") ~= nil
    or label:match("^HM%d") ~= nil
end

local function catalogue(game, pocket)
  if not EDITABLE[pocket] then return {} end
  local rows = {}
  for id, def in pairs((game.data and game.data.items) or {}) do
    if validRecord(id, def) and def.pocket == pocket
        and not (pocket == "TM_HM" and isHM(id, def)) then
      rows[#rows + 1] = { id = id, def = def }
    end
  end
  table.sort(rows, function(a, b)
    if pocket == "BALL" then
      local ar, br = BALL_ORDER[a.id] or 1000, BALL_ORDER[b.id] or 1000
      if ar ~= br then return ar < br end
    elseif pocket == "TM_HM" then
      local ar = tonumber(a.def.tmNumber) or tonumber(a.def.index) or 1000
      local br = tonumber(b.def.tmNumber) or tonumber(b.def.index) or 1000
      if ar ~= br then return ar < br end
    else
      local ar, br = ITEM_STRENGTH[a.id], ITEM_STRENGTH[b.id]
      local ag, bg = ar and ar[1] or 1000, br and br[1] or 1000
      if ag ~= bg then return ag < bg end
      local av, bv = ar and ar[2] or 1000, br and br[2] or 1000
      if av ~= bv then return av < bv end
    end
    local ai, bi = tonumber(a.def.index) or math.huge,
      tonumber(b.def.index) or math.huge
    if ai ~= bi then return ai < bi end
    return a.id < b.id
  end)
  return rows
end

local function displayLabel(game, row, pocket)
  if pocket ~= "TM_HM" then return row.def.name or row.id end
  local move = row.def.teaches and game.data.moves
    and game.data.moves[row.def.teaches]
  local moveName = move and move.name or row.def.teaches
  local number = tonumber(row.def.tmNumber)
  local tm = number and ("TM%02d"):format(number)
    or tostring(row.def.tmLabel or row.def.name or row.id)
  return moveName and (tm .. " " .. moveName) or tm
end

local function refreshRows(game, rows)
  local inventory = game.save and game.save.inventory or {}
  for _, row in ipairs(rows or {}) do
    local owned = tonumber(inventory[row.value]) or 0
    row.right = owned > 0 and ("x" .. tostring(owned)) or "FREE"
  end
end

local function canEdit(pack)
  if not pack or pack.battle or pack.give or pack.tutorial then return false end
  local pocket = pack.pocket and pack:pocket()
  return pocket and EDITABLE[pocket.id] == true
end

local function openCatalogue(game, pack)
  if not (game and game.save and game.data) or not canEdit(pack) then return false end
  if not shared.gameplayAllowed() then return false end
  local pocket = pack:pocket().id
  local source = catalogue(game, pocket)
  local rows = {}
  for _, item in ipairs(source) do
    rows[#rows + 1] = {
      value = item.id,
      label = displayLabel(game, item, pocket),
    }
  end
  refreshRows(game, rows)

  local greeting = "FREE  A:ADD  B:BACK"
  local list
  list = mod.ui.ListMenu.new(game, "ADD " .. pack:pocket().label, rows, {
    rows = 6, wrap = true, pageJump = true, keyRepeat = true,
    footer = greeting,
    onChoose = function(item)
      if not item or not shared.gameplayAllowed() then return end
      local owned = tonumber(game.save.inventory[item.value]) or 0
      if owned >= 99 then list.footer = "That stack is full."; return end
      list.footer = "How many? No charge."
      game.stack:push(mod.ui.QuantityBox.new(game, {
        max = 99 - owned, unitPrice = 0,
        onDone = function(qty)
          if not qty then list.footer = greeting; return end
          local def = game.data.items[item.value]
          list.footer = (def and def.name or item.value)
            .. " x" .. tostring(qty) .. "? FREE."
          game.stack:push(mod.ui.ChoiceBox.new(game, function(yes)
            if not yes then list.footer = greeting; return end
            if not Bag.add(game.save, item.value, qty, game.data) then
              list.footer = "No room in this pocket."
              return
            end
            pack:rebuild()
            pack:storeCursor()
            refreshRows(game, rows)
            list.footer = (def and def.name or item.value)
              .. " x" .. tostring(qty) .. " added."
          end))
        end,
      }))
    end,
  })
  game.stack:push(list)
  return true
end

if type(PackMenu) == "table" and not PackMenu._silverShadowItemEditor then
  local originalArmSwitch = PackMenu.armSwitch
  PackMenu.armSwitch = function(self)
    if self:isCancel() and canEdit(self) then
      openCatalogue(self.game, self)
      return
    end
    return originalArmSwitch(self)
  end

  local originalDescription = PackMenu.description
  PackMenu.description = function(self)
    if self:isCancel() and canEdit(self) then return "SEL: Add Item" end
    return originalDescription(self)
  end
  PackMenu._silverShadowItemEditor = true
end

mod.exports.gen2ItemEditor = {
  catalogue = catalogue,
  canEdit = canEdit,
  open = openCatalogue,
  isHM = isHM,
}
