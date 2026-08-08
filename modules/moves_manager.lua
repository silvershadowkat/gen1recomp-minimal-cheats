-- Moves Manager for Gen1Recomp
-- Adds an out-of-battle MOVES page to the party submenu.
-- The page shows full move data, remembers naturally learned moves and lets
-- the player legally replace or reorder the Pokemon's four move slots.

local SCREEN_ID = "MovesManager"
local MEMORY_FIELD = "movesManagerMemory"

local HM_MOVES = {
  CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
}

local PHYSICAL_TYPES = {
  "NORMAL", "FIGHTING", "POISON", "GROUND",
  "FLYING", "BUG", "ROCK", "GHOST",
}
local SPECIAL_TYPES = {
  "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE", "PSYCHIC", "DRAGON",
}
local STATUS_GROUPS = {
  { key = "major", label = "MAJOR STATUS" },
  { key = "lower", label = "STAT LOWER" },
  { key = "raise", label = "STAT RAISE" },
  { key = "field", label = "FIELD/STATE" },
  { key = "volatile", label = "TRAPS/TRIGGERS" },
  { key = "recovery", label = "RECOVERY" },
  { key = "utility", label = "UTILITY/OTHER" },
}

-- Base-power zero is not synonymous with Status in Gen I.  These effects
-- still deal damage and belong under their physical/special type.
local ZERO_POWER_DAMAGE = {
  BIDE_EFFECT = true, COUNTER_EFFECT = true, SPECIAL_DAMAGE_EFFECT = true,
  SUPER_FANG_EFFECT = true, OHKO_EFFECT = true,
}

