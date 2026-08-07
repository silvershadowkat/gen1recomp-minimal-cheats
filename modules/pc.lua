local mod, shared = ...

local SCREEN = "SilverShadowPC"

local function openPokemon(game)
  mod.ui.push(game, assert(shared.boxScreen, "Gen 3 box screen unavailable"))
end

local function openItems(game)
  mod.ui.push(game, "PlayerPC")
end

mod.content.screens:register(SCREEN, { new = function(game)
  local Menu = require("src.ui.Menu")
  return Menu.new(game, {
    { label = "POKEMON STORAGE", onSelect = function() openPokemon(game) end },
    { label = "ITEM STORAGE", onSelect = function() openItems(game) end },
    { label = "CANCEL" },
  }, { tx = 0, ty = 0, tw = 20, th = 8 })
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
  if shared.ensureRareCandy then shared.ensureRareCandy(game) end
  return items
end

shared.pcScreen = SCREEN
mod.exports.pcScreen = SCREEN
