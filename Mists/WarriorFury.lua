-- WarriorFury.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Warrior: Fury spec

if UnitClassBase( 'player' ) ~= 'WARRIOR' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

local spec = Hekili:NewSpecialization( 72 ) -- Fury spec ID for MoP

-- Register resources
spec:RegisterResource( Enum.PowerType.Rage, {
    ragePerAuto = function ()
        local mult = 1.75 -- Base rage generation multiplier
        
        return 5 * mult -- 5 base rage per auto attack, multiplied by specialization rage multiplier
    end,
    
    regenRate = function ()
        return 0
    end,
} )

-- Tier sets
spec:RegisterGear( "tier14", 85329, 85330, 85331, 85332, 85333 ) -- T14 Warrior Set
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- T15 Warrior Set

-- Talents (MoP talent system - ID, enabled, spell_id)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    juggernaut                 = { 2047, 1, 103156 }, -- Your Charge ability has 2 charges, shares charges with Intervene, and generates 15 Rage.
    double_time                = { 2048, 1, 103827 }, -- Your Charge ability has 2 charges, shares charges with Intervene, and no longer generates Rage.
    warbringer                 = { 2049, 1, 103828 }, -- Charge also roots the target for 4 sec, and Hamstring generates more Rage.

    -- Tier 2 (Level 30) - Healing/Survival
    second_wind                = { 2050, 1, 29838  }, -- While below 35% health, you regenerate 3% of your maximum health every 1 sec. Cannot be triggered if you were reduced below 35% by a creature that rewards experience or honor.
    enraged_regeneration       = { 2051, 1, 55694  }, -- Instantly heals you for 10% of your total health and regenerates an additional 10% over 5 sec. Usable whilst stunned, frozen, incapacitated, feared, or asleep. 1 min cooldown.
    impending_victory          = { 2052, 1, 103840 }, -- Instantly attack the target causing damage and healing you for 10% of your maximum health. Replaces Victory Rush. 30 sec cooldown.

    -- Tier 3 (Level 45) - Utility
    staggering_shout           = { 2053, 1, 107566 }, -- Causes all enemies within 10 yards to have their movement speed reduced by 50% for 15 sec. 40 sec cooldown.
    piercing_howl              = { 2054, 1, 12323  }, -- Causes all enemies within 10 yards to have their movement speed reduced by 50% for 15 sec. 30 sec cooldown.
    disrupting_shout           = { 2055, 1, 102060 }, -- Interrupts all enemy spell casts and prevents any spell in that school from being cast for 4 sec. 40 sec cooldown.

    -- Tier 4 (Level 60) - Burst DPS
    bladestorm                 = { 2056, 1, 46924  }, -- You become a whirlwind of steel, attacking all enemies within 8 yards for 6 sec, but you cannot use Auto Attack, Slam, or Execute during this time. Increases your chance to dodge by 30% for the duration. 1.5 min cooldown.
    shockwave                  = { 2057, 1, 46968  }, -- Sends a wave of force in a frontal cone, causing damage and stunning enemies for 4 sec. This ability is usable in all stances. 40 sec cooldown. Cooldown reduced by 20 sec if it strikes at least 3 targets.
    dragon_roar                = { 2058, 1, 118000 }, -- Roar powerfully, dealing damage to all enemies within 8 yards, knockback and disarming all enemies for 4 sec. The damage is always a critical hit. 1 min cooldown.

    -- Tier 5 (Level 75) - Survivability
    mass_spell_reflection      = { 2059, 1, 114028 }, -- Reflects the next spell cast on you and all allies within 20 yards back at the caster. 1 min cooldown.
    safeguard                  = { 2060, 1, 114029 }, -- Intervene also reduces all damage taken by the target by 20% for 6 sec.
    vigilance                  = { 2061, 1, 114030 }, -- Focus your protective gaze on a group member, transferring 30% of damage taken to you. In addition, each time the target takes damage, cooldown on your next Taunt is reduced by 3 sec. Lasts 12 sec.

    -- Tier 6 (Level 90) - Damage
    avatar                     = { 2062, 1, 107574 }, -- You transform into an unstoppable avatar, increasing damage done by 20% and removing and granting immunity to movement imparing effects for 24 sec. 3 min cooldown.
    bloodbath                  = { 2063, 1, 12292  }, -- Increases damage by 30% and causes your auto attacks and damaging abilities to cause the target to bleed for an additional 30% of the damage you initially dealt over 6 sec. Lasts 12 sec. 1 min cooldown.
    storm_bolt                 = { 2064, 1, 107570 }, -- Throws your weapon at the target, causing damage and stunning for 3 sec. This ability is usable in all stances. 30 sec cooldown.
} )

