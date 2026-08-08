local mod, shared = ...

local SCREEN = "SilverShadowPC"

local function openPokemon(game)
  mod.ui.push(game, assert(shared.boxScreen, "Gen 3 box screen unavailable"))
end

local function openItems(game)
  mod.ui.push(game, "PlayerPC")
end

local function openItemEditor(game)
  mod.ui.push(game, assert(shared.itemEditorScreen, "Item editor unavailable"),
    { store = "pc" })
end

mod.content.screens:register(SCREEN, { new = function(game)
  local Menu = require("src.ui.Menu")
  return Menu.new(game, {
    { label = "POKEMON STORAGE", onSelect = function() openPokemon(game) end },
    { label = "ITEM STORAGE", onSelect = function() openItems(game) end },
    { label = "EDIT PC ITEMS", onSelect = function() openItemEditor(game) end },
    { label = "CANCEL" },
  }, { tx = 0, ty = 0, tw = 20, th = 10 })
end })

shared.registerStartItem("pc", 10, function(game)
  return { label = "PC", onSelect = function() mod.ui.push(game, SCREEN) end }
end)

shared.decoratePcItems = function(game, items)
  for index, item in ipairs(items or {}) do
    local label = tostring(item.label or "")
    if label == "BILL'S PC" or label == "SOMEONE'S PC" then
      items[index] = {
        label = "POKEMON STORAGE", keepOpen = true,
        onSelect = function() openPokemon(game) end,
      }
    elseif label:match("'s PC$") and label ~= "PROF.OAK's PC" then
      items[index] = {
        label = "ITEM STORAGE", keepOpen = true,
        onSelect = function() openItems(game) end,
      }
    end
  end
  local hasEditor = false
  for _, item in ipairs(items or {}) do
    if item.label == "EDIT PC ITEMS" then hasEditor = true; break end
  end
  if not hasEditor then
    mod.ui.insertBefore(items, "LOG OFF", {
      label = "EDIT PC ITEMS",
      keepOpen = true,
      onSelect = function() openItemEditor(game) end,
    })
  end
  if shared.ensureRareCandy then shared.ensureRareCandy(game) end
  return items
end

shared.pcScreen = SCREEN
mod.exports.pcScreen = SCREEN
