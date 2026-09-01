-- A bounded, scrollable Gen 2 Pokemon action submenu.
--
-- Gold's native box assumes at most eight rows. SilverShadow can add FREEFLY,
-- MOVES and DV/EV to a Pokemon that already knows several field moves, which
-- otherwise computes a negative top coordinate and draws the first rows above
-- the Game Boy screen. Keep the engine's selection/dispatch and replace only
-- the oversized menu's viewport.

local mod = ...
local PartyMenu = require("src.ui.gen2.PartyMenu")
local Chrome = require("src.ui.gen2.Chrome")

local VISIBLE_ROWS = 6
local LEFT, RIGHT, BOTTOM = 6, 19, 17

local function syncWindow(menu)
  if not (menu and type(menu.items) == "table") then return 1 end
  local total = #menu.items
  if total <= VISIBLE_ROWS then
    menu.silverFirstRow = 1
    return 1
  end
  local first = math.max(1, math.min(tonumber(menu.silverFirstRow) or 1,
    total - VISIBLE_ROWS + 1))
  if menu.index < first then first = menu.index end
  if menu.index > first + VISIBLE_ROWS - 1 then
    first = menu.index - VISIBLE_ROWS + 1
  end
  menu.silverFirstRow = first
  return first
end

local function drawScrollable(self)
  local menu = self.submenu
  if not (menu and not menu.battle and #menu.items > VISIBLE_ROWS) then
    return false
  end
  local first = syncWindow(menu)
  local top = 1 + BOTTOM - 2 * (VISIBLE_ROWS + 1)
  Chrome.box(LEFT, top, RIGHT - LEFT + 1, BOTTOM - top + 1)
  for visible = 1, VISIBLE_ROWS do
    local row = first + visible - 1
    local item = menu.items[row]
    if item then
      local tx, ty = LEFT + 2, top + 2 + (visible - 1) * 2
      if row == menu.index then Chrome.cursor(tx - 1, ty) end
      Chrome.print(item.label, tx, ty)
    end
  end
  -- Plain cart glyphs: the selection itself remains the main scroll cue, and
  -- these compact markers show when more rows exist above or below.
  if first > 1 then Chrome.print("^", RIGHT - 1, top + 1) end
  if first + VISIBLE_ROWS - 1 < #menu.items then
    Chrome.print("v", RIGHT - 1, BOTTOM - 1)
  end
  return true
end

if not PartyMenu.__silverScrollWrapped then
  PartyMenu.__silverScrollWrapped = true
  PartyMenu.__silverScrollOriginalOpen = PartyMenu.openSubmenu
  PartyMenu.__silverScrollOriginalUpdate = PartyMenu.updateSubmenu
  PartyMenu.__silverScrollOriginalDraw = PartyMenu.drawSubmenu

  PartyMenu.openSubmenu = function(self, ...)
    local result = PartyMenu.__silverScrollOriginalOpen(self, ...)
    if self.submenu then syncWindow(self.submenu) end
    return result
  end
  PartyMenu.updateSubmenu = function(self, ...)
    local menu = self.submenu
    local result = PartyMenu.__silverScrollOriginalUpdate(self, ...)
    if menu and self.submenu == menu then syncWindow(menu) end
    return result
  end
  PartyMenu.drawSubmenu = function(self, ...)
    if drawScrollable(self) then return end
    return PartyMenu.__silverScrollOriginalDraw(self, ...)
  end
end

mod.exports.gen2PartyScroll = {
  visibleRows = VISIBLE_ROWS,
  syncWindow = syncWindow,
}

return mod.exports.gen2PartyScroll
