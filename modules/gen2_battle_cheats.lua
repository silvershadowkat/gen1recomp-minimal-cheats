local mod, shared = ...

local battleState = setmetatable({}, { __mode = "k" })
local critEligible = false
local BALL_IDS = {
  POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true, MASTER_BALL = true,
  FAST_BALL = true, LEVEL_BALL = true, LURE_BALL = true, HEAVY_BALL = true,
  LOVE_BALL = true, FRIEND_BALL = true, MOON_BALL = true, PARK_BALL = true,
}

pcall(function()
  for id in mod.content.balls:each() do BALL_IDS[id] = true end
end)

local function isPlayer(battle, mon)
  return mon ~= nil and (mon.isPlayer == true or (battle and battle.player == mon))
end

local function gameplayAllowed(battle)
  return shared.gameplayAllowed(battle) and not (battle and battle.linkBattle)
end

local function expMultiplier()
  return shared.allowed("exp_multiplier", shared.EXP_MULTIPLIERS, 1)
end

local function damageMode()
  return shared.allowed("damage_multiplier", shared.DAMAGE_MODES, 1)
end

local function findOrderIndex(order, id)
  for index, value in ipairs(type(order) == "table" and order or {}) do
    if value == id then return index end
  end
end

local function snapshotBattle(battle)
  local state = { balls = {}, pp = nil }
  battleState[battle] = state
  if not gameplayAllowed(battle) then return state end
  local save = shared.game and shared.game.save
  local inventory = save and save.inventory
  for id in pairs(BALL_IDS) do
    local qty = type(inventory) == "table" and tonumber(inventory[id]) or nil
    if qty and qty > 0 then
      state.balls[id] = { qty = qty, orderIndex = findOrderIndex(save.bagOrder, id) }
    end
  end
  return state
end

local function ensureBattleState(battle)
  return battleState[battle] or snapshotBattle(battle)
end

