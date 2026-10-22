local mod, shared = ...
local Adapter = require("src.core.game3.battle.adapter")
local Bag = require("src.core.game3.bag")
local Items = require("src.core.game3.items_data")
local states = setmetatable({}, { __mode = "k" })
local active

local function player(b) return b and b.side == "player" end
local function allowed(st) return shared.gameplayAllowed(st) end
local function enabled(key, st) return shared.bool(key, false) and allowed(st) end
local function eachPlayer(st, fn)
  if not st then return end
  for _, id in ipairs({0, 2}) do
    local b = st.battlers and st.battlers[id] or (id == 0 and st.player)
    if b and b.mon and not (st.absent and st.absent[id]) then fn(b) end
  end
end

-- All HP-loss paths (including poison, recoil and fixed damage) pass through
-- the adapter. Scope the wrapper to its battle, including both allied slots.
local originalAdapter = Adapter.new
Adapter.new = function(st, ...)
  local a = originalAdapter(st, ...)
  local loss, setHp = a.applyHpLoss, a.setHp
  a.applyHpLoss = function(self, b, amount, opts)
    if player(b) and enabled("infinite_hp", st) then return 0 end
    return loss(self, b, amount, opts)
  end
  a.setHp = function(self, b, value, opts)
    if player(b) and b.mon and enabled("infinite_hp", st)
        and (tonumber(value) or 0) < (tonumber(b.mon.hp) or 0) then return end
    return setHp(self, b, value, opts)
  end
  return a
end

mod.hooks:wrap("battle.damage", function(next, ctx)
  local damage, info = next(ctx)
  local st = ctx and ctx.battle
  if not ctx or not allowed(st) then return damage, info end
  if player(ctx.target) and enabled("infinite_hp", st) then return 0, info end
  if player(ctx.user) and not player(ctx.target) and type(damage) == "number" and damage > 0 then
    local mode = shared.allowed("damage_multiplier", shared.DAMAGE_MODES, 1)
    if mode == "OHKO" then
      damage = math.max(damage, tonumber(ctx.target and ctx.target.mon and ctx.target.mon.hp) or damage)
    elseif type(mode) == "number" then damage = math.floor(damage * mode) end
  end
  return damage, info
end)
mod.hooks:wrap("battle.accuracy", function(next, ctx)
  if ctx and player(ctx.user) and enabled("always_hit", ctx.battle) then return true end
  return next(ctx)
end)
mod.hooks:wrap("battle.crit", function(next, ctx)
  if ctx and player(ctx.attacker) and enabled("always_crit", ctx.battle) then return true end
  return next(ctx)
end)
mod.hooks:wrap("battle.turn_order", function(next, a, am, b, bm, ctx)
  if enabled("always_first", ctx and ctx.battle) and player(a) ~= player(b) then
    return player(a) == true
  end
  return next(a, am, b, bm, ctx)
end)
mod.hooks:wrap("battle.run", function(next, ctx)
  if enabled("always_escape", ctx and ctx.battle) then return true end
  return next(ctx)
end)
mod.hooks:wrap("exp.gain", function(next, ctx)
  local amount = next(ctx)
  if not allowed(ctx and ctx.battle) or type(amount) ~= "number" then return amount end
  return math.floor(amount * shared.allowed("exp_multiplier", shared.EXP_MULTIPLIERS, 1))
end)
mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
  if enabled("guaranteed_catch", opts and opts.battle) then return true, 4 end
  return next(ball, mon, def, opts)
end)
mod.hooks:wrap("encounter.roll", function(next, def, ctx)
  local search=shared.gen3DexNavPending and shared.gen3DexNavPending()
  if (enabled("no_encounters")and not search)or shared.gen3Flying then return nil end
  return next(def, ctx)
end)

local function restorePP(st)
  local state = states[st]
  if not state or not enabled("infinite_pp", st) then return end
  for mon, pp in pairs(state.pp or {}) do
    for i, value in pairs(pp) do if mon.pp then mon.pp[i] = value end end
  end
end
local function healActive(st)
  if enabled("infinite_hp", st) then
    eachPlayer(st, function(b) b.mon.hp = b.mon.maxHp or b.mon.hp; b.fainted = false end)
  end
end
mod.events:on("battle.started", function(e)
  local st = e and e.battle
  if not st then return end
  active = st
  states[st] = { pp = {} }
  healActive(st)
end)
mod.events:on("battle.turn_started", function(e)
  local st = e and e.battle
  if not st or not allowed(st) then return end
  active = st
  local state = states[st] or {}; states[st] = state; state.pp = {}
  if enabled("infinite_pp", st) then
    eachPlayer(st, function(b)
      local pp = {}; for i, value in pairs(b.mon.pp or {}) do pp[i] = value end
      state.pp[b.mon] = pp
    end)
  end
  healActive(st)
end)
mod.events:on("battle.move_used", function(e) if e and e.battle then restorePP(e.battle) end end)
mod.events:on("battle.turn_ended", function(e)
  if e and e.battle then restorePP(e.battle); healActive(e.battle) end
end)
mod.events:on("battle.battler_switched", function(e) if e then healActive(e.battle) end end)
mod.events:on("battle.ended", function(e)
  if e and e.battle then restorePP(e.battle); states[e.battle] = nil end
  active = nil
end)

-- Prevent exactly the battle's ball consumption rather than restoring an old
-- bag snapshot (which can duplicate or delete legitimately acquired items).
local remove = Bag.remove
Bag.remove = function(bag, id, qty)
  if active and active.session and bag == active.session.bag
      and enabled("unlimited_balls", active) then
    for _, row in ipairs(Bag.listPocket(bag, "POKE_BALLS")) do
      if row.id == (Items.toNumericId(id) or id) and row.qty >= (qty or 1) then return true end
    end
  end
  return remove(bag, id, qty)
end
shared.gen3Battle = { isPlayer = player, allowed = allowed }
