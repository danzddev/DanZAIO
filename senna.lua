--[[
    DanZ-AIO Senna
    Q Extended Range Refactor v3 + Soul Collection v1
    REVISED & DEBUGGED
]]

if player.charName ~= "Senna" then return end
chat.print("DanZ-AIO Senna Loaded (Q Extended Range v3 + Soul Collection v1)")

-- Module Imports
local orb = module.internal("orb")
local ts = module.internal("TS")
local pred = module.internal("pred")
local damagelib = module.internal("damagelib")
-- local evade = module.internal("evade") -- Keep commented unless needed

-- Constants & Globals
local Q_BUFF_HEAL_HASH = game.fnvhash("SennaQHeal")
local W_MARK_HASH = game.fnvhash("SennaW")
local PASSIVE_STACK_HASH = game.fnvhash("sennapassivemarker")
local SOUL_CHAR_NAME = "SennaSoul"
local Q_MAX_EFFECTIVE_RANGE = 1300 -- Max reach of Q through targets
local Q_CAST_RANGE_BONUS = 25 -- Q cast range is slightly longer than AA

local State = {
    q_farm_enabled = true,
    last_w_gapclose_time = 0,
    last_e_time = 0,
    last_r_save_time = 0,
    last_ward_attempt_time = 0, -- <<< ADD THIS LINE: Prevent spamming ward attempts

}
local circle_effects = {
    aa = graphics.create_effect(graphics.CIRCLE_GLOW_RAINBOW),
    q = graphics.create_effect(graphics.CIRCLE_GLOW_RAINBOW),
    w = graphics.create_effect(graphics.CIRCLE_GLOW_RAINBOW),
    r = graphics.create_effect(graphics.CIRCLE_GLOW_RAINBOW) -- R KS range will still use draw_circle
}
local WARD_RANGE = 600 -- Standard ward placement range

-- Ward Item IDs (Common ones)
local WARD_ITEM_IDS = {
    [3340] = true, -- Stealth Ward (Trinket)
    [3363] = true, -- Farsight Alteration (Trinket) - Note: Different placement logic might be needed
    [2055] = true, -- Control Ward
    -- Add other ward types if necessary (e.g., event wards)
}
-- Mapping Inventory Slots to Spell Slots for Actives
local INVENTORY_TO_SPELL_SLOT = {
    [0] = 6, [1] = 7, [2] = 8, [3] = 9, [4] = 10, [5] = 11, -- Items 1-6
    [6] = 6 -- Trinket (Commonly slot 6)
}



-- Helper: Is Valid Target Check
local function IsValidTarget(target, range)
    if not target or not target.valid or target.isDead then
        return false
    end
    -- Souls might not have isTargetable property or it might be false, but we can still attack/move to them
    if target.charName ~= SOUL_CHAR_NAME and (not target.isVisible or not target.isTargetable) then
         return false
    end
    if range then
        local range_sqr = range * range
        -- Use serverPos for more accurate range checks, fallback to pos if needed
        local check_pos = target.path and target.path.serverPos or target.pos
        if player.pos:distSqr(check_pos) > range_sqr then
            return false
        end
    end
    return true
end

-- Helper: Mana Check
local function HasEnoughMana(pct)
    return player.mana / player.maxMana * 100 >= pct
end

-- Helper: Check if target is CC'd
local function IsCCd(target)
    if not target or not target.valid then return false end
    -- Simplified check using buff types
    return target.buff[BUFF_STUN] or target.buff[BUFF_SNARE] or target.buff[BUFF_TAUNT] or
           target.buff[BUFF_CHARM] or target.buff[BUFF_FEAR] or target.buff[BUFF_SUPPRESSION] or
           target.buff[BUFF_KNOCKUP] or target.buff[BUFF_KNOCKBACK] or target.buff[BUFF_ASLEEP]
end

-- Helper: Get Senna's dynamic AA/Q range
local function GetDynamicAARange()
     -- Use serverPos for player range calculation if available
     return player.attackRange + player.boundingRadius
end

local function GetDynamicQCastRange()
    -- Senna Q *cast* range scales with Attack Range
    return GetDynamicAARange() + Q_CAST_RANGE_BONUS
end

-- Helper: Simple Position Prediction (adjust time as needed)
local function PredictTargetPos(target, delay_time)
    if not target or not target.valid then return target and target.pos or nil end -- Return current pos if invalid/no path
    if not delay_time or delay_time <= 0 then return target.path and target.path.serverPos or target.pos end

    -- Use prediction module if available and target is moving
    if pred and target.path and target.path.isMoving and target.path.count > 0 then
        local predicted_pos_2d = pred.core.get_pos_after_time(target, delay_time)
        if predicted_pos_2d then
            return predicted_pos_2d:to3D(target.pos.y) -- Estimate Y
        end
    end
    -- Fallback to server position or current position if prediction fails or target isn't moving
    return target.path and target.path.serverPos or target.pos
end


-- Menu Creation (Structure remains the same)
local isCN = hanbot and hanbot.language == 1
local menu = menu("danz_senna", isCN and "DanZ-AIO ????" or "DanZ-AIO Senna")

-- Q Settings
menu:menu("q", "Q - " .. (isCN and "???????" or "Piercing Darkness"))
menu.q:dropdown("q_extend_prediction", isCN and "Q 扩展预测模式" or "Q Extend Prediction Mode", 1, { isCN and "快速预测" or "Fast Prediction", isCN and "高级预测 (仅移动)" or "Advanced Prediction (Moving Only)" })
menu.q.q_extend_prediction:set('tooltip', isCN and "快速: 使用最近的单位扩展Q。\n高级: 仅当目标最近改变路径时才尝试扩展Q。" or "Fast: Uses nearest unit to extend Q.\nAdvanced: Only attempts Q extend if target recently changed path.")

menu.q:boolean("auto_q_cc", isCN and "??? Q ???????" or "Auto Q on CC'd", true)
menu.q:boolean("auto_q_cc_ally", isCN and "自动 Q 控制中的队友" or "Auto Q on CC'd Ally", true) -- NEW
menu.q:boolean("combo", isCN and "????????? Q" or "Use Q in Combo", true)
menu.q:boolean("harass", isCN and "???????? Q" or "Use Q in Harass", true)
menu.q:slider("harass_mana", isCN and "??? Q ??????? %" or "Harass Q Min Mana %", 60, 0, 100, 5)
menu.q:keybind("farm_toggle", isCN and "?л? Q ??????" or "Toggle Q Farm Mode", nil, "MMB", true)
menu.q:slider("q_min_minions", isCN and "Q 至少命中多少小兵" or "Min Minions for Q", 2, 1, 10, 1) -- <-- ADD THIS LINE
menu.q:slider("farm_mana", isCN and "???? Q ??????? %" or "Farm Q Min Mana %", 50, 0, 100, 5)
menu.q:boolean("jungle", isCN and "???????? Q" or "Use Q in Jungle Clear", true)
menu.q:boolean("heal_ally", isCN and "??? Q ???????" or "Use Q to Heal Allies", true)
menu.q:slider("heal_ally_hp", isCN and "?????????? % ?????" or "Heal Ally Below HP %", 70, 0, 100, 5)
menu.q:dropdown("q_priority", isCN and "Q ??????" or "Q Priority Mode", 1, { isCN and "???????" or "Damage First", isCN and "????????" or "Heal First" }) -- 1: Damage, 2: Heal
menu.q:menu("heal_blacklist", isCN and "Q ?????????" or "Q Heal Blacklist")
menu.q.heal_blacklist:header("heal_blacklist_info_header", isCN and "???????????" or "Select Allies NOT to Heal")
-- Inside menu.q definition
menu.q:boolean("q_ward_ks", isCN and "??? Q+???? ??????" or "Use Q+Ward Extend KS", false)
menu.q.q_ward_ks:set('tooltip', isCN and "???????Q??Ч??Χ??????????????Χ????????????????Q????????????" or "Attempts to place a ward and Q through it if target is killable within effective Q range but outside direct cast range.")

-- W Settings
menu:menu("w", "W - " .. (isCN and "???????" or "Last Embrace"))
-- Inside menu.w definition
menu.w:boolean("killsteal", isCN and "??? W ?????" or "Use W to Killsteal", true) -- Default ON
menu.w:boolean("auto_w_cc", isCN and "??? W ???????" or "Auto W on CC'd", true)
menu.w:boolean("combo", isCN and "????????? W" or "Use W in Combo", true)
menu.w:boolean("harass", isCN and "???????? W" or "Use W in Harass", false)
menu.w:slider("harass_mana", isCN and "??? W ??????? %" or "Harass W Min Mana %", 70, 0, 100, 5)
menu.w:boolean("anti_gapclose", isCN and "??? W ??????" or "Use W vs Gap Closers", true)
menu.w:slider("anti_gapclose_hp", isCN and "??????????? % ???? W ??????" or "Use W vs Gap Closers Below Player HP %", 60, 0, 100, 5)

-- E Settings
menu:menu("e", "E - " .. (isCN and "?????丽" or "Curse of the Black Mist"))
menu.e:boolean("combo", isCN and "????????? E (????/???)" or "Use E in Combo (Escape/Chase)", false)
menu.e:boolean("flee", isCN and "???????? E" or "Use E When Fleeing", true)
menu.e:boolean("auto_escape", isCN and "??? E ?????????" or "Auto E on Low HP", true)
menu.e:slider("auto_escape_hp", isCN and "??????????? % ???? E" or "Auto E Below Player HP %", 30, 0, 100, 5)

