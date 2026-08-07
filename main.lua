local SCREEN_ROOT = "MinimalCheatsMenu"
local SCREEN_BATTLE = "MinimalCheatsBattle"
local SCREEN_WORLD = "MinimalCheatsWorld"
local SCREEN_SUPPLIES = "MinimalCheatsSupplies"

local EXP_MULTIPLIERS = { 1, 2, 4, 8, 10 }
local DAMAGE_MODES = { 1, 2, 4, 8, 10, "OHKO" }
local MOVE_SPEEDS = { 1, 2, 3, 4 }

-- Built-in Gen I balls. We also merge any additional balls that are already
-- registered when this mod loads so ball restoration remains friendly to mods
-- that add their balls before us.
local BALL_IDS = {
    POKE_BALL = true,
    GREAT_BALL = true,
    ULTRA_BALL = true,
    MASTER_BALL = true,
}

return function(mod)
    -- Weak keys ensure completed BattleState instances can still be collected.
    local battleState = setmetatable({}, { __mode = "k" })

    -- The Game object is intentionally obtained through the public game.ready
    -- event. It gives us an additional online/link-session guard for hooks that
    -- do not receive a BattleState in their arguments.
    local gameRef = nil
    local linkBattleActive = false

    -- battle.crit does not receive the target or BattleState. battle.damage
    -- does, and battle.crit runs from inside the vanilla damage calculation,
    -- so this narrow dynamic flag lets ALWAYS CRIT apply only to a normal
    -- single-player player->enemy damage calculation.
    local critEligible = false

    -- Read-only registry discovery through the supported mod object. The four
    -- built-in IDs above remain as a fallback if another mod/API version changes
    -- registry iteration behavior.
    pcall(function()
        for id in mod.content.balls:each() do
            BALL_IDS[id] = true
        end
    end)

    local function enabled(key)
        return mod.save:get(key, false) == true
    end

    local function isLinkBattle(battle)
        return battle ~= nil and battle.kind == "link"
    end

    local function onlineSessionActive()
        if linkBattleActive then
            return true
        end
        local game = gameRef
        if game == nil then
            return false
        end
        if game.linkSession ~= nil then
            return true
        end
        if game.linkNet ~= nil and game.linkNet.closed ~= true then
            return true
        end
        return false
    end

    local function battleCheatsAllowed(battle)
        return not onlineSessionActive() and not isLinkBattle(battle)
    end

    local function allowedValue(key, values, default)
        local current = mod.save:get(key, default)
        for _, allowed in ipairs(values) do
            if current == allowed then
                return current
            end
        end
        return default
    end

    local function expMultiplier()
        local raw = tonumber(mod.save:get("exp_multiplier", 1)) or 1
        for _, allowed in ipairs(EXP_MULTIPLIERS) do
            if raw == allowed then
                return allowed
            end
        end
        return 1
    end

    local function damageMode()
        return allowedValue("damage_multiplier", DAMAGE_MODES, 1)
    end

    local function moveSpeed()
        local raw = tonumber(mod.save:get("movement_speed", 1)) or 1
        for _, allowed in ipairs(MOVE_SPEEDS) do
            if raw == allowed then
                return allowed
            end
        end
        return 1
    end

    local function cycleValue(key, values, default)
        local current = allowedValue(key, values, default)
        local nextValue = values[1]
        for i, value in ipairs(values) do
            if value == current then
                nextValue = values[(i % #values) + 1]
                break
            end
        end
        mod.save:set(key, nextValue)
        return nextValue
    end

    local function cycleExpMultiplier()
        local current = expMultiplier()
        local nextValue = EXP_MULTIPLIERS[1]
        for i, value in ipairs(EXP_MULTIPLIERS) do
            if value == current then
                nextValue = EXP_MULTIPLIERS[(i % #EXP_MULTIPLIERS) + 1]
                break
            end
        end
        mod.save:set("exp_multiplier", nextValue)
        return nextValue
    end

    local function cycleMoveSpeed()
        local current = moveSpeed()
        local nextValue = MOVE_SPEEDS[1]
        for i, value in ipairs(MOVE_SPEEDS) do
            if value == current then
                nextValue = MOVE_SPEEDS[(i % #MOVE_SPEEDS) + 1]
                break
            end
        end
        mod.save:set("movement_speed", nextValue)
        return nextValue
    end

    local function displayMultiplier(value)
        if value == "OHKO" then
            return "OHKO"
        end
        return "x" .. tostring(value)
    end

    local function toggleLabel(key)
        return enabled(key) and "ON" or "OFF"
    end

    local function healActivePlayer(battle)
        if battle == nil or not battleCheatsAllowed(battle) then
            return
        end

        local battler = battle.player
        local mon = battler and battler.mon
        local maxHP = mon and mon.stats and tonumber(mon.stats.hp)
        if mon == nil or maxHP == nil or maxHP <= 0 then
            return
        end

        mon.hp = maxHP
        if battler.shownHP ~= nil then
            battler.shownHP = maxHP
        end
    end

    local function findOrderIndex(order, id)
        if type(order) ~= "table" then
            return nil
        end
        for i, value in ipairs(order) do
            if value == id then
                return i
            end
        end
        return nil
    end

    local function snapshotBattle(battle)
        local state = {
            balls = {},
            safariBalls = nil,
            pp = nil,
        }
        battleState[battle] = state

        if battle == nil or not battleCheatsAllowed(battle) then
            return state
        end

        local save = battle.game and battle.game.save
        local inventory = save and save.inventory
        local order = save and save.bagOrder

        if type(inventory) == "table" then
            for id in pairs(BALL_IDS) do
                local qty = tonumber(inventory[id])
                if qty ~= nil and qty > 0 then
                    state.balls[id] = {
                        qty = qty,
                        orderIndex = findOrderIndex(order, id),
                    }
                end
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
        if type(order) ~= "table" then
            return
        end

        if findOrderIndex(order, id) ~= nil then
            return
        end

        local index = tonumber(preferredIndex) or (#order + 1)
        if index < 1 then
            index = 1
        elseif index > (#order + 1) then
            index = #order + 1
        end
        table.insert(order, index, id)
    end

    local function restoreBall(battle, id)
        if battle == nil or not battleCheatsAllowed(battle)
            or not enabled("unlimited_balls")
        then
            return
        end

        local state = ensureBattleState(battle)

        if id == "SAFARI_BALL" and state.safariBalls ~= nil and battle.safari then
            battle.safari.balls = state.safariBalls
            return
        end

        local saved = state.balls[id]
        local save = battle.game and battle.game.save
        local inventory = save and save.inventory
        if saved == nil or type(inventory) ~= "table" then
            return
        end

        local current = tonumber(inventory[id]) or 0
        if current < saved.qty then
            inventory[id] = saved.qty
        end
        restoreBagOrder(save, id, saved.orderIndex)
    end

    local function restoreAllBalls(battle)
        if battle == nil or not battleCheatsAllowed(battle)
            or not enabled("unlimited_balls")
        then
            return
        end

        local state = ensureBattleState(battle)
        if state.safariBalls ~= nil and battle.safari then
            battle.safari.balls = state.safariBalls
        end

        for id in pairs(state.balls) do
            restoreBall(battle, id)
        end
    end

    -- Keep at least 99 Rare Candies in the player's item-storage PC while the
    -- cheat is enabled. Existing amounts above 99 are never reduced, and a new
    -- stack is not inserted when the PC is already at its normal stack cap.
    -- Because this runs from the public input.step hook, it also covers the
    -- bedroom PC, which bypasses the Pokemon Center ui.pc.items hook.
    local function ensureRareCandy(game)
        if not enabled("pc_rare_candy") or onlineSessionActive() then
            return false
        end
        if game == nil or game.save == nil then
            return false
        end
        if game.data and game.data.items and game.data.items.RARE_CANDY == nil then
            return false
        end

        game.save.pcItems = game.save.pcItems or {}
        local pc = game.save.pcItems
        local current = tonumber(pc.RARE_CANDY) or 0
        if current >= 99 then
            return true
        end

        if current <= 0 and pc.RARE_CANDY == nil then
            local cap = (game.data and game.data.field and game.data.field.pcItemCap) or 50
            local stacks = 0
            for _ in pairs(pc) do
                stacks = stacks + 1
            end
            if stacks >= cap then
                return false
            end
        end

        pc.RARE_CANDY = 99
        return true
    end

    local function toggleItem(label, key)
        return {
            label = label,
            key = key,
            kind = "toggle",
            right = toggleLabel(key),
        }
    end

    local function openItem(label, screen)
        return {
            label = label,
            kind = "screen",
            screen = screen,
            right = "OPEN",
        }
    end

    local function handleMenuItem(game, item, list)
        if item.kind == "toggle" then
            local value = not enabled(item.key)
            mod.save:set(item.key, value)
            item.right = value and "ON" or "OFF"
            if item.key == "pc_rare_candy" and value then
                if ensureRareCandy(game) then
                    list.footer = "PC stocked with Rare Candy."
                else
                    list.footer = "PC is full; free one item slot."
                end
            end
        elseif item.kind == "exp" then
            item.right = "x" .. tostring(cycleExpMultiplier())
        elseif item.kind == "damage" then
            item.right = displayMultiplier(cycleValue(
                "damage_multiplier", DAMAGE_MODES, 1))
        elseif item.kind == "speed" then
            item.right = "x" .. tostring(cycleMoveSpeed())
        elseif item.kind == "screen" then
            mod.ui.push(game, item.screen)
        elseif item.kind == "action" and item.action == "max_coins" then
            if onlineSessionActive() then
                list.footer = "Unavailable during online/link play."
                return
            end
            if game and game.save then
                game.save.coins = 9999
                item.right = "9999"
                list.footer = "Game Corner coins set to 9999."
            end
        end
    end

    local function makeMenu(game, title, items, kind)
        local footer = kind == "minimal_cheats_root"
            and "A:OPEN  B:BACK"
            or "A:CHANGE  B:BACK"

        return mod.ui.ListMenu.new(game, title, items, {
            kind = kind,
            -- Reserve the bottom two text lines for the footer. Long cheat
            -- categories now scroll instead of letting row 7 collide with a
            -- wrapped footer/message.
            rows = 6,
            footer = footer,
            onChoose = function(item, list)
                handleMenuItem(game, item, list)
            end,
        })
    end

    -- Category root. The growing cheat set stays organized instead of turning
    -- the Options screen into one long flat list.
    mod.content.screens:register(SCREEN_ROOT, {
        new = function(game)
            return makeMenu(game, "CHEATS", {
                openItem("BATTLE", SCREEN_BATTLE),
                openItem("WORLD", SCREEN_WORLD),
                openItem("SUPPLIES", SCREEN_SUPPLIES),
            }, "minimal_cheats_root")
        end,
    })

    mod.content.screens:register(SCREEN_BATTLE, {
        new = function(game)
            return makeMenu(game, "BATTLE CHEATS", {
                toggleItem("INFINITE HP", "infinite_hp"),
                toggleItem("INFINITE PP", "infinite_pp"),
                { label = "EXP RATE", key = "exp_multiplier", kind = "exp",
                  right = "x" .. tostring(expMultiplier()) },
                { label = "DAMAGE", key = "damage_multiplier", kind = "damage",
                  right = displayMultiplier(damageMode()) },
                toggleItem("ALWAYS HIT", "always_hit"),
                toggleItem("ALWAYS CRIT", "always_crit"),
                toggleItem("ALWAYS FIRST", "always_first"),
                toggleItem("ALWAYS ESCAPE", "always_escape"),
                toggleItem("100% CATCH", "guaranteed_catch"),
            }, "minimal_cheats_battle")
        end,
    })

    mod.content.screens:register(SCREEN_WORLD, {
        new = function(game)
            return makeMenu(game, "WORLD CHEATS", {
                toggleItem("NO ENCOUNTERS", "no_encounters"),
                { label = "MOVE SPEED", key = "movement_speed", kind = "speed",
                  right = "x" .. tostring(moveSpeed()) },
            }, "minimal_cheats_world")
        end,
    })

    mod.content.screens:register(SCREEN_SUPPLIES, {
        new = function(game)
            return makeMenu(game, "SUPPLIES", {
                toggleItem("ENDLESS BALLS", "unlimited_balls"),
                toggleItem("PC RARE CANDY", "pc_rare_candy"),
                { label = "MAX GAME COINS", kind = "action", action = "max_coins",
                  right = "SET" },
            }, "minimal_cheats_supplies")
        end,
    })

    mod.hooks:wrap("ui.options.rows", function(next, game, rows)
        local out = next(game, rows)
        if type(out) ~= "table" then
            return out
        end

        out[#out + 1] = {
            id = "minimal_cheats",
            label = "CHEATS",
            value = function()
                return "OPEN"
            end,
            activate = function(g)
                mod.ui.push(g, SCREEN_ROOT)
            end,
        }

        return out
    end)

    -- Pokemon Center PCs expose this public hook. The continuous input.step
    -- replenisher below also covers Red's bedroom PC and provides the actual
    -- "always at least 99" behavior after withdrawals.
    mod.hooks:wrap("ui.pc.items", function(next, game, items)
        gameRef = gameRef or game
        ensureRareCandy(game)
        return next(game, items)
    end)

    mod.hooks:wrap("input.step", function(next, game, dt)
        gameRef = gameRef or game
        local result = next(game, dt)
        ensureRareCandy(game)
        return result
    end)

    -- Normal battle damage uses the documented battle.damage hook. This is
    -- deliberately single-player only. It also provides the dynamic context
    -- used by ALWAYS CRIT so that confusion/self-damage is never force-critted.
    mod.hooks:wrap("battle.damage", function(next, ctx)
        local battle = ctx and ctx.battle
        local user = ctx and ctx.user
        local target = ctx and ctx.target
        local allowed = battleCheatsAllowed(battle)
        local playerAttackingEnemy = allowed
            and user ~= nil and user.isPlayer == true
            and target ~= nil and target.isPlayer ~= true

        local previousCritEligible = critEligible
        critEligible = playerAttackingEnemy
        local damage, info = next(ctx)
        critEligible = previousCritEligible

        if allowed
            and enabled("infinite_hp")
            and target ~= nil
            and target.isPlayer == true
        then
            return 0, info
        end

        if playerAttackingEnemy and type(damage) == "number" and damage > 0 then
            local mode = damageMode()
            if mode == "OHKO" then
                local hp = target.mon and tonumber(target.mon.hp)
                if hp ~= nil and hp > 0 then
                    damage = math.max(damage, hp)
                end
            elseif type(mode) == "number" and mode > 1 then
                damage = math.max(1, math.floor(damage * mode))
            end
        end

        return damage, info
    end)

    mod.hooks:wrap("battle.accuracy", function(next, ctx)
        local hit = next(ctx)
        local battle = ctx and ctx.battle
        local user = ctx and ctx.user
        local target = ctx and ctx.target

        if enabled("always_hit")
            and battleCheatsAllowed(battle)
            and user ~= nil and user.isPlayer == true
            and target ~= nil and target.isPlayer ~= true
        then
            return true
        end

        return hit
    end)

    mod.hooks:wrap("battle.crit", function(next, ctx)
        local crit = next(ctx)
        if enabled("always_crit")
            and critEligible
            and not onlineSessionActive()
            and ctx ~= nil
            and ctx.attacker ~= nil
            and ctx.attacker.isPlayer == true
        then
            return true
        end
        return crit
    end)

    -- LinkBattle intentionally calls this same hook, but unlike the normal
    -- BattleState call it always supplies ctx.invertTie (true or false).
    -- Requiring nil here is an additional hard PvP guard on top of the global
    -- online/link-session lock.
    mod.hooks:wrap("battle.turn_order", function(next, player, playerMove, enemy, enemyMove, ctx)
        local playerFirst = next(player, playerMove, enemy, enemyMove, ctx)
        if enabled("always_first")
            and not onlineSessionActive()
            and type(ctx) == "table"
            and ctx.invertTie == nil
            and player ~= nil and player.isPlayer == true
            and enemy ~= nil and enemy.isPlayer ~= true
        then
            return true
        end
        return playerFirst
    end)

    mod.hooks:wrap("battle.run", function(next, ctx)
        local escaped = next(ctx)
        local battle = ctx and ctx.battle
        if enabled("always_escape") and battleCheatsAllowed(battle) then
            return true
        end
        return escaped
    end)

    mod.hooks:wrap("exp.gain", function(next, ctx)
        local gained = next(ctx)
        local multiplier = expMultiplier()

        -- Link battles normally award no EXP, but this guard also ensures a
        -- future engine change cannot make the multiplier affect PvP.
        if onlineSessionActive() or multiplier == 1 or type(gained) ~= "number" then
            return gained
        end

        return math.max(0, math.floor(gained * multiplier))
    end)

    mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
        local caught, shakes = next(ball, mon, def, opts)
        local battle = opts and opts.battle

        if enabled("guaranteed_catch") and battleCheatsAllowed(battle) then
            return true, 3
        end

        return caught, shakes
    end)

    mod.hooks:wrap("encounter.roll", function(next, encounterDef, ctx)
        local encounter = next(encounterDef, ctx)
        if enabled("no_encounters") and not onlineSessionActive() then
            return nil
        end
        return encounter
    end)

    mod.hooks:wrap("movement.speed", function(next, frames, ctx)
        local vanillaFrames = next(frames, ctx)
        if onlineSessionActive() then
            return vanillaFrames
        end

        local multiplier = moveSpeed()
        if multiplier <= 1 then
            return vanillaFrames
        end

        return math.max(1, math.floor((tonumber(vanillaFrames) or frames or 16) / multiplier))
    end)

    mod.events:on("game.ready", function(event)
        gameRef = event and event.game or gameRef
        if gameRef then
            ensureRareCandy(gameRef)
        end
    end)

    mod.events:on("battle.started", function(event)
        local battle = event and event.battle
        if battle == nil then
            return
        end

        if isLinkBattle(battle) or (event and event.kind == "link") then
            linkBattleActive = true
            battleState[battle] = { balls = {}, safariBalls = nil, pp = nil }
            return
        end

        snapshotBattle(battle)
        if enabled("infinite_hp") then
            healActivePlayer(battle)
        end
    end)

    -- Snapshot the exact selected move instance before PP is consumed. The
    -- documented move_used event fires immediately after normal PP decrement,
    -- allowing the same instance's PP to be restored without replacing move
    -- resolution code.
    mod.events:on("battle.turn_started", function(event)
        local battle = event and event.battle
        if battle == nil then
            return
        end
        if isLinkBattle(battle) then
            linkBattleActive = true
            return
        end
        if not battleCheatsAllowed(battle) then
            return
        end

        if enabled("infinite_hp") then
            healActivePlayer(battle)
        end

        local state = ensureBattleState(battle)
        state.pp = nil

        if enabled("infinite_pp") then
            local action = event.playerAction
            if type(action) == "table" and action.id ~= nil and type(action.pp) == "number" then
                state.pp = {
                    move = action,
                    pp = action.pp,
                }
            end
        end
    end)

    mod.events:on("battle.move_used", function(event)
        local battle = event and event.battle
        if battle == nil or not battleCheatsAllowed(battle)
            or not enabled("infinite_pp")
        then
            return
        end

        local user = event.user
        if user == nil or user.isPlayer ~= true then
            return
        end

        local state = ensureBattleState(battle)
        local saved = state.pp
        state.pp = nil

        if saved ~= nil and type(saved.move) == "table" and type(saved.move.pp) == "number" then
            saved.move.pp = saved.pp
        end
    end)

    mod.events:on("battle.ball_thrown", function(event)
        local battle = event and event.battle
        local ball = event and event.ball
        if battle ~= nil and ball ~= nil then
            restoreBall(battle, ball)
        end
    end)

    mod.events:on("battle.battler_switched", function(event)
        local battle = event and event.battle
        local battler = event and event.battler
        if enabled("infinite_hp")
            and battleCheatsAllowed(battle)
            and battler ~= nil and battler.isPlayer == true
        then
            healActivePlayer(battle)
        end
    end)

    mod.events:on("battle.turn_ended", function(event)
        local battle = event and event.battle
        if battle == nil then
            return
        end
        if isLinkBattle(battle) then
            linkBattleActive = true
            return
        end
        if not battleCheatsAllowed(battle) then
            return
        end

        -- Safety fallback for paths where a ball may be consumed without a
        -- normal ball_thrown event (for example a blocked throw).
        restoreAllBalls(battle)

        -- Heal at a documented safe boundary to cover nonlethal direct/residual
        -- HP writes that do not pass through battle.damage.
        if enabled("infinite_hp") then
            healActivePlayer(battle)
        end
    end)

    mod.events:on("battle.ended", function(event)
        local battle = event and event.battle
        if battle == nil then
            return
        end

        if isLinkBattle(battle) then
            battleState[battle] = nil
            linkBattleActive = false
            critEligible = false
            return
        end

        restoreAllBalls(battle)
        battleState[battle] = nil
        critEligible = false
    end)
end
