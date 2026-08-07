local mod, shared = ...

local battleState = setmetatable({}, { __mode = "k" })
local critEligible = false
local BALL_IDS = {
  POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true, MASTER_BALL = true,
}

pcall(function()
  for id in mod.content.balls:each() do BALL_IDS[id] = true end
end)

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
  return nil
end

local function snapshotBattle(battle)
  local state = { balls = {}, safariBalls = nil, pp = nil }
  battleState[battle] = state
  if not shared.gameplayAllowed(battle) then return state end
  local save = battle.game and battle.game.save
  local inventory = save and save.inventory
  for id in pairs(BALL_IDS) do
    local qty = type(inventory) == "table" and tonumber(inventory[id]) or nil
    if qty and qty > 0 then
      state.balls[id] = { qty = qty, orderIndex = findOrderIndex(save.bagOrder, id) }
    end
  end
  if battle.safari and type(battle.safari.balls) == "number" then
    state.safariBalls = battle.safari.balls
  end
  return state
end

local function ensureBattleState(battle)
  return battleState[battle] or snapshotBattle(battle)
end

local function restoreBagOrder(save, id, preferredIndex)
  local order = save and save.bagOrder
  if type(order) ~= "table" or findOrderIndex(order, id) then return end
  local index = math.max(1, math.min(tonumber(preferredIndex) or (#order + 1), #order + 1))
  table.insert(order, index, id)
end

local function restoreBall(battle, id)
  if not battle or not shared.gameplayAllowed(battle)
      or not shared.bool("unlimited_balls", false) then return end
  local state = ensureBattleState(battle)
  if id == "SAFARI_BALL" and state.safariBalls and battle.safari then
    battle.safari.balls = state.safariBalls
    return
  end
  local saved = state.balls[id]
  local save = battle.game and battle.game.save
  local inventory = save and save.inventory
  if not saved or type(inventory) ~= "table" then return end
  if (tonumber(inventory[id]) or 0) < saved.qty then inventory[id] = saved.qty end
  restoreBagOrder(save, id, saved.orderIndex)
end

local function restoreAllBalls(battle)
  if not battle or not shared.gameplayAllowed(battle)
      or not shared.bool("unlimited_balls", false) then return end
  local state = ensureBattleState(battle)
  if state.safariBalls and battle.safari then battle.safari.balls = state.safariBalls end
  for id in pairs(state.balls) do restoreBall(battle, id) end
end

local function healActivePlayer(battle)
  if not battle or not shared.gameplayAllowed(battle) then return end
  local battler = battle.player
  local mon = battler and battler.mon
  local maxHP = mon and mon.stats and tonumber(mon.stats.hp)
  if not maxHP or maxHP <= 0 then return end
  mon.hp = maxHP
  if battler.shownHP ~= nil then battler.shownHP = maxHP end
end

local function livePcCapacity(game)
  return tonumber(game and game.data and game.data.field
    and game.data.field.pcItemCap) or 999
end

local function ensureRareCandy(game)
  if not shared.bool("pc_rare_candy", false) or shared.online()
      or not (game and game.save) then return false end
  if game.data and game.data.items and not game.data.items.RARE_CANDY then return false end
  game.save.pcItems = game.save.pcItems or {}
  local pc = game.save.pcItems
  local current = tonumber(pc.RARE_CANDY) or 0
  if current >= 99 then return true end
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
  local allowed = shared.gameplayAllowed(battle)
  local playerAttackingEnemy = allowed and user and user.isPlayer == true
    and target and target.isPlayer ~= true
  local previous = critEligible
  critEligible = playerAttackingEnemy
  local damage, info = next(ctx)
  critEligible = previous
  if allowed and shared.bool("infinite_hp", false)
      and target and target.isPlayer == true then return 0, info end
  if playerAttackingEnemy and type(damage) == "number" and damage > 0 then
    local mode = damageMode()
    if mode == "OHKO" then
      damage = math.max(damage, tonumber(target.mon and target.mon.hp) or damage)
    elseif type(mode) == "number" and mode > 1 then
      damage = math.max(1, math.floor(damage * mode))
    end
  end
  return damage, info
end)

mod.hooks:wrap("battle.accuracy", function(next, ctx)
  local hit = next(ctx)
  if shared.bool("always_hit", false) and shared.gameplayAllowed(ctx and ctx.battle)
      and ctx and ctx.user and ctx.user.isPlayer == true
      and ctx.target and ctx.target.isPlayer ~= true then return true end
  return hit
end)

mod.hooks:wrap("battle.crit", function(next, ctx)
  local crit = next(ctx)
  if shared.bool("always_crit", false) and critEligible and not shared.online()
      and ctx and ctx.attacker and ctx.attacker.isPlayer == true then return true end
  return crit
end)

mod.hooks:wrap("battle.turn_order", function(next, player, playerMove, enemy, enemyMove, ctx)
  local first = next(player, playerMove, enemy, enemyMove, ctx)
  if shared.bool("always_first", false) and not shared.online()
      and type(ctx) == "table" and ctx.invertTie == nil
      and player and player.isPlayer == true and enemy and enemy.isPlayer ~= true then
    return true
  end
  return first
end)

mod.hooks:wrap("battle.run", function(next, ctx)
  local escaped = next(ctx)
  if shared.bool("always_escape", false)
      and shared.gameplayAllowed(ctx and ctx.battle) then return true end
  return escaped
end)

mod.hooks:wrap("exp.gain", function(next, ctx)
  local gained = next(ctx)
  local multiplier = expMultiplier()
  if shared.online() or multiplier == 1 or type(gained) ~= "number" then return gained end
  return math.max(0, math.floor(gained * multiplier))
end)

mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
  local caught, shakes = next(ball, mon, def, opts)
  if shared.bool("guaranteed_catch", false)
      and shared.gameplayAllowed(opts and opts.battle) then return true, 3 end
  return caught, shakes
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
  if shared.isLinkBattle(battle) then
    battleState[battle] = { balls = {}, pp = nil }
    return
  end
  snapshotBattle(battle)
  if shared.bool("infinite_hp", false) then healActivePlayer(battle) end
end)

mod.events:on("battle.turn_started", function(event)
  local battle = event and event.battle
  if not battle or not shared.gameplayAllowed(battle) then return end
  if shared.bool("infinite_hp", false) then healActivePlayer(battle) end
  local state = ensureBattleState(battle)
  state.pp = nil
  local action = event.playerAction
  if shared.bool("infinite_pp", false) and type(action) == "table"
      and action.id ~= nil and type(action.pp) == "number" then
    state.pp = { move = action, pp = action.pp }
  end
end)

mod.events:on("battle.move_used", function(event)
  local battle = event and event.battle
  if not battle or not shared.gameplayAllowed(battle)
      or not shared.bool("infinite_pp", false)
      or not (event.user and event.user.isPlayer == true) then return end
  local state = ensureBattleState(battle)
  local saved = state.pp
  state.pp = nil
  if saved and type(saved.move.pp) == "number" then saved.move.pp = saved.pp end
end)

mod.events:on("battle.ball_thrown", function(event)
  if event and event.battle and event.ball then restoreBall(event.battle, event.ball) end
end)

mod.events:on("battle.battler_switched", function(event)
  if shared.bool("infinite_hp", false) and shared.gameplayAllowed(event and event.battle)
      and event.battler and event.battler.isPlayer == true then
    healActivePlayer(event.battle)
  end
end)

mod.events:on("battle.turn_ended", function(event)
  local battle = event and event.battle
  if not battle or not shared.gameplayAllowed(battle) then return end
  restoreAllBalls(battle)
  if shared.bool("infinite_hp", false) then healActivePlayer(battle) end
end)

mod.events:on("battle.ended", function(event)
  local battle = event and event.battle
  if not battle then return end
  if not shared.isLinkBattle(battle) then restoreAllBalls(battle) end
  battleState[battle] = nil
  critEligible = false
end)

mod.exports.ensureRareCandy = ensureRareCandy
