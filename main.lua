local SCREEN_ID = "MinimalCheatsMenu"

local EXP_MULTIPLIERS = { 1, 2, 4, 8, 10 }

-- Built-in Gen I balls.  We also merge any additional balls that are already
-- registered when this mod loads so ball-restoration remains friendly to mods
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

    -- Read-only registry discovery through the supported mod object.  The four
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

    local function expMultiplier()
        local value = tonumber(mod.save:get("exp_multiplier", 1)) or 1
        for _, allowed in ipairs(EXP_MULTIPLIERS) do
            if value == allowed then
                return allowed
            end
        end
        return 1
    end

    local function isLinkBattle(battle)
        return battle ~= nil and battle.kind == "link"
    end

    local function healActivePlayer(battle)
        if battle == nil or isLinkBattle(battle) then
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

        if battle == nil or isLinkBattle(battle) then
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
        if battle == nil or isLinkBattle(battle) or not enabled("unlimited_balls") then
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
        if battle == nil or isLinkBattle(battle) or not enabled("unlimited_balls") then
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

    local function toggleLabel(key)
        return enabled(key) and "ON" or "OFF"
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

    -- Direct Options -> CHEATS screen.  Settings are save-scoped via the
    -- supported mod.save API and are read at the moment each hook/event fires,
    -- so no game restart is needed.
    mod.content.screens:register(SCREEN_ID, {
        new = function(game)
            local items = {
                { label = "INFINITE HP", key = "infinite_hp", kind = "toggle", right = toggleLabel("infinite_hp") },
                { label = "INFINITE PP", key = "infinite_pp", kind = "toggle", right = toggleLabel("infinite_pp") },
                { label = "EXP RATE", key = "exp_multiplier", kind = "exp", right = "x" .. tostring(expMultiplier()) },
                { label = "ENDLESS BALLS", key = "unlimited_balls", kind = "toggle", right = toggleLabel("unlimited_balls") },
                { label = "100% CATCH", key = "guaranteed_catch", kind = "toggle", right = toggleLabel("guaranteed_catch") },
            }

            return mod.ui.ListMenu.new(game, "CHEATS", items, {
                kind = "minimal_cheats",
                footer = "A: CHANGE   B: BACK",
                onChoose = function(item)
                    if item.kind == "toggle" then
                        local value = not enabled(item.key)
                        mod.save:set(item.key, value)
                        item.right = value and "ON" or "OFF"
                    elseif item.kind == "exp" then
                        item.right = "x" .. tostring(cycleExpMultiplier())
                    end
                end,
            })
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
                mod.ui.push(g, SCREEN_ID)
            end,
        }

        return out
    end)

    -- Normal battle damage uses the documented battle.damage hook.  This is
    -- deliberately player-only and disabled in link battles.
    mod.hooks:wrap("battle.damage", function(next, ctx)
        local damage, info = next(ctx)
        local battle = ctx and ctx.battle
        local target = ctx and ctx.target

        if enabled("infinite_hp")
            and not isLinkBattle(battle)
            and target ~= nil
            and target.isPlayer == true
        then
            return 0, info
        end

        return damage, info
    end)

    mod.hooks:wrap("exp.gain", function(next, ctx)
        local gained = next(ctx)
        local multiplier = expMultiplier()

        if multiplier == 1 or type(gained) ~= "number" then
            return gained
        end

        return math.max(0, math.floor(gained * multiplier))
    end)

    mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
        local caught, shakes = next(ball, mon, def, opts)
        local battle = opts and opts.battle

        if enabled("guaranteed_catch") and not isLinkBattle(battle) then
            return true, 3
        end

        return caught, shakes
    end)

    mod.events:on("battle.started", function(event)
        local battle = event and event.battle
        if battle == nil then
            return
        end

        snapshotBattle(battle)
        if enabled("infinite_hp") then
            healActivePlayer(battle)
        end
    end)

    -- Snapshot the exact selected move instance before PP is consumed.  The
    -- documented move_used event fires immediately after normal PP decrement,
    -- allowing the same instance's PP to be restored without replacing move
    -- resolution code.
    mod.events:on("battle.turn_started", function(event)
        local battle = event and event.battle
        if battle == nil or isLinkBattle(battle) then
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
        if battle == nil or isLinkBattle(battle) or not enabled("infinite_pp") then
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
        if enabled("infinite_hp") and battler ~= nil and battler.isPlayer == true then
            healActivePlayer(battle)
        end
    end)

    mod.events:on("battle.turn_ended", function(event)
        local battle = event and event.battle
        if battle == nil then
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

        restoreAllBalls(battle)
        battleState[battle] = nil
    end)
end
