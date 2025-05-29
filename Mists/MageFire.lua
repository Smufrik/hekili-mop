-- MageFire.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Mage: Fire spec

if UnitClassBase( 'player' ) ~= 'MAGE' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 63 ) -- Fire spec ID for MoP

local strformat = string.format
local FindUnitBuffByID = ns.FindUnitBuffByID
local FindUnitDebuffByID = ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )

-- Tier sets
spec:RegisterGear( "tier14", 85370, 85371, 85372, 85373, 85369 ) -- T14 Malevolent Gladiator's Silk
spec:RegisterGear( "tier15", 95893, 95894, 95895, 95897, 95892 ) -- T15 Kirin Tor Garb

-- Talents (MoP 6-tier system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility/Instant Cast
    presence_of_mind      = { 101380, 1, 12043 }, -- Your next 3 spells are instant cast
    blazing_speed         = { 101384, 1, 108843 }, -- Increases movement speed by 150% for 1.5 sec after taking damage
    ice_floes             = { 101386, 1, 108839 }, -- Allows you to cast 3 spells while moving

    -- Tier 2 (Level 30) - Survivability
    flameglow             = { 101388, 1, 140468 }, -- Reduces spell damage taken by a fixed amount
    ice_barrier           = { 101397, 1, 11426 }, -- Absorbs damage for 1 min
    temporal_shield       = { 101389, 1, 115610 }, -- 100% of damage taken is healed back over 6 sec

    -- Tier 3 (Level 45) - Control
    ring_of_frost         = { 101391, 1, 113724 }, -- Incapacitates enemies entering the ring
    ice_ward              = { 101392, 1, 111264 }, -- Frost Nova gains 2 charges
    frostjaw              = { 101393, 1, 102051 }, -- Silences and freezes target

    -- Tier 4 (Level 60) - Utility
    greater_invisibility  = { 101394, 1, 110959 }, -- Invisible for 20 sec, 90% damage reduction when visible
    cold_snap             = { 101396, 1, 11958 }, -- Finishes cooldown on Frost spells, heals 25%
    cauterize             = { 101398, 1, 86949 }, -- Fatal damage brings you to 35% health

    -- Tier 5 (Level 75) - DoT/Bomb Spells
    nether_tempest        = { 101400, 1, 114923 }, -- Arcane DoT that spreads
    living_bomb           = { 101401, 1, 44457 }, -- Fire DoT that explodes
    frost_bomb            = { 101402, 1, 112948 }, -- Frost bomb with delayed explosion

    -- Tier 6 (Level 90) - Power/Mana Management
    invocation            = { 101403, 1, 114003 }, -- Evocation increases damage by 25%
    rune_of_power         = { 101404, 1, 116011 }, -- Ground rune increases spell damage by 15%
    incanter_s_ward       = { 101405, 1, 1463 }, -- Converts 30% damage taken to mana
} )

-- Tier Sets
spec:RegisterGear( 13, 8, { -- Tier 14
    { 86886, head = 86701, shoulder = 86702, chest = 86699, hands = 86700, legs = 86703 }, -- LFR
    { 87139, head = 85370, shoulder = 85372, chest = 85373, hands = 85371, legs = 85369 }, -- Normal
    { 87133, head = 87105, shoulder = 87107, chest = 87108, hands = 87106, legs = 87104 }, -- Heroic
} )

spec:RegisterGear( 14, 8, { -- Tier 15
    { 95890, head = 95308, shoulder = 95310, chest = 95306, hands = 95307, legs = 95309 }, -- LFR
    { 95891, head = 95893, shoulder = 95895, chest = 95897, hands = 95894, legs = 95892 }, -- Normal
    { 95892, head = 96633, shoulder = 96631, chest = 96629, hands = 96632, legs = 96630 }, -- Heroic
} )

-- Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [104035] = "Glyph of Arcane Explosion",
    [104036] = "Glyph of Arcane Power",
    [104037] = "Glyph of Armors",
    [104038] = "Glyph of Blink",
    [104039] = "Glyph of Combustion",
    [104040] = "Glyph of Cone of Cold",
    [104041] = "Glyph of Dragon's Breath",
    [104042] = "Glyph of Evocation",
    [104043] = "Glyph of Frost Armor",
    [104044] = "Glyph of Frost Nova",
    [104045] = "Glyph of Frostbolt",
    [104046] = "Glyph of Frostfire",
    [104047] = "Glyph of Frostfire Bolt",
    [104048] = "Glyph of Ice Block",
    [104049] = "Glyph of Ice Lance",
    [104050] = "Glyph of Icy Veins",
    [104051] = "Glyph of Inferno Blast",
    [104052] = "Glyph of Invisibility",
    [104053] = "Glyph of Mage Armor",
    [104054] = "Glyph of Mana Gem",
    [104055] = "Glyph of Mirror Image",
    [104056] = "Glyph of Polymorph",
    [104057] = "Glyph of Remove Curse",
    [104058] = "Glyph of Slow Fall",
    [104059] = "Glyph of Spellsteal",
    [104060] = "Glyph of Water Elemental",
    -- Minor Glyphs
    [104061] = "Glyph of Illusion",
    [104062] = "Glyph of Momentum",
    [104063] = "Glyph of the Bear Cub",
    [104064] = "Glyph of the Monkey",
    [104065] = "Glyph of the Penquin",
    [104066] = "Glyph of the Porcupine",
} )