local function restoreBall(battle, id)
  if not battle or not gameplayAllowed(battle)
      or not shared.bool("unlimited_balls", false) then return end
  local state = ensureBattleState(battle)
  local saved = state.balls[id]
  local save = shared.game and shared.game.save
  local inventory = save and save.inventory
  if not saved or type(inventory) ~= "table" then return end
  if (tonumber(inventory[id]) or 0) < saved.qty then inventory[id] = saved.qty end
  local order = save.bagOrder
  if type(order) == "table" and not findOrderIndex(order, id) then
    local at = math.max(1, math.min(saved.orderIndex or (#order + 1), #order + 1))
    table.insert(order, at, id)
  end
end

local function restoreAllBalls(battle)
  local state = battleState[battle]
  if not state then return end
  for id in pairs(state.balls) do restoreBall(battle, id) end
end

local function healActivePlayer(battle)
  if not battle or not gameplayAllowed(battle) then return end
  local mon = battle.player
  local maximum = mon and mon.stats and tonumber(mon.stats.hp)
  if maximum and maximum > 0 then mon.hp = maximum end
end

local function livePcCapacity(game)
  return tonumber(game and game.data and game.data.constants
    and game.data.constants.pcItemCap) or 50
end

local function ensureRareCandy(game)
  if not shared.bool("pc_rare_candy", false) or shared.online()
      or not (game and game.save) then return false end
  if game.data and game.data.items and not game.data.items.RARE_CANDY then return false end
  game.save.pcItems = game.save.pcItems or {}
  local pc = game.save.pcItems
  if (tonumber(pc.RARE_CANDY) or 0) >= 99 then return true end
  if pc.RARE_CANDY == nil then
    local stacks = 0
    for _ in pairs(pc) do stacks = stacks + 1 end
    if stacks >= livePcCapacity(game) then return false end
  end
  pc.RARE_CANDY = 99
  return true
end

shared.ensureRareCandy = ensureRareCandy
shared.maxCoins = function(game)
  if shared.online() or not (game and game.save) then return false end
  game.save.coins = 9999
  return true
end
shared.registerStepCallback("rare_candy", 50, ensureRareCandy)

mod.hooks:wrap("battle.damage", function(next, ctx)
  local battle, user, target = ctx and ctx.battle, ctx and ctx.user, ctx and ctx.target
  local allowed = gameplayAllowed(battle)
  local playerAttacking = allowed and isPlayer(battle, user)
    and target and not isPlayer(battle, target)
  local previous = critEligible
  critEligible = playerAttacking
  local damage, info = next(ctx)
  critEligible = previous
  if allowed and shared.bool("infinite_hp", false) and isPlayer(battle, target) then
    return 0, info
  end
  if playerAttacking and type(damage) == "number" and damage > 0 then
    local mode = damageMode()
    if mode == "OHKO" then
      damage = math.max(damage, tonumber(target.hp) or damage)
    elseif type(mode) == "number" and mode > 1 then
      damage = math.max(1, math.floor(damage * mode))
    end
  end
  return damage, info
end)

mod.hooks:wrap("battle.accuracy", function(next, ctx)
  local hit = next(ctx)
  if shared.bool("always_hit", false) and gameplayAllowed(ctx and ctx.battle)
      and isPlayer(ctx.battle, ctx.user) then return true end
  return hit
end)

mod.hooks:wrap("battle.crit", function(next, ctx)
  local crit = next(ctx)
  if shared.bool("always_crit", false) and critEligible
      and gameplayAllowed(ctx and ctx.battle)
      and isPlayer(ctx.battle, ctx.attacker) then return true end
  return crit
end)

mod.hooks:wrap("battle.turn_order", function(next, player, playerMove,
    enemy, enemyMove, ctx)
  local first = next(player, playerMove, enemy, enemyMove, ctx)
  if shared.bool("always_first", false) and gameplayAllowed(ctx and ctx.battle)
      and isPlayer(ctx.battle, player) then return true end
  return first
end)

mod.hooks:wrap("battle.run", function(next, ctx)
  local escaped = next(ctx)
  if shared.bool("always_escape", false) and gameplayAllowed(ctx and ctx.battle) then
    return true
  end
  return escaped
end)

mod.hooks:wrap("exp.gain", function(next, ctx)
  local gained = next(ctx)
  local multiplier = expMultiplier()
  if shared.online() or multiplier == 1 or type(gained) ~= "number" then
    return gained
  end
  return math.max(0, math.floor(gained * multiplier))
end)

mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
  local caught, rate = next(ball, mon, def, opts)
  if shared.bool("guaranteed_catch", false)
      and gameplayAllowed(opts and opts.battle) then return true, 255 end
  return caught, rate
end)

mod.hooks:wrap("encounter.roll", function(next, encounterDef, ctx)
  local encounter = next(encounterDef, ctx)
  if shared.bool("no_encounters", false) and not shared.online() then return nil end
  return encounter
end)

mod.events:on("game.ready", function(event)
  ensureRareCandy(event and event.game)
end)

mod.events:on("battle.started", function(event)
  local battle = event and event.battle
  if not battle then return end
  snapshotBattle(battle)
  if shared.bool("infinite_hp", false) then healActivePlayer(battle) end
end)

mod.events:on("battle.turn_started", function(event)
  local battle = event and event.battle
  if not battle or not gameplayAllowed(battle) then return end
  if shared.bool("infinite_hp", false) then healActivePlayer(battle) end
  local state = ensureBattleState(battle)
  state.pp = nil
  local action = event.playerAction
  if shared.bool("infinite_pp", false) and type(action) == "table" and action.id then
    for _, move in ipairs(battle.player and battle.player.moves or {}) do
      if move.id == action.id then state.pp = { move = move, pp = move.pp }; break end
    end
  end
end)

mod.events:on("battle.move_used", function(event)
  local battle = event and event.battle
  if not battle or not gameplayAllowed(battle) or not isPlayer(battle, event.user)
      or not shared.bool("infinite_pp", false) then return end
  local state = ensureBattleState(battle)
  local saved = state.pp
  state.pp = nil
  if saved and saved.pp ~= nil then saved.move.pp = saved.pp end
end)

mod.events:on("battle.ball_thrown", function(event)
  if event and event.battle and event.ball then restoreBall(event.battle, event.ball) end
end)

mod.events:on("battle.battler_switched", function(event)
  if shared.bool("infinite_hp", false) and gameplayAllowed(event and event.battle)
      and isPlayer(event.battle, event.battler) then healActivePlayer(event.battle) end
end)

mod.events:on("battle.turn_ended", function(event)
  local battle = event and event.battle
  if not battle or not gameplayAllowed(battle) then return end
  restoreAllBalls(battle)
  if shared.bool("infinite_hp", false) then healActivePlayer(battle) end
end)

mod.events:on("battle.ended", function(event)
  local battle = event and event.battle
  if not battle then return end
  if gameplayAllowed(battle) then restoreAllBalls(battle) end
  battleState[battle] = nil
  critEligible = false
end)

mod.exports.ensureRareCandy = ensureRareCandy
