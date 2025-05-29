-- PaladinRetribution.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Paladin: Retribution spec

if UnitClassBase( 'player' ) ~= 'PALADIN' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 70 ) -- Retribution spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

spec:RegisterResource( Enum.PowerType.Mana )
spec:RegisterResource( Enum.PowerType.HolyPower )

-- Tier sets
spec:RegisterGear( "tier14", 85349, 85350, 85351, 85352, 85353 ) -- T14 Retribution Paladin Set
spec:RegisterGear( "tier15", 95280, 95282, 95278, 95281, 95279 ) -- T15 Retribution Paladin Set

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Movement
    speed_of_light            = { 2199, 1, 85499  }, -- +70% movement speed for 8 sec
    long_arm_of_the_law       = { 2200, 1, 114158 }, -- Judgments increase movement speed by 45% for 3 sec
    pursuit_of_justice        = { 2201, 1, 26023  }, -- +15% movement speed per Holy Power charge

    -- Tier 2 (Level 30) - Control
    fist_of_justice           = { 2202, 1, 105593 }, -- Reduces Hammer of Justice cooldown by 50%
    repentance                = { 2203, 1, 20066  }, -- Puts the enemy target in a state of meditation, incapacitating them for up to 1 min.
    blinding_light            = { 2204, 1, 115750 }, -- Emits dazzling light in all directions, blinding enemies within 10 yards for 6 sec.

    -- Tier 3 (Level 45) - Healing
    selfless_healer           = { 2205, 1, 85804  }, -- Your Holy power spending abilities reduce the cast time and mana cost of your next Flash of Light.
    eternal_flame             = { 2206, 1, 114163 }, -- Consumes all Holy Power to place a protective Holy flame on a friendly target, which heals over 30 sec.
    sacred_shield             = { 2207, 1, 20925  }, -- Places a Sacred Shield on a friendly target, absorbing damage every 6 sec for 30 sec.

    -- Tier 4 (Level 60) - Utility/CC
    hand_of_purity            = { 2208, 1, 114039 }, -- Protects a party or raid member, reducing harmful periodic effects by 70% for 6 sec.
    unbreakable_spirit        = { 2209, 1, 114154 }, -- Reduces the cooldown of your Divine Shield, Divine Protection, and Lay on Hands by 50%.
    clemency                  = { 2210, 1, 105622 }, -- Increases the number of charges on your Hand spells by 1.

    -- Tier 5 (Level 75) - DPS
    divine_purpose            = { 2211, 1, 86172  }, -- Your Holy Power abilities have a 15% chance to make your next Holy Power ability free and more effective.
    holy_avenger              = { 2212, 1, 105809 }, -- Your Holy power generating abilities generate 3 charges of Holy Power for 18 sec.
    sanctified_wrath          = { 2213, 1, 53376  }, -- Increases the duration of Avenging Wrath by 5 sec and causes your Judgment to generate 1 additional Holy Power during Avenging Wrath.

    -- Tier 6 (Level 90) - DPS/Utility
    holy_prism                = { 2214, 1, 114165 }, -- Fires a beam of light that hits a target for Holy damage or healing.
    lights_hammer             = { 2215, 1, 114158 }, -- Hurls a Light-infused hammer to the ground, dealing Holy damage to enemies and healing allies.
    execution_sentence        = { 2216, 1, 114157 }  -- A hammer slowly falls from the sky, dealing Holy damage to an enemy or healing an ally.
} )

-- Retribution-specific Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [56414] = "double_jeopardy",   -- Your Judgment deals 20% additional damage when striking a target already affected by your Judgment.
    [56420] = "mass_exorcism",     -- Your Exorcism is now instant and hits all targets within 8 yards of your target, but has a 20 sec cooldown.
    [56416] = "inquisition",       -- Increases the duration of your Inquisition by 30 sec.
    [63219] = "final_wrath",       -- Avenging Wrath increases the damage of Hammer of Wrath by 50%.
    [54935] = "templars_verdict",  -- Your Templar's Verdict automatically hits an additional nearby enemy for 50% damage.
    [57937] = "divine_storm",      -- Increases the damage of Divine Storm by 20%, but removes the healing component of the ability.
    
    -- Minor Glyphs
    [57954] = "righteous_retreat", -- When you use Divine Shield, you also become immune to disarm effects, but the cooldown of Divine Shield is increased by 50%.
    [57947] = "blessed_life",      -- You have a 50% chance to generate 1 charge of Holy Power when you take damage.
    [43367] = "fire_from_heaven",  -- Your Holy Wrath is channeled, dealing 40% damage per second for 3 sec, and has a 15 sec cooldown.
} )

