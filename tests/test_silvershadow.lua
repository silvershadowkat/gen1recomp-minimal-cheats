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

local saved, hooks, events = {}, {}, {}
local mod = {
  id = "minimal_cheats", path = ".", exports = {},
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn)
    events[name] = events[name] or {}; events[name][#events[name] + 1] = fn
  end },
  content = {
    balls = { each = function() return function() return nil end end },
    screens = { register = function() end },
  },
  commands = { register = function() end },
  ui = {
    push = function() end,
    insertAfter = function(rows, _, item) rows[#rows + 1] = item end,
  },
  log = {
    info = function() end, warn = function() end,
    error = function() end,
  },
  find = function() return nil end,
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
install("modules/cheats.lua", mod, shared)
install("modules/movement.lua", mod, shared)
install("modules/healing.lua", mod, shared)
install("modules/moves_manager.lua", mod, shared)
install("modules/dexnav.lua", mod, shared)
install("modules/field_moves.lua", mod, shared)

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
  local ctx = { player = avatar, onBike = kind == "bike", surfing = kind == "surf",
    input = { isDown = function(_, key) return key == "b" and held end } }
  return hooks["movement.speed"](function(frames) return frames end, 16, ctx), avatar
end
for _, kind in ipairs({ "foot", "bike", "surf" }) do
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
}, moves = {} } }
local butterfree = { species = "BUTTERFREE", level = 12, moves = {} }
local learned = mod.exports.learnedMoves(moveGame, butterfree)
eq(table.concat(learned, ","), "TACKLE,STRING_SHOT,HARDEN,CONFUSION",
  "Butterfree remembers legitimate evolutionary-line moves")

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

-- SELECT arbitration wraps an existing handler. Controller and virtual/touch
-- SELECT are consumed in free roam; non-SELECT input (including keyboard 3)
-- and unsafe/scripted contexts continue to the existing handler unchanged.
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
eq(originalCalls, 2, "unsafe/battle/menu SELECT is not stolen")
host.player.inputLocked = false
host:handleInput()
eq(queued, 2, "virtual touch SELECT uses the DexNav path")

print(("SilverShadow headless regression tests: %d passed"):format(passed))
