package.path = "references/gen1recomp/?.lua;references/gen1recomp/?/init.lua;" .. package.path

local passed = 0
local function check(value, message)
  assert(value, message)
  passed = passed + 1
end
local function eq(actual, expected, message)
  assert(actual == expected, (message or "values differ") .. ": expected "
    .. tostring(expected) .. ", got " .. tostring(actual))
  passed = passed + 1
end

local saved, hooks, events, screens, foundMods = {}, {}, {}, {}, {}
local mod = {
  id = "minimal_cheats", path = ".", exports = {},
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
  hooks = { wrap = function(_, name, fn)
    local inner = hooks[name]
    if not inner then hooks[name] = fn; return end
    hooks[name] = function(next, ...)
      return fn(function(...)
        return inner(next, ...)
      end, ...)
    end
  end },
  events = { on = function(_, name, fn)
    events[name] = events[name] or {}; events[name][#events[name] + 1] = fn
  end },
  content = {
    balls = { each = function() return function() return nil end end },
    constants = { patch = function() end },
    field = { patch = function() end },
    screens = { register = function(_, id, def) screens[id] = def end },
  },
  commands = { register = function() end },
  ui = {
    push = function() end,
    insertAfter = function(rows, _, item) rows[#rows + 1] = item end,
    ListMenu = { new = function(game, title, items, opts)
      return { game = game, title = title, items = items, wrap = opts.wrap,
        rows = opts.rows, footer = opts.footer, onChoose = opts.onChoose }
    end },
  },
  log = {
    info = function() end, warn = function() end,
    error = function() end,
  },
  find = function(_, id) return foundMods[id] end,
}

local function emit(name, payload)
  for _, fn in ipairs(events[name] or {}) do fn(payload or {}) end
end
local function install(path, ...)
  local value = assert(loadfile(path))(...)
  if type(value) == "function" then return value(...) end
  return value
end

local shared = install("modules/core.lua", mod)
install("modules/useful_bag.lua", mod, shared)
install("modules/pc.lua", mod, shared)
install("modules/extended_levels.lua", mod, shared)
install("modules/cheats.lua", mod, shared)
install("modules/movement.lua", mod, shared)
install("modules/healing.lua", mod, shared)
install("modules/moves_manager.lua", mod, shared)
install("modules/dv_ev_editor.lua", mod, shared)
install("modules/dexnav.lua", mod, shared)
install("modules/field_moves.lua", mod, shared)
install("modules/followers_integration.lua", mod, shared)
install("modules/free_fly.lua", mod, shared)
local fakeHudLayer = {}
local fakeOverworldBattle = {}
fakeOverworldBattle.hudTexture = function() return fakeHudLayer end
fakeOverworldBattle.snapHUDs = function(battle)
  fakeOverworldBattle.hudTexture(battle, 0)
  return true
end
foundMods.DRAMATIC_SHAPE = { exports = { lib = {
  require = function(name)
    if name == "OverworldBattle" then return fakeOverworldBattle end
  end,
} } }
install("modules/display.lua", mod, shared)
install("modules/options.lua", mod, shared)

-- The item editor is driven by live item records, preserves their native ROM
-- order, and rejects every machine, key item, badge, and placeholder slot.
local itemTools = mod.exports.usefulBag
local itemGame = {
  save = { inventory = {}, pcItems = {}, money = 0 },
  data = {
    constants = { bagSize = 999 },
    field = { pcItemCap = 999 },
    items = {
      ESCAPE_ROPE = { name = "ESCAPE ROPE", index = 10, price = 550 },
      POTION = { name = "POTION", index = 20, price = 300 },
      GREAT_BALL = { name = "GREAT BALL", index = 4, price = 600,
        ball = "GREAT_BALL" },
      POKE_BALL = { name = "POKE BALL", index = 5, price = 200,
        ball = "POKE_BALL" },
      X_ATTACK = { name = "X ATTACK", index = 30, price = 500 },
      TM_TEST = { name = "TM01", index = 40, price = 3000,
        machine = { kind = "TM", number = 1, move = "TACKLE" } },
      HM_TEST = { name = "HM01", index = 41, price = 0,
        machine = { kind = "HM", number = 1, move = "CUT" } },
      BICYCLE = { name = "BICYCLE", index = 6, price = 0, keyItem = true },
      ITEM_2C = { name = "?????", index = 44, price = 0 },
      BOULDERBADGE = { name = "BOULDERBADGE", index = 60, price = 0 },
    },
    moves = {},
  },
}
local ballCatalog = itemTools.catalogIds(itemGame, "balls")
eq(#ballCatalog, 2, "Ball add catalogue contains only live ball records")
eq(ballCatalog[1], "GREAT_BALL",
  "Add catalogue follows native ROM order instead of alphabetical order")
eq(ballCatalog[2], "POKE_BALL", "Native ball order remains stable")
for _, id in ipairs({ "TM_TEST", "HM_TEST", "BICYCLE", "ITEM_2C",
                       "BOULDERBADGE" }) do
  check(not itemTools.editable(itemGame.data, id),
    id .. " is excluded from item creation and quantity editing")
end
check(itemTools.addQuantity(itemGame, "bag", "POTION", 5),
  "Bag editor creates a normal item stack")
eq(itemGame.save.inventory.POTION, 5, "Bag add quantity is exact")
check(itemTools.setQuantity(itemGame, "bag", "POTION", 42),
  "Bag editor changes an existing quantity")
eq(itemGame.save.inventory.POTION, 42, "Bag quantity editor stores 1-99")
check(not itemTools.addQuantity(itemGame, "bag", "TM_TEST", 1),
  "Bag editor refuses TMs")
check(not itemTools.setQuantity(itemGame, "bag", "BICYCLE", 2),
  "Bag editor refuses key-item quantity changes")
check(itemTools.addQuantity(itemGame, "pc", "ESCAPE_ROPE", 7),
  "PC editor creates a normal item stack")
eq(itemGame.save.pcItems.ESCAPE_ROPE, 7, "PC add quantity is exact")
check(itemTools.setQuantity(itemGame, "pc", "ESCAPE_ROPE", 99),
  "PC editor changes an existing quantity")
eq(itemGame.save.pcItems.ESCAPE_ROPE, 99, "PC quantity cap reaches 99")
check(not itemTools.addQuantity(itemGame, "pc", "ESCAPE_ROPE", 1),
  "PC editor refuses stacks above 99")
shared.linkBattleActive = true
check(not itemTools.setQuantity(itemGame, "bag", "POTION", 10),
  "Item quantity editing is inert during link play")
eq(itemGame.save.inventory.POTION, 42,
  "Link safety leaves the bag quantity unchanged")
shared.linkBattleActive = false
check(itemTools.addQuantity(itemGame, "bag", "ESCAPE_ROPE", 1),
  "Bag setup can add a second native item")
local stackItems = {}
itemGame.stack = {
  push = function(_, value) stackItems[#stackItems + 1] = value end,
  pop = function() return table.remove(stackItems) end,
  top = function() return stackItems[#stackItems] end,
}
local bagEditor = screens.BagMenu.new(itemGame, {})
bagEditor.onChoose(bagEditor.items[1], bagEditor)
local itemActions = itemGame.stack:top()
local hasQuantity = false
for _, row in ipairs(itemActions.items) do
  if row.label == "QUANTITY" then hasQuantity = true end
end
check(hasQuantity, "An ordinary bag item's USE/TOSS menu adds QUANTITY")
stackItems = {}
local emptyPocketGame = {
  save = { inventory = {}, pcItems = {}, money = 0 },
  data = itemGame.data,
  stack = itemGame.stack,
  input = { wasPressed = function(_, key) return key == "select" end },
}
local emptyPocketBag = screens.BagMenu.new(emptyPocketGame, {})
emptyPocketBag:update(0)
eq(emptyPocketGame.stack:top().title, "ADD ITEMS",
  "SELECT opens the add catalogue even when the current pocket is empty")
local pcItemEditor = screens[itemTools.itemEditorScreen].new(
  itemGame, { store = "pc" })
eq(pcItemEditor.title, "PC ITEMS", "PC item editor opens in the Items pocket")
eq(pcItemEditor.items[1].value, "ESCAPE_ROPE",
  "PC item editor projects existing editable stacks")
stackItems = {}
pcItemEditor.onChoose(pcItemEditor.items[1])
local pcActions = itemGame.stack:top()
local pcQuantity, pcRemove = false, false
for _, row in ipairs(pcActions.items) do
  if row.label == "QUANTITY" then pcQuantity = true end
  if row.label == "REMOVE" then pcRemove = true end
end
check(pcQuantity and pcRemove,
  "Existing PC stacks expose quantity and removal actions")
stackItems = {}
itemGame.input = { wasPressed = function(_, key) return key == "select" end }
pcItemEditor:update(0)
eq(itemGame.stack:top().title, "ADD ITEMS",
  "SELECT opens the active PC pocket's add catalogue")
local integratedPc = screens.SilverShadowPC.new(itemGame)
local integratedLabels = {}
for _, row in ipairs(integratedPc.items) do integratedLabels[row.label] = true end
check(integratedLabels["EDIT PC ITEMS"],
  "Start PC exposes the categorized PC item editor")

-- SilverShadow is the first normal Options row, every grouped menu wraps,
-- and compact labels leave room between the label and right-side value.
local optionRows = hooks["ui.options.rows"](function(_, list) return list end,
  {}, { { id = "vanilla", label = "TEXT SPEED" } })
eq(optionRows[1].id, "minimal_cheats", "SilverShadow heads normal Options")
for _, id in ipairs({
  "SilverShadowOptions", "SilverShadowBattle", "SilverShadowCapture",
  "SilverShadowWorld", "SilverShadowHealing", "SilverShadowSupplies",
  "SilverShadowMovement", "SilverShadowDisplay", "SilverShadowStorage",
  "SilverShadowFollowers",
}) do
  local def = screens[id]
  local menu = def.new({})
  check(menu.wrap == true, id .. " menu wraps at both ends")
end
local function labels(id)
  local found = {}
  for _, row in ipairs(screens[id].new({}).items) do found[row.label] = true end
  return found
end
local captureLabels = labels("SilverShadowCapture")
check(captureLabels["CATCH HEAL"], "Capture uses compact Catch Heal label")
local healingLabels = labels("SilverShadowHealing")
check(healingLabels["MAP HEAL"] and healingLabels["BATTLE HEAL"]
  and healingLabels["BOX HEAL"], "Healing labels fit beside values")
local displayLabels = labels("SilverShadowDisplay")
check(displayLabels["CAUGHT ICON"] and displayLabels["MAP BANNERS"],
  "Display labels fit beside values")
local movementLabels = labels("SilverShadowMovement")
for _, label in ipairs({ "FLY BOOST", "FLY HEIGHT", "TRAINER SIGHT",
                         "STORY GATES", "BADGE CHECK" }) do
  check(movementLabels[label], "Movement exposes " .. label)
end
local battleLabels = labels("SilverShadowBattle")
check(battleLabels["NO DRAWBACKS"],
  "Battle menu exposes the player-only move drawback toggle")

-- The menu count means Pokemon on screen when a Pokemon leads, but means
-- Pokemon behind the trainer when the trainer leads.
local plan = mod.exports.followersIntegration.followerPlan
local mode, count = plan("trainer", false, 0)
eq(mode, "follow", "Zero followers keeps the trainer in front")
eq(count, 0, "Zero followers produces a trainer-only composition")
mode, count = plan("trainer", false, 1)
eq(mode, "follow", "Trainer-front uses follow mode")
eq(count, 1, "Trainer-front count remains trailer count")
mode, count = plan("pokemon", false, 1)
eq(mode, "pokemon", "One Pokemon alone uses Pokemon mode")
eq(count, 0, "Lead Pokemon is included in displayed count")
mode, count = plan("pokemon", false, 0)
eq(mode, "pokemon", "Pokemon-front mode always retains its controlled lead")
eq(count, 0, "Pokemon-front zero normalizes to one visible lead")
mode, count = plan("pokemon", true, 1)
eq(mode, "lead_trainer", "Trainer can trail one lead Pokemon")
eq(count, 0, "Trainer trail does not force a second Pokemon")
mode, count = plan("pokemon", false, 5)
eq(count, 4, "Five Pokemon means lead plus four trailers")
mode, count = plan("pokemon", false, 6)
eq(count, 5, "Six Pokemon remains distinct from five")
shared.set("follower_mode", "pokemon")
shared.set("trainer_follows", false)
check(not mod.exports.freeFly.trainerRides(),
  "Pokemon lead with Trainer Trail off travels without the trainer")
shared.set("trainer_follows", true)
check(mod.exports.freeFly.trainerRides(),
  "Pokemon lead with Trainer Trail on keeps the trainer riding")
shared.set("follower_mode", "trainer")
shared.set("trainer_follows", false)
check(mod.exports.freeFly.trainerRides(),
  "Trainer-front mode always keeps the trainer riding")
local followerDecorator = false
local freeFlyDecorator
local fieldMovesDecorator
for _, entry in ipairs(shared.sortedPartyDecorators()) do
  if entry.id == "followers" then followerDecorator = true end
  if entry.id == "free_fly" then freeFlyDecorator = entry.decorate end
  if entry.id == "field_moves" then fieldMovesDecorator = entry.decorate end
end
check(not followerDecorator, "PokéPC exclusively owns the FOLLOWING party row")
check(type(freeFlyDecorator) == "function",
  "SilverShadow owns one coordinated FREEFLY party decorator")
check(type(fieldMovesDecorator) == "function",
  "SilverShadow owns one coordinated field-move party decorator")
saved.fly_badge_checks = false
local flyMon = { species = "PIDGEY", hp = 10, moves = { { id = "FLY" } } }
local flyMenu = freeFlyDecorator({
  save = { inventory = {} },
  data = { field = { outsideTilesets = { "OVERWORLD" } },
    pokemon = { PIDGEY = { types = { "FLYING" }, tmhm = { "FLY" } } } },
}, {}, flyMon, { overworld = {
  map = { def = { tileset = "OVERWORLD" } }, player = {},
} })
eq(flyMenu[1].label, "FREEFLY", "Eligible outdoor FLY user gets FREEFLY")

-- A move added through ALL MOVES is authoritative even when the species
-- could never naturally learn it. The same hacked FLY must unlock Free Fly,
-- ordinary town Fly, the Start -> HM parent, and airborne follower travel.
local hackedFlyMon = {
  species = "WEEDLE", hp = 10, moves = { { id = "FLY" } },
}
local hackedFlyGame = {
  save = { inventory = {}, party = { hackedFlyMon } },
  data = {
    field = { outsideTilesets = { "OVERWORLD" } },
    items = {}, text = {},
    pokemon = { WEEDLE = { types = { "BUG", "POISON" }, tmhm = {} } },
  },
}
local hackedFlyContext = { overworld = {
  map = { def = { tileset = "OVERWORLD" } }, player = {},
} }
local hackedFlyMenu = freeFlyDecorator(
  hackedFlyGame, {}, hackedFlyMon, hackedFlyContext)
hackedFlyMenu = fieldMovesDecorator(
  hackedFlyGame, hackedFlyMenu, hackedFlyMon, hackedFlyContext)
eq(#hackedFlyMenu, 2, "Hacked FLY exposes exactly two distinct travel actions")
eq(hackedFlyMenu[1].label, "FREEFLY", "Hacked FLY retains Free Fly")
eq(hackedFlyMenu[2].label, "FLY", "Hacked FLY exposes ordinary town Fly")
eq(mod.exports.freeFly.classify(hackedFlyGame, hackedFlyMon), "air",
  "Hacked FLY makes a ground species an airborne travel follower")
local hmFactory
for _, entry in ipairs(shared.sortedStartItems()) do
  if entry.id == "hm" then hmFactory = entry.factory end
end
check(type(hmFactory) == "function", "HM Start-menu factory is registered")
eq(hmFactory(hackedFlyGame), nil,
  "Edited FLY does not create the owned-HM Start menu")
local ownedFlyGame = {
  save = { inventory = { HM02 = 1 }, party = {} },
  data = { items = {
    HM02 = { machine = { kind = "HM", move = "FLY" } },
  } },
}
check(hmFactory(ownedFlyGame) ~= nil,
  "An actual HM02 item creates the Start HM menu")

local hackedSurfMon = {
  species = "WEEDLE", hp = 10, moves = { { id = "SURF" } },
}
local hackedSurfGame = {
  save = { inventory = {}, party = { hackedSurfMon } },
  data = {
    field = { outsideTilesets = { "OVERWORLD" } },
    items = {}, text = {},
    pokemon = { WEEDLE = { types = { "BUG", "POISON" }, tmhm = {} } },
  },
}
local hackedSurfMenu = fieldMovesDecorator(
  hackedSurfGame, {}, hackedSurfMon, hackedFlyContext)
eq(#hackedSurfMenu, 1, "Edited SURF exposes one field action without HM03")
eq(hackedSurfMenu[1].label, "SURF",
  "Edited SURF appears in Weedle's Pokemon submenu")
check(mod.exports.fieldCapable(hackedSurfGame, "SURF"),
  "Edited SURF grants actual field capability without HM03")
check(mod.exports.freeFly.surfAllowed(hackedSurfGame),
  "Edited SURF permits water travel when badge checks are off")
local editedSurfActivated = false
local hackedSurfOverworld = {
  player = { facingCell = function() return 4, 5 end },
  useSurfFieldMove = function() return "ok" end,
  trySurf = function(_, fx, fy)
    editedSurfActivated = fx == 4 and fy == 5
  end,
}
check(mod.exports.useEditedSurf(hackedSurfGame, hackedSurfOverworld),
  "Edited SURF executes without HM03 when badge checks are off")
check(editedSurfActivated,
  "Edited SURF reaches the engine's real surf mount path")

saved.fly_badge_checks = true
eq(#freeFlyDecorator(hackedFlyGame, {}, hackedFlyMon, hackedFlyContext), 0,
  "Badge check hides hacked Free Fly before the Thunder Badge")
eq(#fieldMovesDecorator(hackedFlyGame, {}, hackedFlyMon, hackedFlyContext), 0,
  "Badge check hides hacked town Fly before the Thunder Badge")
saved.fly_badge_checks = false

local followerMenu = screens.SilverShadowFollowers.new({})
local followerCountRow
for _, row in ipairs(followerMenu.items) do
  if row.label == "FOLLOWERS" then followerCountRow = row._silver end
end
check(followerCountRow ~= nil, "Followers menu exposes a count row")
eq(followerCountRow.values[1], 0, "Followers menu includes trainer-only zero")
shared.set("follower_mode", "pokemon")
shared.set("trainer_follows", true)
shared.applyFollowerCount({}, 0)
eq(saved.follower_mode, "trainer", "Zero followers switches to Trainer mode")
eq(saved.trainer_follows, false, "Zero followers disables Trainer Trail")
shared.applyFollowerMode({}, "pokemon")
eq(saved.follower_count, 1, "Pokemon mode restores its required visible lead")

local caughtX, caughtY, caughtRadius =
  mod.exports.display.caughtPosition(false, 8, false)
eq(caughtX, 24, "Classic caught icon sits before the level label")
eq(caughtY, 12, "Caught icon shares the level row")
eq(caughtRadius, 4, "Classic HUD uses a readable Poke Ball radius")
caughtX = mod.exports.display.caughtPosition(false, 24, false)
eq(caughtX, 24, "Level 100 does not move the classic caught icon")
caughtX, _, caughtRadius = mod.exports.display.caughtPosition(true, 24, false)
eq(caughtX, 80, "Wide caught icon sits before the level label")
eq(caughtRadius, 3, "Wide HUD shrinks the Poke Ball to stay contained")

-- A staged battle embeds the icon in Dramatic Shape's HUD texture. The
-- regular centered overlay then suppresses its duplicate.
local previousLove = love
local previousFont = package.loaded["src.render.Font"]
package.loaded["src.render.Font"] = {
  width = function(value) return #tostring(value) * 8 end,
}
local activeCanvas, embeddedBalls, redDraws, whiteDraws = nil, 0, 0, 0
love = { graphics = {
  getCanvas = function() return activeCanvas end,
  setCanvas = function(value) activeCanvas = value end,
  getBlendMode = function() return "alpha", "alphamultiply" end,
  setBlendMode = function() end,
  getShader = function() return nil end,
  setShader = function() end,
  getColor = function() return 1, 1, 1, 1 end,
  setColor = function(r, green, blue)
    if r == 0.88 and green == 0.08 and blue == 0.08 then
      redDraws = redDraws + 1
    elseif r == 1 and green == 1 and blue == 1
        and activeCanvas == fakeHudLayer then
      whiteDraws = whiteDraws + 1
    end
  end,
  circle = function(mode, x)
    if activeCanvas == fakeHudLayer and mode == "fill" then
      embeddedBalls = embeddedBalls + 1
      eq(x, 24, "Dramatic Shape embeds the Poke Ball before the level")
    end
  end,
  line = function() end,
  polygon = function() end,
  push = function() end,
  pop = function() end,
} }
local stagedBattle = {
  kind = "wild", enemy = { mon = { level = 100 }, fainted = false },
  game = { save = { pokedex = { owned = { RATTATA = true } } } },
  wideLayout = function() return false end,
}
emit("battle.started", { battle = stagedBattle, species = "RATTATA" })
check(fakeOverworldBattle.snapHUDs(stagedBattle, {}),
  "Dramatic Shape HUD snapshot succeeds")
hooks["battle.overlay"](function() end, stagedBattle)
eq(embeddedBalls, 4, "Centered overlay does not duplicate embedded Poke Ball")
eq(redDraws, 1, "Caught Poke Ball has one red upper-half pass")
check(whiteDraws >= 2, "Caught Poke Ball has a white lower half and button")
love = previousLove
package.loaded["src.render.Font"] = previousFont

-- Gen1Recomp's updater accepts SilverShadow's friendly release asset name
-- even though the internal mod id remains minimal_cheats.
local ModUpdate = require("src.mods.ModUpdate")
local release = assert(ModUpdate.parseRelease({
  tag_name = "v2.1.6",
  assets = { {
    name = "silvershadow-mods-v2.1.6.zip",
    browser_download_url = "https://example.invalid/silvershadow.zip",
    size = 123,
  } },
}, "minimal_cheats"))
eq(release.version, "2.1.6", "Updater reads SilverShadow release version")
eq(release.zip.name, "silvershadow-mods-v2.1.6.zip",
  "Updater selects SilverShadow release ZIP")

-- Existing cheat modes and link safeguards.
for _, factor in ipairs(shared.EXP_MULTIPLIERS) do
  saved.exp_multiplier = factor
  eq(hooks["exp.gain"](function() return 17 end, {}), 17 * factor,
    "EXP multiplier x" .. factor)
end
saved.damage_multiplier = 4
eq(hooks["battle.damage"](function() return 7, "info" end,
  { user = { isPlayer = true }, target = { isPlayer = false, mon = { hp = 50 } } }), 28,
  "damage multiplier")
saved.damage_multiplier = "OHKO"
eq(hooks["battle.damage"](function() return 7 end,
  { user = { isPlayer = true }, target = { isPlayer = false, mon = { hp = 50 } } }), 50,
  "OHKO damage")
saved.infinite_hp = true
eq(hooks["battle.damage"](function() return 7 end,
  { user = { isPlayer = false }, target = { isPlayer = true } }), 0, "infinite HP")
saved.always_hit = true
check(hooks["battle.accuracy"](function() return false end,
  { user = { isPlayer = true }, target = { isPlayer = false } }), "always hit")
saved.always_escape = true
check(hooks["battle.run"](function() return false end, {}), "always escape")
saved.guaranteed_catch = true
local caught, shakes = hooks["catch.rate"](function() return false, 0 end)
check(caught and shakes == 3, "guaranteed catch")
saved.no_encounters = true
eq(hooks["encounter.roll"](function() return { species = "RATTATA" } end), nil,
  "random encounters disabled")
local link = { kind = "link" }
eq(hooks["battle.damage"](function() return 7 end,
  { battle = link, user = { isPlayer = false }, target = { isPlayer = true } }), 7,
  "link damage stays vanilla")
emit("battle.started", { battle = link })
check(shared.online(), "link session lock starts")
emit("battle.ended", { kind = "link", battle = link })
check(not shared.online(), "link session lock clears")

-- Supplies respect the 999 distinct-stack capacity and 99 quantity cap.
saved.pc_rare_candy = true
local game = { save = { pcItems = {}, coins = 0 }, data = {
  field = { pcItemCap = 999 }, items = { RARE_CANDY = {} },
} }
check(mod.exports.ensureRareCandy(game), "Rare Candy can be stocked")
eq(game.save.pcItems.RARE_CANDY, 99, "Rare Candy restock target")
game.save.pcItems.RARE_CANDY = 120
mod.exports.ensureRareCandy(game)
eq(game.save.pcItems.RARE_CANDY, 120, "Rare Candy never reduces larger stack")
check(shared.maxCoins(game), "Max Coins action succeeds")
eq(game.save.coins, 9999, "Max Coins value")

-- Unified movement matrix, B inversion, player-only scope, and 4-frame floor.
local function speed(state, factor, held, kind, player)
  saved.move_boost = factor
  saved.foot_boost, saved.bike_boost, saved.surf_boost = "OFF", "OFF", "OFF"
  saved[kind .. "_boost"] = state
  local avatar = player or { moving = true }
  avatar.freeFlying = kind == "fly" or nil
  local ctx = { player = avatar, onBike = kind == "bike", surfing = kind == "surf",
    input = { isDown = function(_, key) return key == "b" and held end } }
  return hooks["movement.speed"](function(frames) return frames end, 16, ctx), avatar
end
for _, kind in ipairs({ "foot", "bike", "surf", "fly" }) do
  for _, factor in ipairs(shared.MOVE_MULTIPLIERS) do
    local expected = math.max(4, math.floor(16 / factor + 0.5))
    eq(speed("OFF", factor, true, kind), 16, kind .. " OFF")
    eq(speed("ON", factor, false, kind), expected, kind .. " ON")
    eq(speed("ON", factor, true, kind), 16, kind .. " ON+B")
    eq(speed("HOLD", factor, false, kind), 16, kind .. " HOLD")
    eq(speed("HOLD", factor, true, kind), expected, kind .. " HOLD+B")
  end
end
local nonPlayer = { moving = true }
local ctx = { player = false, input = { isDown = function() return true end } }
eq(hooks["movement.speed"](function() return 16 end, 16, ctx), 16, "NPC untouched")
local boosted, avatar = speed("ON", 4, false, "foot")
avatar.stepFramesCur = boosted
emit("script.started")
eq(avatar.stepFramesCur, 16, "script movement restores vanilla duration")

-- Healing helpers and move-memory evolutionary reconstruction.
local poisoned = { { hp = 1, status = "PSN" }, { hp = 5, status = "PSN" } }
eq(#mod.exports.healing.poisonClamp(poisoned, 1), 1, "Poison Save catches lethal tick")
eq(poisoned[1].hp, 1, "Poison Save leaves one HP")
local moveGame = { data = { pokemon = {
  CATERPIE = { evolutions = { { species = "METAPOD" } },
    level1Moves = { "TACKLE", "STRING_SHOT" }, learnset = {} },
  METAPOD = { evolutions = { { species = "BUTTERFREE" } },
    level1Moves = { "HARDEN" }, learnset = {} },
  BUTTERFREE = { evolutions = {}, level1Moves = {},
    learnset = { { level = 10, move = "CONFUSION" }, { level = 20, move = "WHIRLWIND" } } },
}, moves = {
  TACKLE = { name = "Tackle", type = "NORMAL", power = 40,
    effect = "NO_ADDITIONAL_EFFECT", pp = 35 },
  EXPLOSION = { name = "Explosion", type = "NORMAL", power = 170,
    effect = "EXPLODE_EFFECT", pp = 5 },
  HYPER_BEAM = { name = "Hyper Beam", type = "NORMAL", power = 150,
    effect = "HYPER_BEAM_EFFECT", pp = 5 },
  COUNTER = { name = "Counter", type = "FIGHTING", power = 0,
    effect = "COUNTER_EFFECT", pp = 20 },
  SOLARBEAM = { name = "SolarBeam", type = "GRASS", power = 120,
    effect = "CHARGE_EFFECT", pp = 10 },
  WATERFALL = { name = "Waterfall", type = "WATER", power = 80,
    effect = "NO_ADDITIONAL_EFFECT", pp = 15 },
  THUNDER_WAVE = { name = "Thunder Wave", type = "ELECTRIC", power = 0,
    effect = "PARALYZE_EFFECT", pp = 20 },
  METRONOME = { name = "Metronome", type = "NORMAL", power = 0,
    effect = "METRONOME_EFFECT", pp = 10 },
} } }
local butterfree = { species = "BUTTERFREE", level = 12, moves = {} }
local learned = mod.exports.learnedMoves(moveGame, butterfree)
eq(table.concat(learned, ","), "TACKLE,STRING_SHOT,HARDEN,CONFUSION",
  "Butterfree remembers legitimate evolutionary-line moves")
local allMoves = mod.exports.allMoves
local covered, missing, total = allMoves.coverage(moveGame)
check(covered and missing == nil and total == 8,
  "All Moves assigns every registered move exactly once")
local physicalNormal = allMoves.rows(moveGame, "physical", "NORMAL")
eq(table.concat((function()
  local out = {}; for _, row in ipairs(physicalNormal) do out[#out + 1] = row.id end
  return out
end)(), ","), "EXPLOSION,HYPER_BEAM,TACKLE",
  "Caterpie can browse every alphabetical Normal attack")
eq(select(1, allMoves.branch(moveGame.data.moves.COUNTER)), "physical",
  "zero-power Counter remains a damaging Physical move")
local specialWater = allMoves.rows(moveGame, "special", "WATER")
eq(specialWater[1].id, "WATERFALL",
  "Gen I Waterfall remains available as a regular Water battle move")
local section, group = allMoves.branch(moveGame.data.moves.THUNDER_WAVE)
eq(section .. "/" .. group, "status/major",
  "Thunder Wave is grouped under Major Status")
section, group = allMoves.branch(moveGame.data.moves.METRONOME)
eq(section .. "/" .. group, "status/utility",
  "Metronome remains reachable under Utility/Other")

-- Player-owned levels extend cleanly through the byte-sized cap while using
-- a constant 99->100 EXP step above level 100.
local levelGame = { data = { constants = {}, growth_rates = nil, pokemon = {
  CATERPIE = { name = "Caterpie", growthRate = "MEDIUM_FAST", baseStats = {
    hp = 45, attack = 30, defense = 35, speed = 45, special = 20,
  } },
} }, save = { party = {}, boxes = {} } }
local levelMon = { species = "CATERPIE", level = 100,
  exp = 1000000, hp = 100, stats = { hp = 100 },
  dvs = {}, statExp = {}, moves = {} }
levelGame.save.party[1] = levelMon
shared.game = levelGame
local extended = mod.exports.extendedLevels
check(extended.setLevel(levelGame, levelMon, 101, true),
  "DV/EV level editor can set level 101")
eq(levelMon.level, 101, "player Pokemon level exceeds 100")
local step = extended.expForLevel("MEDIUM_FAST", 100)
  - extended.expForLevel("MEDIUM_FAST", 99)
eq(extended.expForLevel("MEDIUM_FAST", 101)
  - extended.expForLevel("MEDIUM_FAST", 100), step,
  "post-100 EXP uses the 99->100 requirement")
extended.setLevel(levelGame, levelMon, 999, true)
eq(levelMon.level, 255, "extended level is safely capped at 255")
emit("save.writing", { save = levelGame.save })
eq(levelMon.silverExtendedLevel, 255, "extended level persists beside vanilla data")
levelMon.level = 100
emit("save.loaded", { save = levelGame.save })
eq(levelMon.level, 255, "extended level is restored after vanilla validation")
extended.setLevel(levelGame, levelMon, 100, true)
levelGame.data.constants.levelCap = 255
levelMon.exp = extended.expForLevel("MEDIUM_FAST", 101) - 1
local levels = require("src.battle.Experience").apply(levelGame.data, levelMon, {
  baseExp = 7, baseStats = { hp = 1, attack = 1, defense = 1, speed = 1,
    special = 1 },
}, 1, false, 1, false)
eq(levels[1], 101, "ordinary battle EXP levels a player Pokemon past 100")
levelMon.level = 255
eq(hooks["exp.gain"](function() return 99 end, { mon = levelMon }), 0,
  "level 255 Pokemon stop accumulating experience")
levelMon.level = 101

-- Infinite HP always protects against player Selfdestruct/Explosion; the new
-- toggle provides the same protection even when Infinite HP is off.
local BattleState = require("src.battle.BattleState")
local selfKoBattle = setmetatable({ kind = "wild",
  onFaint = function(_, battler) battler.fainted = true end }, { __index = BattleState })
local selfKoUser = { isPlayer = true, mon = { hp = 50 } }
saved.infinite_hp, saved.no_move_drawbacks = true, false
selfKoBattle:selfDestruct(selfKoUser)
eq(selfKoUser.mon.hp, 50, "Infinite HP blocks Explosion self-KO")
saved.infinite_hp, saved.no_move_drawbacks = false, true
selfKoBattle:selfDestruct(selfKoUser)
eq(selfKoUser.mon.hp, 50, "No Drawbacks blocks Explosion self-KO")

-- DexNav reads the final live table, omits caught species, and never calls
-- encounter.roll (so NO ENCOUNTERS cannot block an explicit request).
local dexGame = { save = { pokedex = { owned = { PIDGEY = true } } }, data = {
  pokemon = { PIDGEY = {}, MEW = {} }, constants = { encounterBuckets = { 100, 200 } },
  encounters = { ROUTE_1 = { grass = { rate = 20, slots = {
    { species = "PIDGEY", level = 3 }, { species = "MEW", level = 5 },
  } } } },
} }
local rows = mod.exports.candidates(dexGame, { map = { id = "ROUTE_1" }, player = {} })
eq(#rows, 1, "DexNav filters caught species")
eq(rows[1].species, "MEW", "DexNav sees patched live encounter")

local hmGame = { save = { inventory = {
  HM03 = 1, SOULBADGE = 1, OLD_ROD = 1, GOOD_ROD = 1, SUPER_ROD = 1,
} }, data = { items = {
  HM03 = { machine = { kind = "HM", move = "SURF" } },
} } }
check(mod.exports.ownedHM(hmGame, "SURF"), "HM item grants field move without teaching")
check(mod.exports.hasBadge(hmGame, "SURF"), "HM badge requirement is retained")
eq(mod.exports.bestRod(hmGame), "SUPER_ROD", "fishing chooses best owned rod")
hmGame.save.inventory.SOULBADGE = nil
check(not mod.exports.hasBadge(hmGame, "SURF"), "missing badge blocks field move")
saved.fly_badge_checks = true
check(not shared.travelBadgeAllowed(hmGame, "SURF"),
  "BADGE CHECK ON requires the Soul Badge for Surf")
check(not mod.exports.freeFly.surfAllowed(hmGame),
  "Free Fly water landing shares the enabled Surf badge check")
saved.fly_badge_checks = false
check(shared.travelBadgeAllowed(hmGame, "SURF"),
  "BADGE CHECK OFF permits Surf with owned HM03")
check(mod.exports.freeFly.surfAllowed(hmGame),
  "Free Fly water landing shares the disabled Surf badge check")

-- Free Fly uses the shared movement multiplier and classifies only safe
-- temporary travel companions. Surf-capable followers stay locked until HM03
-- has actually been obtained.
local travelGame = { save = { inventory = { HM03 = 1 } }, data = {
  items = { HM03 = { machine = { kind = "HM", move = "SURF" } } },
  pokemon = {
    PIDGEY = { types = { "NORMAL", "FLYING" }, tmhm = { "FLY" } },
    ABRA = { types = { "PSYCHIC" } },
    GASTLY = { types = { "GHOST", "POISON" } },
    SQUIRTLE = { types = { "WATER" } },
    CATERPIE = { types = { "BUG" } },
    WEEDLE = { types = { "BUG", "POISON" } },
  },
} }
local classify = mod.exports.freeFly.classify
eq(classify(travelGame, { species = "PIDGEY" }), "air",
  "Flying followers join an airborne formation")
eq(classify(travelGame, { species = "ABRA" }), "hover",
  "Psychic followers may hover")
eq(classify(travelGame, { species = "GASTLY" }), "hover",
  "Ghost followers may hover")
eq(classify(travelGame, { species = "SQUIRTLE" }), "surf",
  "Water followers may swim after Surf is obtained")
eq(classify(travelGame, { species = "CATERPIE" }), nil,
  "Ground-only followers return to their Poke Balls")
eq(classify(travelGame, { species = "CATERPIE" }, "fly", false, true),
  "ground", "Ground-only followers run while Free Fly is over walkable land")
eq(classify(travelGame, { species = "CATERPIE" }, "fly", false, false),
  nil, "Ground-only followers hide over blocked terrain")
local editedSurfer = {
  species = "WEEDLE", moves = { { id = "SURF" } },
}
local editedDualTraveler = {
  species = "WEEDLE", moves = { { id = "FLY" }, { id = "SURF" } },
}
eq(classify(travelGame, editedSurfer, "surf", true), "surf",
  "Edited SURF makes Weedle a swimming follower")
eq(classify(travelGame, editedDualTraveler, "fly", true), "air",
  "A dual edited traveler flies during Free Fly")
eq(classify(travelGame, editedDualTraveler, "surf", true), "surf",
  "A dual edited traveler swims during Surf")
travelGame.save.inventory.HM03 = nil
eq(classify(travelGame, { species = "SQUIRTLE" }), nil,
  "Water followers wait until Surf is obtained")
eq(classify(travelGame, editedSurfer, "surf", true), "surf",
  "A Pokemon that actually knows SURF remains an edited swimmer without HM03")
check(mod.exports.freeFly.eligible(travelGame, {
  species = "PIDGEY", hp = 10, moves = { { id = "FLY" } },
}), "A healthy FLY knower offers FREEFLY")

-- SELECT arbitration wraps an existing handler. Controller and virtual/touch
-- SELECT are consumed in free roam; non-SELECT input (including keyboard 3)
-- and unsafe/scripted movement consumes SELECT without moving the voxel camera.
local dexEvents, originalCalls, queued, selectPressed = {}, 0, 0, false
local dexMod = {
  id = "minimal_cheats", exports = {},
  commands = { register = function() end },
  events = { on = function(_, name, fn) dexEvents[name] = fn end },
  log = mod.log,
  world = { queueScript = function() queued = queued + 1; return true end },
}
local dexInstaller = assert(loadfile("modules/dexnav.lua"))()
dexInstaller(dexMod)
local host = {
  map = { id = "ROUTE_1" }, player = { moving = false }, scriptMoves = {},
  handleInput = function() originalCalls = originalCalls + 1 end,
}
local dexInput = { wasPressed = function(_, key) return key == "select" and selectPressed end }
local dexSelectGame = {
  input = dexInput, overworld = host,
  mods = { exports = { minimal_cheats = dexMod.exports } },
  save = { party = { { hp = 10 } }, pokedex = { owned = {} } },
  data = dexGame.data,
}
dexEvents["game.ready"]({ game = dexSelectGame })
selectPressed = true
host:handleInput()
eq(queued, 1, "controller SELECT triggers DexNav")
eq(originalCalls, 0, "free-roam SELECT is not forwarded to Voxel")
selectPressed = false
host:handleInput()
eq(originalCalls, 1, "keyboard 3/non-SELECT still reaches Voxel")
selectPressed = true
host.player.inputLocked = true
host:handleInput()
eq(originalCalls, 1, "locked overworld SELECT is not forwarded to Voxel")
eq(queued, 1, "locked overworld SELECT does not start DexNav")
host.player.inputLocked = false
host.player.moving = true
host:handleInput()
eq(originalCalls, 1, "moving SELECT is not forwarded to Voxel")
eq(queued, 1, "moving SELECT waits until the player stops")
host.player.moving = false
host:handleInput()
eq(queued, 2, "virtual touch SELECT uses the DexNav path")

print(("SilverShadow headless regression tests: %d passed"):format(passed))