-- R Settings
menu:menu("r", "R - " .. (isCN and "??????" or "Dawning Shadow"))
menu.r:boolean("killsteal", isCN and "??? R ?????" or "Use R to Killsteal", true)
menu.r:slider("min_range_ks", isCN and "???????С R ??Χ" or "Min R Range KS", 1000, 500, 5000, 100)
menu.r:slider("max_range_ks", isCN and "???????? R ??Χ" or "Max R Range KS", 15000, 1000, 25000, 500)
menu.r:boolean("aoe_combo", isCN and "?????ж??????? R" or "Use R for AoE in Combo", true)
menu.r:slider("aoe_min_enemies", isCN and "R ??????С???????? (????)" or "Min Enemies Hit for R (Combo)", 3, 1, 5, 1)
menu.r:boolean("save_ally", isCN and "??? R ????????????" or "Use R to Save Low HP Ally", false)
menu.r:slider("save_ally_hp", isCN and "?????????? % ?????" or "Save Ally Below HP %", 20, 0, 100, 5)
menu.r:slider("save_ally_range", isCN and "????????? R ??Χ" or "Max Range to Save Ally (R)", 1000, 500, 10000, 50) -- <<< ADD THIS LINE
menu.r:keybind("semi_manual", isCN and "????? R ??" or "Semi-Manual R Key", "T", nil)

-- Soul Collection Settings
menu:menu("souls", isCN and "??????" or "Soul Collection")
menu.souls:boolean("enabled", isCN and "??????????" or "Enable Soul Collection", true)
menu.souls:boolean("draw_souls", isCN and "??????????" or "Draw Nearby Souls", true)
menu.souls:color("soul_color", isCN and "?????????" or "Soul Highlight Color", 0, 255, 200, 200)


-- Drawing Settings
menu:menu("drawings", isCN and "????????" or "Draw Settings")
menu.drawings:boolean("enabled", isCN and "???????" or "Enable Drawings", true)
menu.drawings:menu("general_drawings", isCN and "通用绘制" or "General Drawings")
menu.drawings.general_drawings:boolean("minimap_r", isCN and "小地图绘制 R 范围" or "Draw R Range on Minimap", false) -- <<< ADD THIS LINE
menu.drawings:menu("ranges", isCN and "??Χ????" or "Range Drawings")
menu.drawings.ranges:boolean("aa", isCN and "?????????Χ (???)" or "Draw AA Range (Dynamic)", true)
menu.drawings.ranges:boolean("q", isCN and "???? Q ??Χ (???)" or "Draw Q Cast Range (Dynamic)", true) -- Clarified label
menu.drawings.ranges:boolean("w", isCN and "???? W ??Χ" or "Draw W Range", true)
menu.drawings.ranges:boolean("r_ks", isCN and "???? R ???????Χ" or "Draw R KS Range", false)
menu.drawings:menu("colors", isCN and "???????" or "Color Settings")
menu.drawings.colors:color("aa", "AA Range Color", 255, 255, 255, 150)
menu.drawings.colors:color("q", "Q Cast Range Color", 100, 255, 100, 150) -- Clarified label
menu.drawings.colors:color("w", "W Range Color", 100, 100, 255, 150)
--menu.drawings.colors:color("r", "R KS Range Color", 255, 100, 100, 150)
menu.drawings:boolean("damage_indicator", isCN and "???????????????" or "Draw Combo Damage Indicator", true)
menu.drawings:menu("damage_drawing", isCN and "???????" or "Damage Drawing")
menu.drawings.damage_drawing:boolean("use_q", isCN and "??? Q ???" or "Show Q Damage", true)
menu.drawings.damage_drawing:boolean("use_w", isCN and "??? W ??? (Detonation)" or "Show W Damage (Detonation)", true)
menu.drawings.damage_drawing:boolean("use_r", isCN and "??? R ???" or "Show R Damage", true)
menu.drawings.damage_drawing:slider("aa_factor", isCN and "????????п???????????" or "Number of AAs in Damage Calc", 1, 0, 5, 1)
menu.drawings.damage_drawing:boolean("include_passive", isCN and "?????????? (????)" or "Show Passive Damage (Estimate)", true)
menu.drawings:boolean("farm_draw_status", isCN and "???? Q ????????" or "Draw Q Farm Mode Status", true)
menu.drawings:menu("indicators", isCN and "指示器绘制" or "Indicator Drawings") -- Optional: New submenu
menu.drawings.indicators:boolean("q_extend_lines", isCN and "绘制 Q 扩展线" or "Draw Q Extend Lines", true)
menu.drawings.indicators:color("q_extend_color", isCN and "Q 扩展线颜色" or "Q Extend Line Color", 0, 200, 255, 180) -- Cyan-ish default
menu.drawings.indicators:color("q_ward_ks_color", isCN and "Q+守卫 KS 线颜色" or "Q+Ward KS Line Color", 255, 255, 0, 180) -- Yellow default


-- **** NEW: Utility Menu ****
menu:menu("utility", isCN and "??ù???" or "Utility")
menu.utility:keybind("place_ward_key", isCN and "??????????" or "Place Ward Key", "U", nil) -- Key '4' for ward placement
menu.utility.place_ward_key:set('tooltip', isCN and "???????????λ?÷?????????????????" or "Hold this key to place a ward at the mouse cursor (if available)")


-- Populate Ally Blacklist
if menu.q.heal_blacklist then
    for i = 0, objManager.allies_n - 1 do
        local ally = objManager.allies[i]
        if ally and ally.valid and ally.ptr ~= player.ptr then
            local menu_var = "noheal_" .. ally.charName:lower()
            menu.q.heal_blacklist:boolean(menu_var, ally.charName, false)
            local blacklist_item = menu.q.heal_blacklist[menu_var]
            if blacklist_item and ally.iconSquare and ally.iconSquare.valid then
                blacklist_item:set('icon', ally.iconSquare)
            end
        end
    end
else
    chat.print("Error: Heal blacklist menu not found!")
end

-- Load spell icons
local spellIcons = {}
local function LoadSpellIcons()
    local qSlot = player:spellSlot(0)
    if qSlot and qSlot.icon and qSlot.icon.valid then spellIcons.q = qSlot.icon end
    local wSlot = player:spellSlot(1)
    if wSlot and wSlot.icon and wSlot.icon.valid then spellIcons.w = wSlot.icon end
    local eSlot = player:spellSlot(2)
    if eSlot and eSlot.icon and eSlot.icon.valid then spellIcons.e = eSlot.icon end
    local rSlot = player:spellSlot(3)
    if rSlot and rSlot.icon and rSlot.icon.valid then spellIcons.r = rSlot.icon end

    if spellIcons.q and menu.q then menu.q:set('icon', spellIcons.q) end
    if spellIcons.w and menu.w then menu.w:set('icon', spellIcons.w) end
    if spellIcons.e and menu.e then menu.e:set('icon', spellIcons.e) end
    if spellIcons.r and menu.r then menu.r:set('icon', spellIcons.r) end
    local passiveSlot = player:spellSlot(63)
    if passiveSlot and passiveSlot.icon and passiveSlot.icon.valid and menu.souls then
        menu.souls:set('icon', passiveSlot.icon)
    end
    if player.iconCircle and player.iconCircle.valid then menu:set('icon', player.iconCircle) end
end
LoadSpellIcons()

-- Spell Data Table
local spells = {
    q = {
        slot = 0,
        cast_range = GetDynamicQCastRange, -- Function ref for CAST range
        effective_range = Q_MAX_EFFECTIVE_RANGE, -- Max EFFECTIVE range
        delay = 0.4, -- Approximate delay before damage/heal applies
        width = 40, -- Effective width for collision checking the beam
        ready = function() return player:spellSlot(0).state == 0 end,
        mana = function() return 70 + (player:spellSlot(0).level * 10) end,
    },
    w = {
        slot = 1,
        range = 1250,
        speed = 1200,
        width = 70,
        delay = 0.25,
        boundingRadiusMod = 1,
        ready = function() return player:spellSlot(1).state == 0 end,
        mana = function() return 50 + (player:spellSlot(1).level * 5) end,
        collision = { minion = true, hero = true, wall = true }
    },
    e = {
        slot = 2,
        range = 0,
        ready = function() return player:spellSlot(2).state == 0 end,
        mana = function() return 70 end
    },
    r = {
        slot = 3,
        range = 25000,
        speed = 20000,
        width = 160,
        delay = 1.0,
        boundingRadiusMod = 0,
        ready = function() return player:spellSlot(3).state == 0 end,
        mana = function() return 100 end,
        collision = { minion = false, hero = false, wall = true } -- R goes through units but not walls
    }
}

-- Prediction Filtering (Simplified for W/R)
local function PredFilter(seg, obj, input)
    if not seg or not obj or not input then return false end
    -- Check hard CC first
    if pred.trace.linear.hardlock(input, seg, obj) or pred.trace.linear.hardlockmove(input, seg, obj) then
        return true
    end
    -- Check for recent path changes (more likely to dodge)
    if pred.trace.newpath(obj, 0.033, 0.500) then -- Check for path change in last 0.1s
        return true
    end
    -- Could add more checks here (e.g., dashing away)
    return false -- Assume hittable if no obvious dodge indicators
end

-- Get Prediction Logic (Standard for W/R)
local function GetPrediction(spell_key, target)
    local spell = spells[spell_key]
    if not spell or not target or not IsValidTarget(target) then return nil end

    -- Q prediction is handled differently by GetBestQCastTarget
    if spell_key == "q" then
        -- print("Warning: GetPrediction called for Q, use GetBestQCastTarget instead.")
        return PredictTargetPos(target, spells.q.delay) -- Return predicted pos as fallback
    end

    local current_range = spell.range
    if type(current_range) == 'function' then current_range = current_range() end

    local input = {
        delay = spell.delay,
        speed = spell.speed,
        width = spell.width,
        range = current_range,
        boundingRadiusMod = spell.boundingRadiusMod,
        collision = spell.collision
    }

    local seg = pred.linear.get_prediction(input, target)
    if not seg then return nil end

    -- Check range based on segment length (start to predicted end)
    if seg.startPos:distSqr(seg.endPos) > current_range * current_range then return nil end

    -- Check collision if applicable
    if input.collision then
         if pred.collision.get_prediction(input, seg, target) then return nil end
    end

    -- Check if target is likely to dodge
    if not PredFilter(seg, target, input) then return nil end -- If filter returns false (likely hittable), proceed

    return vec3(seg.endPos.x, target.pos.y, seg.endPos.y)
end

