-- Make the title screen's EXIT GAME return to Gen1Recomp's launcher. The
-- launcher restart marker is understood by the host before mods are loaded,
-- including direct-to-game Android launches.
local mod = ...

local RELAUNCH_MARKER = "relaunch_to_launcher.txt"

local function returnToLauncher(fallback)
  if love and love.filesystem and love.filesystem.write then
    pcall(love.filesystem.write, RELAUNCH_MARKER, "1")
  end

  local ok, HostShell = pcall(require, "src.core.HostShell")
  if ok and HostShell and type(HostShell.restart) == "function" then
    local restarted = pcall(HostShell.restart)
    if restarted then return end
  end

  -- Older hosts may not expose the restart bridge. Keep their original Exit
  -- behavior instead of leaving the title menu unresponsive.
  if type(fallback) == "function" then
    fallback()
  elseif love and love.event and love.event.quit then
    love.event.quit()
  end
end

mod.hooks:wrap("ui.title_menu.items", function(next, game, items)
  local out = next(game, items)
  if type(out) ~= "table" then return out end

  for _, item in ipairs(out) do
    if tostring(item.label or ""):upper() == "EXIT GAME" then
      local original = item.onSelect
      item.onSelect = function() returnToLauncher(original) end
      break
    end
  end
  return out
end)

mod.exports.returnToLauncher = returnToLauncher
