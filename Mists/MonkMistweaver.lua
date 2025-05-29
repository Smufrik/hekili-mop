-- MonkMistweaver.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Monk: Mistweaver spec

if UnitClassBase( 'player' ) ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 270 ) -- Mistweaver spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

spec:RegisterResource( Enum.PowerType.Mana )
spec:RegisterResource( Enum.PowerType.Chi )
spec:RegisterResource( Enum.PowerType.Energy, {
    stance = {
        ["stance:2"] = 0.5, -- Serpent Stance energy regen multiplier
    }
} )

-- Tier sets
spec:RegisterGear( "tier14", 85393, 85394, 85395, 85396, 85397 ) -- T14 Mistweaver Set
spec:RegisterGear( "tier15", 95825, 95826, 95827, 95828, 95829 ) -- T15 Mistweaver Set

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    celerity                  = { 2645, 1, 115173 }, -- Reduces Roll cooldown by 5 sec, adds 1 charge
    tigers_lust               = { 2646, 1, 116841 }, -- Increases ally movement speed by 70% for 6 sec
    momentum                  = { 2647, 1, 115294 }, -- Rolling increases movement speed by 25% for 10 sec
    
    -- Tier 2 (Level 30) - Healing
    chi_wave                  = { 2648, 1, 115098 }, -- Chi energy bounces between friends and foes
    zen_sphere                = { 2649, 1, 124081 }, -- Healing sphere around target, explodes on expire
    chi_burst                 = { 2650, 1, 123986 }, -- Chi torrent damages enemies, heals allies
    
    -- Tier 3 (Level 45) - Resource
    power_strikes             = { 2651, 1, 121817 }, -- Every 20 sec, Tiger Palm grants 1 additional Chi
    ascension                 = { 2652, 1, 115396 }, -- +1 max Chi, +15% Energy regeneration
    chi_brew                  = { 2653, 1, 115399 }, -- Restores 2 Chi, 45 sec cooldown
    
    -- Tier 4 (Level 60) - Control
    deadly_reach              = { 2654, 1, 126679 }, -- Increases Paralysis range by 10 yds
    charging_ox_wave          = { 2655, 1, 119392 }, -- Ox wave stuns enemies for 3 sec
    leg_sweep                 = { 2656, 1, 119381 }, -- Stuns nearby enemies for 5 sec
    
    -- Tier 5 (Level 75) - Defense    healing_elixirs           = { 2657, 1, 122280 }, -- Potions heal for +10% max health
    dampen_harm               = { 2658, 1, 122278 }, -- Reduces next 3 large attacks by 50%
    diffuse_magic             = { 2659, 1, 122783 }, -- Transfers debuffs, 90% magic damage reduction
    
    -- Tier 6 (Level 90) - Ultimate
    rushing_jade_wind         = { 2660, 1, 116847 }, -- Whirling tornado damages nearby enemies
    invoke_xuen               = { 2661, 1, 123904 }, -- Summons White Tiger Xuen for 45 sec
    chi_torpedo               = { 2662, 1, 119085 }  -- Torpedo forward, +30% movement speed
} )

-- Glyphs (MoP system)
spec:RegisterGlyphs( {
    [125731] = "afterlife",
    [125732] = "detox",
    [125757] = "enduring_healing_sphere",
    [125671] = "expel_harm",
    [125676] = "fortifying_brew",
    [123763] = "mana_tea",
    [125767] = "paralysis",
    [125755] = "retreat",
    [125678] = "spinning_crane_kick",
    [125750] = "surging_mist",
    [125932] = "targeted_expulsion",
    [125679] = "touch_of_death",
    [125680] = "transcendence",
    [125681] = "zen_meditation",
    [146950] = "renewing_mist",
} )

-- Statuses for Mistweaver
spec:RegisterStateTable( "healing_spheres", setmetatable({}, {
    __index = function( t, k )
        if k == "count" then
            -- In MoP, we would have to check for healing spheres on the ground
            -- This is a simplification
            return 0
        end
        return 0
    end,
}))