-- Replace the entire existing GetBestQCastTarget function with this one:
local function GetBestQCastTarget(intended_enemy, intended_ally)
    local q_cast_range = GetDynamicQCastRange()
    local q_effective_range = spells.q.effective_range
    local q_width = spells.q.width
    local q_delay = spells.q.delay
    local player_pos_2d = player.pos2D

    -- 1. Determine the primary target based on priority menu setting
    local primary_intended_target = nil
    local q_priority_mode = menu.q.q_priority:get()

    if q_priority_mode == 2 and intended_ally then -- Heal Priority
        primary_intended_target = intended_ally
    elseif intended_enemy then -- Damage Priority (or Heal Prio but no ally)
        primary_intended_target = intended_enemy
    elseif q_priority_mode == 1 and intended_ally then -- Damage Prio fallback to Heal
        primary_intended_target = intended_ally
    end

    -- If no valid primary intended target, we can't cast
    if not primary_intended_target or not IsValidTarget(primary_intended_target, q_effective_range) then
        return nil
    end

    -- 2. Predict the primary intended target's position
    local predicted_target_pos = PredictTargetPos(primary_intended_target, q_delay)
    if not predicted_target_pos then return nil end
    local predicted_target_pos_2d = predicted_target_pos:to2D()

    -- 3. **** NEW: Prediction Mode Check for Extended Q ****
    local dist_to_primary_sqr = player_pos_2d:distSqr(predicted_target_pos_2d) -- Use predicted distance for check
    local q_cast_range_sqr = q_cast_range * q_cast_range

    -- Check if the primary target is outside direct cast range (requires extension)
    if dist_to_primary_sqr > q_cast_range_sqr then
        local q_extend_pred_mode = menu.q.q_extend_prediction:get()

        -- If Advanced mode is selected, check the intended *enemy* target's movement
        if q_extend_pred_mode == 2 then
            -- Only apply the movement restriction if there *is* an intended enemy target
            if intended_enemy and IsValidTarget(intended_enemy) then -- Ensure enemy target is valid
                if not pred.trace.newpath(intended_enemy, 0.033, 0.500) then
                    -- Enemy exists but hasn't moved recently, block extended Q in Advanced mode
                    -- print("GetBestQCastTarget: Advanced Mode - Blocking extend, enemy didn't move.") -- Debug
                    return nil
                -- else
                     -- print("GetBestQCastTarget: Advanced Mode - Allowing extend, enemy moved.") -- Debug
                end
            -- else
                -- print("GetBestQCastTarget: Advanced Mode - Allowing extend, no specific enemy intended or enemy invalid.") -- Debug
            end
             -- If no intended enemy, or if the enemy moved, Advanced mode allows proceeding.
        end
        -- If Fast mode (1), we always proceed without the movement check.
        -- print("GetBestQCastTarget: Fast Mode - Allowing extend check.") -- Debug
    end
    -- **** END OF NEW CHECK ****

    -- 4. Gather all potential units we can *click* Q on (within Q CAST range)
    -- (This part remains the same as before)
    local potential_cast_units = {}
    local function add_if_valid_cast_unit(unit)
        if unit and IsValidTarget(unit, q_cast_range) then
            table.insert(potential_cast_units, unit)
        end
    end
    add_if_valid_cast_unit(player)
    for i = 0, objManager.allies_n - 1 do add_if_valid_cast_unit(objManager.allies[i]) end
    for i = 0, objManager.enemies_n - 1 do add_if_valid_cast_unit(objManager.enemies[i]) end
    local lane_minions = objManager.minions["lane_enemy"]
    if lane_minions then for i = 0, objManager.minions.size["lane_enemy"] - 1 do add_if_valid_cast_unit(lane_minions[i]) end end
    local jungle_minions = objManager.minions[TEAM_NEUTRAL]
    if jungle_minions then for i = 0, objManager.minions.size[TEAM_NEUTRAL] - 1 do add_if_valid_cast_unit(jungle_minions[i]) end end
    local ally_minions = objManager.minions[TEAM_ALLY]
    if ally_minions then for i = 0, objManager.minions.size[TEAM_ALLY] - 1 do add_if_valid_cast_unit(ally_minions[i]) end end
    local ally_wards = objManager.wardsAlly
    if ally_wards then for i = 0, ally_wards.size - 1 do add_if_valid_cast_unit(ally_wards[i]) end end
    for i = 0, objManager.turrets.size[TEAM_ENEMY] - 1 do add_if_valid_cast_unit(objManager.turrets[TEAM_ENEMY][i]) end
    for i = 0, objManager.inhibs.size[TEAM_ENEMY] - 1 do add_if_valid_cast_unit(objManager.inhibs[TEAM_ENEMY][i]) end
    local nexus = objManager.nexus[TEAM_ENEMY]
    add_if_valid_cast_unit(nexus)

    -- 5. Iterate through potential cast units and check if the Q beam hits the intended target
    -- (This part remains the same as before)
    local best_cast_unit = nil
    table.sort(potential_cast_units, function(a, b)
        return player_pos_2d:distSqr(a.pos2D) < player_pos_2d:distSqr(b.pos2D)
    end)

    for _, cast_unit in ipairs(potential_cast_units) do
        local direction = (cast_unit.pos2D - player_pos_2d):norm()
        if direction:lenSqr() < 0.01 then direction = player.direction2D:norm() end
        if direction:lenSqr() < 0.01 then direction = vec2(1,0) end

        local q_end_point_2d = player_pos_2d + direction * q_effective_range
        local target_radius = primary_intended_target.boundingRadius + 15

        -- Use the PREDICTED target position for the collision check
        if mathf.col_vec_rect(predicted_target_pos_2d, player_pos_2d, q_end_point_2d, target_radius, q_width) then
            best_cast_unit = cast_unit
            break
        end
    end

    -- 6. Return the best unit found (or nil if none worked or was blocked by Advanced mode)
    return best_cast_unit
end


-- Damage Calculation Helpers (Unchanged)
local function GetQDamage(target)
    if not IsValidTarget(target) then return 0 end
    return damagelib.get_spell_damage("SennaQ", 0, player, target, false, 0)
end
local function GetWDamage(target) -- Detonation damage
    if not IsValidTarget(target) then return 0 end
    return damagelib.get_spell_damage("SennaW", 1, player, target, false, 0)
end
local function GetRDamage(target)
    if not IsValidTarget(target) then return 0 end
    return damagelib.get_spell_damage("SennaR", 3, player, target, false, 0)
end
local function GetPassiveDamage(target)
    if not IsValidTarget(target) then return 0 end
    local passive_base = 20
    local passive_ad_ratio = 0.2
    local level_scaling = 1 + (player.levelRef / 18)
    local raw_passive = (passive_base * level_scaling) + player.totalAd * passive_ad_ratio
    return damagelib.calc_physical_damage(player, target, raw_passive)
end
local function GetQHealAmount(target)
    if not IsValidTarget(target) or target.type ~= TYPE_HERO then return 0 end
    local level = player:spellSlot(0).level
    if level == 0 then return 0 end
    local base_heal = 30 + level * 10
    local ap_ratio = 0.40
    local ad_ratio = 0.30
    local heal_amount = base_heal + player.totalAp * ap_ratio + player.bonusAd * ad_ratio
    -- Consider heal/shield power if needed
    return heal_amount
end

-- Soul Collection Logic (Unchanged)
local function CollectSouls()
    if not menu.souls.enabled:get() then return false end

    local in_combo = orb.combat.is_active()
    local in_flee = orb.menu.flee.key:get()
    local in_valid_mode = orb.menu.hybrid.key:get() or orb.menu.lane_clear.key:get() or orb.menu.last_hit.key:get()

    if in_combo or in_flee or not in_valid_mode then return false end
    if not orb.core.can_action() then return false end

    local collect_range = player.attackRange + player.boundingRadius
    local collect_range_sqr = collect_range * collect_range
    local aa_range = GetDynamicAARange()
    local aa_range_sqr = aa_range * aa_range

    local closest_soul = nil
    local min_dist_sqr = collect_range_sqr + 1

    local all_minions = objManager.allMinions
    if not all_minions then return false end

    for i = 0, all_minions.size - 1 do
        local minion = all_minions[i]
        if minion and minion.charName == SOUL_CHAR_NAME and IsValidTarget(minion) then -- Use IsValidTarget for souls too
            local dist_sqr = player.pos:distSqr(minion.pos)
            if dist_sqr <= collect_range_sqr and dist_sqr < min_dist_sqr then
                min_dist_sqr = dist_sqr
                closest_soul = minion
            end
        end
    end

    if closest_soul then
        if min_dist_sqr <= aa_range_sqr then
            if orb.core.can_attack() then
                player:attack(closest_soul)
                orb.core.set_server_pause()
                return true
            end
        elseif orb.core.can_move() then
             player:move(closest_soul.pos)
             return true
        end
    end
    return false
end


