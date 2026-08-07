-- Universal Free TM Shop
-- Adds a dedicated TM catalogue to every screen that opens the built-in
-- ShopMenu. The normal shop remains available and keeps its original stock.

local Bag = require("src.inventory.Bag")
local ChoiceBox = require("src.ui.ChoiceBox")
local ListMenu = require("src.ui.ListMenu")
local Menu = require("src.ui.Menu")
local QuantityBox = require("src.ui.QuantityBox")
local Strings = require("src.core.Strings")
local VanillaShopMenu = require("src.ui.ShopMenu")


local function isTM(def)
  local machine = def and def.machine
  return machine and machine.kind == "TM"
end

local function machineNumber(def)
  return tonumber(def and def.machine and def.machine.number) or 0
end

local function discoverTMs(data)
  local out = {}
  for id, def in pairs((data and data.items) or {}) do
    if isTM(def) then
      out[#out + 1] = {
        id = id,
        number = machineNumber(def),
        move = def.machine.move,
      }
    end
  end
  table.sort(out, function(a, b)
    if a.number ~= b.number then return a.number < b.number end
    return a.id < b.id
  end)
  return out
end

local function normalStock(game, stock)
  local out = {}
  for _, id in ipairs(stock or {}) do
    if not isTM(game.data.items[id]) then out[#out + 1] = id end
  end
  return out
end

local function moveName(game, machine)
  local def = game.data.moves and game.data.moves[machine.move]
  return (def and def.name) or tostring(machine.move or "")
end

local function tmLabel(game, machine)
  local def = game.data.items[machine.id]
  local tmName = (def and def.name) or ("TM%02d"):format(machine.number)
  return tmName .. " " .. moveName(game, machine)
end

local function freeTMShop(game)
  local rows = {}
  for _, machine in ipairs(discoverTMs(game.data)) do
    rows[#rows + 1] = {
      value = machine.id,
      label = tmLabel(game, machine),
      number = machine.number,
    }
  end

  local greeting = "Every TM is FREE.\nChoose a machine."
  local list
  list = ListMenu.new(game, "TM SHOP", rows, {
    kind = "tm_shop",
    dialogue = true,
    money = function() return game.save.money or 0 end,
    footer = greeting,
    pageJump = true,
    keyRepeat = true,
    onChoose = function(item)
      local id = item.value
      local def = game.data.items[id]
      local owned = tonumber(game.save.inventory[id]) or 0
      if owned >= 99 then
        list.footer = "You already have\n99 of this TM."
        return
      end

      list.footer = Strings("%s is FREE.\nHow many?", def and def.name or id)
      game.stack:push(QuantityBox.new(game, {
        max = 99 - owned,
        unitPrice = 0,
        onDone = function(qty)
          if not qty then
            list.footer = greeting
            return
          end

          list.footer = Strings("%s x%d?\nNo charge. OK?",
                                def and def.name or id, qty)
          game.stack:push(ChoiceBox.new(game, function(yes)
            if not yes then
              list.footer = greeting
              return
            end
            if not Bag.add(game.save, id, qty, game.data) then
              list.footer = "You can't carry\nany more items."
              return
            end
            require("src.core.Sound").play(game.data, "Purchase")
            list.footer = Strings("Here you are!\n%s x%d.",
                                  def and def.name or id, qty)
          end))
        end,
      }))
    end,
  })
  return list
end

local function shopChooser(game, stock, onQuit)
  local chooser
  chooser = Menu.new(game, {
    {
      label = "NORMAL SHOP",
      keepOpen = true,
      onSelect = function()
        -- The built-in shop is required directly, bypassing this registered
        -- ShopMenu replacement and avoiding recursion.
        game.stack:push(VanillaShopMenu.new(
          game, normalStock(game, stock), function() end))
      end,
    },
    {
      label = "TM SHOP",
      keepOpen = true,
      onSelect = function()
        game.stack:push(freeTMShop(game))
      end,
    },
    {
      label = "LEAVE",
      onSelect = onQuit,
    },
  }, { tx = 0, ty = 0, tw = 15, th = 8 })
  chooser.onCancel = onQuit
  return chooser
end

return function(mod)
  -- Buying every distinct TM would exceed the original 20-slot Bag.
  -- Keep all TM transactions economically neutral. Normal shop stock is
  -- filtered below, while selling a free TM yields zero instead of creating
  -- an infinite-money exploit.
  local patched = 0
  for id, def in mod.content.items:each() do
    if isTM(def) then
      mod.content.items:patch(id, { price = 0 })
      patched = patched + 1
    end
  end

  -- Every standard clerk path eventually pushes the screen id ShopMenu.
  -- Registering this screen preserves map scripts and special mart dialogue.
  mod.content.screens:register("ShopMenu", { new = shopChooser })

  mod.exports.listTMs = discoverTMs
  mod.exports.normalStock = normalStock
  mod.exports.tmCount = patched
end