-- Fury-specific Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [58095] = "bladestorm",             -- Reduces the cooldown of your Bladestorm ability by 15 sec.
    [58096] = "bloody_healing",         -- Your Victory Rush and Impending Victory abilities heal you for an additional 10% of your max health.
    [58099] = "bull_rush",              -- Your Charge ability roots the target for 1 sec.
    [58103] = "death_from_above",       -- When you use Charge, you leap into the air on a course to the target.
    [58097] = "die_by_the_sword",       -- Increases the chance to parry of your Die by the Sword ability by 20%, but reduces its duration by 4 sec.
    [58098] = "hamstring",              -- Reduces the global cooldown triggered by your Hamstring to 0.5 sec.
    [58100] = "raging_blow",            -- Reduces the cooldown on your Raging Blow ability by 5 sec, but reduces its damage by 20%.
    [58370] = "raging_wind",            -- Your Raging Blow also consumes the Berserker Stance effect from Colossus Smash.
    [58372] = "shield_wall",            -- Reduces the cooldown of your Shield Wall ability by 2 min, but also reduces its effect by 20%.
    [58101] = "spell_reflection",       -- Reduces the cooldown of your Spell Reflection ability by 5 sec, but reduces its duration by 1 sec.
    [58356] = "unending_rage",          -- Your Enrage effects and Berserker Rage ability last an additional 2 sec.
    [63324] = "victory_rush",           -- Your Victory Rush ability is usable for an additional 5 sec after the duration expires, but heals you for 50% less.
    [58366] = "bloodthirst",            -- Using Bloodthirst refreshes the Strikes of Opportunity from your Taste for Blood.
    [58374] = "wild_strike",            -- Your Wild Strike now costs 5 less Rage to use.
    [58357] = "cleaving",               -- Your Cleave ability now strikes up to 3 targets.
    
    -- Minor Glyphs
    [58355] = "battle",                 -- Your Battle Shout now also increases your maximum health by 3% for 1 hour.
    [58376] = "berserker_rage",         -- Your Berserker Rage no longer causes you to become immune to Fear, Sap, or Incapacitate effects.
    [58385] = "blitz",                  -- When you use Charge, you charge up to 3 enemies near the target.
    [58367] = "burning_anger",          -- Increases the critical strike chance of your Thunder Clap and Shock Wave by 20%, but they cost 20 rage.
    [58388] = "colossus_smash",         -- Your Colossus Smash ability now instantly grants you Berserker Stance.
    [58377] = "furious_sundering",      -- Your Sunder Armor ability now reduces the movement speed of your target by 50% for 15 sec.
    [58386] = "long_charge",            -- Increases the range of your Charge and Intervene abilities by 5 yards.
    [58375] = "resonating_power",       -- The periodic damage of your Thunder Clap ability now also causes enemies to resonate with energy, dealing 5% of the Thunder Clap damage to nearby enemies within 10 yards.
    [58368] = "thunder_strike",         -- Increases the number of targets your Thunder Clap ability hits by 50%, but reduces its damage by 20%.
} )