-- Core Logic Functions (REVISED to use new Q logic)
local function Combo()
    if not orb.combat.is_active() then return end

    local w_target = nil
    -- R target is determined inside the R logic block now
    local q_intended_enemy = nil
    local q_intended_ally = nil

    -- W Logic (Highest priority CC/Setup)
    if menu.w.combo:get() and spells.w.ready() then
        w_target = ts.get_result(function(res, obj, dist)
            if not IsValidTarget(obj, spells.w.range) then return false end
            res.obj = obj
            return true
        end).obj
        if w_target then
            local pred_pos = GetPrediction("w", w_target)
            if pred_pos then
                player:castSpell("pos", spells.w.slot, pred_pos)
                return -- Cast W and exit for this tick
            end
        end
    end

    -- Q Logic (Uses new GetBestQCastTarget)
    if menu.q.combo:get() and spells.q.ready() then
        local q_prio = menu.q.q_priority:get()

        -- Find best enemy target for Q damage (within max effective range)
        q_intended_enemy = ts.get_result(function(res, obj, dist)
            if not IsValidTarget(obj, spells.q.effective_range) then return false end
            res.obj = obj
            return true
        end).obj

        -- Find best ally target for Q heal (within max effective range)
        if menu.q.heal_ally:get() then
            local lowest_hp_ally = nil
            local lowest_hp_pct = 101
            for i = 0, objManager.allies_n - 1 do
                local ally = objManager.allies[i]
                 if IsValidTarget(ally, spells.q.effective_range) then -- Check effective range
                    local blacklist_var = "noheal_" .. ally.charName:lower()
                    if not (menu.q.heal_blacklist[blacklist_var] and menu.q.heal_blacklist[blacklist_var]:get()) then
                        local hp_pct = ally.health / ally.maxHealth * 100
                        if hp_pct < menu.q.heal_ally_hp:get() and hp_pct < lowest_hp_pct then
                            lowest_hp_pct = hp_pct
                            lowest_hp_ally = ally
                        end
                    end
                 end
            end
            q_intended_ally = lowest_hp_ally
        end

        -- Determine intended targets for GetBestQCastTarget based on priority
        local final_intended_enemy = nil
        local final_intended_ally = nil
        if q_prio == 2 and q_intended_ally then -- Heal Prio
            final_intended_ally = q_intended_ally
            final_intended_enemy = q_intended_enemy -- Still pass enemy for potential damage+heal
        else -- Damage Prio (or Heal prio with no heal target)
            final_intended_enemy = q_intended_enemy
            final_intended_ally = q_intended_ally -- Pass heal target for potential damage+heal
        end

        -- Get the actual unit to cast Q on
        local best_q_cast_target = GetBestQCastTarget(final_intended_enemy, final_intended_ally)

        if best_q_cast_target then
            -- print("Combo Q Cast ->", best_q_cast_target.name) -- Optional Debug
            player:castSpell("obj", spells.q.slot, best_q_cast_target)
            return -- Cast Q and exit
        end
    end

    -- R Logic (AoE Combo - REVISED to use fallback logic ONLY)
    if menu.r.aoe_combo:get() and spells.r.ready() then
        local best_r_pos = nil
        local max_enemies_hit = 0 -- Initialize max hits found
        local potential_r_targets = {}

        -- 1. Gather potential targets within R range
        for i = 0, objManager.enemies_n - 1 do
            local enemy = objManager.enemies[i]
            if IsValidTarget(enemy, spells.r.range) then
                table.insert(potential_r_targets, enemy)
            end
        end

        -- 2. Only proceed if the number of potential targets meets the menu requirement
        if #potential_r_targets >= menu.r.aoe_min_enemies:get() then
            -- 3. Iterate through each potential target to find the best AIMING position
            for _, aim_target in ipairs(potential_r_targets) do
                -- Predict where to aim R to hit this specific 'aim_target'
                local pred_aim_pos = GetPrediction("r", aim_target)

                if pred_aim_pos then
                    local current_hits = 0
                    -- 4. For this potential aiming position, check how many targets would be hit
                    for _, check_enemy in ipairs(potential_r_targets) do
                        -- Predict where 'check_enemy' will be when the R (aimed at pred_aim_pos) arrives
                        -- Estimate time based on distance to the *aimed* position
                        local time_to_hit = player.pos:dist(pred_aim_pos) / spells.r.speed + spells.r.delay
                        local check_enemy_predicted_pos = PredictTargetPos(check_enemy, time_to_hit)

                        if check_enemy_predicted_pos then
                            -- Check collision: Does the R line (player -> pred_aim_pos) hit check_enemy_predicted_pos?
                            local dist_from_line = check_enemy_predicted_pos:to2D():distLine(player.pos2D, pred_aim_pos:to2D())
                            -- Check distance from the line segment representing the R path
                            if dist_from_line <= (spells.r.width / 2) + check_enemy.boundingRadius then
                                current_hits = current_hits + 1
                            end
                        end
                    end -- End of checking hits for one aim position

                    -- 5. If this aiming position hits more targets than the current best, update
                    if current_hits > max_enemies_hit then
                        max_enemies_hit = current_hits
                        best_r_pos = pred_aim_pos -- Store this aiming position as the best so far
                    end
                end
            end -- End of iterating through potential aiming targets

            -- 6. Cast R if a suitable position hitting enough enemies was found
            if best_r_pos and max_enemies_hit >= menu.r.aoe_min_enemies:get() then
                -- print("Combo R Cast -> AoE on", max_enemies_hit, "targets.") -- Debug print
                player:castSpell("pos", spells.r.slot, best_r_pos)
                return -- Exit Combo function after casting R
            end
        end
    end -- End of R AoE Combo Logic

    -- E Logic (Combo - Unchanged)
    if menu.e.combo:get() and spells.e.ready() then
        local primary_target = w_target or q_intended_enemy -- Use W target or Q intended enemy
        if IsValidTarget(primary_target) then
            local dist_sqr = player.pos:distSqr(primary_target.pos)
            -- Use Q effective range for chase check, as Q is primary damage tool
            local chase_range_sqr = (spells.q.effective_range * 0.8)^2 -- Chase if slightly outside effective Q range
            local needs_escape = player.health / player.maxHealth * 100 < 40

            if (dist_sqr > chase_range_sqr) or needs_escape then
                 if game.time - State.last_e_time > 1.0 then
                    player:castSpell("self", spells.e.slot)
                    State.last_e_time = game.time
                 end
            end
        end
    end
end

local function Harass()
    if not orb.menu.hybrid.key:get() then return end

    local w_mana_ok = HasEnoughMana(menu.w.harass_mana:get())
    local q_mana_ok = HasEnoughMana(menu.q.harass_mana:get())

    if not q_mana_ok and not w_mana_ok then return end

    -- W Logic (Only if enabled for harass)
    if menu.w.harass:get() and spells.w.ready() and w_mana_ok then
        local target = ts.get_result(function(res, obj, dist)
             if not IsValidTarget(obj, spells.w.range) then return false end
            res.obj = obj
            return true
        end).obj
        if target then
            local pred_pos = GetPrediction("w", target)
            if pred_pos then
                player:castSpell("pos", spells.w.slot, pred_pos)
                return -- Cast W and exit
            end
        end
    end

    -- Q Logic (Uses new GetBestQCastTarget)
    if menu.q.harass:get() and spells.q.ready() and q_mana_ok then
        local q_prio = menu.q.q_priority:get()
        local q_intended_enemy = nil
        local q_intended_ally = nil

        -- Find potential targets within max effective range
        q_intended_enemy = ts.get_result(function(res, obj, dist)
            if not IsValidTarget(obj, spells.q.effective_range) then return false end
            res.obj = obj
            return true
        end).obj

        if menu.q.heal_ally:get() then
             local lowest_hp_ally = nil
             local lowest_hp_pct = 101
             for i = 0, objManager.allies_n - 1 do
                 local ally = objManager.allies[i]
                 if IsValidTarget(ally, spells.q.effective_range) then
                    local blacklist_var = "noheal_" .. ally.charName:lower()
                    if not (menu.q.heal_blacklist[blacklist_var] and menu.q.heal_blacklist[blacklist_var]:get()) then
                        local hp_pct = ally.health / ally.maxHealth * 100
                        if hp_pct < menu.q.heal_ally_hp:get() and hp_pct < lowest_hp_pct then
                            lowest_hp_pct = hp_pct
                            lowest_hp_ally = ally
                        end
                    end
                 end
             end
             q_intended_ally = lowest_hp_ally
        end

        local final_intended_enemy = nil
        local final_intended_ally = nil
        if q_prio == 2 and q_intended_ally then
            final_intended_ally = q_intended_ally
            final_intended_enemy = q_intended_enemy
        else
            final_intended_enemy = q_intended_enemy
            final_intended_ally = q_intended_ally
        end

        local best_q_cast_target = GetBestQCastTarget(final_intended_enemy, final_intended_ally)

        if best_q_cast_target then
            -- print("Harass Q Cast ->", best_q_cast_target.name)
            player:castSpell("obj", spells.q.slot, best_q_cast_target)
            -- No return needed, maybe W is still possible if Q fails?
        end
    end
end

