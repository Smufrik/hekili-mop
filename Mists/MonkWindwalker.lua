-- MonkWindwalker.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Monk: Windwalker spec

if UnitClassBase( 'player' ) ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 269 ) -- Windwalker spec ID for MoP

local strformat = string.format
local FindUnitBuffByID = ns.FindUnitBuffByID
local FindUnitDebuffByID = ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Energy )
spec:RegisterResource( Enum.PowerType.Chi )
spec:RegisterResource( Enum.PowerType.Mana )

-- Tier sets
spec:RegisterGear( "tier14", 85397, 85398, 85399, 85400, 85401 ) -- T14 Windwalker Set
spec:RegisterGear( "tier15", 95829, 95830, 95831, 95832, 95833 ) -- T15 Windwalker Set

-- Glyphs (MoP system)
spec:RegisterGlyphs( {
    [125731] = "afterlife",
    [125872] = "blackout_kick",
    [125671] = "breath_of_fire",
    [125732] = "detox",
    [125757] = "enduring_healing_sphere",
    [125672] = "expel_harm",
    [125676] = "fighting_pose",
    [125687] = "fortifying_brew",
    [125677] = "guard",
    [123763] = "mana_tea",
    [125767] = "paralysis",
    [125755] = "retreat",
    [125678] = "spinning_crane_kick",
    [125750] = "surging_mist",
    [125932] = "targeted_expulsion",
    [125679] = "touch_of_death",
    [125680] = "transcendence",
    [125681] = "zen_meditation",
} )

-- Talents (MoP 6-tier system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    celerity                  = { 2645, 1, 115173 }, -- Reduces Roll cooldown by 5 sec, +1 charge
    tigers_lust               = { 2646, 1, 116841 }, -- +70% movement speed for 6 sec, removes roots/snares
    momentum                  = { 2647, 1, 115294 }, -- Rolling increases movement speed by 25% for 10 sec

    -- Tier 2 (Level 30) - Healing
    chi_wave                  = { 2648, 1, 115098 }, -- Chi energy wave, bounces up to 7 times
    zen_sphere                = { 2649, 1, 124081 }, -- Healing sphere for 16 sec, explodes when consumed
    chi_burst                 = { 2650, 1, 123986 }, -- Chi torrent up to 40 yds, damages/heals in path

    -- Tier 3 (Level 45) - Resource
    power_strikes             = { 2651, 1, 121817 }, -- Every 20 sec, Tiger Palm grants +1 Chi
    ascension                 = { 2652, 1, 115396 }, -- +1 max Chi, +15% Energy regeneration
    chi_brew                  = { 2653, 1, 115399 }, -- Restores 2 Chi, 45 sec cooldown

    -- Tier 4 (Level 60) - Utility
    deadly_reach              = { 2654, 1, 126679 }, -- +10 yds range on Paralysis
    charging_ox_wave          = { 2655, 1, 119392 }, -- Ox wave stuns enemies for 3 sec
    leg_sweep                 = { 2656, 1, 119381 }, -- Knocks down nearby enemies for 5 sec

    -- Tier 5 (Level 75) - Survival
    healing_elixirs           = { 2657, 1, 122280 }, -- +10% max health when drinking potions
    dampen_harm               = { 2658, 1, 122278 }, -- Reduces damage of next 3 big attacks by 50%
    diffuse_magic             = { 2659, 1, 122783 }, -- Transfers harmful effects, 90% magic damage reduction

    -- Tier 6 (Level 90) - DPS
    rushing_jade_wind         = { 2660, 1, 116847 }, -- Whirling tornado for 6 sec
    invoke_xuen               = { 2661, 1, 123904 }, -- Summons White Tiger Xuen for 45 sec
    chi_torpedo               = { 2662, 1, 119085 }, -- Torpedo forward, +30% movement speed
} )

