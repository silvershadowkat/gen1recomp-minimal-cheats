-- SilverShadow Mods 3.1.7
-- One entry point, deterministic module order, and one shared service table.

return function(mod)
  local compile = loadstring or load

  local function loadModule(path, shared)
    local source, readError = mod:read(path)
    if not source then
      error(("SilverShadow module missing: %s (%s)"):format(
        path, tostring(readError)), 0)
    end
    local chunk, compileError = compile(source, "@" .. mod.path .. "/" .. path)
    if not chunk then
      error(("SilverShadow module failed to compile: %s (%s)"):format(
        path, tostring(compileError)), 0)
    end
    local result = chunk(mod, shared)
    if type(result) == "function" then result(mod, shared) end
    return result
  end

  local shared = loadModule("modules/core.lua")
  loadModule("modules/collection_habitats.lua",shared)
  loadModule("modules/type_colors.lua",shared)
  loadModule("modules/follower_transitions.lua",shared)
  loadModule("modules/shader_pixel_scale.lua",shared)
  loadModule("modules/boot_presentation.lua",shared)
  local gen1Modules = {
    -- Content patches run before runtime consumers such as DexNav.
    "modules/content_151.lua",
    "modules/useful_bag.lua",
    "modules/tm_shop.lua",
    "modules/reusable_machines.lua",

    -- Contextual tools and Pokemon screens.
    "modules/extended_levels.lua",
    "modules/moves_manager.lua",
    "modules/dv_ev_editor.lua",
    "modules/field_moves.lua",
    "modules/dexnav.lua",
    "modules/summon.lua",

    -- Unified SilverShadow behavior and compatibility.
    "modules/trigger_buttons.lua",
    "modules/battle_move_info.lua",
    "modules/cheats.lua",
    "modules/healing.lua",
    "modules/movement.lua",
    "modules/display.lua",
    "modules/pc.lua",
    "modules/followers_integration.lua",
    "modules/free_fly.lua",
    "modules/options.lua",
    "modules/ui_hooks.lua",
  }

  -- Gold, Silver, and Crystal share the public hook/menu/storage surfaces,
  -- but not Gen 1's screen classes, battle class, field table, or script VM.
  -- Load only modules with real Gen 2 backing; the complete list above stays
  -- unchanged for Red, Blue, and Yellow.
  local gen2Modules = {
    "modules/content_251.lua",
    "modules/trigger_buttons.lua",
    "modules/gen2_zoom_match.lua",
    "modules/gen2_battle_cheats.lua",
    "modules/movement.lua",
    "modules/gen2_free_fly.lua",
    "modules/gen2_party_scroll.lua",
    "modules/moves_manager.lua",
    "modules/dv_ev_editor.lua",
    "modules/gen2_healing.lua",
    "modules/gen2_dexnav.lua",
    "modules/gen2_summon.lua",
    "modules/gen2_pc.lua",
    "modules/gen2_item_editor.lua",
    "modules/gen2_field_tools.lua",
    "modules/followers_integration.lua",
    "modules/gen2_options.lua",
    "modules/ui_hooks.lua",
  }

  local gen3Modules = {
    "modules/gen3_battle_cheats.lua",
    "modules/gen3_field.lua",
    "modules/gen3_collection.lua",
    "modules/gen3_moves.lua",
    "modules/gen3_field_tools.lua",
    "modules/gen3_followers.lua",
    "modules/gen3_options.lua",
    "modules/gen3_move_info.lua",
    "modules/gen3_battle_presentation.lua",
    "modules/gen3_menu_presentation.lua",
  }
  local modules = shared.generation == 3 and gen3Modules
    or shared.generation == 2 and gen2Modules or gen1Modules
  for _, path in ipairs(modules) do loadModule(path, shared) end
  loadModule("modules/instant_text.lua",shared)
  if shared.generation~=3 then
    loadModule("modules/battle_assets.lua",shared)
    loadModule("modules/capture_ball_presentation.lua",shared)
    loadModule("modules/battle_presentation.lua",shared)
    if shared.generation==2 then loadModule("modules/gen2_menu_presentation.lua",shared) end
    loadModule("modules/evolution_presentation.lua",shared)
    loadModule("modules/move_learning_presentation.lua",shared)
  end
  if shared.gameVersion=="yellow" then loadModule("modules/yellow_companion.lua",shared) end
  mod.exports.silvershadow = shared
  mod.log:info("SilverShadow Mods 3.1.7 loaded for Gen %s", shared.generation)
end