local function Farm()
    -- Basic checks: if Q farming is enabled, Q is ready, and player has enough mana
    if not State.q_farm_enabled then return end
    if not spells.q.ready() then return end
    if not HasEnoughMana(menu.q.farm_mana:get()) then return end -- Use farm mana limit from menu

    -- Get Q properties for calculations
    local q_cast_range = GetDynamicQCastRange() -- The range we must be within to click a unit
    local q_effective_range = spells.q.effective_range -- The maximum reach of the beam
    local q_width = spells.q.width -- The width (diameter) of the beam for collision checks

    -- Get the list of enemy lane minions
    local enemy_minions = objManager.minions["lane_enemy"]
    if not enemy_minions then return end -- Return if no enemy lane minions table exists
    local enemy_minion_size = objManager.minions.size["lane_enemy"]
    if enemy_minion_size == 0 then return end -- Return if there are no enemy lane minions

    -- Variables to store the best result found
    local best_q_cast_target_for_farm = nil
    local max_minions_hit = 0

    -- Get the minimum number of minions required to hit from the menu
    local min_minions_required = menu.q.q_min_minions:get()

    -- Get player position (2D) and Q spell delay for prediction
    local player_pos_2d = player.pos2D
    local q_delay = spells.q.delay

    -- Iterate through each enemy lane minion. We will consider each of these minions
    -- as a potential target that the Q beam *must* pass through (determines beam direction).
    for i = 0, enemy_minion_size - 1 do
        local potential_aim_minion = enemy_minions[i]

        -- Ensure the potential aiming minion is valid and within the Q effective range (as a hit target)
        if potential_aim_minion and potential_aim_minion.isVisible and not potential_aim_minion.isDead and potential_aim_minion.isTargetable and player_pos_2d:distSqr(potential_aim_minion.pos2D) <= q_effective_range * q_effective_range then

            -- Predict the position of this potential aiming minion when the Q beam would arrive.
            local predicted_aim_pos = PredictTargetPos(potential_aim_minion, q_delay)
            if not predicted_aim_pos then
                goto next_potential_aim_minion -- Skip to the next minion if prediction fails
            end
            local predicted_aim_pos_2d = predicted_aim_pos:to2D()

            -- Calculate the direction of the hypothetical Q beam from the player to the predicted aim position.
            local beam_direction = (predicted_aim_pos_2d - player_pos_2d):norm()
             if beam_direction:lenSqr() < 0.01 then
                 beam_direction = player.direction2D:norm()
                 if beam_direction:lenSqr() < 0.01 then beam_direction = vec2(1,0) end
             end

            -- Calculate the end point of this hypothetical Q beam.
            local beam_end_point_2d = player_pos_2d + beam_direction * q_effective_range

            local current_minions_hit = 0
            local first_valid_clickable_enemy_minion = nil

            -- Iterate through ALL enemy lane minions *again* to count how many would be hit by this beam
            -- AND find if there's at least one clickable enemy minion on this path.
            for j = 0, enemy_minion_size - 1 do
                local check_minion = enemy_minions[j]
                 -- Ensure the minion is valid, visible, and targetable
                if check_minion and check_minion.isVisible and not check_minion.isDead and check_minion.isTargetable then

                    -- Predict the position of this minion
                    local predicted_check_pos = PredictTargetPos(check_minion, q_delay)
                    if predicted_check_pos then
                        local predicted_check_pos_2d = predicted_check_pos:to2D()
                        local check_minion_radius = check_minion.boundingRadius

                        -- Check for collision between the minion (predicted) and the beam line segment
                        if mathf.col_vec_rect(predicted_check_pos_2d, player_pos_2d, beam_end_point_2d, check_minion_radius, q_width) then
                            current_minions_hit = current_minions_hit + 1

                            -- *** NEW: Check if this minion is also a valid CLICKABLE target within CAST range and is the first found ***
                            if first_valid_clickable_enemy_minion == nil and player_pos_2d:distSqr(check_minion.pos2D) <= q_cast_range * q_cast_range then
                                -- Store this minion as the unit we would click on if this beam path is chosen
                                first_valid_clickable_enemy_minion = check_minion
                            end
                        end -- End if collision occurs
                    end -- End if predicted_check_pos is valid
                end -- End if check_minion is valid
            end -- End inner loop (checking how many minions and if any are clickable on this beam)

            -- Now, evaluate this beam path:
            -- 1. Does it hit enough minions?
            -- 2. Is there at least one clickable enemy minion on this path within Q cast range?
            -- 3. Is this the best path found so far based on minion count?

            if current_minions_hit >= min_minions_required and first_valid_clickable_enemy_minion ~= nil then
                 if current_minions_hit > max_minions_hit then
                    -- This is a new best path. Store the clickable unit and the hit count.
                    max_minions_hit = current_minions_hit
                    best_q_cast_target_for_farm = first_valid_clickable_enemy_minion
                 end
            end

        end -- End if potential_aim_minion is valid and in range
        ::next_potential_aim_minion:: -- Label for the goto statement
    end -- End outer loop (iterating through potential aiming minions)

    -- After checking all potential aiming minions, if we found a suitable clickable target
    -- that initiates a beam hitting enough enemy minions, cast Q on that target.
    if best_q_cast_target_for_farm and max_minions_hit >= min_minions_required then
        -- print(string.format("Farm Q Cast -> %s (Click Target) | Hitting %d minions (Predicted Aim: %s).", best_q_cast_target_for_farm.name or "Unknown", max_minions_hit, potential_aim_minion and potential_aim_minion.name or "N/A")) -- More detailed debug
        player:castSpell("obj", spells.q.slot, best_q_cast_target_for_farm)
        -- Optional: Add a small server pause or a spell cooldown state here if needed
        -- orb.core.set_server_pause()
    end
end

local function JungleClear()
    if not menu.q.jungle:get() or not spells.q.ready() then return end
    if not HasEnoughMana(menu.q.farm_mana:get()) then return end

    local target_mob = nil
    local best_cast_unit_for_jungle = nil
    local highest_hp = 0

    local jungle_mobs = objManager.minions[TEAM_NEUTRAL]
    if not jungle_mobs then return end

    -- Prioritize Epic > Large > Small
    local mob_priority = { Epic = 3, Large = 2, Small = 1, Default = 0 }
    local best_priority = -1

    for i = 0, objManager.minions.size[TEAM_NEUTRAL] - 1 do
        local mob = jungle_mobs[i]
        if IsValidTarget(mob, spells.q.effective_range) then
            local current_priority = mob_priority.Default
            if mob.isEpicMonster then current_priority = mob_priority.Epic
            elseif mob.isLargeMonster then current_priority = mob_priority.Large
            else current_priority = mob_priority.Small end

            if current_priority > best_priority then
                 local cast_unit = GetBestQCastTarget(mob, nil)
                 if cast_unit then
                     best_priority = current_priority
                     highest_hp = mob.health -- Track HP within best priority
                     target_mob = mob
                     best_cast_unit_for_jungle = cast_unit
                 end
            -- If same priority, target higher HP one (usually the main camp monster)
            elseif current_priority == best_priority and mob.health > highest_hp then
                 local cast_unit = GetBestQCastTarget(mob, nil)
                 if cast_unit then
                     highest_hp = mob.health
                     target_mob = mob
                     best_cast_unit_for_jungle = cast_unit
                 end
            end
        end
    end

    if best_cast_unit_for_jungle and target_mob then
        -- print("Jungle Q Cast ->", best_cast_unit_for_jungle.name, "to hit", target_mob.name)
        player:castSpell("obj", spells.q.slot, best_cast_unit_for_jungle)
    end
end

local function HealAllies()
    if not menu.q.heal_ally:get() or not spells.q.ready() then return end
    if orb.combat.is_active() or orb.menu.hybrid.key:get() then return end
    if not HasEnoughMana(menu.q.harass_mana:get()) then return end

    local lowest_hp_ally = nil
    local lowest_hp_pct = 101

    for i = 0, objManager.allies_n - 1 do
        local ally = objManager.allies[i]
         if IsValidTarget(ally, spells.q.effective_range) then -- Check effective range
            local blacklist_var = "noheal_" .. ally.charName:lower()
            if not (menu.q.heal_blacklist[blacklist_var] and menu.q.heal_blacklist[blacklist_var]:get()) then
                local hp_pct = ally.health / ally.maxHealth * 100
                if hp_pct < menu.q.heal_ally_hp:get() and hp_pct < lowest_hp_pct then
                    lowest_hp_pct = hp_pct
                    lowest_hp_ally = ally
                end
            end
         end
    end

    if lowest_hp_ally then
        local best_q_cast_target = GetBestQCastTarget(nil, lowest_hp_ally) -- Prioritize ally
        if best_q_cast_target then
            -- print("Heal Q Cast ->", best_q_cast_target.name, "to heal", lowest_hp_ally.name)
            player:castSpell("obj", spells.q.slot, best_q_cast_target)
        end
    end
end



local function AutoCC()
    -- Auto Q on CC (Uses new Q logic)
    if menu.q.auto_q_cc:get() and spells.q.ready() then
         local target = ts.get_result(function(res, obj, dist)
            -- Check effective range for CC targets
            if not IsValidTarget(obj, spells.q.effective_range) then return false end
             if IsCCd(obj) then
                 res.obj = obj
                 return true
             end
             return false
         end).obj
        if target then
             local best_q_cast_target = GetBestQCastTarget(target, nil) -- Prioritize enemy
             if best_q_cast_target then
                 -- print("Auto Q on CC ->", best_q_cast_target.name, "to hit", target.name)
                 player:castSpell("obj", spells.q.slot, best_q_cast_target)
                 return -- Return to prioritize Q on CC
             end
        end
    end

    -- Auto W on CC (Unchanged)
    if menu.w.auto_w_cc:get() and spells.w.ready() then
         local target = ts.get_result(function(res, obj, dist)
            if not IsValidTarget(obj, spells.w.range) then return false end
             if IsCCd(obj) then
                 res.obj = obj
                 return true
             end
             return false
         end).obj
        if target then
            local pred_pos = GetPrediction("w", target)
            if pred_pos then
                player:castSpell("pos", spells.w.slot, pred_pos)
                -- No return needed, Q might still be useful
            end
        end
    end
end

-- AntiGapclose, AutoEscape, Flee, SaveAllyR, SemiManualR (All Unchanged Logically)
local function AntiGapclose()
    if not menu.w.anti_gapclose:get() or not spells.w.ready() then return end
    if player.health / player.maxHealth * 100 > menu.w.anti_gapclose_hp:get() then return end
    if game.time - State.last_w_gapclose_time < 1.0 then return end

    for i = 0, objManager.enemies_n - 1 do
        local enemy = objManager.enemies[i]
        -- Check W range for anti-gapclose initiation
        if IsValidTarget(enemy, spells.w.range + 200) and enemy.path.isDashing then
            local dash_end_pos = enemy.path.endPos
            local dist_to_player_sqr = player.pos:distSqr(dash_end_pos)
            -- Trigger range check
            if dist_to_player_sqr <= 400 * 400 then
                local pred_pos = GetPrediction("w", enemy)
                if pred_pos then
                    player:castSpell("pos", spells.w.slot, pred_pos)
                    State.last_w_gapclose_time = game.time
                    return
                end
            end
        end
    end
end


local function AutoEscape()
    if not menu.e.auto_escape:get() or not spells.e.ready() then return end
    if player.health / player.maxHealth * 100 < menu.e.auto_escape_hp:get() then
        if game.time - State.last_e_time > 1.0 then
            player:castSpell("self", spells.e.slot)
            State.last_e_time = game.time
        end
    end
end

local function Flee()
    if not orb.menu.flee.key:get() then return end
    if menu.e.flee:get() and spells.e.ready() then
         if game.time - State.last_e_time > 1.0 then
            player:castSpell("self", spells.e.slot)
            State.last_e_time = game.time
         end
    end
end