-- Windwalker specific auras
spec:RegisterAuras( {    -- Tiger Power debuff (MoP 5.1.0: 30% armor reduction, single application, no stacking)
    tiger_power = {
        id = 125359,
        duration = 20,  -- 20 seconds
        max_stack = 1,  -- Single application, no stacking (MoP 5.1.0 change)
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 125359, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
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
    
    -- Combo Breaker: Tiger Palm
    combo_breaker_tiger_palm = {
        id = 118864,
        duration = 15,
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
    
    -- Combo Breaker: Blackout Kick
    combo_breaker_blackout_kick = {
        id = 116768,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116768 )
            
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
      -- Rising Sun Kick debuff (MoP 5.3.0: 20% increased damage from monk abilities)
    rising_sun_kick = {
        id = 130320,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 130320, "PLAYER" )
            
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
    
    -- Energizing Brew buff
    energizing_brew = {
        id = 115288,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115288 )
            
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
    
    -- Tigereye Brew stacks
    tigereye_brew_stack = {
        id = 125195,
        duration = 120,
        max_stack = 20,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 125195 )
            
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
    
    -- Tigereye Brew buff
    tigereye_brew = {
        id = 116740,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116740 )
            
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
    
    -- Legacy of the White Tiger (group buff)
    legacy_of_the_white_tiger = {
        id = 116781,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116781 )
            
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
    
    -- Fists of Fury channel
    fists_of_fury = {
        id = 113656,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 113656 )
            
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
    
    -- Touch of Karma
    touch_of_karma = {
        id = 125174,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 125174 )
            
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
    
    -- Disable
    disable = {
        id = 116095,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 116095, "PLAYER" )
            
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
    
    -- Flying Serpent Kick
    flying_serpent_kick = {
        id = 123586,
        duration = 2,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 123586 )
            
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
      -- Mastery: Bottled Fury
    bottled_fury = {
        id = 115636,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Mortal Wounds debuff from Rising Sun Kick
    mortal_wounds = {
        id = 115804,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115804, "PLAYER" )
            
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
    
    -- Fists of Fury stun debuff
    fists_of_fury_stun = {
        id = 117418,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 117418, "PLAYER" )
            
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

-- Monk shared abilities and Windwalker abilities
spec:RegisterAbilities( {    -- Core Windwalker Abilities
    blackout_kick = {
        id = 100784,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return buff.combo_breaker_blackout_kick.up and 0 or 2 end,
        spendType = "chi",
        
        startsCombat = true,
        texture = 574575,
        
        -- WoW Sims verified: 7.12 damage multiplier, 2 Chi cost
        handler = function()
            if buff.combo_breaker_blackout_kick.up then
                removeBuff("combo_breaker_blackout_kick")
            end
            
            -- MoP Combat Conditioning: 20% extra damage over 4s if behind target
            -- or instant heal for 20% of damage if in front
        end,
    },
    
    energizing_brew = {
        id = 115288,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 608938,
        
        handler = function()
            applyBuff("energizing_brew")
        end,
    },
      fists_of_fury = {
        id = 113656,
        cast = 4,
        cooldown = 25,
        gcd = "spell",
        
        spend = 3,
        spendType = "chi",
        
        startsCombat = true,
        texture = 627606,
        
        toggle = "cooldowns",
        
        channeled = true,
        
        -- WoW Sims verified: 6.675 damage multiplier per tick (7.5 * 0.89)
        -- 4 second channel, 4 ticks (1 per second), 25s cooldown, 3 Chi cost
        -- Damage split evenly between all targets, stuns targets
        handler = function()
            applyBuff("fists_of_fury", 4)
            
            -- Apply stun to all targets in cone
            active_enemies = active_enemies or 1
            for i = 1, active_enemies do
                applyDebuff("target", "fists_of_fury_stun", 4)
            end
            
            -- Delay auto-attacks during channel
        end,
    },
    
    flying_serpent_kick = {
        id = 101545,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        startsCombat = true,
        texture = 606545,
        
        handler = function()
            applyBuff("flying_serpent_kick")
        end,
    },
    
    legacy_of_the_white_tiger = {
        id = 116781,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 607848,
        
        handler = function()
            applyBuff("legacy_of_the_white_tiger")
        end,
    },      rising_sun_kick = {
        id = 107428,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 2,
        spendType = "chi",
        
        startsCombat = true,
        texture = 574578,
        
        -- MoP 5.4.8: 8s cooldown, 2 Chi cost
        -- MoP 5.3.0: 20% damage increase debuff to ALL targets within 8 yards for 15 seconds
        -- Always applies Mortal Wounds (healing reduction)
        handler = function()
            -- Apply Rising Sun Kick debuff to primary target
            applyDebuff("target", "rising_sun_kick", 15)
            applyDebuff("target", "mortal_wounds", 10) -- Healing reduction
            
            -- MoP 5.3.0: Apply 20% damage increase debuff to ALL targets within 8 yards
            -- This represents the area effect that was core to MoP Windwalker gameplay
            active_enemies = active_enemies or 1
            if active_enemies > 1 then
                for i = 1, min(active_enemies, 8) do -- Cap at 8 enemies for performance
                    applyDebuff("target", "rising_sun_kick", 15)
                end
            end
        end,
    },
    
    tigereye_brew = {
        id = 116740,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 608939,
        
        usable = function()
            return buff.tigereye_brew_stack.stack > 0
        end,
        
        handler = function()
            -- Convert stacks to buff
            local stacks = min(10, buff.tigereye_brew_stack.stack)
            removeStack("tigereye_brew_stack", stacks)
            applyBuff("tigereye_brew")
        end,
    },
    
    touch_of_karma = {
        id = 122470,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = true,
        texture = 651728,
        
        handler = function()
            applyBuff("touch_of_karma")
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
    
    disable = {
        id = 116095,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 15,
        spendType = "energy",
        
        startsCombat = true,
        texture = 461484,
        
        handler = function()
            applyDebuff("target", "disable")
        end,
    },
    
    expel_harm = {
        id = 115072,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        startsCombat = true,
        texture = 627485,
        
        handler = function()
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
      jab = {
        id = 100780,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,  -- WoW Sims verified: 40 energy (0 in Wise Serpent stance)
        spendType = "energy",
        
        startsCombat = true,
        texture = 574573,
        
        -- WoW Sims verified: 1.5 damage multiplier, generates 1 Chi (2 in Fierce Tiger stance)
        handler = function()
            gain(1, "chi")  -- Base Chi generation (2 in Fierce Tiger stance)
            
            -- Combo Breaker procs (8% chance each)
            if math.random() < 0.08 then
                applyBuff("combo_breaker_tiger_palm")
            end
            
            if math.random() < 0.08 then
                applyBuff("combo_breaker_blackout_kick")
            end
            
            -- Power Strikes talent
            if talent.power_strikes.enabled and cooldown.power_strikes.remains == 0 then
                gain(1, "chi")
                setCooldown("power_strikes", 20)
            end
            
            -- Tigereye Brew generation, approximately one stack per 3 Chi spent
            if math.random() < 0.33 then
                addStack("tigereye_brew_stack", nil, 1)
            end
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
        
        spend = 20,
        spendType = "energy",
        
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
        
        spend = 40,
        spendType = "energy",
        
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
      tiger_palm = {
        id = 100787,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return buff.combo_breaker_tiger_palm.up and 0 or 1 end,
        spendType = "chi",
        
        startsCombat = true,
        texture = 606551,
        
        -- MoP 5.4.8: Costs 1 Chi (removed in Legion 7.0.3), applies Tiger Power (30% armor reduction single application)
        handler = function()
            -- Check if we had free proc
            if buff.combo_breaker_tiger_palm.up then
                removeBuff("combo_breaker_tiger_palm")
            end
            
            -- MoP 5.1.0: Tiger Power reduces target armor by 30% with single application, no longer stacks
            applyDebuff("target", "tiger_power", 20)
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
        end,
    },
} )

-- Specific to Xuen
spec:RegisterPet( "xuen_the_white_tiger", 73967, "invoke_xuen", 45 )

-- State Expressions for Windwalker
spec:RegisterStateExpr( "combo_breaker_bok", function()
    return buff.combo_breaker_blackout_kick.up
end )

spec:RegisterStateExpr( "combo_breaker_tp", function()
    return buff.combo_breaker_tiger_palm.up
end )

spec:RegisterStateExpr( "teb_stacks", function()
    return buff.tigereye_brew_stack.stack
end )

-- Range
spec:RegisterRanges( "tiger_palm", "blackout_kick", "paralysis", "provoke", "crackling_jade_lightning" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "virmen_bite_potion",
    
    package = "Windwalker",
} )

-- Register default pack for MoP Windwalker
spec:RegisterPack( "Windwalker", 20250517, [[Hekili:T3vBVTTn04FldjTrXocoqRiKMh7KvA3KRJ1AWTLr0cbrjdduiHZLPLtfJ1JdKiLmoQiUAWtlW5)GLYmvoWpXIYofJNVQP3YZVCtDw7ZlUm74NwF2G5xnC7JA3YnxFDWp8Yv6(oOV94A7zL9ooX60FsNn2GxV3cW0CwVdF9C4O83PhEKwmDDVF8W)V65a89FdFCRV7uCHthVJ6kXbqnuSmQbCG45DYCFND7zs0MYVsHvyeTDxJzKWx0yZlzZZmylTiWOZ(vPzZIx1uUZE7)aXuZ(qx45sNUZbkn(BNUgCn(RcYdVS(RYqxP2tixP5wOLLNcXE0mbYTj81zg7a8uHMtlP(vHJYTF1Z2ynOBMd6YoLAvJVS3QVdVJOUjP(WV8jntTj63bRuvuV5JaEHN0VEvZP4JNpEvX7P4OeJUFPTxuTSU5tP5wm)8j]] )

-- Register pack selector for Windwalker
spec:RegisterPackSelector( "windwalker", "Windwalker", "|T627606:0|t Windwalker",
    "Handles all aspects of Windwalker Monk DPS rotation with focus on managing Combo Breaker procs and Chi regeneration.",
    nil )