local function clamp(value, minimum, maximum)
  value = math.floor(tonumber(value) or minimum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function maxPP(moveDef, moveInst)
  if not moveDef then return 0 end
  local ups = clamp(moveInst and moveInst.ppUps or 0, 0, 3)
  return (moveDef.pp or 0) + ups * math.floor((moveDef.pp or 0) / 5)
end

local function humanize(id)
  local text = tostring(id or "--")
  text = text:gsub("_TYPE$", "")
  text = text:gsub("_EFFECT$", "")
  text = text:gsub("_", " ")
  return text
end

local function fit(text, maxChars)
  text = tostring(text or "")
  if #text <= maxChars then return text end
  if maxChars <= 1 then return text:sub(1, maxChars) end
  return text:sub(1, maxChars - 1) .. "."
end

local function memoryFor(mon)
  local memory = mon[MEMORY_FIELD]
  if type(memory) ~= "table" then
    memory = { order = {}, known = {} }
    mon[MEMORY_FIELD] = memory
  end
  if type(memory.order) ~= "table" then memory.order = {} end
  if type(memory.known) ~= "table" then
    memory.known = {}
    for _, id in ipairs(memory.order) do memory.known[id] = true end
  end
  return memory
end

local function remember(mon, moveId)
  if type(moveId) ~= "string" or moveId == "" then return end
  local memory = memoryFor(mon)
  if memory.known[moveId] then return end
  memory.known[moveId] = true
  memory.order[#memory.order + 1] = moveId
end

local function reverseEvolutions(game)
  local reverse = {}
  for speciesId, def in pairs(game.data.pokemon or {}) do
    for _, evo in ipairs(def.evolutions or {}) do
      if evo.species then
        reverse[evo.species] = reverse[evo.species] or {}
        reverse[evo.species][#reverse[evo.species] + 1] = speciesId
      end
    end
  end
  for _, rows in pairs(reverse) do table.sort(rows) end
  return reverse
end

local function evolutionLine(game, speciesId)
  local reverse = reverseEvolutions(game)
  local out, seen = {}, {}
  local function visit(id)
    if seen[id] then return end
    seen[id] = true
    for _, parent in ipairs(reverse[id] or {}) do visit(parent) end
    out[#out + 1] = id
  end
  visit(speciesId)
  return out
end

local function seedMemory(game, mon)
  local data = game.data
  local level = clamp(mon.level or 1, 1, 255)
  local line = evolutionLine(game, mon.species)

  -- Reconstruct the natural move history from the evolution line. Gen I save
  -- data does not record when evolution happened, so this is deliberately a
  -- generous reconstruction: every natural move in the line up to the current
  -- level is considered remembered.
  for _, speciesId in ipairs(line) do
    local def = data.pokemon[speciesId]
    if def then
      for _, moveId in ipairs(def.level1Moves or {}) do remember(mon, moveId) end
      for _, entry in ipairs(def.learnset or {}) do
        if (entry.level or 1) <= level then remember(mon, entry.move) end
      end
    end
  end

  -- Current TM/HM, traded or modded moves are always remembered even when they
  -- are not present in the natural learnset reconstruction.
  for _, move in ipairs(mon.moves or {}) do remember(mon, move.id) end
  return memoryFor(mon)
end

local function knownSlot(mon, moveId)
  for i, move in ipairs(mon.moves or {}) do
    if move.id == moveId then return i end
  end
  return nil
end

local function applyReplacement(game, mon, slot, moveId)
  local moveDef = game.data.moves and game.data.moves[moveId]
  if not moveDef then return false, "unknown_move" end

  mon.moves = mon.moves or {}
  slot = clamp(slot or 1, 1, 4)
  local old = mon.moves[slot]
  if old and HM_MOVES[old.id] then return false, "hm_locked" end

  local duplicate = knownSlot(mon, moveId)
  if duplicate and duplicate ~= slot then return false, "duplicate" end
  if old and old.id == moveId then return false, "same_move" end

  if old then remember(mon, old.id) end
  remember(mon, moveId)
  local newInst = { id = moveId, pp = moveDef.pp or 0 }
  if slot <= #mon.moves then
    mon.moves[slot] = newInst
  else
    mon.moves[#mon.moves + 1] = newInst
    slot = #mon.moves
  end
  return true, old and old.id or nil, slot
end

local function multiHitText(value)
  if value == nil then return "--" end
  if type(value) == "number" then return tostring(value) end
  if type(value) ~= "table" or #value == 0 then return "SPECIAL" end
  local minimum, maximum = value[1], value[1]
  for _, n in ipairs(value) do
    if n < minimum then minimum = n end
    if n > maximum then maximum = n end
  end
  if minimum == maximum then return tostring(minimum) end
  return tostring(minimum) .. "-" .. tostring(maximum)
end

return function(mod, shared)
  local Font = mod.ui.Font
  local Theme = mod.ui.Theme
  local TextBox = mod.ui.TextBox

  local function typeRecord(moveDef)
    return moveDef and mod.content.type_chart:get(moveDef.type) or nil
  end

  local function typeName(moveDef)
    local record = typeRecord(moveDef)
    return (record and record.name) or humanize(moveDef and moveDef.type)
  end

  local function categoryName(moveDef)
    if not moveDef then return "--" end
    local record = typeRecord(moveDef)
    local category = moveDef.category or (record and record.category)
    if not category then category = (moveDef.power or 0) == 0 and "status" or "physical" end
    return tostring(category):upper()
  end

  local function effectKind(moveDef)
    local record = moveDef and mod.content.move_effects:get(moveDef.effect)
    return record and tostring(record.kind):upper() or "--"
  end

  local function learnedRows(game, mon)
    local memory = seedMemory(game, mon)
    local rows = {}
    for _, moveId in ipairs(memory.order) do
      local moveDef = game.data.moves[moveId]
      if moveDef and not knownSlot(mon, moveId) then
        rows[#rows + 1] = { id = moveId, name = moveDef.name or moveId }
      end
    end
    return rows
  end

  local function normalizedType(moveDef)
    return tostring(moveDef and moveDef.type or "UNKNOWN"):gsub("_TYPE$", "")
  end

  local function isStatusMove(moveDef)
    if not moveDef or (tonumber(moveDef.power) or 0) > 0 then return false end
    if moveDef.fixedDamage ~= nil then return false end
    return not ZERO_POWER_DAMAGE[moveDef.effect]
  end

  local function statusGroup(moveDef)
    local effect = tostring(moveDef and moveDef.effect or "")
    if effect:find("SLEEP", 1, true) or effect:find("POISON", 1, true)
        or effect:find("PARALYZE", 1, true) then return "major" end
    if effect:find("_DOWN", 1, true) then return "lower" end
    if effect:find("_UP", 1, true) or effect == "FOCUS_ENERGY_EFFECT" then
      return "raise"
    end
    if effect == "HEAL_EFFECT" or effect == "REST_EFFECT" then return "recovery" end
    if effect:find("CONFUS", 1, true) or effect == "DISABLE_EFFECT"
        or effect == "LEECH_SEED_EFFECT" then return "volatile" end
    if effect == "SUBSTITUTE_EFFECT" or effect == "LIGHT_SCREEN_EFFECT"
        or effect == "REFLECT_EFFECT" or effect == "MIST_EFFECT"
        or effect == "HAZE_EFFECT" or effect == "TRANSFORM_EFFECT"
        or effect == "CONVERSION_EFFECT" then return "field" end
    return "utility"
  end

  local function moveBranch(moveDef)
    if isStatusMove(moveDef) then return "status", statusGroup(moveDef) end
    local moveType = normalizedType(moveDef)
    for _, value in ipairs(PHYSICAL_TYPES) do
      if moveType == value then return "physical", value end
    end
    for _, value in ipairs(SPECIAL_TYPES) do
      if moveType == value then return "special", value end
    end
    -- A content mod may add a non-Gen-I type.  It must remain reachable rather
    -- than disappearing from ALL MOVES, so the explicit catch-all owns it.
    return "status", "utility"
  end

  local function allMoveRows(game, section, group)
    local rows = {}
    for id, def in pairs(game.data.moves or {}) do
      local moveSection, moveGroup = moveBranch(def)
      if moveSection == section and moveGroup == group then
        rows[#rows + 1] = { id = id, name = def.name or id }
      end
    end
    table.sort(rows, function(a, b)
      local an, bn = tostring(a.name):upper(), tostring(b.name):upper()
      if an == bn then return tostring(a.id) < tostring(b.id) end
      return an < bn
    end)
    return rows
  end

  local function coverage(game)
    local seen, total, indexed = {}, 0, 0
    for _ in pairs(game.data.moves or {}) do total = total + 1 end
    local function count(section, group)
      for _, row in ipairs(allMoveRows(game, section, group)) do
        indexed = indexed + 1
        seen[row.id] = (seen[row.id] or 0) + 1
      end
    end
    for _, moveType in ipairs(PHYSICAL_TYPES) do count("physical", moveType) end
    for _, moveType in ipairs(SPECIAL_TYPES) do count("special", moveType) end
    for _, row in ipairs(STATUS_GROUPS) do count("status", row.key) end
    for id in pairs(game.data.moves or {}) do
      if seen[id] ~= 1 then return false, id, total, indexed end
    end
    if indexed ~= total then return false, "COUNT_MISMATCH", total, indexed end
    return true, nil, total, indexed
  end

  local Manager = {}
  Manager.__index = Manager
  Manager.isOpaque = true
  Manager.screenId = SCREEN_ID

  function Manager.new(game, mon)
    seedMemory(game, mon)
    return setmetatable({
      game = game,
      mon = mon,
      mode = "known",
      slot = 1,
      detailPage = 1,
      pool = {},
      poolIndex = 1,
      poolScroll = 0,
      poolTitle = "LEARNED MOVES",
      candidateBackMode = "pool",
      allSection = nil,
      swapSlot = nil,
    }, Manager)
  end

  function Manager:monName()
    local def = self.game.data.pokemon[self.mon.species]
    return self.mon.nickname or (def and def.name) or tostring(self.mon.species)
  end

  function Manager:currentMove()
    return self.mon.moves and self.mon.moves[self.slot] or nil
  end

  function Manager:currentDef()
    local move = self:currentMove()
    return move and self.game.data.moves[move.id] or nil
  end

  function Manager:candidate()
    return self.pool[self.poolIndex]
  end

  function Manager:openList(mode, title, rows)
    self.mode = mode
    self.poolTitle = title
    self.pool = rows or {}
    self.poolIndex = 1
    self.poolScroll = 0
  end

  function Manager:openPool()
    local current = self:currentMove()
    if current and HM_MOVES[current.id] then
      self.game.stack:push(TextBox.new(self.game, "HM techniques\ncan't be deleted!"))
      return
    end
    self:openList("pool", "LEARNED MOVES", learnedRows(self.game, self.mon))
  end

  function Manager:openAllSections()
    self:openList("all_sections", "ALL MOVES", {
      { key = "physical", name = "PHYSICAL" },
      { key = "special", name = "SPECIAL" },
      { key = "status", name = "STATUS" },
    })
  end

  function Manager:openAllGroups(section)
    self.allSection = section
    local rows, title = {}, "STATUS GROUPS"
    if section == "physical" or section == "special" then
      title = section == "physical" and "PHYSICAL TYPES" or "SPECIAL TYPES"
      local source = section == "physical" and PHYSICAL_TYPES or SPECIAL_TYPES
      for _, key in ipairs(source) do rows[#rows + 1] = { key = key, name = key } end
    else
      for _, row in ipairs(STATUS_GROUPS) do
        rows[#rows + 1] = { key = row.key, name = row.label }
      end
    end
    self:openList("all_groups", title, rows)
  end

  function Manager:openAllMoves(group)
    local label = group
    for _, row in ipairs(STATUS_GROUPS) do
      if row.key == group then label = row.label break end
    end
    self:openList("all_moves", fit(label .. " MOVES", 13),
      allMoveRows(self.game, self.allSection, group))
  end

  function Manager:showCurrentDetail()
    if self:currentMove() then
      self.detailPage = 1
      self.mode = "current_detail"
    else
      self:openPool()
    end
  end

  function Manager:swapMoves(a, b)
    local moves = self.mon.moves or {}
    if a == b or not moves[a] or not moves[b] then return false end
    moves[a], moves[b] = moves[b], moves[a]
    return true
  end

  function Manager:teachCandidate()
    local candidate = self:candidate()
    if not candidate then return end
    local old = self:currentMove()
    local oldName = old and ((self.game.data.moves[old.id] or {}).name or old.id) or nil
    local ok, reason, actualSlot = applyReplacement(self.game, self.mon, self.slot, candidate.id)
    if not ok then
      local message = "That move cannot\nbe selected."
      if reason == "duplicate" then message = self:monName() .. " already\nknows that move!" end
      if reason == "hm_locked" then message = "HM techniques\ncan't be deleted!" end
      if reason == "same_move" then message = "That move is already\nin this slot." end
      self.game.stack:push(TextBox.new(self.game, message))
      return
    end

    self.slot = actualSlot or self.slot
    self.mode = "known"
    self.swapSlot = nil
    local newName = (self.game.data.moves[candidate.id] or {}).name or candidate.id
    local message
    if oldName then
      message = self:monName() .. " forgot\n" .. oldName .. "!\fAnd learned\n" .. newName .. "!"
    else
      message = self:monName() .. " learned\n" .. newName .. "!"
    end
    self.game.stack:push(TextBox.new(self.game, message))
  end

  function Manager:updateKnown(input)
    if input:wasPressed("up") then
      self.slot = self.slot > 1 and self.slot - 1 or 4
    elseif input:wasPressed("down") then
      self.slot = self.slot < 4 and self.slot + 1 or 1
    elseif input:wasPressed("select") then
      if self.swapSlot then
        if self:swapMoves(self.swapSlot, self.slot) then
          self.swapSlot = nil
        elseif self.slot == self.swapSlot then
          self.swapSlot = nil
        end
      elseif self.mon.moves and self.mon.moves[self.slot] then
        self.swapSlot = self.slot
      end
    elseif input:wasPressed("a") then
      if self.swapSlot then
        self:swapMoves(self.swapSlot, self.slot)
        self.swapSlot = nil
      else
        self:showCurrentDetail()
      end
    elseif input:wasPressed("b") then
      if self.swapSlot then self.swapSlot = nil else self.game.stack:pop() end
    end
  end

  function Manager:updateDetail(input, candidate)
    if input:wasPressed("left") then
      self.detailPage = self.detailPage > 1 and self.detailPage - 1 or 3
    elseif input:wasPressed("right") or input:wasPressed("select") then
      self.detailPage = self.detailPage < 3 and self.detailPage + 1 or 1
    elseif input:wasPressed("a") then
      if candidate then self:teachCandidate() else self:openPool() end
    elseif input:wasPressed("b") then
      self.mode = candidate and self.candidateBackMode or "known"
      self.detailPage = 1
    end
  end

  function Manager:chooseList()
    local entry = self:candidate()
    if not entry then return end
    if self.mode == "all_sections" then
      self:openAllGroups(entry.key)
    elseif self.mode == "all_groups" then
      self:openAllMoves(entry.key)
    else
      self.candidateBackMode = self.mode
      self.detailPage = 1
      self.mode = "candidate_detail"
    end
  end

  function Manager:backList()
    if self.mode == "all_moves" then
      self:openAllGroups(self.allSection)
    elseif self.mode == "all_groups" then
      self:openAllSections()
    else
      self.mode = self:currentMove() and "current_detail" or "known"
    end
  end

  function Manager:updatePool(input)
    local n = #self.pool
    if n == 0 then
      if input:wasPressed("select") then
        if self.mode == "pool" then self:openAllSections() else self:openPool() end
      elseif input:wasPressed("a") or input:wasPressed("b") then
        self:backList()
      end
      return
    end
    if input:wasPressed("up") then
      self.poolIndex = self.poolIndex > 1 and self.poolIndex - 1 or n
    elseif input:wasPressed("down") then
      self.poolIndex = self.poolIndex < n and self.poolIndex + 1 or 1
    elseif input:wasPressed("left") then
      self.poolIndex = math.max(1, self.poolIndex - 6)
    elseif input:wasPressed("right") then
      self.poolIndex = math.min(n, self.poolIndex + 6)
    elseif input:wasPressed("select") then
      if self.mode == "pool" then self:openAllSections() else self:openPool() end
    elseif input:wasPressed("a") then
      self:chooseList()
    elseif input:wasPressed("b") then
      self:backList()
    end
    if self.poolIndex < self.poolScroll + 1 then self.poolScroll = self.poolIndex - 1 end
    if self.poolIndex > self.poolScroll + 6 then self.poolScroll = self.poolIndex - 6 end
  end

  function Manager:update()
    local input = self.game.input
    if self.mode == "known" then
      self:updateKnown(input)
    elseif self.mode == "pool" or self.mode == "all_sections"
        or self.mode == "all_groups" or self.mode == "all_moves" then
      self:updatePool(input)
    elseif self.mode == "candidate_detail" then
      self:updateDetail(input, true)
    else
      self:updateDetail(input, false)
    end
  end

  local function drawLabelValue(label, value, y)
    Font.draw(label, 8, y)
    Font.draw(tostring(value), 80, y)
  end

  local function wrappedLines(text, width, maxLines)
    text = humanize(text)
    local lines, current = {}, ""
    for word in text:gmatch("%S+") do
      local candidate = current == "" and word or (current .. " " .. word)
      if #candidate <= width then
        current = candidate
      else
        if current ~= "" then lines[#lines + 1] = current end
        current = word
        if #lines >= maxLines then break end
      end
    end
    if current ~= "" and #lines < maxLines then lines[#lines + 1] = current end
    if #lines == 0 then lines[1] = "--" end
    return lines
  end

  function Manager:drawKnown()
    Font.draw("MOVES", 8, 8)
    Font.draw(fit(self:monName(), 10), 80, 8)
    for i = 1, 4 do
      local y = 24 + (i - 1) * 24
      local move = self.mon.moves and self.mon.moves[i]
      local selected = self.slot == i
      if selected then Font.drawCode(Theme.cursor, 8, y) end
      if self.swapSlot == i then Font.drawCode(Theme.cursorHollow, 8, y) end
      if move then
        local def = self.game.data.moves[move.id]
        Font.draw(fit(def and def.name or move.id, 16), 16, y)
        Font.draw(("PP %2d/%2d"):format(move.pp or 0, maxPP(def, move)), 80, y + 10)
      else
        Font.draw("- EMPTY -", 16, y)
      end
    end
    if self.swapSlot then
      Font.draw("A/SELECT SWAP", 8, 128)
      Font.draw("B CANCEL", 8, 136)
    else
      Font.draw("A DETAILS", 8, 128)
      Font.draw("SELECT SWAP  B BACK", 8, 136)
    end
  end

  function Manager:drawPool()
    Font.draw(fit(self.poolTitle or "MOVES", 13), 8, 8)
    Font.draw(("%d/%d"):format(math.min(self.poolIndex, #self.pool), #self.pool), 120, 8)
    if #self.pool == 0 then
      Font.draw("No moves here.", 16, 56)
      Font.draw(self.mode == "pool" and "SELECT: ALL MOVES" or "SELECT: LEARNED", 8, 128)
      Font.draw("A/B BACK", 8, 136)
      return
    end
    for row = 1, 6 do
      local i = self.poolScroll + row
      local entry = self.pool[i]
      if not entry then break end
      local y = 16 + row * 16
      if i == self.poolIndex then Font.drawCode(Theme.cursor, 8, y) end
      Font.draw(fit(entry.name, 17), 16, y)
    end
    if self.mode == "pool" then
      Font.draw("A DETAILS SEL:ALL", 8, 128)
    elseif self.mode == "all_moves" then
      Font.draw("A DETAILS SEL:LEARN", 8, 128)
    else
      Font.draw("A OPEN  SEL:LEARN", 8, 128)
    end
    Font.draw("B BACK", 8, 136)
  end

  function Manager:drawDetail(moveId, moveInst, candidate)
    local def = moveId and self.game.data.moves[moveId]
    if not def then
      Font.draw("MOVE DATA MISSING", 8, 56)
      return
    end
    Font.draw(fit(def.name or moveId, 15), 8, 8)
    Font.draw(tostring(self.detailPage) .. "/3", 136, 8)

    if self.detailPage == 1 then
      drawLabelValue("TYPE", fit(typeName(def), 10), 28)
      drawLabelValue("CLASS", categoryName(def), 41)
      drawLabelValue("POWER", def.power or 0, 54)
      drawLabelValue("ACCURACY", tostring(def.accuracy or 0) .. "%", 67)
      local ppText
      if moveInst then
        ppText = ("%d/%d"):format(moveInst.pp or 0, maxPP(def, moveInst))
      else
        ppText = ("--/%d"):format(maxPP(def, nil))
      end
      drawLabelValue("PP", ppText, 80)
      drawLabelValue("PP UPS", moveInst and clamp(moveInst.ppUps or 0, 0, 3) or 0, 93)
      drawLabelValue("PRIORITY", def.priority or 0, 106)
      drawLabelValue("HIGH CRIT", def.highCrit and "YES" or "NO", 119)
    elseif self.detailPage == 2 then
      drawLabelValue("EFFECT", fit(humanize(def.effect), 10), 28)
      drawLabelValue("KIND", effectKind(def), 41)
      local fixed = "--"
      if type(def.fixedDamage) == "number" then fixed = tostring(def.fixedDamage)
      elseif type(def.fixedDamage) == "function" then fixed = "SPECIAL" end
      drawLabelValue("FIXED DMG", fixed, 54)
      drawLabelValue("MULTI HIT", multiHitText(def.multiHit), 67)
      drawLabelValue("COUNTER", def.counterable == false and "NO" or "YES", 80)
      drawLabelValue("CHARGE", def.chargeText and "YES" or "NO", 93)
      drawLabelValue("SEMI INV", def.semiInvulnerable and "YES" or "NO", 106)
      drawLabelValue("INDEX", def.index or "--", 119)
    else
      Font.draw("MOVE ID", 8, 22)
      local moveLines = wrappedLines(moveId, 18, 2)
      Font.draw(moveLines[1] or "--", 16, 34)
      if moveLines[2] then Font.draw(moveLines[2], 16, 44) end

      Font.draw("EFFECT ID", 8, 56)
      local effectLines = wrappedLines(def.effect, 18, 2)
      Font.draw(effectLines[1] or "--", 16, 68)
      if effectLines[2] then Font.draw(effectLines[2], 16, 78) end

      Font.draw("CHARGE TEXT", 8, 90)
      Font.draw(fit(def.chargeText or "--", 18), 16, 102)
      Font.draw("ANIMATION", 8, 114)
      local anim = def.anim == nil and "--" or (type(def.anim) == "table" and "CUSTOM" or tostring(def.anim))
      Font.draw(fit(anim, 18), 16, 124)
    end

    if self.detailPage < 3 then
      Font.draw((candidate and "A TEACH" or "A CHANGE") .. "  L/R PAGE", 8, 128)
      Font.draw("B BACK", 8, 136)
    else
      Font.draw(candidate and "A TEACH" or "A CHANGE", 8, 128)
      Font.draw("L/R PAGE  B BACK", 8, 136)
    end
  end

  function Manager:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)

    if self.mode == "known" then
      self:drawKnown()
    elseif self.mode == "pool" or self.mode == "all_sections"
        or self.mode == "all_groups" or self.mode == "all_moves" then
      self:drawPool()
    elseif self.mode == "candidate_detail" then
      local candidate = self:candidate()
      self:drawDetail(candidate and candidate.id, nil, true)
    else
      local move = self:currentMove()
      self:drawDetail(move and move.id, move, false)
    end

    love.graphics.setColor(1, 1, 1, 1)
  end


  -- Gen1 Modern UI compatibility contract (API v1). Moves Manager keeps
  -- ownership of move memory, navigation and edits. Modern UI only presents a
  -- read-only model of the live screen and sends semantic pointer actions.
  -- Without Modern UI the native 160x144 renderer above remains unchanged.
  local function syncModernPool(state)
    local n = #state.pool
    if n == 0 then
      state.poolIndex, state.poolScroll = 1, 0
      return
    end
    state.poolIndex = math.max(1, math.min(n, state.poolIndex or 1))
    if state.poolIndex < state.poolScroll + 1 then
      state.poolScroll = state.poolIndex - 1
    end
    if state.poolIndex > state.poolScroll + 6 then
      state.poolScroll = state.poolIndex - 6
    end
    state.poolScroll = math.max(0, math.min(state.poolScroll, math.max(0, n - 6)))
  end

  local function isListMode(mode)
    return mode == "pool" or mode == "all_sections"
      or mode == "all_groups" or mode == "all_moves"
  end

  local function modernKnownModel(state)
    local rows = {}
    for i = 1, 4 do
      local move = state.mon.moves and state.mon.moves[i]
      if move then
        local def = state.game.data.moves[move.id]
        rows[#rows + 1] = {
          label = (def and def.name) or move.id,
          value = ("PP %d/%d"):format(move.pp or 0, maxPP(def, move)),
          marker = state.swapSlot == i,
          enabled = true,
        }
      else
        rows[#rows + 1] = {
          label = "EMPTY SLOT",
          value = "--",
          marker = state.swapSlot == i,
          enabled = true,
        }
      end
    end
    return {
      title = "MOVES - " .. state:monName(),
      rows = rows,
      index = math.max(1, math.min(4, state.slot or 1)),
      scroll = 0,
      footer = state.swapSlot
        and { "A/SELECT SWAP", "B CANCEL" }
        or { "A DETAILS", "SELECT SWAP", "B BACK" },
    }
  end

  local function modernPoolModel(state)
    local rows = {}
    for _, entry in ipairs(state.pool or {}) do
      local def = entry.id and state.game.data.moves[entry.id] or nil
      rows[#rows + 1] = {
        label = entry.name or entry.id,
        value = def and typeName(def) or "OPEN",
        enabled = true,
      }
    end
    local footer
    if #rows == 0 then
      footer = { "NO MOVES HERE", "SELECT SWITCH", "A/B BACK" }
    elseif state.mode == "pool" then
      footer = { "A DETAILS", "SELECT ALL MOVES", "B BACK" }
    elseif state.mode == "all_moves" then
      footer = { "A DETAILS", "SELECT LEARNED", "B BACK" }
    else
      footer = { "A OPEN", "SELECT LEARNED", "B BACK" }
    end
    return {
      title = ("%s %d/%d"):format(state.poolTitle or "MOVES",
        math.min(state.poolIndex or 1, #rows), #rows),
      rows = rows,
      index = math.max(1, math.min(math.max(1, #rows), state.poolIndex or 1)),
      scroll = math.max(0, state.poolScroll or 0),
      footer = footer,
    }
  end

  local function modernDetailModel(state, candidate)
    local moveInst, moveId
    if candidate then
      local entry = state:candidate()
      moveId = entry and entry.id
    else
      moveInst = state:currentMove()
      moveId = moveInst and moveInst.id
    end
    local def = moveId and state.game.data.moves[moveId]
    if not def then
      return {
        title = "MOVE DETAILS",
        rows = { { label = "MOVE DATA MISSING", enabled = false } },
        index = 1,
        scroll = 0,
        footer = { "B BACK" },
      }
    end

    local rows = {
      { label = def.name or moveId, header = true, enabled = false },
    }
    if state.detailPage == 1 then
      local ppText = moveInst
        and ("%d/%d"):format(moveInst.pp or 0, maxPP(def, moveInst))
        or ("--/%d"):format(maxPP(def, nil))
      rows[#rows + 1] = { label = "TYPE", value = typeName(def), enabled = false }
      rows[#rows + 1] = { label = "CLASS", value = categoryName(def), enabled = false }
      rows[#rows + 1] = { label = "POWER", value = def.power or 0, enabled = false }
      rows[#rows + 1] = { label = "ACCURACY",
        value = tostring(def.accuracy or 0) .. "%", enabled = false }
      rows[#rows + 1] = { label = "PP", value = ppText, enabled = false }
      rows[#rows + 1] = { label = "PP UPS",
        value = moveInst and clamp(moveInst.ppUps or 0, 0, 3) or 0, enabled = false }
      rows[#rows + 1] = { label = "PRIORITY", value = def.priority or 0, enabled = false }
      rows[#rows + 1] = { label = "HIGH CRIT",
        value = def.highCrit and "YES" or "NO", marker = def.highCrit or nil,
        enabled = false }
    elseif state.detailPage == 2 then
      local fixed = "--"
      if type(def.fixedDamage) == "number" then fixed = tostring(def.fixedDamage)
      elseif type(def.fixedDamage) == "function" then fixed = "SPECIAL" end
      rows[#rows + 1] = { label = "EFFECT", value = humanize(def.effect), enabled = false }
      rows[#rows + 1] = { label = "KIND", value = effectKind(def), enabled = false }
      rows[#rows + 1] = { label = "FIXED DMG", value = fixed, enabled = false }
      rows[#rows + 1] = { label = "MULTI HIT",
        value = multiHitText(def.multiHit), enabled = false }
      rows[#rows + 1] = { label = "COUNTER",
        value = def.counterable == false and "NO" or "YES", enabled = false }
      rows[#rows + 1] = { label = "CHARGE",
        value = def.chargeText and "YES" or "NO", enabled = false }
      rows[#rows + 1] = { label = "SEMI INV",
        value = def.semiInvulnerable and "YES" or "NO", enabled = false }
      rows[#rows + 1] = { label = "INDEX", value = def.index or "--", enabled = false }
    else
      rows[#rows + 1] = { label = "MOVE ID", value = moveId, enabled = false }
      rows[#rows + 1] = { label = "EFFECT ID",
        value = def.effect or "--", enabled = false }
      rows[#rows + 1] = { label = "CHARGE TEXT",
        value = def.chargeText or "--", enabled = false }
      local anim = def.anim == nil and "--"
        or (type(def.anim) == "table" and "CUSTOM" or tostring(def.anim))
      rows[#rows + 1] = { label = "ANIMATION", value = anim, enabled = false }
    end
    rows[#rows + 1] = {
      label = candidate and "TEACH MOVE" or "CHANGE MOVE",
      value = "A",
      marker = true,
      enabled = true,
    }
    return {
      title = ("MOVE DETAILS %d/3"):format(state.detailPage or 1),
      rows = rows,
      index = #rows,
      scroll = math.max(0, #rows - 7),
      footer = {
        "L/R PAGE",
        candidate and "A TEACH" or "A CHANGE",
        "B BACK",
      },
    }
  end

  local function modernModel(state)
    if state.mode == "known" then return modernKnownModel(state) end
    if isListMode(state.mode) then return modernPoolModel(state) end
    return modernDetailModel(state, state.mode == "candidate_detail")
  end

  local modernUiContract = {
    apiVersion = 1,
    screens = {
      moves_manager = {
        match = function(state)
          return type(state) == "table" and state.screenId == SCREEN_ID
            and type(state.mon) == "table" and type(state.mode) == "string"
        end,
        canSuppressNative = true,
        model = function(_, state) return modernModel(state) end,
        actions = {
          hover = function(_, state, index)
            index = math.floor(tonumber(index) or 0)
            if state.mode == "known" then
              if index < 1 or index > 4 then return false end
              state.slot = index
              return true
            elseif isListMode(state.mode) then
              if not state.pool[index] then return false end
              state.poolIndex = index
              syncModernPool(state)
              return true
            end
            return index > 0
          end,
          select = function(_, state, index)
            index = math.floor(tonumber(index) or 0)
            if state.mode == "known" then
              if index >= 1 and index <= 4 then state.slot = index end
              if state.swapSlot then
                state:swapMoves(state.swapSlot, state.slot)
                state.swapSlot = nil
              else
                state:showCurrentDetail()
              end
              return true
            elseif isListMode(state.mode) then
              if index > 0 and state.pool[index] then state.poolIndex = index end
              if not state:candidate() then return false end
              syncModernPool(state)
              state:chooseList()
              return true
            elseif state.mode == "candidate_detail" then
              state:teachCandidate()
              return true
            elseif state.mode == "current_detail" then
              state:openPool()
              return true
            end
            return false
          end,
          up = function(_, state)
            if state.mode == "known" then
              state.slot = state.slot > 1 and state.slot - 1 or 4
              return true
            elseif isListMode(state.mode) and #state.pool > 0 then
              state.poolIndex = state.poolIndex > 1
                and state.poolIndex - 1 or #state.pool
              syncModernPool(state)
              return true
            end
            return false
          end,
          down = function(_, state)
            if state.mode == "known" then
              state.slot = state.slot < 4 and state.slot + 1 or 1
              return true
            elseif isListMode(state.mode) and #state.pool > 0 then
              state.poolIndex = state.poolIndex < #state.pool
                and state.poolIndex + 1 or 1
              syncModernPool(state)
              return true
            end
            return false
          end,
          left = function(_, state)
            if isListMode(state.mode) and #state.pool > 0 then
              state.poolIndex = math.max(1, state.poolIndex - 6)
              syncModernPool(state)
              return true
            elseif state.mode == "candidate_detail"
                or state.mode == "current_detail" then
              state.detailPage = state.detailPage > 1 and state.detailPage - 1 or 3
              return true
            end
            return false
          end,
          right = function(_, state)
            if isListMode(state.mode) and #state.pool > 0 then
              state.poolIndex = math.min(#state.pool, state.poolIndex + 6)
              syncModernPool(state)
              return true
            elseif state.mode == "candidate_detail"
                or state.mode == "current_detail" then
              state.detailPage = state.detailPage < 3 and state.detailPage + 1 or 1
              return true
            end
            return false
          end,
          back = function(_, state)
            if state.mode == "known" then
              if state.swapSlot then
                state.swapSlot = nil
              else
                state.game.stack:pop()
              end
            elseif isListMode(state.mode) then
              state:backList()
            elseif state.mode == "candidate_detail" then
              state.mode = state.candidateBackMode or "pool"
              state.detailPage = 1
            else
              state.mode = "known"
              state.detailPage = 1
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
      owner = "moves_manager",
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

  mod.content.screens:register(SCREEN_ID, {
    new = function(game, mon)
      ensureModernUiAdapter()
      return Manager.new(game, mon)
    end,
  })

  local function hasLabel(items, label)
    for _, item in ipairs(items or {}) do
      if item.label == label then return true end
    end
    return false
  end

  shared.registerPartyDecorator("moves", 20, function(game, result, mon, ctx)
    if not (ctx and ctx.battle) and not hasLabel(result, "MOVES") then
      mod.ui.insertAfter(result, "STATS", {
        label = "MOVES",
        onSelect = function(selectedMon, selectedGame)
          mod.ui.push(selectedGame, SCREEN_ID, selectedMon)
        end,
      })
    end
    return result
  end)

  mod.events:on("game.ready", function()
    ensureModernUiAdapter()
    local game = shared.game
    if game then
      local ok, missing, total = coverage(game)
      assert(ok, "ALL MOVES coverage failed for " .. tostring(missing))
      mod.log:info("All Moves indexed %d registered moves", total)
    end
  end)

  -- Register immediately when load order permits it; game.ready and screen
  -- creation retry for reloads or unusual optional-dependency ordering.
  ensureModernUiAdapter()

  mod.events:on("pokemon.move_learned", function(event)
    if event and event.mon and event.moveId then remember(event.mon, event.moveId) end
  end)

  mod.exports.learnedMoves = function(game, mon)
    local memory = seedMemory(game, mon)
    local out = {}
    for _, id in ipairs(memory.order) do out[#out + 1] = id end
    return out
  end
  mod.exports.replaceMove = applyReplacement
  mod.exports.maxPP = maxPP
  mod.exports.allMoves = {
    branch = moveBranch,
    rows = allMoveRows,
    coverage = coverage,
    physicalTypes = PHYSICAL_TYPES,
    specialTypes = SPECIAL_TYPES,
    statusGroups = STATUS_GROUPS,
  }
end