-- Fury Warrior specific auras
spec:RegisterAuras( {
    -- Core buffs/debuffs
    battle_shout = {
        id = 6673,
        duration = 3600,
        max_stack = 1,
    },
    commanding_shout = {
        id = 469,
        duration = 3600,
        max_stack = 1,
    },
    colossus_smash = {
        id = 86346,
        duration = 6,
        max_stack = 1,
    },
    raging_blow = {
        id = 131116,
        duration = 12,
        max_stack = 2,
    },
    enrage = {
        id = 12880,
        duration = function() return glyph.unending_rage.enabled and 8 or 6 end,
        max_stack = 1,
    },
    berserker_rage = {
        id = 18499,
        duration = function() return glyph.unending_rage.enabled and 8 or 6 end,
        max_stack = 1,
    },
    meat_cleaver = {
        id = 85739,
        duration = 10,
        max_stack = 3,
    },
    bloodsurge = {
        id = 46916,
        duration = 10,
        max_stack = 1,
    },
    
    -- Talent-specific buffs/debuffs
    avatar = {
        id = 107574,
        duration = 24,
        max_stack = 1,
    },
    bladestorm = {
        id = 46924,
        duration = 6,
        max_stack = 1,
    },
    bloodbath = {
        id = 12292,
        duration = 12,
        max_stack = 1,
    },
    bloodbath_dot = {
        id = 113344,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
    },
    dragon_roar = {
        id = 118000,
        duration = 4,
        max_stack = 1,
    },
    second_wind = {
        id = 29838,
        duration = 3600,
        max_stack = 1,
    },
    vigilance = {
        id = 114030,
        duration = 12,
        max_stack = 1,
    },
    
    -- Defensives
    die_by_the_sword = {
        id = 118038,
        duration = function() return glyph.die_by_the_sword.enabled and 4 or 8 end,
        max_stack = 1,
    },
    shield_wall = {
        id = 871,
        duration = 12,
        max_stack = 1,
    },
    spell_reflection = {
        id = 23920,
        duration = function() return glyph.spell_reflection.enabled and 4 or 5 end,
        max_stack = 1,
    },
    mass_spell_reflection = {
        id = 114028,
        duration = 5,
        max_stack = 1,
    },
    enraged_regeneration = {
        id = 55694,
        duration = 5,
        tick_time = 1,
        max_stack = 1,
    },
    
    -- Crowd control / utility
    hamstring = {
        id = 1715,
        duration = 15,
        max_stack = 1,
    },
    piercing_howl = {
        id = 12323,
        duration = 15,
        max_stack = 1,
    },
    staggering_shout = {
        id = 107566,
        duration = 15,
        max_stack = 1,
    },
    shockwave = {
        id = 46968,
        duration = 4,
        max_stack = 1,
    },
    storm_bolt = {
        id = 107570,
        duration = 3,
        max_stack = 1,
    },
    war_banner = {
        id = 114207,
        duration = 15,
        max_stack = 1,
    },
    rallying_cry = {
        id = 97462,
        duration = 10,
        max_stack = 1,
    },
    demoralizing_shout = {
        id = 1160,
        duration = 10,
        max_stack = 1,
    },
    disrupting_shout = {
        id = 102060,
        duration = 4,
        max_stack = 1,
    },
    intimidating_shout = {
        id = 5246,
        duration = 8,
        max_stack = 1,
    },
    charge_root = {
        id = 105771,
        duration = function() 
            if talent.warbringer.enabled then
                return 4
            elseif glyph.bull_rush.enabled then
                return 1
            end
            return 0
        end,
        max_stack = 1,
    },
} )

