-- SUMMON for Gen1Recomp
-- Adds a numeric Pokédex selector to the Start menu and starts a normal wild
-- encounter with the selected species. It never grants a Pokémon directly.

local SCREEN = "SummonPokemonScreen"
local COMMAND = "summon_pokemon_battle"

local GRID = {
  { "1", "2", "3" },
  { "4", "5", "6" },
  { "7", "8", "9" },
  { "DEL", "0", "OK" },
  { "CANCEL" },
}

-- Expose the keypad as a real grid. Gen1 Modern UI recognizes this
-- naming-style public shape and renders each key as a large, separate cell
-- instead of flattening the keypad into a hard-to-use vertical list.

local function moveGrid(state, direction)
  local current = GRID[state.row]
  if direction == "up" then
    state.row = state.row > 1 and state.row - 1 or #GRID
    state.col = math.min(state.col, #GRID[state.row])
  elseif direction == "down" then
    state.row = state.row < #GRID and state.row + 1 or 1
    state.col = math.min(state.col, #GRID[state.row])
  elseif direction == "left" then
    state.col = state.col > 1 and state.col - 1 or #current
  elseif direction == "right" then
    state.col = state.col < #current and state.col + 1 or 1
  end
end

local function clamp(value, low, high)
  value = tonumber(value) or low
  if value < low then return low end
  if value > high then return high end
  return value
end

local function hasHealthyParty(game)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if (tonumber(mon.hp) or 0) > 0 then return true end
  end
  return false
end

local function summonLevel(game)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if (tonumber(mon.hp) or 0) > 0 then
      return math.floor(clamp(mon.level, 1, 100))
    end
  end
  return nil
end

local function buildDexIndex(mod)
  local rows = {}
  for id, def in mod.content.pokemon:each() do
    local dex = tonumber(def and def.dex)
    if dex and dex >= 1 and dex % 1 == 0 then
      rows[#rows + 1] = {
        id = id,
        dex = math.floor(dex),
        name = (def and def.name) or id,
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.dex ~= b.dex then return a.dex < b.dex end
    return a.id < b.id
  end)

  local byDex, maxDex = {}, 0
  for _, row in ipairs(rows) do
    -- Vanilla numbers are unique. If two mods reuse one number, resolve it
    -- deterministically to the alphabetically first species id.
    if not byDex[row.dex] then byDex[row.dex] = row end
    if row.dex > maxDex then maxDex = row.dex end
  end
  return byDex, maxDex
end

local function sourceFor(mod, game, hook)
  local overworld = game and game.overworld
  local mapId = overworld and overworld.map and overworld.map.id or "?"
  return {
    source = {
      modId = mod.id,
      mapId = mapId,
      hook = hook or "start_menu",
      strict = true,
    },
  }
end

local function registerBattleCommand(mod)
  mod.commands:register(COMMAND, function(ctx, species, level)
    local BattleState = require("src.battle.BattleState")
    local Map = require("src.world.Map")
    local battle = BattleState.newWild(ctx.game, species,
      math.floor(clamp(level, 1, 100)))

    -- A player currently inside the Safari game must keep its dedicated
    -- BALL / BAIT / ROCK / RUN rules.
    local mapDef = ctx.overworld and ctx.overworld.map
      and ctx.overworld.map.def
    if ctx.save.safari and mapDef
        and Map.inRegion(mapDef, "SAFARI", "SAFARI_ZONE") then
      battle:makeSafari(ctx.save.safari)
    end

    local runner = ctx.runner
    battle.onFinish = function(result)
      ctx.lastBattleResult = result
      ctx.lastCheck = result == "win"
      if ctx.overworld then ctx.overworld:afterBattle(result, battle) end
      runner:resume()
    end

    -- Use the overworld's normal flash/wipe transition rather than dropping
    -- directly into BattleState from the menu.
    ctx.overworld:pushBattle(battle)
    runner:yield()
  end)
end

local function makeScreenClass(mod)
  local Font = mod.ui.Font
  local Theme = mod.ui.Theme
  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true

  function Screen.new(game)
    local byDex, maxDex = buildDexIndex(mod)
    return setmetatable({
      game = game,
      byDex = byDex,
      maxDex = maxDex,
      digits = "",
      glyphs = {},
      maxLen = 3,
      title = "SUMMON",
      row = 1,
      col = 1,
      message = "",
      -- A screen id containing "nickname" plus grid/glyphs/row/col is the
      -- public naming-screen shape consumed by Gen1 Modern UI. This lets the
      -- UI use its proper large-cell keyboard presenter while Summon keeps
      -- ownership of all input and encounter logic.
      screenId = "SummonNicknameKeypad",
      modernBagSearchKeyboard = true,
      modernBagSearchHint = "A CHOOSE   B BACK   SELECT CLEAR   START OK",
      modernBagSearchActionLabel = "OK",
    }, Screen)
  end

  function Screen:grid()
    return GRID
  end

  function Screen:syncDigits()
    self.digits = table.concat(self.glyphs or {})
  end

  function Screen:clearDigits()
    self.glyphs = {}
    self:syncDigits()
    self.message = ""
  end

  function Screen:selectedNumber()
    if self.digits == "" then return nil end
    return tonumber(self.digits)
  end

  function Screen:selectedSpecies()
    local n = self:selectedNumber()
    return n and self.byDex[n] or nil
  end

  function Screen:appendDigit(digit)
    if #(self.glyphs or {}) >= self.maxLen then return end
    if digit == "0" and #self.glyphs == 0 then
      -- Keep the field clean: 025 can still be entered as 25 and is displayed
      -- with leading zeroes automatically.
      return
    end
    self.glyphs[#self.glyphs + 1] = digit
    self:syncDigits()
    self.message = ""
  end

  function Screen:deleteDigit()
    table.remove(self.glyphs)
    self:syncDigits()
    self.message = ""
  end

  function Screen:cancel()
    self.game.stack:pop()
    mod.ui.push(self.game, "StartMenu")
  end

  function Screen:submit()
    local number = self:selectedNumber()
    if not number then
      self.message = "ENTER A NUMBER"
      return
    end
    local row = self.byDex[number]
    if not row then
      self.message = ("No.%03d NOT FOUND"):format(number)
      return
    end
    local level = summonLevel(self.game)
    if not level then
      self.message = "NO HEALTHY POKEMON"
      return
    end
    local world = mod.world
    if not world then
      self.message = "WORLD API UNAVAILABLE"
      return
    end

    self.game.stack:pop()
    local ok, err = world:queueScript({
      { COMMAND, row.id, level },
    }, sourceFor(mod, self.game, "summon"))
    if not ok then
      mod.log:warn("SUMMON request failed: %s", tostring(err))
      self.game.stack:push(mod.ui.TextBox.new(self.game,
        "SUMMON failed.\nTry again.", function()
          mod.ui.push(self.game, "StartMenu")
        end))
    end
  end

  function Screen:activate(label)
    if label:match("^%d$") then
      self:appendDigit(label)
    elseif label == "DEL" then
      self:deleteDigit()
    elseif label == "OK" then
      self:submit()
    elseif label == "CANCEL" then
      self:cancel()
    end
  end

  function Screen:update()
    local input = self.game.input
    local current = GRID[self.row]
    if input:wasPressed("up") then
      moveGrid(self, "up")
    elseif input:wasPressed("down") then
      moveGrid(self, "down")
    elseif input:wasPressed("left") then
      moveGrid(self, "left")
    elseif input:wasPressed("right") then
      moveGrid(self, "right")
    elseif input:wasPressed("select") then
      self:clearDigits()
    elseif input:wasPressed("start") then
      self:submit()
    elseif input:wasPressed("b") then
      self:cancel()
    elseif input:wasPressed("a") then
      self:activate(current[self.col])
    end
  end

  -- Physical keyboard support in addition to the controller-style keypad.
  -- Game:keypressed gives the top state first refusal through onKeyPressed.
  function Screen:onKeyPressed(key)
    local digit = key and key:match("^([0-9])$")
      or (key and key:match("^kp([0-9])$"))
    if digit then
      self:appendDigit(digit)
    elseif key == "backspace" or key == "delete" then
      self:deleteDigit()
    elseif key == "return" or key == "kpenter" then
      self:submit()
    elseif key == "escape" then
      self:cancel()
    elseif self.game.input and self.game.input.keypressed then
      -- Having onKeyPressed gives this screen first refusal over every keyboard
      -- event. Forward unhandled keys to Input so arrows, Z/X, WASD and custom
      -- bindings still produce the normal mapped button presses.
      self.game.input:keypressed(key)
    end
  end

  local function centerX(label, center)
    return center - math.floor(Font.width(label) / 2)
  end

  function Screen:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)

    Font.draw("SUMMON", 8, 8)
    Font.drawBox(1, 2, 18, 5)
    local number = self:selectedNumber()
    local display = number and ("No.%03d"):format(number) or "No.---"
    Font.draw(display, 16, 24)

    local species = self:selectedSpecies()
    if species then
      Font.draw(species.name, 16, 40)
      Font.draw(("LV%3d"):format(summonLevel(self.game) or 0), 112, 40)
    else
      Font.draw(("VALID: 1-%d"):format(self.maxDex), 16, 40)
    end

    local centers = { 32, 80, 128 }
    local startY = 72
    for r, row in ipairs(GRID) do
      local y = startY + (r - 1) * 14
      if #row == 1 then
        local label = row[1]
        Font.draw(label, centerX(label, 80), y)
      else
        for c, label in ipairs(row) do
          Font.draw(label, centerX(label, centers[c]), y)
        end
      end
    end

    local row = GRID[self.row]
    local center = #row == 1 and 80 or centers[self.col]
    Font.drawCode(Theme.cursor, center - math.floor(Font.width(row[self.col]) / 2) - 8,
      startY + (self.row - 1) * 14)

    if self.message ~= "" then
      Font.draw(self.message, centerX(self.message, 80), 136)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  return Screen
end

return function(mod, shared)
  registerBattleCommand(mod)

  local Screen = makeScreenClass(mod)

  mod.content.screens:register(SCREEN, {
    new = function(game)
      return Screen.new(game)
    end,
  })

  shared.registerStartItem("summon", 40, function(game)
    return {
      label = "SUMMON",
      onSelect = function()
        if not hasHealthyParty(game) then
          game.stack:push(mod.ui.TextBox.new(game,
            "No healthy POKEMON\ncan battle.", function()
              mod.ui.push(game, "StartMenu")
            end))
          return
        end
        mod.ui.push(game, SCREEN)
      end,
    }
  end)


  mod.exports.buildDexIndex = function() return buildDexIndex(mod) end
  mod.exports.summonLevel = summonLevel
  mod.exports.newScreen = function(game) return Screen.new(game) end

  mod.log:info("Summon loaded")
end
