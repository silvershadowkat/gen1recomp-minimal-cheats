local mod = ...

local M = {
  version = "2.1.2",
  game = nil,
  linkBattleActive = false,
  startItems = {},
  partyDecorators = {},
  stepCallbacks = {},
}

M.EXP_MULTIPLIERS = { 1, 2, 4, 8, 10 }
M.DAMAGE_MODES = { 1, 2, 4, 8, 10, "OHKO" }
M.MOVE_MULTIPLIERS = { 1.5, 2, 3, 4 }
M.BOOST_STATES = { "OFF", "ON", "HOLD" }
M.FLY_HEIGHTS = { "LOW", "MED", "HIGH" }

function M.get(key, default)
  local value = mod.save:get(key, default)
  if value == nil then return default end
  return value
end

function M.set(key, value)
  mod.save:set(key, value)
  return value
end

function M.bool(key, default)
  return M.get(key, default == true) == true
end

function M.allowed(key, values, default)
  local value = M.get(key, default)
  for _, candidate in ipairs(values) do
    if candidate == value then return value end
  end
  -- JSON-backed saves can turn integral values into strings in older builds.
  local numeric = tonumber(value)
  if numeric ~= nil then
    for _, candidate in ipairs(values) do
      if type(candidate) == "number" and candidate == numeric then return candidate end
    end
  end
  return default
end

function M.cycle(key, values, default)
  local current = M.allowed(key, values, default)
  for index, value in ipairs(values) do
    if current == value then
      return M.set(key, values[(index % #values) + 1])
    end
  end
  return M.set(key, values[1])
end

function M.isLinkBattle(battle)
  return battle ~= nil and battle.kind == "link"
end

function M.online()
  if M.linkBattleActive then return true end
  local game = M.game
  if not game then return false end
  if game.linkSession ~= nil then return true end
  return game.linkNet ~= nil and game.linkNet.closed ~= true
end

function M.gameplayAllowed(battle)
  return not M.online() and not M.isLinkBattle(battle)
end

function M.registerStartItem(id, priority, factory)
  M.startItems[#M.startItems + 1] = {
    id = id, priority = tonumber(priority) or 100, factory = factory,
  }
end

function M.registerPartyDecorator(id, priority, decorate)
  M.partyDecorators[#M.partyDecorators + 1] = {
    id = id, priority = tonumber(priority) or 100, decorate = decorate,
  }
end

function M.registerStepCallback(id, priority, callback)
  M.stepCallbacks[#M.stepCallbacks + 1] = {
    id = id, priority = tonumber(priority) or 100, callback = callback,
  }
end

local function stableSort(rows)
  table.sort(rows, function(a, b)
    if a.priority == b.priority then return a.id < b.id end
    return a.priority < b.priority
  end)
end

function M.sortedStartItems()
  stableSort(M.startItems)
  return M.startItems
end

function M.sortedPartyDecorators()
  stableSort(M.partyDecorators)
  return M.partyDecorators
end

function M.sortedStepCallbacks()
  stableSort(M.stepCallbacks)
  return M.stepCallbacks
end

function M.healPokemon(game, mon)
  if not mon then return end
  local ok, Pokemon = pcall(require, "src.pokemon.Pokemon")
  if ok and Pokemon and type(Pokemon.heal) == "function" then
    Pokemon.heal(mon)
    return
  end
  local def = game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
  local maxHP = mon.stats and mon.stats.hp or (def and def.hp) or mon.hp or 1
  mon.hp = math.max(1, tonumber(maxHP) or 1)
  mon.status = nil
  for _, move in ipairs(mon.moves or {}) do
    local moveDef = game.data.moves and game.data.moves[move.id]
    if moveDef then
      move.pp = (moveDef.pp or 0)
        + (move.ppUps or 0) * math.floor((moveDef.pp or 0) / 5)
    end
  end
end

mod.events:on("game.ready", function(event)
  M.game = event and event.game or M.game
end)

mod.events:on("battle.started", function(event)
  local battle = event and event.battle
  if M.isLinkBattle(battle) or (event and event.kind == "link") then
    M.linkBattleActive = true
  end
end)

mod.events:on("battle.ended", function(event)
  if M.isLinkBattle(event and event.battle) or (event and event.kind == "link") then
    M.linkBattleActive = false
  end
end)

return M