-- Fury Warrior abilities
spec:RegisterAbilities( {
    -- Core rotational abilities
    bloodthirst = {
        id = 23881,
        cast = 0,
        cooldown = 3,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 136012,
        
        handler = function()
            -- 20% chance to trigger Enrage
            if math.random() < 0.2 then
                applyBuff( "enrage" )
                if raging_blow.stack < 2 then
                    addStack( "raging_blow" )
                end
            end
            
            -- 30% chance to trigger Bloodsurge
            if math.random() < 0.3 then
                applyBuff( "bloodsurge" )
            end
            
            -- Restore 1% of max health
            local heal_amount = health.max * 0.01
            gain( heal_amount, "health" )
            
            -- Glyph of Bloodthirst
            if glyph.bloodthirst.enabled and buff.taste_for_blood.up then
                -- Refresh Taste for Blood
                buff.taste_for_blood.expires = query_time + 10
            end
        end,
    },
    
    raging_blow = {
        id = 85288,
        cast = 0,
        cooldown = function() return glyph.raging_blow.enabled and 3 or 8 end,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 589119,
        
        usable = function()
            return buff.raging_blow.stack > 0, "requires raging_blow buff"
        end,
        
        handler = function()
            if buff.raging_blow.stack > 1 then
                removeStack( "raging_blow" )
            else
                removeBuff( "raging_blow" )
            end
            
            -- Glyph of Raging Wind
            if glyph.raging_wind.enabled and debuff.colossus_smash.up then
                removeDebuff( "target", "colossus_smash" )
            end
        end,
    },
    
    colossus_smash = {
        id = 86346,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 464973,
        
        handler = function()
            applyDebuff( "target", "colossus_smash" )
            if glyph.colossus_smash.enabled then
                applyBuff( "enrage" )
            end
        end,
    },
    
    execute = {
        id = 5308,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            -- Minimum 10 rage plus additional rage up to 30
            return 10
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 135358,
        
        usable = function()
            return target.health_pct < 20, "requires target below 20% health"
        end,
        
        handler = function()
            -- No specific effect for Execute
        end,
    },
    
    wild_strike = {
        id = 100130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if buff.bloodsurge.up then return 0 end
            if glyph.wild_strike.enabled then return 40 end
            return 45 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 589617,
        
        handler = function()
            removeBuff( "bloodsurge" )
        end,
    },
    
    whirlwind = {
        id = 1680,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132369,
        
        handler = function()
            -- Apply Meat Cleaver
            if not buff.meat_cleaver.up then
                applyBuff( "meat_cleaver" )
                buff.meat_cleaver.stack = 1
            else
                addStack( "meat_cleaver", nil, 1 )
            end
        end,
    },
    
    cleave = {
        id = 845,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 20,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132338,
        
        handler = function()
            -- No specific effect for Cleave
        end,
    },
    
    -- Defensive / utility
    battle_shout = {
        id = 6673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132333,
        
        handler = function()
            applyBuff( "battle_shout" )
        end,
    },
    
    commanding_shout = {
        id = 469,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132351,
        
        handler = function()
            applyBuff( "commanding_shout" )
        end,
    },
    
    charge = {
        id = 100,
        cast = 0,
        cooldown = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 20 
        end,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = 20,
        gcd = "off",
        
        spend = function()
            if talent.juggernaut.enabled then return -15 end
            return 0
        end,
        spendType = "rage",
        
        range = function() 
            if glyph.long_charge.enabled then
                return 30
            end
            return 25 
        end,
        
        startsCombat = true,
        texture = 132337,
        
        handler = function()
            if talent.warbringer.enabled or glyph.bull_rush.enabled then
                applyDebuff( "target", "charge_root" )
            end
        end,
    },
    
    hamstring = {
        id = 1715,
        cast = 0,
        cooldown = 0,
        gcd = function() return glyph.hamstring.enabled and 0.5 or 1.5 end,
        
        spend = function() 
            if talent.warbringer.enabled then return 5 end
            return 10 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132316,
        
        handler = function()
            applyDebuff( "target", "hamstring" )
        end,
    },
    
    berserker_rage = {
        id = 18499,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 136009,
        
        handler = function()
            applyBuff( "berserker_rage" )
            if raging_blow.stack < 2 then
                addStack( "raging_blow" )
            end
        end,
    },
    
    heroic_leap = {
        id = 6544,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 236171,
        
        handler = function()
            -- No specific effect, just the leap
        end,
    },
    
    rallying_cry = {
        id = 97462,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132351,
        
        handler = function()
            applyBuff( "rallying_cry" )
        end,
    },
    
    die_by_the_sword = {
        id = 118038,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132336,
        
        handler = function()
            applyBuff( "die_by_the_sword" )
        end,
    },
    
    intervene = {
        id = 3411,
        cast = 0,
        cooldown = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 30 
        end,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 30 
        end,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        range = function() 
            if glyph.long_charge.enabled then
                return 30
            end
            return 25 
        end,
        
        startsCombat = false,
        texture = 132365,
        
        handler = function()
            if talent.safeguard.enabled then
                -- Apply damage reduction to the target (handled by the game)
            end
        end,
    },
    
    -- Talent abilities
    avatar = {
        id = 107574,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 613534,
        
        handler = function()
            applyBuff( "avatar" )
        end,
    },
    
    bloodbath = {
        id = 12292,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236304,
        
        handler = function()
            applyBuff( "bloodbath" )
        end,
    },
    
    bladestorm = {
        id = 46924,
        cast = 0,
        cooldown = function() return glyph.bladestorm.enabled and 75 or 90 end,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236303,
        
        handler = function()
            applyBuff( "bladestorm" )
        end,
    },
    
    dragon_roar = {
        id = 118000,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 642418,
        
        handler = function()
            applyDebuff( "target", "dragon_roar" )
        end,
    },
    
    shockwave = {
        id = 46968,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = function() 
            if glyph.burning_anger.enabled then return 20 end
            return 0 
        end,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236312,
        
        handler = function()
            applyDebuff( "target", "shockwave" )
        end,
    },
    
    storm_bolt = {
        id = 107570,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 613535,
        
        handler = function()
            applyDebuff( "target", "storm_bolt" )
        end,
    },
    
    vigilance = {
        id = 114030,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236331,
        
        handler = function()
            applyBuff( "vigilance" )
        end,
    },
    
    impending_victory = {
        id = 103840,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 10,
        spendType = "rage",
        
        startsCombat = true,
        texture = 589768,
        
        handler = function()
            local heal_amount = health.max * (glyph.bloody_healing.enabled and 0.2 or 0.1)
            gain( heal_amount, "health" )
        end,
    },
    
    staggering_shout = {
        id = 107566,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132346,
        
        handler = function()
            applyDebuff( "target", "staggering_shout" )
        end,
    },
    
    piercing_howl = {
        id = 12323,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132117,
        
        handler = function()
            applyDebuff( "target", "piercing_howl" )
        end,
    },
    
    disrupting_shout = {
        id = 102060,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "interrupts",
        
        startsCombat = true,
        texture = 132117,
        
        handler = function()
            applyDebuff( "target", "disrupting_shout" )
        end,
    },
    
    enraged_regeneration = {
        id = 55694,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132345,
        
        handler = function()
            local instant_heal = health.max * 0.1
            gain( instant_heal, "health" )
            applyBuff( "enraged_regeneration" )
        end,
    },
    
    spell_reflection = {
        id = 23920,
        cast = 0,
        cooldown = function() return glyph.spell_reflection.enabled and 20 or 25 end,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132361,
        
        handler = function()
            applyBuff( "spell_reflection" )
        end,
    },
    
    mass_spell_reflection = {
        id = 114028,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132361,
        
        handler = function()
            applyBuff( "mass_spell_reflection" )
        end,
    },
    
    war_banner = {
        id = 114207,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 603532,
        
        handler = function()
            applyBuff( "war_banner" )
        end,
    },
    
    thunder_clap = {
        id = 6343,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = function() 
            if glyph.burning_anger.enabled then return 20 end
            return 0 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 136105,
        
        handler = function()
            -- Apply debuff
        end,
    },
    
    intimidating_shout = {
        id = 5246,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132154,
        
        handler = function()
            applyDebuff( "target", "intimidating_shout" )
        end,
    },
    
    demoralizing_shout = {
        id = 1160,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132366,
        
        handler = function()
            applyDebuff( "target", "demoralizing_shout" )
        end,
    },
} )

-- Range
spec:RegisterRanges( "bloodthirst", "charge", "heroic_throw" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "golemblood",
    
    package = "Fury",
} )

-- Default pack for MoP Fury Warrior
spec:RegisterPack( "Fury", 20250515, [[Hekili:TznBVTTnu4FlXjHjMjENnWUYJaUcMLf8KvAm7nYjPPQonGwX2jzlkiuQumzkaLRQiQOeH9an1Y0YnpYoWgwlYFltwGtRJ(aiCN9tobHNVH)8TCgF)(5ElyJlFNlcDnPXD5A8j0)(MNZajDa3aNjp2QphnPtoKvyF)GcKKOzjI08QjnOVOCXMj3nE)waT58Pw(aFm0P)MM]] )

-- Register pack selector for Fury
spec:RegisterPackSelector( "fury", "Fury", "|T132347:0|t Fury",
    "Handles all aspects of Fury Warrior DPS with focus on dual-wielding and Blood Thirst usage.",
    nil )
