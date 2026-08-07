-- DV EV Editor for Gen1Recomp
-- Adds a DV/EV page to the out-of-battle Pokemon party submenu.
-- Generation I uses DVs (0..15) and Stat EXP (0..65535), not modern EVs.

local Stats = require("src.pokemon.Stats")

local STAT_ROWS = {
  { key = "hp",      label = "HP"  },
  { key = "attack",  label = "ATK" },
  { key = "defense", label = "DEF" },
  { key = "speed",   label = "SPD" },
  { key = "special", label = "SPC" },
}

local DV_ROWS = {
  { key = "attack",  label = "ATK" },
  { key = "defense", label = "DEF" },
  { key = "speed",   label = "SPD" },
  { key = "special", label = "SPC" },
}

local function clampInteger(value, minimum, maximum)
  value = math.floor(tonumber(value) or minimum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function derivedHpDv(dvs)
  return ((dvs.attack or 0) % 2) * 8
       + ((dvs.defense or 0) % 2) * 4
       + ((dvs.speed or 0) % 2) * 2
       + ((dvs.special or 0) % 2)
end

-- The effective Gen I EV term shown to the player. Stats.calc uses the same
-- ceil(sqrt(Stat EXP)) / 4 rule, capped before the division.
local function effectiveEv(statExp)
  local root = math.min(255, math.ceil(math.sqrt(clampInteger(statExp, 0, 65535))))
  return math.floor(root / 4)
end

local function ensureMon(game, mon)
  mon.dvs = mon.dvs or {}
  for _, row in ipairs(DV_ROWS) do
    mon.dvs[row.key] = clampInteger(mon.dvs[row.key], 0, 15)
  end
  mon.dvs.hp = derivedHpDv(mon.dvs)

  mon.statExp = mon.statExp or {}
  for _, row in ipairs(STAT_ROWS) do
    mon.statExp[row.key] = clampInteger(mon.statExp[row.key], 0, 65535)
  end

  Stats.ensure(game.data.pokemon[mon.species], mon)
end

local function recalculate(game, mon)
  ensureMon(game, mon)
  local def = game.data.pokemon[mon.species]
  if not def then return end

  local oldMax = mon.stats and mon.stats.hp or 1
  local oldHp = clampInteger(mon.hp, 0, oldMax)
  local missing = math.max(0, oldMax - oldHp)

  mon.dvs.hp = derivedHpDv(mon.dvs)
  mon.stats = Stats.calc(def, mon.level or 1, mon.dvs, mon.statExp)

  -- Match the game's level-up behavior: changing maximum HP preserves the
  -- amount of HP missing. A fainted Pokemon stays fainted.
  if oldHp <= 0 then
    mon.hp = 0
  else
    mon.hp = math.max(1, math.min(mon.stats.hp, mon.stats.hp - missing))
  end
end

local function actualStat(mon, key)
  return mon.stats and mon.stats[key] or 0
end

local function padded(value, width)
  return ("%0" .. tostring(width) .. "d"):format(value)
end

return function(mod, shared)
  local Font = mod.ui.Font
  local Theme = mod.ui.Theme

  local Editor = {}
  Editor.__index = Editor
  Editor.isOpaque = true
  Editor.screenId = "DvEvEditor"

  function Editor.new(game, mon)
    ensureMon(game, mon)
    return setmetatable({
      game = game,
      mon = mon,
      page = 1,
      row = 1,
      editing = false,
      editValue = 0,
      editDigit = 1,
      editWidth = 2,
      editMax = 15,
    }, Editor)
  end

  function Editor:rowCount()
    return self.page == 1 and #DV_ROWS or #STAT_ROWS
  end

  function Editor:selectedRow()
    if self.page == 1 then return DV_ROWS[self.row] end
    return STAT_ROWS[self.row]
  end

  function Editor:setPage(page)
    self.page = page < 1 and 2 or (page > 2 and 1 or page)
    self.row = math.min(self.row, self:rowCount())
  end

  function Editor:startEdit()
    local row = self:selectedRow()
    if not row then return end
    if self.page == 1 then
      self.editValue = clampInteger(self.mon.dvs[row.key], 0, 15)
      self.editWidth = 2
      self.editMax = 15
    else
      self.editValue = clampInteger(self.mon.statExp[row.key], 0, 65535)
      self.editWidth = 5
      self.editMax = 65535
    end
    self.editDigit = 1
    self.editing = true
  end

  function Editor:changeDigit(delta)
    local place = 10 ^ (self.editWidth - self.editDigit)
    self.editValue = clampInteger(self.editValue + delta * place, 0, self.editMax)
  end

  function Editor:applyEdit()
    local row = self:selectedRow()
    if not row then return end
    if self.page == 1 then
      self.mon.dvs[row.key] = clampInteger(self.editValue, 0, 15)
      self.mon.dvs.hp = derivedHpDv(self.mon.dvs)
    else
      self.mon.statExp[row.key] = clampInteger(self.editValue, 0, 65535)
    end
    recalculate(self.game, self.mon)
    self.editing = false
  end

  function Editor:update()
    local input = self.game.input

    if self.editing then
      if input:wasPressed("left") then
        self.editDigit = self.editDigit > 1 and self.editDigit - 1 or self.editWidth
      elseif input:wasPressed("right") then
        self.editDigit = self.editDigit < self.editWidth and self.editDigit + 1 or 1
      elseif input:wasPressed("up") then
        self:changeDigit(1)
      elseif input:wasPressed("down") then
        self:changeDigit(-1)
      elseif input:wasPressed("a") then
        self:applyEdit()
      elseif input:wasPressed("b") then
        self.editing = false
      end
      return
    end

    local n = self:rowCount()
    if input:wasPressed("up") then
      self.row = self.row > 1 and self.row - 1 or n
    elseif input:wasPressed("down") then
      self.row = self.row < n and self.row + 1 or 1
    elseif input:wasPressed("left") then
      self:setPage(self.page - 1)
    elseif input:wasPressed("right") or input:wasPressed("select") then
      self:setPage(self.page + 1)
    elseif input:wasPressed("a") then
      self:startEdit()
    elseif input:wasPressed("b") then
      self.game.stack:pop()
    end
  end

  local function drawDigitCursor(x, y, digit)
    love.graphics.rectangle("fill", x + (digit - 1) * 8, y + 9, 7, 1)
  end

  function Editor:drawHeader()
    local mon = self.mon
    local def = self.game.data.pokemon[mon.species]
    local name = mon.nickname or (def and def.name) or tostring(mon.species)
    Font.draw("DV/EV EDITOR", 8, 8)
    Font.draw(("%s :L%d"):format(name, mon.level or 1), 8, 24)
    Font.draw(self.page == 1 and "DV  1/2" or "STAT EXP  2/2", 96, 8)
  end

  function Editor:drawDvPage()
    Font.draw("HP  DV", 16, 40)
    Font.draw(("%02d"):format(self.mon.dvs.hp or 0), 72, 40)
    Font.draw(("STAT %3d"):format(actualStat(self.mon, "hp")), 96, 40)

    for i, row in ipairs(DV_ROWS) do
      local y = 56 + (i - 1) * 16
      local value = self.mon.dvs[row.key] or 0
      if self.editing and self.row == i then value = self.editValue end
      if self.row == i then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(row.label .. " DV", 16, y)
      Font.draw(padded(value, 2), 72, y)
      Font.draw(("STAT %3d"):format(actualStat(self.mon, row.key)), 96, y)
      if self.editing and self.row == i then drawDigitCursor(72, y, self.editDigit) end
    end
  end

  function Editor:drawEvPage()
    Font.draw("RAW    EV  STAT", 40, 40)
    for i, row in ipairs(STAT_ROWS) do
      local y = 56 + (i - 1) * 14
      local raw = self.mon.statExp[row.key] or 0
      if self.editing and self.row == i then raw = self.editValue end
      if self.row == i then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(row.label, 16, y)
      Font.draw(padded(raw, 5), 40, y)
      Font.draw(("%02d"):format(effectiveEv(raw)), 96, y)
      Font.draw(("%3d"):format(actualStat(self.mon, row.key)), 128, y)
      if self.editing and self.row == i then drawDigitCursor(40, y, self.editDigit) end
    end
  end

  function Editor:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)

    self:drawHeader()
    if self.page == 1 then self:drawDvPage() else self:drawEvPage() end

    if self.editing then
      Font.draw("L/R DIGIT U/D VALUE", 8, 128)
      Font.draw("A OK   B CANCEL", 8, 136)
    else
      Font.draw("L/R PAGE  A EDIT", 8, 128)
      Font.draw("B BACK", 8, 136)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Gen1 Modern UI compatibility contract (API v1). DV EV Editor keeps
  -- ownership of DV/Stat EXP edits and stat recalculation. Modern UI only
  -- presents a read-only model and sends semantic pointer actions. When
  -- Modern UI is absent, the native 160x144 editor above is unchanged.
  local function modernRows(state)
    local rows = {}
    if state.page == 1 then
      rows[#rows + 1] = {
        label = "HP DV",
        value = ("%02d   STAT %3d"):format(
          state.mon.dvs.hp or 0, actualStat(state.mon, "hp")),
        enabled = false,
      }
      for i, row in ipairs(DV_ROWS) do
        local value = state.mon.dvs[row.key] or 0
        if state.editing and state.row == i then value = state.editValue end
        local valueText = ("%02d   STAT %3d"):format(value,
          actualStat(state.mon, row.key))
        if state.editing and state.row == i then
          valueText = valueText .. ("   DIGIT %d/%d"):format(
            state.editDigit or 1, state.editWidth or 2)
        end
        rows[#rows + 1] = {
          label = row.label .. " DV",
          value = valueText,
          marker = state.editing and state.row == i or nil,
          enabled = true,
        }
      end
    else
      for i, row in ipairs(STAT_ROWS) do
        local raw = state.mon.statExp[row.key] or 0
        if state.editing and state.row == i then raw = state.editValue end
        local valueText = ("RAW %05d   EV %02d   STAT %3d"):format(
          raw, effectiveEv(raw), actualStat(state.mon, row.key))
        if state.editing and state.row == i then
          valueText = valueText .. ("   DIGIT %d/%d"):format(
            state.editDigit or 1, state.editWidth or 5)
        end
        rows[#rows + 1] = {
          label = row.label,
          value = valueText,
          marker = state.editing and state.row == i or nil,
          enabled = true,
        }
      end
    end
    return rows
  end

  local function modernModel(state)
    local def = state.game.data.pokemon[state.mon.species]
    local name = state.mon.nickname or (def and def.name)
      or tostring(state.mon.species)
    local rows = modernRows(state)
    local index = state.page == 1 and math.min(#rows, (state.row or 1) + 1)
      or math.min(#rows, state.row or 1)
    return {
      title = (state.page == 1 and "DV 1/2 - " or "STAT EXP 2/2 - ")
        .. name .. (" Lv%d"):format(state.mon.level or 1),
      rows = rows,
      index = math.max(1, index),
      scroll = 0,
      footer = state.editing
        and { "L/R DIGIT", "U/D VALUE", "A OK", "B CANCEL" }
        or { "L/R PAGE", "A EDIT", "B BACK" },
    }
  end

  local modernUiContract = {
    apiVersion = 1,
    screens = {
      dv_ev_editor = {
        match = function(state)
          return type(state) == "table" and state.screenId == "DvEvEditor"
            and type(state.mon) == "table" and type(state.game) == "table"
        end,
        canSuppressNative = true,
        model = function(_, state) return modernModel(state) end,
        actions = {
          hover = function(_, state, index)
            index = math.floor(tonumber(index) or 0)
            if state.editing then return index > 0 end
            if state.page == 1 then
              -- Row 1 is the read-only derived HP DV; editable rows start at 2.
              if index < 2 or index > #DV_ROWS + 1 then return false end
              state.row = index - 1
              return true
            end
            if index < 1 or index > #STAT_ROWS then return false end
            state.row = index
            return true
          end,
          select = function(_, state, index)
            index = math.floor(tonumber(index) or 0)
            if not state.editing then
              if state.page == 1 then
                if index >= 2 and index <= #DV_ROWS + 1 then
                  state.row = index - 1
                elseif index == 1 then
                  return false
                end
              elseif index >= 1 and index <= #STAT_ROWS then
                state.row = index
              end
              state:startEdit()
            else
              state:applyEdit()
            end
            return true
          end,
          up = function(_, state)
            if state.editing then
              state:changeDigit(1)
              return true
            end
            local n = state:rowCount()
            state.row = state.row > 1 and state.row - 1 or n
            return true
          end,
          down = function(_, state)
            if state.editing then
              state:changeDigit(-1)
              return true
            end
            local n = state:rowCount()
            state.row = state.row < n and state.row + 1 or 1
            return true
          end,
          left = function(_, state)
            if state.editing then
              state.editDigit = state.editDigit > 1
                and state.editDigit - 1 or state.editWidth
            else
              state:setPage(state.page - 1)
            end
            return true
          end,
          right = function(_, state)
            if state.editing then
              state.editDigit = state.editDigit < state.editWidth
                and state.editDigit + 1 or 1
            else
              state:setPage(state.page + 1)
            end
            return true
          end,
          back = function(_, state)
            if state.editing then
              state.editing = false
            else
              state.game.stack:pop()
            end
            return true
          end,
        },
      },
    },
  }

  local modernUiExports
  local modernUiRegistered = false
  local function ensureModernUiAdapter()
    if type(mod.find) ~= "function" then return false end
    local okFind, handle = pcall(mod.find, "gen1_modern_ui")
    if not okFind or type(handle) ~= "table" or type(handle.exports) ~= "table" then
      modernUiExports, modernUiRegistered = nil, false
      return false
    end
    local ex = handle.exports
    if tonumber(ex.compatibilityApiVersion or 1) ~= 1
        or type(ex.registerAdapter) ~= "function" then
      modernUiExports, modernUiRegistered = ex, false
      return false
    end
    if modernUiRegistered and modernUiExports == ex then return true end
    local ok, registered, reason = pcall(ex.registerAdapter, {
      owner = "dv_ev_editor",
      version = "1.0.1",
      contract = modernUiContract,
    })
    if ok and registered ~= false then
      modernUiExports, modernUiRegistered = ex, true
      return true
    end
    modernUiExports, modernUiRegistered = ex, false
    if mod.log then
      mod.log:warn("Gen1 Modern UI adapter unavailable: %s",
        tostring(ok and reason or registered))
    end
    return false
  end

  mod.exports.gen1ModernUi = modernUiContract
  mod.exports.ensureModernUiAdapter = ensureModernUiAdapter

  local function hasLabel(items, label)
    for _, item in ipairs(items or {}) do
      if item.label == label then return true end
    end
    return false
  end

  shared.registerPartyDecorator("dv_ev", 30, function(game, result, mon, ctx)
    -- Editing during a running battle would leave that battle's temporary
    -- battler stats stale. Keep the editor in the normal field party menu.
    if not (ctx and ctx.battle) and not hasLabel(result, "DV/EV") then
      mod.ui.insertAfter(result, "STATS", {
        label = "DV/EV",
        onSelect = function(selectedMon, selectedGame)
          ensureModernUiAdapter()
          selectedGame.stack:push(Editor.new(selectedGame, selectedMon))
        end,
      })
    end
    return result
  end)

  mod.events:on("game.ready", function()
    ensureModernUiAdapter()
  end)

  -- Register immediately when load order permits it; game.ready and opening
  -- the editor retry after reloads or unusual optional-dependency ordering.
  ensureModernUiAdapter()

  mod.exports.effectiveEv = effectiveEv
  mod.exports.derivedHpDv = derivedHpDv
  mod.log:info("DV EV Editor loaded")
end
