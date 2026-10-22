local mod, shared = ...

local ROOT = "SilverShadowGen2Options"
local SCREENS = {
  battle = "SilverShadowGen2Battle",
  pokemon = "SilverShadowGen2Pokemon",
  healing = "SilverShadowGen2Healing",
  movement = "SilverShadowGen2Movement",
  followers = "SilverShadowGen2Followers",
}

local function toggle(label, key, default, after)
  return { label = label, kind = "toggle", key = key, default = default,
    after = after,
    right = function() return shared.bool(key, default) and "ON" or "OFF" end }
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
  return { label = label, kind = "action", run = run, right = "OPEN" }
end

local function screen(label, target)
  return { label = label, kind = "screen", target = target, right = "OPEN" }
end

local function rightValue(item)
  return type(item.right) == "function" and item.right() or item.right
end

local function makeMenu(game, title, items)
  local rows = {}
  for _, item in ipairs(items) do
    rows[#rows + 1] = { label = item.label, right = rightValue(item), _silver = item }
  end
  local list
  list = mod.ui.ListMenu.new(game, title, rows, {
    rows = 6, wrap = true, footer = "A:CHANGE  B:BACK",
    onChoose = function(row)
      local item = row._silver
      if item.kind == "toggle" then
        local value = not shared.bool(item.key, item.default)
        shared.set(item.key, value)
        if item.after then item.after(game, value) end
      elseif item.kind == "choice" then
        local value = shared.cycle(item.key, item.values, item.default)
        if item.after then item.after(game, value) end
      elseif item.kind == "screen" then
        mod.ui.push(game, item.target)
      elseif item.kind == "action" then
        item.run(game)
      end
      for _, visible in ipairs(list.items) do
        visible.right = rightValue(visible._silver)
      end
    end,
  })
  return list
end

local function multiplier(value)
  return value == "OHKO" and value or "x" .. tostring(value)
end

local defs = {
  battle = function()
    return {
      toggle("MODERN HUD", "modern_battle_hud", true),
      toggle("MODERN EVOLUTION", "modern_evolution_screen", true),
      toggle("INSTANT TEXT", "instant_text", true),
      choice("EXP MULT", "exp_multiplier", shared.EXP_MULTIPLIERS, 1, multiplier),
      choice("DAMAGE", "damage_multiplier", shared.DAMAGE_MODES, 1, multiplier),
      toggle("HP NEVER 0", "infinite_hp", false),
      toggle("PP NEVER 0", "infinite_pp", false),
      toggle("NO BALL LOSS", "unlimited_balls", false),
      toggle("HIT ALWAYS", "always_hit", false),
      toggle("CRIT ALWAYS", "always_crit", false),
      toggle("MOVE FIRST", "always_first", false),
      toggle("ESCAPE ALL", "always_escape", false),
      toggle("CATCH ALL", "guaranteed_catch", false),
      toggle("NO WILDS", "no_encounters", false),
    }
  end,
  pokemon = function()
    return {
      toggle("HM DEVICE", "hm_device", true),
      toggle("REUSABLE TMS", "reusable_tms", true),
      toggle("UNCAUGHT AREA", "all_251_catchable", true),
      toggle("PC RARE CANDY", "pc_rare_candy", false),
      action("MAX COINS", function(game) shared.maxCoins(game) end),
    }
  end,
  healing = function()
    return {
      toggle("CATCH MAX DVS", "perfect_dvs", false),
      toggle("HEAL CATCH", "catch_heal", false),
      toggle("BATTLE HEAL", "heal_battle", false),
      toggle("MAP HEAL", "heal_map_change", false),
      action("HEAL NOW", function(game) shared.healParty(game) end),
    }
  end,
  movement = function()
    return {
      choice("MOVE SPEED", "move_boost", shared.MOVE_MULTIPLIERS, 2, multiplier),
      choice("FOOT BOOST", "foot_boost", shared.BOOST_STATES, "ON"),
      choice("BIKE BOOST", "bike_boost", shared.BOOST_STATES, "OFF"),
      choice("SURF BOOST", "surf_boost", shared.BOOST_STATES, "OFF"),
      choice("FLY BOOST", "fly_boost", shared.BOOST_STATES, "ON"),
      choice("FLY HEIGHT", "fly_height", shared.FLY_HEIGHTS, "MED"),
      toggle("TRAINER SIGHT", "fly_trainer_sight", false),
      toggle("STORY GATES", "fly_story_gates", true),
      toggle("BADGE CHECK", "fly_badge_checks", true),
    }
  end,
  followers = function()
    return {
      choice("MODE", "follower_mode", { "trainer", "pokemon" }, "trainer",
        function(value) return value:upper() end,
        function(game, value) shared.applyFollowerMode(game, value) end),
      toggle("TRAINER TRAIL", "trainer_follows", false,
        function(game, value) shared.applyTrainerFollows(game, value) end),
      choice("FOLLOWERS", "follower_count", { 0, 1, 2, 3, 4, 5, 6 }, 1,
        tostring, function(game, value) shared.applyFollowerCount(game, value) end),
    }
  end,
}

shared.modDeckMenus = defs
local rootItems = {
  screen("BATTLE", SCREENS.battle),
  screen("POKEMON", SCREENS.pokemon),
  screen("HEALING", SCREENS.healing),
  screen("MOVEMENT", SCREENS.movement),
}

mod.content.screens:register(ROOT, {
  new = function(game)
    local items = {}
    for _, item in ipairs(rootItems) do items[#items + 1] = item end
    if shared.followersAvailable and shared.followersAvailable(game) then
      items[#items + 1] = screen("FOLLOWERS", SCREENS.followers)
    end
    return makeMenu(game, "SILVERSHADOW", items)
  end,
})

for key, id in pairs(SCREENS) do
  mod.content.screens:register(id, {
    new = function(game) return makeMenu(game, key:upper(), defs[key]()) end,
  })
end

-- Gold/Silver/Crystal use the same post-hook category grouping as Gen 1, so
-- restore the two SilverShadow rows to the head of the finished top-level
-- view after that grouping pass.
local TOP_OPTION_IDS = { "minimal_cheats", "silvershadow_lcd:settings" }
local function promoteOptionsView(menu)
  local view = menu and menu.view
  if type(view) ~= "table" then return menu end
  local found = {}
  for i = #view, 1, -1 do
    local id = view[i] and view[i].id
    for rank, wanted in ipairs(TOP_OPTION_IDS) do
      if id == wanted then found[rank] = table.remove(view, i); break end
    end
  end
  for rank = #TOP_OPTION_IDS, 1, -1 do
    if found[rank] then table.insert(view, 1, found[rank]) end
  end
  return menu
end
shared.promoteOptionsView = promoteOptionsView

local okOptions, OptionsMenu = pcall(require, "src.ui.gen2.OptionsMenu")
if okOptions and type(OptionsMenu) == "table"
    and type(OptionsMenu.new) == "function"
    and not OptionsMenu._silverShadowTopRows then
  local originalNew = OptionsMenu.new
  OptionsMenu.new = function(...)
    return promoteOptionsView(originalNew(...))
  end
  OptionsMenu._silverShadowTopRows = true
end

mod.hooks:wrap("ui.options.rows", function(next, game, current)
  local out = next(game, current)
  if type(out) ~= "table" then return out end
  table.insert(out, 1, {
    id = "minimal_cheats", label = "SILVERSHADOW",
    value = function() return "OPEN" end,
    activate = function(g) mod.ui.push(g, ROOT) end,
  })
  return out
end)

shared.optionsScreen = ROOT
