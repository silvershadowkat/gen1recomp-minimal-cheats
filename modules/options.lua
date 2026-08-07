local mod, shared = ...

local ROOT = "SilverShadowOptions"
local SCREENS = {
  battle = "SilverShadowBattle", capture = "SilverShadowCapture",
  world = "SilverShadowWorld", healing = "SilverShadowHealing",
  supplies = "SilverShadowSupplies", movement = "SilverShadowMovement",
  display = "SilverShadowDisplay", storage = "SilverShadowStorage",
  followers = "SilverShadowFollowers",
}

local function toggle(label, key, default, after)
  return { label = label, kind = "toggle", key = key, default = default,
    right = function() return shared.bool(key, default) and "ON" or "OFF" end,
    after = after }
end

local function choice(label, key, values, default, display, after)
  return { label = label, kind = "choice", key = key, values = values,
    default = default, display = display, after = after,
    right = function()
      local value = shared.allowed(key, values, default)
      return display and display(value) or tostring(value)
    end }
end

local function action(label, run)
  return { label = label, kind = "action", run = run, right = "SET" }
end

local function screen(label, target)
  return { label = label, kind = "screen", target = target, right = "OPEN" }
end

local function rightValue(item)
  return type(item.right) == "function" and item.right() or item.right
end

local function rows(items)
  local out = {}
  for _, item in ipairs(items) do
    out[#out + 1] = {
      label = item.label, right = rightValue(item), _silver = item,
    }
  end
  return out
end

local function makeMenu(game, title, items, footer)
  local list
  list = mod.ui.ListMenu.new(game, title, rows(items), {
    rows = 6,
    footer = footer or "A:CHANGE  B:BACK",
    onChoose = function(row)
      local item = row._silver
      if item.kind == "toggle" then
        local value = not shared.bool(item.key, item.default)
        shared.set(item.key, value)
        if item.after then item.after(game, value, list) end
      elseif item.kind == "choice" then
        local value = shared.cycle(item.key, item.values, item.default)
        if item.after then item.after(game, value, list) end
      elseif item.kind == "screen" then
        mod.ui.push(game, item.target)
      elseif item.kind == "action" then
        item.run(game, list)
      end
      row.right = rightValue(item)
    end,
  })
  return list
end

local function multiplier(value)
  if value == "OHKO" then return value end
  return "x" .. tostring(value)
end

local menuDefs = {
  battle = function()
    return {
      toggle("INFINITE HP", "infinite_hp", false),
      toggle("INFINITE PP", "infinite_pp", false),
      choice("EXP RATE", "exp_multiplier", shared.EXP_MULTIPLIERS, 1, multiplier),
      choice("DAMAGE", "damage_multiplier", shared.DAMAGE_MODES, 1, multiplier),
      toggle("ALWAYS HIT", "always_hit", false),
      toggle("ALWAYS CRIT", "always_crit", false),
      toggle("ALWAYS FIRST", "always_first", false),
      toggle("ALWAYS ESCAPE", "always_escape", false),
    }
  end,
  capture = function()
    return {
      toggle("100% CATCH", "guaranteed_catch", false),
      toggle("ENDLESS BALLS", "unlimited_balls", false),
      toggle("FULL HEAL CATCH", "catch_heal", false),
      toggle("PERFECT DVS", "perfect_dvs", false),
    }
  end,
  world = function()
    return {
      toggle("NO ENCOUNTERS", "no_encounters", false),
      toggle("LIGHTS ON", "lights_on", false, function(game)
        if shared.refreshLights then shared.refreshLights(game) end
      end),
    }
  end,
  healing = function()
    return {
      toggle("POISON SAVE", "poison_save", false),
      toggle("HEAL ON MAP CHANGE", "heal_map_change", false),
      toggle("HEAL AFTER BATTLE", "heal_battle", false),
      toggle("BOX HEALS", "box_heals", false),
    }
  end,
  supplies = function()
    return {
      toggle("PC RARE CANDY", "pc_rare_candy", false, function(game, value, list)
        if value and shared.ensureRareCandy and not shared.ensureRareCandy(game) then
          list.footer = "PC is full; free one item slot."
        end
      end),
      action("MAX GAME COINS", function(game, list)
        if shared.maxCoins(game) then list.footer = "Game Corner coins set to 9999."
        else list.footer = "Unavailable during online/link play." end
      end),
    }
  end,
  movement = function()
    return {
      choice("MOVE BOOST", "move_boost", shared.MOVE_MULTIPLIERS, 2, multiplier),
      choice("FOOT BOOST", "foot_boost", shared.BOOST_STATES, "ON"),
      choice("BIKE BOOST", "bike_boost", shared.BOOST_STATES, "OFF"),
      choice("SURF BOOST", "surf_boost", shared.BOOST_STATES, "OFF"),
    }
  end,
  display = function()
    return {
      toggle("XP BAR", "xp_bar", true),
      toggle("CAUGHT INDICATOR", "caught_indicator", true),
      toggle("LOCATION BANNERS", "location_banners", true),
    }
  end,
  storage = function()
    return {
      choice("BOX GRID", "box_grid", { "classic", "big" }, "classic",
        function(v) return tostring(v):upper() end),
      toggle("CURSOR WRAP", "cursor_wrap", true),
    }
  end,
  followers = function()
    return {
      choice("MODE", "follower_mode", { "trainer", "pokemon" }, "trainer",
        function(v) return tostring(v):upper() end,
        function(game, value) if shared.applyFollowerMode then shared.applyFollowerMode(game, value) end end),
      toggle("TRAINER FOLLOWS", "trainer_follows", false,
        function(game, value) if shared.applyTrainerFollows then shared.applyTrainerFollows(game, value) end end),
      choice("FOLLOWER COUNT", "follower_count", { 1, 2, 3, 4, 5, 6 }, 1,
        tostring, function(game, value)
          if shared.applyFollowerCount then shared.applyFollowerCount(game, value) end
        end),
    }
  end,
}

mod.content.screens:register(ROOT, { new = function(game)
  local items = {
    screen("BATTLE", SCREENS.battle), screen("CAPTURE", SCREENS.capture),
    screen("WORLD", SCREENS.world), screen("HEALING", SCREENS.healing),
    screen("SUPPLIES", SCREENS.supplies), screen("MOVEMENT", SCREENS.movement),
    screen("DISPLAY", SCREENS.display), screen("STORAGE", SCREENS.storage),
  }
  if shared.followersAvailable and shared.followersAvailable(game) then
    items[#items + 1] = screen("FOLLOWERS", SCREENS.followers)
  end
  return makeMenu(game, "SILVERSHADOW", items, "A:OPEN  B:BACK")
end })

for key, id in pairs(SCREENS) do
  local menuKey, screenId = key, id
  mod.content.screens:register(screenId, { new = function(game)
    return makeMenu(game, menuKey:upper(), menuDefs[menuKey]())
  end })
end

-- One normal Options row, as requested.
mod.hooks:wrap("ui.options.rows", function(next, game, current)
  local out = next(game, current)
  if type(out) ~= "table" then return out end
  out[#out + 1] = {
    id = "minimal_cheats", label = "SILVERSHADOW",
    value = function() return "OPEN" end,
    activate = function(g) mod.ui.push(g, ROOT) end,
  }
  return out
end)

shared.optionsScreen = ROOT