local function SaveAllyR()
    if not menu.r.save_ally:get() or not spells.r.ready() then return end
    if game.time - State.last_r_save_time < 2.0 then return end

    local save_range = menu.r.save_ally_range:get() -- Get the range from the new slider

    local target_ally = nil
    local lowest_hp_pct = 101

    for i = 0, objManager.allies_n - 1 do
        local ally = objManager.allies[i]
         -- Check R range for saving allies using the menu slider value
         if IsValidTarget(ally, save_range) and ally.ptr ~= player.ptr then
             local hp_pct = ally.health / ally.maxHealth * 100
             if hp_pct < menu.r.save_ally_hp:get() and ally.pos:countEnemies(800) > 0 then -- Keep enemy check near ally
                 if hp_pct < lowest_hp_pct then
                     lowest_hp_pct = hp_pct
                     target_ally = ally
                 end
             end
         end
    end

    if target_ally then
        player:castSpell("pos", spells.r.slot, target_ally.pos)
        State.last_r_save_time = game.time
    end
end

local function SemiManualR()
    -- Check if the key is held and R is ready
    if not menu.r.semi_manual:get() or not spells.r.ready() then return end

    local mouse_pos = game.mousePos -- Get current mouse position in world space
    local closest_enemy = nil
    local min_dist_to_mouse_sqr = math.huge

    -- Iterate through enemy heroes
    for i = 0, objManager.enemies_n - 1 do
        local enemy = objManager.enemies[i]
        -- Check if the enemy is valid and within R range
        if IsValidTarget(enemy, spells.r.range) then
            local dist_sqr = mouse_pos:distSqr(enemy.pos) -- Calculate squared distance to mouse
            if dist_sqr < min_dist_to_mouse_sqr then
                min_dist_to_mouse_sqr = dist_sqr
                closest_enemy = enemy
            end
        end
    end

    -- If a closest enemy to the mouse was found
    if closest_enemy then
        -- Get prediction for the R spell on the closest enemy
        local pred_pos = GetPrediction("r", closest_enemy)
        if pred_pos then
            -- print("Semi-Manual R -> Casting on", closest_enemy.charName, "closest to mouse.") -- Optional Debug
            player:castSpell("pos", spells.r.slot, pred_pos)
            orb.core.set_server_pause() -- Add a pause after casting
        end
    end
end





-- Helper function to find a usable ward slot
-- Returns: inventory_slot_index, spell_slot_index OR nil, nil
local function FindUsableWardSlot()
    print("--- FindUsableWardSlot START (Jax Logic Inspired) ---") -- Debug Start

    -- 1. Explicit Trinket Check (Inventory Slot 6 -> Spell Slot 12? or 6?)
    -- Let's first check the item in inventory slot 6 to *confirm* it's a ward trinket.
    local trinket_inv_slot = player:inventorySlot(6)
    if trinket_inv_slot and trinket_inv_slot.hasItem and WARD_ITEM_IDS[trinket_inv_slot.id] then
        print("  Inventory Slot 6 has a Ward Trinket (ID: " .. trinket_inv_slot.id .. ", Stacks: " .. trinket_inv_slot.stacks .. ")")

        -- Now, check the spell slot(s) associated with it. Try Slot 12 first based on Jax.
        local trinket_spell_slot_12 = player:spellSlot(12)
        if trinket_spell_slot_12 and trinket_spell_slot_12.isNotEmpty and string.find(trinket_spell_slot_12.name, "Trinket", 1, true) then -- Check if slot 12 looks like a trinket
             print("  Checking Spell Slot 12 (Name: " .. trinket_spell_slot_12.name .. ", State: " .. trinket_spell_slot_12.state .. ")")
             -- Check state AND stacks from the inventory slot
             if trinket_spell_slot_12.state == 0 and trinket_inv_slot.stacks > 0 then
                 print("  Spell Slot 12 is READY (State 0, Stacks > 0).")
                 print("--- FindUsableWardSlot END (Found Trinket: Inv 6, Spell 12) ---")
                 return 6, 12 -- Return Inv Slot 6, Spell Slot 12
             else
                 print("  Spell Slot 12 is NOT ready (State: " .. trinket_spell_slot_12.state .. ", Stacks: " .. trinket_inv_slot.stacks .. ")")
             end
        else
            print("  Spell Slot 12 is empty or not a trinket.")
        end

        -- If Slot 12 didn't work, try the standard mapping (Inv 6 -> Spell 6)
        local trinket_spell_slot_6 = player:spellSlot(6)
        if trinket_spell_slot_6 and trinket_spell_slot_6.isNotEmpty then -- Check if slot 6 exists
             print("  Checking Spell Slot 6 (Name: " .. trinket_spell_slot_6.name .. ", State: " .. trinket_spell_slot_6.state .. ")")
             -- Check state AND stacks from the inventory slot
             if trinket_spell_slot_6.state == 0 and trinket_inv_slot.stacks > 0 then
                 print("  Spell Slot 6 is READY (State 0, Stacks > 0).")
                 print("--- FindUsableWardSlot END (Found Trinket: Inv 6, Spell 6) ---")
                 return 6, 6 -- Return Inv Slot 6, Spell Slot 6
             else
                 print("  Spell Slot 6 is NOT ready (State: " .. trinket_spell_slot_6.state .. ", Stacks: " .. trinket_inv_slot.stacks .. ")")
             end
        else
            print("  Spell Slot 6 is empty.")
        end

    else
        if trinket_inv_slot then print("  Inventory Slot 6 does not contain a known Ward Trinket.")
        else print("  Inventory Slot 6 is empty or invalid.") end
    end

    -- 2. Check Item Slots (Inventory 0-5 -> Spell Slots 6-11) if Trinket not found/ready
    print("  Trinket not found/ready. Checking Item Slots 0-5...")
    for inv_slot_index = 0, 5 do
        local inv_slot = player:inventorySlot(inv_slot_index)
        if inv_slot and inv_slot.hasItem and WARD_ITEM_IDS[inv_slot.id] then
            print(string.format("  Checking Item Inv Slot %d (ID: %d, Stacks: %d)", inv_slot_index, inv_slot.id, inv_slot.stacks))
            local spell_slot_index = INVENTORY_TO_SPELL_SLOT[inv_slot_index] -- Should be 6 to 11
            if spell_slot_index then
                local spell_slot = player:spellSlot(spell_slot_index)
                if spell_slot and spell_slot.isNotEmpty then
                     print(string.format("    Mapped to Spell Slot %d (State: %d)", spell_slot_index, spell_slot.state))
                     -- Check state AND stacks
                     if spell_slot.state == 0 and inv_slot.stacks > 0 then
                         print(string.format("    Item Ward in Inv Slot %d (Spell %d) is READY.", inv_slot_index, spell_slot_index))
                         print("--- FindUsableWardSlot END (Found Item Ward: Inv " .. inv_slot_index .. ", Spell " .. spell_slot_index .. ") ---")
                         return inv_slot_index, spell_slot_index
                     else
                         print(string.format("    Item Ward in Inv Slot %d (Spell %d) is NOT ready (State: %d, Stacks: %d).", inv_slot_index, spell_slot_index, spell_slot.state, inv_slot.stacks))
                     end
                else
                    print("    Failed to get mapped Spell Slot object for index " .. spell_slot_index)
                end
            else
                print("    No spell slot mapping found for Inv Slot " .. inv_slot_index)
            end
        end
    end

    print("--- FindUsableWardSlot END (No usable ward found) ---") -- Debug Not Found
    return nil, nil -- No usable ward found
end

-- Function to handle ward placement logic
local function HandlePlaceWard()
    -- Check if the keybind is held down
    if not menu.utility.place_ward_key:get() then
        return false -- Key not pressed, do nothing
    end

    -- Prevent spamming attempts
    local current_time = game.time
    if current_time - State.last_ward_attempt_time < 0.2 then
        return true -- Still cooling down from last attempt, but block other actions if key is held
    end

    -- Find a usable ward
    local inv_slot_idx, spell_slot_idx = FindUsableWardSlot()
    if not spell_slot_idx then
        -- print("HandlePlaceWard: No ward available to place.") -- Debug
        State.last_ward_attempt_time = current_time -- Update time even if no ward found, to prevent spam checking
        return true -- Key held, but no ward, block other actions
    end

    -- Get ward placement position (mouse cursor)
    local ward_pos = game.mousePos

    -- Check range
    if player.pos:distSqr(ward_pos) > WARD_RANGE * WARD_RANGE then
        -- print("HandlePlaceWard: Target position out of range.") -- Debug
        player:move(ward_pos) -- Move towards the desired location if out of range
        State.last_ward_attempt_time = current_time -- Update time
        return true -- Block other actions while moving
    end

    -- Check if the position is a wall
    if navmesh.isWall(ward_pos) then
        -- print("HandlePlaceWard: Target position is inside a wall.") -- Debug
        State.last_ward_attempt_time = current_time -- Update time
        return true -- Block other actions if trying to ward in a wall
    end

    -- All checks passed, cast the ward spell
    print(string.format("HandlePlaceWard: Attempting to cast ward from Spell Slot %d to Pos (%.1f, %.1f, %.1f)", spell_slot_idx, ward_pos.x, ward_pos.y, ward_pos.z)) -- Debug
    player:castSpell('pos', spell_slot_idx, ward_pos)
    orb.core.set_server_pause() -- <<< ADDED THIS LINE to prevent orbwalker interruption
    State.last_ward_attempt_time = current_time -- Update time after successful cast attempt

    return true -- Ward action attempted, block other logic
end
















