-- SilverShadow Mods 2.0.2
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
  local modules = {
    -- Content patches run before runtime consumers such as DexNav.
    "modules/content_151.lua",
    "modules/useful_bag.lua",
    "modules/storage_boxes.lua",
    "modules/tm_shop.lua",
    "modules/reusable_machines.lua",

    -- Contextual tools and Pokemon screens.
    "modules/moves_manager.lua",
    "modules/dv_ev_editor.lua",
    "modules/field_moves.lua",
    "modules/dexnav.lua",
    "modules/summon.lua",
    "modules/heal_anywhere.lua",

    -- Unified SilverShadow behavior and compatibility.
    "modules/battle_move_info.lua",
    "modules/cheats.lua",
    "modules/healing.lua",
    "modules/movement.lua",
    "modules/display.lua",
    "modules/pc.lua",
    "modules/followers_integration.lua",
    "modules/options.lua",
    "modules/ui_hooks.lua",
  }

  for _, path in ipairs(modules) do loadModule(path, shared) end
  mod.exports.silvershadow = shared
  mod.log:info("SilverShadow Mods 2.0.2 loaded")
end