-- Retribution Paladin specific auras
spec:RegisterAuras( {
    -- Inquisition: Key damage buff
    inquisition = {
        id = 84963,
        duration = function() 
            -- Base duration of 30 seconds + 30 seconds per Holy Power spent
            local duration = 30 * state.holy_power.current
            -- Glyph of Inquisition increases duration by 30 sec
            if state.glyph.inquisition.enabled then
                duration = duration + 30
            end
            return duration
        end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 84963 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Divine Purpose: Free and enhanced Holy Power ability
    divine_purpose = {
        id = 86172,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 86172 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Avenging Wrath: Increased damage
    avenging_wrath = {
        id = 31884,
        duration = function() 
            return state.talent.sanctified_wrath.enabled and 25 or 20
        end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 31884 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Guardian of Ancient Kings (Ret version): Major damage cooldown
    guardian_of_ancient_kings = {
        id = 86698,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 86698 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Holy Avenger: Holy Power abilities more effective
    holy_avenger = {
        id = 105809,
        duration = 18,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 105809 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Divine Protection: Reduces damage taken
    divine_protection = {
        id = 498,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 498 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Divine Shield: Complete immunity
    divine_shield = {
        id = 642,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 642 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Forbearance: Cannot receive certain immunities again
    forbearance = {
        id = 25771,
        duration = 60,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "player", 25771 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Speed of Light: Increased movement speed
    speed_of_light = {
        id = 85499,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 85499 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Long Arm of the Law: Increased movement speed after Judgment
    long_arm_of_the_law = {
        id = 114158,
        duration = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114158 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Pursuit of Justice: Increased movement speed from Holy Power
    pursuit_of_justice = {
        id = 26023,
        duration = 3600,
        max_stack = 3,
        generate = function( t )
            t.count = state.holy_power.current
            t.expires = 3600
            t.applied = 0
            t.caster = "player"
        end
    },
    
    -- Hand of Freedom: Immunity to movement impairing effects
    hand_of_freedom = {
        id = 1044,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1044, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Hand of Protection: Immunity to physical damage
    hand_of_protection = {
        id = 1022,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1022, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Hand of Sacrifice: Redirects damage to Paladin
    hand_of_sacrifice = {
        id = 6940,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 6940, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Sacred Shield: Absorbs damage periodically
    sacred_shield = {
        id = 65148,
        duration = 30,
        tick_time = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 65148 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Eternal Flame: HoT from talent
    eternal_flame = {
        id = 114163,
        duration = function() return 30 + (3 * state.holy_power.current) end,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114163, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Art of War: Proc for instant and free Exorcism
    art_of_war = {
        id = 87138,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 87138 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
} )

-- Retribution Paladin abilities
spec:RegisterAbilities( {
    -- Core Retribution abilities
    templars_verdict = {
        id = 85256,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if state.buff.divine_purpose.up then return 0 end
            return 3 
        end,
        spendType = "holy_power",
        
        startsCombat = true,
        texture = 461860,
        
        handler = function()
            -- Templar's Verdict mechanic
            if state.buff.divine_purpose.up then
                removeBuff("divine_purpose")
            end
            
            -- Divine Purpose talent proc chance
            if state.talent.divine_purpose.enabled and not state.buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    divine_storm = {
        id = 53385,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if state.buff.divine_purpose.up then return 0 end
            return 3 
        end,
        spendType = "holy_power",
        
        startsCombat = true,
        texture = 236250,
        
        handler = function()
            -- Divine Storm mechanic
            if state.buff.divine_purpose.up then
                removeBuff("divine_purpose")
            end
            
            -- Divine Purpose talent proc chance
            if state.talent.divine_purpose.enabled and not state.buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    exorcism = {
        id = 879,
        cast = function() 
            if state.buff.art_of_war.up then return 0 end
            if state.glyph.mass_exorcism.enabled then return 0 end
            return 1.5 
        end,
        cooldown = function() 
            if state.glyph.mass_exorcism.enabled then return 20 end
            return 15 
        end,
        gcd = "spell",
        
        spend = function() 
            if state.buff.art_of_war.up then return 0 end
            return 0.18 
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135903,
        
        handler = function()
            -- Exorcism mechanic
            if state.buff.art_of_war.up then
                removeBuff("art_of_war")
            end
            
            gain(1, "holy_power")
        end
    },
    
    inquisition = {
        id = 84963,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if state.buff.divine_purpose.up then return 0 end
            return 3 
        end,
        spendType = "holy_power",
        
        startsCombat = false,
        texture = 135975,
        
        handler = function()
            -- Inquisition mechanic - consumes all Holy Power for duration
            local duration = 30 * state.holy_power.current
            
            if state.buff.divine_purpose.up then
                -- If Divine Purpose, treat as 3 Holy Power
                removeBuff("divine_purpose")
                duration = 90
            end
            
            -- Glyph of Inquisition increases duration by 30 sec
            if state.glyph.inquisition.enabled then
                duration = duration + 30
            end
            
            applyBuff("inquisition", duration)
            
            -- Divine Purpose talent proc chance
            if state.talent.divine_purpose.enabled and not state.buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    guardian_of_ancient_kings = {
        id = 86698,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 409594,
        
        handler = function()
            applyBuff("guardian_of_ancient_kings")
        end
    },
    
    avenging_wrath = {
        id = 31884,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 135875,
        
        handler = function()
            applyBuff("avenging_wrath")
        end
    },
    
    holy_avenger = {
        id = 105809,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        talent = "holy_avenger",
        
        startsCombat = false,
        texture = 571555,
        
        handler = function()
            applyBuff("holy_avenger")
        end
    },
    
    holy_prism = {
        id = 114165,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0.35,
        spendType = "mana",
        
        talent = "holy_prism",
        
        startsCombat = function() return not state.option.holy_prism_heal end,
        texture = 613407,
        
        handler = function()
            -- Holy Prism mechanic
            -- If cast on enemy, damages target and heals 5 nearby friendlies
            -- If cast on friendly, heals target and damages 5 nearby enemies
        end
    },
    
    lights_hammer = {
        id = 114158,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.38,
        spendType = "mana",
        
        talent = "lights_hammer",
        
        startsCombat = true,
        texture = 613952,
        
        handler = function()
            -- Light's Hammer mechanic - ground target AoE that heals allies and damages enemies
        end
    },
    
    execution_sentence = {
        id = 114157,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.38,
        spendType = "mana",
        
        talent = "execution_sentence",
        
        startsCombat = function() return not state.option.execution_sentence_heal end,
        texture = 613954,
        
        handler = function()
            -- Execution Sentence mechanic
            -- If cast on enemy, damages after 10 seconds
            -- If cast on friendly, heals after 10 seconds
        end
    },
    
    divine_shield = {
        id = 642,
        cast = 0,
        cooldown = function()
            return state.talent.unbreakable_spirit.enabled and 150 or 300
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 524354,
        
        handler = function()
            applyBuff("divine_shield")
            applyDebuff("player", "forbearance")
        end
    },
    
    divine_protection = {
        id = 498,
        cast = 0,
        cooldown = function()
            return state.talent.unbreakable_spirit.enabled and 30 or 60
        end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 524353,
        
        handler = function()
            applyBuff("divine_protection")
        end
    },
    
    lay_on_hands = {
        id = 633,
        cast = 0,
        cooldown = function() 
            return state.talent.unbreakable_spirit.enabled and 360 or 600
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 135928,
        
        handler = function()
            -- Heals target for Paladin's maximum health
            -- Applies Forbearance
            applyDebuff("target", "forbearance")
        end
    },
    
    hand_of_freedom = {
        id = 1044,
        cast = 0,
        cooldown = function() 
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 25 }
            end
            return 25
        end,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135968,
        
        handler = function()
            applyBuff("hand_of_freedom")
        end
    },
    
    hand_of_protection = {
        id = 1022,
        cast = 0,
        cooldown = function() 
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 300 }
            end
            return 300
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 135964,
        
        handler = function()
            applyBuff("hand_of_protection")
            applyDebuff("player", "forbearance")
        end
    },
    
    hand_of_sacrifice = {
        id = 6940,
        cast = 0,
        cooldown = function() 
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 120 }
            end
            return 120
        end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 135966,
        
        handler = function()
            applyBuff("hand_of_sacrifice", "target")
        end
    },
    
    hand_of_purity = {
        id = 114039,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        talent = "hand_of_purity",
        
        startsCombat = false,
        texture = 458726,
        
        handler = function()
            -- Applies Hand of Purity effect
        end
    },
    
    -- Shared Paladin abilities
    crusader_strike = {
        id = 35395,
        cast = 0,
        cooldown = 4.5,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135891,
        
        handler = function()
            gain(1, "holy_power")
            
            -- Art of War proc chance (20%)
            if math.random() < 0.20 then
                applyBuff("art_of_war")
            end
        end
    },
    
    judgment = {
        id = 20271,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135959,
        
        handler = function()
            -- Sanctified Wrath talent interaction - Judgment generates 1 additional Holy Power during Avenging Wrath
            if state.buff.avenging_wrath.up and state.talent.sanctified_wrath.enabled then
                gain(2, "holy_power")
            else
                gain(1, "holy_power")
            end
            
            -- Long Arm of the Law movement speed
            if state.talent.long_arm_of_the_law.enabled then
                applyBuff("long_arm_of_the_law")
            end
        end
    },
    
    cleanse = {
        id = 4987,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.14,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135949,
        
        handler = function()
            -- Removes 1 Poison effect, 1 Disease effect, and 1 Magic effect from a friendly target
        end
    },
    
    hammer_of_justice = {
        id = 853,
        cast = 0,
        cooldown = function() 
            if state.talent.fist_of_justice.enabled then
                return 30
            end
            return 60
        end,
        gcd = "spell",
        
        startsCombat = true,
        texture = 135963,
        
        handler = function()
            -- Stuns target for 6 seconds
        end
    },
    
    hammer_of_wrath = {
        id = 24275,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        usable = function()
            -- Usable when target below 20% health or during Avenging Wrath
            return target.health_pct < 20 or state.buff.avenging_wrath.up
        end,
        
        startsCombat = true,
        texture = 138168,
        
        handler = function()
            gain(1, "holy_power")
        end
    },
    
    consecration = {
        id = 26573,
        cast = 0,
        cooldown = 9,
        gcd = "spell",
        
        spend = 0.24,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135926,
        
        handler = function()
            -- Creates consecrated ground that deals Holy damage over time
        end
    },
    
    word_of_glory = {
        id = 85673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if state.buff.divine_purpose.up then return 0 end
            return 3 
        end,
        spendType = "holy_power",
        
        startsCombat = false,
        texture = 646176,
        
        handler = function()
            -- Word of Glory mechanic - consumes all Holy Power
            if state.buff.divine_purpose.up then
                removeBuff("divine_purpose")
            else
                -- Modify healing based on Holy Power consumed
                -- Word of Glory's base healing amount is multiplied per Holy Power
            end
            
            -- Selfless Healer reductions for next Flash of Light if talented
            if state.talent.selfless_healer.enabled then
                applyBuff("selfless_healer", nil, 3)
            end
            
            -- Eternal Flame talent application instead of direct heal
            if state.talent.eternal_flame.enabled then
                applyBuff("eternal_flame")
            end
            
            -- Divine Purpose talent proc chance
            if state.talent.divine_purpose.enabled and not state.buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    repentance = {
        id = 20066,
        cast = 1.5,
        cooldown = 15,
        gcd = "spell",
        
        talent = "repentance",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135942,
        
        handler = function()
            -- Incapacitates target for up to 1 minute
        end
    },
    
    blinding_light = {
        id = 115750,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        talent = "blinding_light",
        
        spend = 0.18,
        spendType = "mana",
        
        startsCombat = true,
        texture = 571553,
        
        handler = function()
            -- Disorients all nearby enemies
        end
    },
    
    speed_of_light = {
        id = 85499,
        cast = 0,
        cooldown = 45,
        gcd = "off",
        
        talent = "speed_of_light",
        
        startsCombat = false,
        texture = 538056,
        
        handler = function()
            applyBuff("speed_of_light")
        end
    },
    
    sacred_shield = {
        id = 20925,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        talent = "sacred_shield",
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = false,
        texture = 612316,
        
        handler = function()
            applyBuff("sacred_shield")
        end
    },
} )

-- States and calculations for Retribution specific mechanics
local function checkArtOfWar()
    -- 20% chance to proc Art of War on Crusader Strike
    return buff.art_of_war.up
end

state.RegisterExpressions( {
    ['artOfWarActive'] = function()
        return checkArtOfWar()
    end
} )

-- Range
spec:RegisterRanges( "judgment", "hammer_of_justice", "rebuke", "crusader_strike" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 2,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent_potion",
    
    package = "Retribution",
    
    holy_prism_heal = false,
    execution_sentence_heal = false,
} )

-- Register default pack for MoP Retribution Paladin
spec:RegisterPack( "Retribution", 20250515, [[Hekili:T1PBVTTn04FlXjHj0OfnrQ97Lvv9n0KxkzPORkyzyV1ikA2JC7fSOhtkfLjjRKKGtkLQfifs4YC7O3MF11Fw859fNZXPb72TQWN3yiOtto8jREEP(D)CaaR7oXR]hYdVp)NhS4(SZdhFpzmYBPn2qGdjcw5Jt8jc((52Lbb6W0P)MM]] )

-- Register pack selector for Retribution
spec:RegisterPackSelector( "retribution", "Retribution", "|T135873:0|t Retribution",
    "Handles all aspects of Retribution Paladin DPS with focus on Holy Power generation and spending.",
    nil )