-- Mistweaver specific auras
spec:RegisterAuras( {
    -- Serpent Stance (automatically gained for Mistweavers)
    stance_of_the_wise_serpent = {
        id = 115070,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115070 )
            
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
    
    -- Mana Tea: Restores 4% of maximum mana per stack
    mana_tea = {
        id = 115867,
        duration = 30,
        max_stack = 20,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115867 )
            
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
    
    -- Jade Mist: Healing mist jumps to nearby targets
    jade_mist = {
        id = 115151,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115151 )
            
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
    
    -- Renewing Mist: HoT that also jumps to new targets
    renewing_mist = {
        id = 119611,
        duration = 18,
        tick_time = 2,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 119611, "PLAYER" )
            
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
    
    -- Soothing Mist: Channeled healing
    soothing_mist = {
        id = 115175,
        duration = 8,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 115175, "PLAYER" )
            
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
    
    -- Thunder Focus Tea: Enhances your next Surging Mist or Uplift
    thunder_focus_tea = {
        id = 116680,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116680 )
            
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
    
    -- Life Cocoon: Absorbs damage and increases healing received
    life_cocoon = {
        id = 116849,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 116849, "PLAYER" )
            
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
    
    -- Enveloping Mist: Increases healing received from Soothing Mist
    enveloping_mist = {
        id = 124682,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 124682, "PLAYER" )
            
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
    
    -- Uplift: AoE heal for all targets with Renewing Mist
    uplift = {
        id = 116670,
        duration = 1,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116670 )
            
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
    
    -- Teachings of the Monastery: Modifies Tiger Palm, Blackout Kick, and Jab
    teachings_of_the_monastery = {
        id = 116645,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116645 )
            
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
    
    -- Serpent's Zeal - Gained from Blackout Kick in Serpent Stance
    serpents_zeal = {
        id = 127722,
        duration = 20,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 127722 )
            
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
    
    -- Vital Mists - Stacks from Jab, consumed by Surging Mist
    vital_mists = {
        id = 118674,
        duration = 30,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118674 )
            
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
    
    -- Muscle Memory - Gained from Tiger Palm in Serpent Stance
    muscle_memory = {
        id = 118864,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118864 )
            
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
    
    -- Mastery: Gift of the Serpent
    gift_of_the_serpent = {
        id = 117907,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 117907 )
            
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
    
    -- Zen Focus: Reduces mana cost while channeling Soothing Mist
    zen_focus = {
        id = 124416,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124416 )
            
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
    
    -- Path of Blossoms from Chi Torpedo
    path_of_blossoms = {
        id = 121027,
        duration = 10,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 121027 )
            
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
    
    -- Momentum from talent
    momentum = {
        id = 119085,
        duration = 10,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 119085 )
            
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
    
    -- Paralysis
    paralysis = {
        id = 115078,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115078, "PLAYER" )
            
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

-- Monk shared abilities and Mistweaver abilities
spec:RegisterAbilities( {
    -- Core Mistweaver Abilities
    enveloping_mist = {
        id = 124682,
        cast = function()
            if buff.soothing_mist.up then return 0 end
            return 2
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 3,
        spendType = "chi",
        
        startsCombat = false,
        texture = 775461,
        
        handler = function()
            applyBuff("enveloping_mist", "target")
        end,
    },
    
    life_cocoon = {
        id = 116849,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "defensives", 
        
        startsCombat = false,
        texture = 627485,
        
        handler = function()
            applyBuff("life_cocoon", "target")
        end,
    },
    
    mana_tea = {
        id = 123761,
        cast = function() return glyph.mana_tea.enabled and 0 or 0.5 end,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 608939,
        
        buff = "mana_tea",
        
        usable = function()
            return buff.mana_tea.stack > 0, "requires mana_tea stacks"
        end,
        
        handler = function()
            -- Consumption of stacks depends on channel duration
            -- In the simple case, consumes all stacks at once
            local stacks = buff.mana_tea.stack
            removeStack("mana_tea", stacks)
        end,
    },
    
    renewing_mist = {
        id = 119611,
        cast = 0,
        cooldown = 8,
        charges = 2,
        recharge = 8,
        gcd = "spell",
        
        spend = 1,
        spendType = "chi",
        
        startsCombat = false,
        texture = 627487,
        
        handler = function()
            applyBuff("renewing_mist", "target")
        end,
    },
    
    revival = {
        id = 115310,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 627483,
        
        handler = function()
            applyBuff("revival")
        end,
    },
    
    soothing_mist = {
        id = 115175,
        cast = 8,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 606550,
        
        channeled = true,
        
        handler = function()
            applyBuff("soothing_mist", "target")
        end,
    },
    
    surging_mist = {
        id = 116694,
        cast = function() 
            if buff.soothing_mist.up then return 0 end
            return 2
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.vital_mists.stack == 5 then return 0 end
            return 0.2 * (1 - 0.2 * buff.vital_mists.stack)
        end,
        spendType = "mana",
        
        startsCombat = false,
        texture = 606549,
        
        handler = function()
            if buff.vital_mists.stack == 5 then
                removeBuff("vital_mists")
            else
                removeStack("vital_mists", buff.vital_mists.stack)
            end
            
            if buff.thunder_focus_tea.up then
                removeBuff("thunder_focus_tea")
            end
        end,
    },
    
    thunder_focus_tea = {
        id = 116680,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        startsCombat = false,
        texture = 611418,
        
        handler = function()
            applyBuff("thunder_focus_tea")
        end,
    },
    
    uplift = {
        id = 116670,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 2,
        spendType = "chi",
        
        startsCombat = false,
        texture = 775466,
        
        handler = function()
            -- Heals all targets with Renewing Mist
            -- If Thunder Focus Tea is active, double the healing
            if buff.thunder_focus_tea.up then
                removeBuff("thunder_focus_tea")
            end
        end,
    },
    
    zen_sphere = {
        id = 124081,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "chi",
        
        talent = "zen_sphere",
        
        startsCombat = false,
        texture = 651728,
        
        handler = function()
            -- Places a healing sphere on target
            -- Maximum of one sphere at a time
        end,
    },
    
    -- Special Mistweaver abilities
    blackout_kick = {
        id = 100784,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 2,
        spendType = "chi",
        
        startsCombat = true,
        texture = 574575,
        
        handler = function()
            -- In Serpent Stance, generates Serpent's Zeal
            addStack("serpents_zeal", nil, 1)
        end,
    },
    
    detox = {
        id = 115450,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 460692,
        
        handler = function()
            -- Removes 1 Magic effect and 1 Poison/Disease effect
        end,
    },
    
    jab = {
        id = 100780,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        startsCombat = true,
        texture = 574573,
        
        handler = function()
            gain(1, "chi")
            
            -- In Serpent Stance, generates 1 stack of Vital Mists
            addStack("vital_mists", nil, 1)
            
            -- Power Strikes talent
            if talent.power_strikes.enabled and cooldown.power_strikes.remains == 0 then
                gain(1, "chi")
                setCooldown("power_strikes", 20)
            end
        end,
    },
    
    tiger_palm = {
        id = 100787,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "chi",
        
        startsCombat = true,
        texture = 606551,
        
        handler = function()
            -- In Serpent Stance, generates Muscle Memory for next Surging Mist
            applyBuff("muscle_memory")
        end,
    },
    
    -- Shared Monk Abilities
    chi_brew = {
        id = 115399,
        cast = 0,
        cooldown = 45,
        gcd = "off",
        
        talent = "chi_brew",
        
        startsCombat = false,
        texture = 647487,
        
        handler = function()
            gain(2, "chi")
        end,
    },
    
    chi_burst = {
        id = 123986,
        cast = 1,
        cooldown = 30,
        gcd = "spell",
        
        talent = "chi_burst",
        
        startsCombat = true,
        texture = 135734,
        
        handler = function()
            -- Does damage to enemies and healing to allies
        end,
    },
    
    chi_torpedo = {
        id = 115008,
        cast = 0,
        cooldown = 20,
        charges = 2,
        recharge = 20,
        gcd = "off",
        
        talent = "chi_torpedo",
        
        startsCombat = false,
        texture = 607849,
        
        handler = function()
            -- Moves you forward and increases movement speed
            applyBuff("path_of_blossoms")
        end,
    },
    
    chi_wave = {
        id = 115098,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        talent = "chi_wave",
        
        startsCombat = true,
        texture = 606541,
        
        handler = function()
            -- Does damage to enemies and healing to allies, bouncing between targets
        end,
    },
    
    dampen_harm = {
        id = 122278,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        talent = "dampen_harm",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 620827,
        
        handler = function()
            -- Reduces damage from the next 3 attacks
        end,
    },
    
    diffuse_magic = {
        id = 122783,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        talent = "diffuse_magic",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 612968,
        
        handler = function()
            -- Reduces magic damage and returns harmful effects to caster
        end,
    },
    
    expel_harm = {
        id = 115072,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 627485,
        
        handler = function()
            -- Healing to self and damage to nearby enemy
            gain(1, "chi")
        end,
    },
    
    fortifying_brew = {
        id = 115203,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 432106,
        
        handler = function()
            applyBuff("fortifying_brew")
        end,
    },
    
    invoke_xuen = {
        id = 123904,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        talent = "invoke_xuen",
        
        startsCombat = true,
        texture = 620832,
        
        handler = function()
            summonPet("xuen", 45)
        end,
    },
    
    leg_sweep = {
        id = 119381,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        talent = "leg_sweep",
        
        startsCombat = true,
        texture = 642414,
        
        handler = function()
            -- Stuns all nearby enemies
        end,
    },
    
    paralysis = {
        id = 115078,
        cast = 0,
        cooldown = function()
            -- Deadly Reach talent extends range but adds 15s to cooldown
            return talent.deadly_reach.enabled and 30 or 15
        end,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 629534,
        
        handler = function()
            applyDebuff("target", "paralysis")
        end,
    },
    
    roll = {
        id = 109132,
        cast = 0,
        cooldown = 20,
        charges = function() return talent.celerity.enabled and 3 or 2 end,
        recharge = function() return talent.celerity.enabled and 15 or 20 end,
        gcd = "off",
        
        startsCombat = false,
        texture = 574574,
        
        handler = function()
            -- Moves you forward quickly
            if talent.momentum.enabled then
                applyBuff("momentum")
            end
        end,
    },
    
    rushing_jade_wind = {
        id = 116847,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 1,
        spendType = "chi",
        
        talent = "rushing_jade_wind",
        
        startsCombat = true,
        texture = 606549,
        
        handler = function()
            -- Applies a whirling tornado around you
        end,
    },
    
    spear_hand_strike = {
        id = 116705,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        interrupt = true,
        
        startsCombat = true,
        texture = 608940,
        
        toggle = "interrupts",
        
        usable = function() return target.casting end,
        
        handler = function()
            interrupt()
        end,
    },
    
    spinning_crane_kick = {
        id = 101546,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.15,
        spendType = "mana",
        
        startsCombat = true,
        texture = 606544,
        
        handler = function()
            -- Does AoE damage around you
            if talent.power_strikes.enabled and cooldown.power_strikes.remains == 0 then
                gain(1, "chi")
                setCooldown("power_strikes", 20)
            end
        end,
    },
    
    tigers_lust = {
        id = 116841,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 1,
        spendType = "chi",
        
        talent = "tigers_lust",
        
        startsCombat = false,
        texture = 651727,
        
        handler = function()
            -- Increases movement speed of target
        end,
    },
    
    touch_of_death = {
        id = 115080,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 607853,
        
        usable = function() 
            if target.health_pct > 10 then return false end
            return true
        end,
        
        handler = function()
            -- Instantly kills enemy with less than 10% health or deals high damage to players
        end,
    },
    
    transcendence = {
        id = 101643,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        startsCombat = false,
        texture = 627608,
        
        handler = function()
            -- Creates a copy of yourself
        end,
    },
    
    transcendence_transfer = {
        id = 119996,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        startsCombat = false,
        texture = 627609,
        
        handler = function()
            -- Swaps places with your transcendence copy
        end,
    },
} )

-- Specific to Xuen
spec:RegisterPet( "xuen_the_white_tiger", 73967, "invoke_xuen", 45 )

-- State Expressions for Mistweaver
spec:RegisterStateExpr( "healing_sphere_count", function()
    return healing_spheres.count or 0
end )

spec:RegisterStateExpr( "vital_mists_stack", function()
    return buff.vital_mists.stack
end )

-- Range and Targeting
spec:RegisterRanges( "renewing_mist", "tiger_palm", "blackout_kick", "paralysis", "provoke", "crackling_jade_lightning" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "virmen_bite_potion",
    
    package = "Mistweaver",
} )

-- Register default pack for MoP Mistweaver Monk
spec:RegisterPack( "Mistweaver", 20250517, [[Hekili:v3vBVnTns4FthjJY5gC03WlKGSqLVA2qzDXDZfbgJt)g7oLK7pszKDQAXnr5JTOl3JNPh3KiBSWCPHEyI6DfWo7bU5WHuT09qSHGzrtbcnZ5YXXsxGBpXlpjDRBl(mGfKiLsf6n5PZpC8MO2)W7cIRPqn5rCRgk5wQxrpCXrRH72sOoHJUu1HPOujjrKxTdF2HZ5wNXLk(kC9OQTgDxXQgOuZkExxDxXQYEQnQrtcxPxuQFbTe1sGvzsgLo0n4U8zYkm55aZQm5u8sfLnkLl81hskEqrMzXlSE3tvY3MBbCvZli5lQnY3mMh)ENKvTMBJTkV8CsVMoOvHXLsH3aOkYUkj(5RZgGTxHnJ3B(j44FWr)lXH06W9GCbg)Z8VuCLo0hVZmEPsOUbRrz5G5jQo0rzt)8VbbYAM2jkz5Y1qkiG8NnQEzRq(4cYOb7UCOmrCkebZoVOkL9KM9B1JMDDVGnzrCVYgYbAXrxNv6kTyK)YKj4MaLO)5jZi)bKLSxlQMfVf4eN3Q)ycUhD3cV9eLc8Vu9TjAo69R)SyEz1p)rIJ93Dl2mOF0Qx4aCkqpj(KmcqcRfhT)]] )

-- Register pack selector for Mistweaver
spec:RegisterPackSelector( "mistweaver", "Mistweaver", "|T627487:0|t Mistweaver",
    "Handles all aspects of Mistweaver Monk healing rotation with focus on effective Chi usage.",
    nil )