-- Auras
spec:RegisterAuras( {
    -- Fire-specific Auras
    combustion = {
        id = 11129,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 11129 )
            
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
    
    critical_mass = {
        id = 117216,
        duration = 3600,
        max_stack = 1
    },
    
    heating_up = {
        id = 48107,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48107 )
            
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
    
    hot_streak = {
        id = 48108,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48108 )
            
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
    
    pyroblast = {
        id = 11366,
        duration = 18,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 11366, "PLAYER" )
            
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
    
    pyroblast_clearcasting = {
        id = 48108,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48108 )
            
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
    
    living_bomb = {
        id = 44457,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 44457, "PLAYER" )
            
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
    
    -- Shared Mage Auras
    arcane_brilliance = {
        id = 1459,
        duration = 3600,
        max_stack = 1
    },
    
    alter_time = {
        id = 110909,
        duration = 6,
        max_stack = 1
    },
    
    blink = {
        id = 1953,
        duration = 0.3,
        max_stack = 1
    },
    
    polymorph = {
        id = 118,
        duration = 60,
        max_stack = 1
    },
    
    counterspell = {
        id = 2139,
        duration = 6,
        max_stack = 1
    },
    
    frost_nova = {
        id = 122,
        duration = 8,
        max_stack = 1
    },
    
    frostjaw = {
        id = 102051,
        duration = 8,
        max_stack = 1
    },
    
    ice_block = {
        id = 45438,
        duration = 10,
        max_stack = 1
    },
    
    ice_barrier = {
        id = 11426,
        duration = 60,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 11426 )
            
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
    
    incanter_s_ward = {
        id = 1463,
        duration = 15,
        max_stack = 1
    },
    
    invocation = {
        id = 114003,
        duration = 40,
        max_stack = 1
    },
    
    slow = {
        id = 31589,
        duration = 15,
        max_stack = 1
    },
    
    slow_fall = {
        id = 130,
        duration = 30,
        max_stack = 1
    },
    
    time_warp = {
        id = 80353,
        duration = 40,
        max_stack = 1
    },
    
    presence_of_mind = {
        id = 12043,
        duration = 10,
        max_stack = 1
    },
    
    ring_of_frost = {
        id = 113724,
        duration = 10,
        max_stack = 1
    },
    
    -- Armor Auras
    frost_armor = {
        id = 7302,
        duration = 1800,
        max_stack = 1
    },
    
    mage_armor = {
        id = 6117,
        duration = 1800,
        max_stack = 1
    },
    
    molten_armor = {
        id = 30482,
        duration = 1800,
        max_stack = 1
    },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Fire Core Abilities
    fireball = {
        id = 133,
        cast = 2.25,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135812,
        
        handler = function()
            -- Chance to proc Heating Up or convert to Hot Streak
            -- Use simulation rather than trying to model RNG here
        end,
    },
    
    inferno_blast = {
        id = 108853,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135813,
          handler = function()
            -- Guaranteed crit
            -- Proc Hot Streak on Heating Up
            if buff.heating_up.up then
                removeBuff( "heating_up" )
                applyBuff( "hot_streak" ) -- Correct MoP mechanic
            end
        end,
    },
      pyroblast = {
        id = 11366,
        cast = function() return buff.hot_streak.up and 0 or 4.5 end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135808,
        
        handler = function()
            if buff.hot_streak.up then
                removeBuff( "hot_streak" )
            end
            applyDebuff( "target", "pyroblast" )
        end,
    },
    
    combustion = {
        id = 11129,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 135824,
        
        handler = function()
            applyBuff( "combustion" )
        end,
    },
    
    dragons_breath = {
        id = 31661,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = true,
        texture = 134153,
        
        handler = function()
            applyDebuff( "target", "dragons_breath" )
        end,
    },
    
    blast_wave = {
        id = 11113,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135903,
        
        handler = function()
            applyDebuff( "target", "blast_wave" )
        end,
    },
    
    scorch = {
        id = 2948,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135827,
        
        handler = function()
            -- Similar to Fireball, can proc Heating Up / Hot Streak
        end,
    },
    
    living_bomb = {
        id = 44457,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 236220,
        
        talent = "living_bomb",
        
        handler = function()
            applyDebuff( "target", "living_bomb" )
        end,
    },
    
    flamestrike = {
        id = 2120,
        cast = 2,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.035,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135826,
        
        handler = function()
            -- Apply Flamestrike DoT
        end,
    },
    
    -- Shared Mage Abilities
    arcane_brilliance = {
        id = 1459,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135932,
        
        handler = function()
            applyBuff( "arcane_brilliance" )
        end,
    },
    
    alter_time = {
        id = 108978,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 607849,
        
        handler = function()
            applyBuff( "alter_time" )
        end,
    },
    
    blink = {
        id = 1953,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135736,
        
        handler = function()
            applyBuff( "blink" )
        end,
    },
    
    cone_of_cold = {
        id = 120,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135852,
        
        handler = function()
            applyDebuff( "target", "cone_of_cold" )
        end,
    },
    
    conjure_mana_gem = {
        id = 759,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 134132,
        
        handler = function()
            -- Creates a Mana Gem
        end,
    },
    
    counterspell = {
        id = 2139,
        cast = 0,
        cooldown = 24,
        gcd = "off",
        
        interrupt = true,
        
        startsCombat = true,
        texture = 135856,
        
        toggle = "interrupts",
        
        usable = function() return target.casting end,
        
        handler = function()
            interrupt()
            applyDebuff( "target", "counterspell" )
        end,
    },
    
    evocation = {
        id = 12051,
        cast = 6,
        cooldown = 120,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136075,
        
        talent = function() return not talent.rune_of_power.enabled end,
        
        handler = function()
            -- Restore 60% mana over 6 sec
            gain( 0.6 * mana.max, "mana" )
            
            if talent.invocation.enabled then
                applyBuff( "invocation" )
            end
        end,
    },
    
    frost_nova = {
        id = 122,
        cast = 0,
        cooldown = function() return talent.ice_ward.enabled and 20 or 30 end,
        charges = function() return talent.ice_ward.enabled and 2 or nil end,
        recharge = function() return talent.ice_ward.enabled and 20 or nil end,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135848,
        
        handler = function()
            applyDebuff( "target", "frost_nova" )
        end,
    },
    
    frostjaw = {
        id = 102051,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607853,
        
        talent = "frostjaw",
        
        handler = function()
            applyDebuff( "target", "frostjaw" )
        end,
    },
    
    ice_barrier = {
        id = 11426,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135988,
        
        talent = "ice_barrier",
        
        handler = function()
            applyBuff( "ice_barrier" )
        end,
    },
    
    ice_block = {
        id = 45438,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 135841,
        
        handler = function()
            applyBuff( "ice_block" )
            setCooldown( "hypothermia", 30 )
        end,
    },
    
    ice_floes = {
        id = 108839,
        cast = 0,
        cooldown = 45,
        charges = 3,
        recharge = 45,
        gcd = "off",
        
        startsCombat = false,
        texture = 610877,
        
        talent = "ice_floes",
        
        handler = function()
            applyBuff( "ice_floes" )
        end,
    },
    
    incanter_s_ward = {
        id = 1463,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        startsCombat = false,
        texture = 250986,
        
        talent = "incanter_s_ward",
        
        handler = function()
            applyBuff( "incanter_s_ward" )
        end,
    },
    
    invisibility = {
        id = 66,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132220,
        
        handler = function()
            applyBuff( "invisibility" )
        end,
    },
    
    greater_invisibility = {
        id = 110959,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 606086,
        
        talent = "greater_invisibility",
        
        handler = function()
            applyBuff( "greater_invisibility" )
        end,
    },
    
    presence_of_mind = {
        id = 12043,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136031,
        
        talent = "presence_of_mind",
        
        handler = function()
            applyBuff( "presence_of_mind" )
        end,
    },
    
    ring_of_frost = {
        id = 113724,
        cast = 1.5,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = false,
        texture = 464484,
        
        talent = "ring_of_frost",
        
        handler = function()
            -- Places Ring of Frost at target location
        end,
    },
    
    rune_of_power = {
        id = 116011,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 609815,
        
        talent = "rune_of_power",
        
        handler = function()
            -- Places Rune of Power on the ground
        end,
    },
    
    slow = {
        id = 31589,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136091,
        
        handler = function()
            applyDebuff( "target", "slow" )
        end,
    },
    
    slow_fall = {
        id = 130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135992,
        
        handler = function()
            applyBuff( "slow_fall" )
        end,
    },
    
    spellsteal = {
        id = 30449,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135729,
        
        handler = function()
            -- Attempt to steal a buff from the target
        end,
    },
    
    time_warp = {
        id = 80353,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 458224,
        
        handler = function()
            applyBuff( "time_warp" )
            applyDebuff( "player", "temporal_displacement" )
        end,
    },
    
    -- Armor Spells
    frost_armor = {
        id = 7302,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135843,
        
        handler = function()
            removeBuff( "mage_armor" )
            removeBuff( "molten_armor" )
            applyBuff( "frost_armor" )
        end,
    },
    
    mage_armor = {
        id = 6117,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135991,
        
        handler = function()
            removeBuff( "frost_armor" )
            removeBuff( "molten_armor" )
            applyBuff( "mage_armor" )
        end,
    },
    
    molten_armor = {
        id = 30482,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132221,
        
        handler = function()
            removeBuff( "frost_armor" )
            removeBuff( "mage_armor" )
            applyBuff( "molten_armor" )
        end,
    },
} )

-- State Functions and Expressions
spec:RegisterStateExpr( "hot_streak", function()
    return buff.pyroblast_clearcasting.up
end )

-- Range
spec:RegisterRanges( "fireball", "polymorph", "blink" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 40,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent_potion",
    
    package = "Fire",
} )

-- Register default pack for MoP Fire Mage
spec:RegisterPack( "Fire", 20250517, [[Hekili:TzvBVTTn04FldjH0cbvgL62TG4I3KRlvnTlSynuRiknIWGQ1W2jzlkitIhLmzImzkKSqu6Mi02Y0YbpYoWoz9ogRWEJOJTFYl(S3rmZXRwKSWNrx53Ntta5(S3)8dyNF3BhER85x(jym5nymTYnv0drHbpz5IW1vZgbo1P)MM]] )

-- Register pack selector for Fire
spec:RegisterPackSelector( "fire", "Fire", "|T135810:0|t Fire",
    "Handles all aspects of Fire Mage rotation with focus on Hot Streak procs and critical strike chance.",
    nil )