local function Killsteal()
    if player.isRecalling then return end
    local current_time = game.time -- Get current time for cooldown checks

    -- R Killsteal (Existing Logic - Unchanged)
    if menu.r.killsteal:get() and spells.r.ready() then
        local min_r_ks = menu.r.min_range_ks:get()
        local max_r_ks = menu.r.max_range_ks:get()
        for i = 0, objManager.enemies_n - 1 do
            local enemy = objManager.enemies[i]
            if IsValidTarget(enemy) then
                local dist_sqr = player.pos:distSqr(enemy.pos)
                if dist_sqr >= min_r_ks * min_r_ks and dist_sqr <= max_r_ks * max_r_ks then
                    if GetRDamage(enemy) >= enemy.health then
                        local pred_pos = GetPrediction("r", enemy)
                        if pred_pos then
                            player:castSpell("pos", spells.r.slot, pred_pos)
                            return -- Prioritize R Killsteal
                        end
                    end
                end
            end
        end
    end

    -- Q Killsteal (Modified with Q+Ward)
    if spells.q.ready() then
        local target_for_q_ks = nil
        local is_target_killable_by_q = false

        -- Find the best killable target first
        local potential_target = ts.get_result(function(res, obj, dist)
            -- Check effective range for KS potential
            if not IsValidTarget(obj, spells.q.effective_range) then return false end
            if GetQDamage(obj) >= obj.health then
                res.obj = obj
                return true -- Found a target killable by Q within effective range
            end
            return false
        end).obj

        if potential_target then
            target_for_q_ks = potential_target
            is_target_killable_by_q = true

            -- Try standard Q KS first (using GetBestQCastTarget)
            local best_direct_q_target = GetBestQCastTarget(target_for_q_ks, nil)
            if best_direct_q_target then
                -- print("KS Q Cast (Direct) ->", best_direct_q_target.name, "to kill", target_for_q_ks.name)
                player:castSpell("obj", spells.q.slot, best_direct_q_target)
                return -- Standard Q KS succeeded
            end

            -- *** Q+Ward KS Logic ***
            if menu.q.q_ward_ks:get() then
                if current_time - State.last_ward_attempt_time < 1.0 then
                    goto skip_ward_ks
                end

                local q_cast_range = GetDynamicQCastRange()
                local q_cast_range_sqr = q_cast_range * q_cast_range

                if player.pos:distSqr(target_for_q_ks.pos) > q_cast_range_sqr then
                    local inv_slot_idx, ward_spell_slot_idx = FindUsableWardSlot()
                    if ward_spell_slot_idx then
                        local dir_to_target = (target_for_q_ks.pos - player.pos):norm()
                        local placement_dist = math.min(WARD_RANGE - 50, q_cast_range - 50)
                        local ward_pos = player.pos + dir_to_target * placement_dist

                        if not navmesh.isWall(ward_pos) and player.pos:distSqr(ward_pos) <= WARD_RANGE * WARD_RANGE then
                            -- print(string.format("KS Q+Ward: Placing Ward (Slot %d) at (%.1f, %.1f) for target %s", ward_spell_slot_idx, ward_pos.x, ward_pos.z, target_for_q_ks.name))
                            player:castSpell('pos', ward_spell_slot_idx, ward_pos)
                            State.last_ward_attempt_time = current_time
                            orb.core.set_server_pause()
                            return
                        end
                    end
                end
            end
        end
        ::skip_ward_ks::
    end

    -- W Killsteal (Modified with Menu Check)
    -- **** ADD MENU CHECK HERE ****
    if menu.w.killsteal:get() and spells.w.ready() then
        local target_for_w_ks = ts.get_result(function(res, obj, dist)
            if not IsValidTarget(obj, spells.w.range) then return false end
            if GetWDamage(obj) >= obj.health then
                res.obj = obj
                return true
            end
            return false
        end).obj
        if target_for_w_ks then
            local pred_pos = GetPrediction("w", target_for_w_ks)
            if pred_pos then
                player:castSpell("pos", spells.w.slot, pred_pos)
                return -- Prioritize W Killsteal if Q failed/not possible
            end
        end
    end -- **** END OF W KS MENU CHECK ****

end -- End Q ready check (for Q KS part)



-- Helper function to check if target is CC'd (assuming this function already exists and is correct)
-- local function IsCCd(target) ... end

-- NEW: Function to handle Auto Q on CC'd Ally (REVISED - No Min HP Check)
local function AutoQCCAlly()
    -- Check if the feature is enabled and Q is ready
    if not menu.q.auto_q_cc_ally:get() or not spells.q.ready() then return false end
    -- Decide if you want this to only work out of combat, or always.
    -- Example: If orb.combat.is_active() then return false end -- Uncomment to restrict to out of combat

    local lowest_hp_ally = nil
    local lowest_hp = math.huge -- Initialize with a very high value to find the minimum

    -- Loop through all allies
    for i = 0, objManager.allies_n - 1 do
        local ally = objManager.allies[i]

        -- Check if the ally is valid, not self, within Q effective range, and is CC'd
        if IsValidTarget(ally, spells.q.effective_range) and ally.ptr ~= player.ptr and IsCCd(ally) then

            -- We found a valid CC'd ally within range.
            -- Now check if they have less HP than the current lowest HP CC'd ally found so far.
            if ally.health < lowest_hp then
                 lowest_hp = ally.health -- Update lowest HP found
                 lowest_hp_ally = ally -- This is the new best target (lowest HP)
            end
        end
    end

    -- If we found any suitable CC'd ally (lowest_hp_ally will not be nil)
    if lowest_hp_ally then
        -- Use GetBestQCastTarget to find the best unit to click on to hit this ally.
        -- Pass nil for the enemy target and the found ally object.
        local best_q_cast_target = GetBestQCastTarget(nil, lowest_hp_ally)

        -- If a unit to click on was found
        if best_q_cast_target then
            -- print("Auto Q CC Ally Cast ->", best_q_cast_target.name, "to heal", lowest_hp_ally.name) -- Optional debug
            player:castSpell("obj", spells.q.slot, best_q_cast_target)
            -- Optionally, add a small server pause or a cooldown state here if you want to prevent rapid Qs
            -- orb.core.set_server_pause() -- Use if you want to briefly pause orbwalker after cast
            -- State.last_q_cast_time = game.time -- Requires adding this state variable
            return true -- Indicate that an action was taken
        end
    end

    return false -- No action was taken
end




-- OnTick Function (Order adjusted for soul collection)
local function OnTick()
    if player.isDead then return end



    if HandlePlaceWard() then
        return -- If ward placement was attempted (or key held waiting), skip everything else
    end

    AutoQCCAlly()
    Killsteal()
    AntiGapclose()
    AutoEscape()
    AutoCC()
    SaveAllyR()
    SemiManualR()

    CollectSouls() 


    -- Flee overrides soul collection
    if orb.menu.flee.key:get() then
        Flee()
        return -- Don't do anything else if fleeing
    end



    -- Mode-based Logic (Only runs if no soul action was taken)
    if orb.combat.is_active() then
        Combo()
    elseif orb.menu.hybrid.key:get() then
        Harass()
    elseif orb.menu.lane_clear.key:get() or orb.menu.last_hit.key:get() then
        if State.q_farm_enabled then
            Farm()
        end
        JungleClear()
    else
        -- Out of combat heal (lower priority than souls)
        HealAllies()
    end
end

-- OnKeyUp for Farm Toggle (Unchanged)
local function OnKeyUp(key)
    local farm_toggle_key_code = keyboard.stringToKeyCode("MMB")
    if key == farm_toggle_key_code then
        State.q_farm_enabled = not State.q_farm_enabled
        chat.print("Senna Q Farm: " .. (State.q_farm_enabled and "ON" or "OFF"))
    end
end

-- Drawing Functions
local function DrawRanges()
    local q_cast_range = GetDynamicQCastRange() -- Draw the CAST range
    local w_range = spells.w.range
    local aa_range = GetDynamicAARange()

    if menu.drawings.ranges.aa:get() then
        graphics.draw_circle(player.pos, aa_range, 1, menu.drawings.colors.aa:get(), 64)
    end
    if menu.drawings.ranges.q:get() and spells.q.ready() then
        graphics.draw_circle(player.pos, q_cast_range, 1, menu.drawings.colors.q:get(), 64)
    end
    if menu.drawings.ranges.w:get() and spells.w.ready() then
        graphics.draw_circle(player.pos, w_range, 1, menu.drawings.colors.w:get(), 64)
    end
    if menu.drawings.ranges.r_ks:get() and spells.r.ready() then
        local min_r = menu.r.min_range_ks:get()
        local max_r = menu.r.max_range_ks:get()
        graphics.draw_circle(player.pos, max_r, 1, menu.drawings.colors.r:get(), 128)
        if min_r > 0 then
             graphics.draw_circle(player.pos, min_r, 1, graphics.argb(100, 150, 150, 150), 64)
        end
    end
end

local function DrawDamageIndicator(target)
    if not IsValidTarget(target) then return end
    local qDmg = (menu.drawings.damage_drawing.use_q:get() and GetQDamage(target)) or 0
    local wDmg = (menu.drawings.damage_drawing.use_w:get() and GetWDamage(target)) or 0
    local rDmg = (menu.drawings.damage_drawing.use_r:get() and GetRDamage(target)) or 0
    local passiveDmg = (menu.drawings.damage_drawing.include_passive:get() and GetPassiveDamage(target)) or 0
    local aa_damage_factor = menu.drawings.damage_drawing.aa_factor:get()
    local aa_damage = damagelib.calc_aa_damage(player, target, true) * aa_damage_factor
    local totalDmg = qDmg + wDmg + rDmg + passiveDmg + aa_damage
    if totalDmg <= 0 then return end
    local damagePercent = math.min((totalDmg / target.health) * 100, 100)
    local pos = graphics.world_to_screen(target.pos)
    if not pos then return end
    local text = string.format((isCN and "???: %.0f%%" or "Damage: %.0f%%"), damagePercent)
    if totalDmg >= target.health then text = text .. (isCN and " (????)" or " (Killable)") end
    local color = totalDmg >= target.health and 0xFF00FF00 or 0xFFFFFFFF
    -- Draw outline
    for ox = -1, 1 do for oy = -1, 1 do if ox ~= 0 or oy ~= 0 then graphics.draw_text_2D(text, 14, pos.x - 30 + ox, pos.y - 35 + oy, 0xFF000000) end end end
    graphics.draw_text_2D(text, 14, pos.x - 30, pos.y - 35, color)
    local breakdown = string.format("Q:%.0f W:%.0f R:%.0f P:%.0f AA:%.0f", qDmg, wDmg, rDmg, passiveDmg, aa_damage)
    graphics.draw_text_2D(breakdown, 12, pos.x - 30, pos.y - 20, 0xFFCCCCCC)
    -- Draw on health bar
    if target.isOnScreen then
      local barPos = target.barPos
      if barPos then
        local percentHealthAfterDamage = math.max(0, target.health - totalDmg) / target.maxHealth
        local barStartX = barPos.x + 165 -- Adjust if needed
        local barWidth = 103 -- Adjust if needed
        graphics.draw_line_2D(barStartX + barWidth * target.health / target.maxHealth, barPos.y + 123, barStartX + barWidth * percentHealthAfterDamage, barPos.y + 123, 11, graphics.argb(90, 255, 169, 4))
      end
    end
end

local function DrawFarmStatusOverlay()
    if player.isDead or not menu.drawings.enabled:get() or not menu.drawings.farm_draw_status:get() then return end
    local pos = graphics.world_to_screen(player.pos)
    if not pos then return end
    local farmModeText = State.q_farm_enabled and (isCN and "Q ????: ????" or "Q Farm: ON") or (isCN and "Q ????: ???" or "Q Farm: OFF")
    local textColor = State.q_farm_enabled and graphics.argb(255, 0, 255, 0) or graphics.argb(255, 255, 0, 0)
    -- Draw outline
    for ox = -1, 1 do for oy = -1, 1 do if ox ~= 0 or oy ~= 0 then graphics.draw_text_2D(farmModeText, 16, pos.x - 50 + ox, pos.y + 20 + oy, 0xFF000000) end end end
    graphics.draw_text_2D(farmModeText, 16, pos.x - 50, pos.y + 20, textColor)
end

-- Soul Collection Drawing (Unchanged)
local function DrawSoulCollection()
    if not menu.drawings.enabled:get() then return end

    local draw_souls = menu.souls.draw_souls:get()
    local collect_range = player.attackRange + player.boundingRadius
    local soul_color = menu.souls.soul_color:get()

    if not draw_souls then return end



    if draw_souls then
        local all_minions = objManager.allMinions
        if not all_minions then return end
        for i = 0, all_minions.size - 1 do
            local minion = all_minions[i]
            if minion and minion.charName == SOUL_CHAR_NAME and IsValidTarget(minion) and minion.isOnScreen then
                local dist_sqr = player.pos:distSqr(minion.pos)
                if dist_sqr <= collect_range * collect_range then
                    graphics.draw_circle(minion.pos, minion.boundingRadius + 20, 2, soul_color, 16)
                end
            end
        end
    end
end



local function DrawExtendedQVisuals()
    -- Initial checks
    if not menu.drawings.enabled:get() then return end
    if not menu.drawings.indicators.q_extend_lines:get() then return end -- Check the new menu option
    if player.isDead or not spells.q.ready() then return end

    local q_cast_range = GetDynamicQCastRange()
    local q_effective_range = spells.q.effective_range
    local q_line_color = menu.drawings.indicators.q_extend_color:get()
    local q_ward_ks_color = menu.drawings.indicators.q_ward_ks_color:get()
    local player_pos = player.pos
    local player_pos_2d = player.pos2D

    -- 1. Determine Intended Target (Focus on Combo/Harass first for simplicity)
    local intended_target = nil
        intended_target = ts.get_result(function(res, obj, dist_sq)
            -- Check effective range directly here
            if not IsValidTarget(obj, q_effective_range) then return false end
            res.obj = obj
            return true
        end).obj

    -- 2. Draw Standard Extended Q Line (if applicable)
    if intended_target and IsValidTarget(intended_target, q_effective_range) then
        local dist_to_target = player_pos:dist(intended_target.pos)

        -- Check if target is outside cast range but inside effective range
        if dist_to_target > q_cast_range and dist_to_target <= q_effective_range then
            -- Find the best unit to cast through
            local best_cast_unit = GetBestQCastTarget(intended_target, nil) -- Pass only the enemy

            if best_cast_unit and best_cast_unit.ptr ~= intended_target.ptr then
                -- Calculate line end position (capped at effective range)
                local direction = (best_cast_unit.pos - player_pos):norm()
                if direction:lenSqr() < 0.01 then direction = player.direction:norm() end
                if direction:lenSqr() < 0.01 then direction = vec3(1,0,0) end -- Fallback

                local line_end_pos = player_pos + direction * q_effective_range

                -- Draw the line
                graphics.draw_line(player_pos, line_end_pos, 2, q_line_color)

                -- Highlight the unit being used for extension
                graphics.draw_circle(best_cast_unit.pos, best_cast_unit.boundingRadius + 15, 1, q_line_color, 16)

                -- Highlight the final intended target
                graphics.draw_circle(intended_target.pos, intended_target.boundingRadius + 25, 1, q_line_color, 20)

                goto finished_drawing -- Don't draw ward KS line if standard extension found
            end
        end
    end

    -- 3. Draw Q+Ward KS Potential Line
    if menu.q.q_ward_ks:get() then
        local ks_target = nil
        local killable_found = false
        for i = 0, objManager.enemies_n - 1 do
            local enemy = objManager.enemies[i]
            if IsValidTarget(enemy, q_effective_range) then
                local dist_to_enemy = player_pos:dist(enemy.pos)
                -- Check if killable with Q and OUTSIDE cast range but INSIDE effective range
                if GetQDamage(enemy) >= enemy.health and dist_to_enemy > q_cast_range and dist_to_enemy <= q_effective_range then
                     ks_target = enemy
                     killable_found = true
                     break -- Found a potential target
                end
            end
        end

        if killable_found then
            local inv_slot_idx, ward_spell_slot_idx = FindUsableWardSlot()
            if ward_spell_slot_idx then -- Check if a ward is actually available
                 -- Calculate potential ward placement
                 local dir_to_target = (ks_target.pos - player.pos):norm()
                 -- Place ward slightly inside max cast range and inside max ward range
                 local placement_dist = math.min(WARD_RANGE - 50, q_cast_range - 50)
                 if placement_dist <= 0 then goto finished_drawing end -- Cannot place ward close enough

                 local potential_ward_pos = player_pos + dir_to_target * placement_dist

                 -- Check if placement is valid (not in wall, roughly correct distance)
                 if not navmesh.isWall(potential_ward_pos) and player_pos:dist(potential_ward_pos) <= WARD_RANGE then
                     -- Calculate final line end position (capped at effective range)
                     local direction_from_ward = (ks_target.pos - potential_ward_pos):norm()
                     if direction_from_ward:lenSqr() < 0.01 then direction_from_ward = dir_to_target end -- Use original dir if needed

                     -- The visual line should *still* originate from the player, but "pass through" the ward spot
                     local visual_direction = (potential_ward_pos - player_pos):norm()
                     if visual_direction:lenSqr() < 0.01 then visual_direction = dir_to_target end

                     local line_end_pos = player_pos + visual_direction * q_effective_range

                     -- Draw the line with the special color
                     graphics.draw_line(player_pos, line_end_pos, 2, q_ward_ks_color)

                     -- Draw a placeholder for the ward
                     graphics.draw_circle(potential_ward_pos, 35, 2, q_ward_ks_color, 12)

                     -- Highlight the KS target
                     graphics.draw_circle(ks_target.pos, ks_target.boundingRadius + 25, 1, q_ward_ks_color, 20)
                 end
            end
        end
    end

    ::finished_drawing::
end


local function OnDraw()
    local drawings_enabled = menu.drawings.enabled:get()

    if player.isDead or not drawings_enabled then
        -- Hide all shader effects if dead or drawings disabled
        circle_effects.aa:update_circle(vec3(0,0,0), 0, 0, 0)
        circle_effects.q:update_circle(vec3(0,0,0), 0, 0, 0)
        circle_effects.w:update_circle(vec3(0,0,0), 0, 0, 0)
        -- No need to hide R KS effect here as it uses draw_circle directly
        return
    end

    DrawExtendedQVisuals()
        -- Always Draw R KS Range on Minimap if R is Ready
        local max_r_ks = menu.r.max_range_ks:get() -- Get radius from menu setting
        minimap.draw_circle(player.pos, max_r_ks, 1.5, 0xFFFFFFFF, 50)
    

    -- Dynamic Ranges
    local aa_range = GetDynamicAARange()
    local q_cast_range = GetDynamicQCastRange()
    local w_range = spells.w.range
    local min_r_ks = menu.r.min_range_ks:get()

    -- Update AA Range Shader
    if menu.drawings.ranges.aa:get() then
        circle_effects.aa:update_circle(player.pos, aa_range, 2, menu.drawings.colors.aa:get())
    else
        circle_effects.aa:update_circle(vec3(0,0,0), 0, 0, 0)
    end

    -- Update Q Cast Range Shader
    if menu.drawings.ranges.q:get() and spells.q.ready() then
        circle_effects.q:update_circle(player.pos, q_cast_range, 2, menu.drawings.colors.q:get())
    else
        circle_effects.q:update_circle(vec3(0,0,0), 0, 0, 0)
    end

    -- Update W Range Shader
    if menu.drawings.ranges.w:get() and spells.w.ready() then
        circle_effects.w:update_circle(player.pos, w_range, 2, menu.drawings.colors.w:get())
    else
        circle_effects.w:update_circle(vec3(0,0,0), 0, 0, 0)
    end


    

    -- Keep other drawing functions
    DrawFarmStatusOverlay()
    DrawSoulCollection()
    for i = 0, objManager.enemies_n - 1 do
        local enemy = objManager.enemies[i]
        if menu.drawings.damage_indicator:get() and IsValidTarget(enemy) and enemy.isOnScreen then
            DrawDamageIndicator(enemy)
        end
    end
end


-- Register Callbacks
cb.add(cb.tick, OnTick)
cb.add(cb.draw, OnDraw)
cb.add(cb.keyup, OnKeyUp)

chat.print("DanZ-AIO Senna Initialized (Q Extended Range v3 + Soul Collection v1)")