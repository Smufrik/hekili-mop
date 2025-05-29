-- MonkBrewmaster.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Monk: Brewmaster spec

if UnitClassBase( 'player' ) ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 268 ) -- Brewmaster spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

spec:RegisterResource( Enum.PowerType.Energy )
spec:RegisterResource( Enum.PowerType.Chi )
spec:RegisterResource( Enum.PowerType.Mana )

-- Tier sets
spec:RegisterGear( "tier14", 85394, 85395, 85396, 85397, 85398 ) -- T14 Brewmaster Set
spec:RegisterGear( "tier15", 95832, 95833, 95834, 95835, 95836 ) -- T15 Brewmaster Set

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
    
    -- Tier 5 (Level 75) - Defense
    healing_elixirs           = { 2657, 1, 122280 }, -- Potions heal for +10% max health
    dampen_harm               = { 2658, 1, 122278 }, -- Reduces next 3 large attacks by 50%
    diffuse_magic             = { 2659, 1, 122783 }, -- Transfers debuffs, 90% magic damage reduction
    
    -- Tier 6 (Level 90) - Ultimate    rushing_jade_wind         = { 2660, 1, 116847 }, -- Whirling tornado damages nearby enemies
    invoke_xuen               = { 2661, 1, 123904 }, -- Summons White Tiger Xuen for 45 sec
    chi_torpedo               = { 2662, 1, 119085 }  -- Torpedo forward, +30% movement speed
} )

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

-- Statuses for Brewmaster predictions
spec:RegisterStateTable( "stagger", setmetatable({}, {
    __index = function( t, k )
        if k == "light" then
            return FindUnitBuffByID("player", 124275)
        elseif k == "moderate" then
            return FindUnitBuffByID("player", 124274)
        elseif k == "heavy" then
            return FindUnitBuffByID("player", 124273)
        elseif k == "any" then
            return FindUnitBuffByID("player", 124275) or FindUnitBuffByID("player", 124274) or FindUnitBuffByID("player", 124273)
        end
        return false
    end,
}))

-- Brewmaster specific auras
spec:RegisterAuras( {
    -- Stagger damage taken, and amplify staggering
    moderate_stagger = {
        id = 124274,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124274 )
            
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
    heavy_stagger = {
        id = 124273,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124273 )
            
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
    light_stagger = {
        id = 124275,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124275 )
            
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
    },    -- Elusive Brew: Increases dodge chance based on stacks
    elusive_brew = {
        id = 128939,
        duration = function() return buff.elusive_brew.stack * 1 end, -- 1 second per stack
        max_stack = 15,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 128939 )
            
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
    -- Elusive Brew: Stacks gained from critical strikes
    elusive_brew_stack = {
        id = 128938,
        duration = 60,
        max_stack = 15,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 128938 )
            
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
    -- Guard: Absorbs damage
    guard = {
        id = 115295,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115295 )
            
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
    -- Shuffle: Increases Stagger amount and parry chance
    shuffle = {
        id = 115307,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115307 )
            
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
    -- Breath of Fire: Disorients enemies
    breath_of_fire = {
        id = 123725,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 123725, "PLAYER" )
            
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
    -- Keg Smash: Reduces enemy movement speed and attack speed
    keg_smash = {
        id = 121253,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 121253, "PLAYER" )
            
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
    -- Dizzying Haze: Slows and forces enemies to attack you
    dizzying_haze = {
        id = 115180,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115180, "PLAYER" )
            
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
    -- Fortifying Brew: Increases stamina and reduces damage taken
    fortifying_brew = {
        id = 120954,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 120954 )
            
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
    -- Zen Meditation: Reduces damage taken
    zen_meditation = {
        id = 115176,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115176 )
            
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
    -- Mastery: Elusive Brawler
    -- Increases your chance to dodge by 15%.
    elusive_brawler = {
        id = 117967,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 117967 )
            
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
    -- Tiger Power (Stance buff)
    tiger_power = {
        id = 125359,
        duration = 30,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 125359 )
            
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
    -- Power Guard (reduces damage taken)
    power_guard = {
        id = 118636,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118636 )
            
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
    -- Weakened Blows (caused by Keg Smash)
    weakened_blows = {
        id = 115798,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115798, "PLAYER" )
            
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

-- Monk shared abilities and Brewmaster abilities
spec:RegisterAbilities( {
    -- Core Brewmaster Abilities
    breath_of_fire = {
        id = 115181,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 1,
        spendType = "chi",
        
        startsCombat = true,
        texture = 571657,
        
        handler = function()
            applyDebuff("target", "breath_of_fire")
        end,
    },
    
    dizzying_haze = {
        id = 115180,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 20,
        spendType = "energy",
        
        startsCombat = true,
        texture = 614680,
        
        handler = function()
            applyDebuff("target", "dizzying_haze")
        end,
    },
    
    elusive_brew = {
        id = 115308,
        cast = 0,
        cooldown = 6,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 603532,
          buff = "elusive_brew_stack",
        
        usable = function() return buff.elusive_brew_stack.stack > 0 end,
        
        handler = function()
            -- Convert elusive_brew_stack to elusive_brew buff
            local stacks = buff.elusive_brew_stack.stack
            if stacks > 0 then
                removeBuff("elusive_brew_stack")
                -- Each stack gives 1% dodge for 15 seconds, max 15%
                local dodge_duration = min(stacks * 15, 225) -- Max 15 stacks * 15 seconds
                applyBuff("elusive_brew", dodge_duration)
            end
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
    
    guard = {
        id = 115295,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 2,
        spendType = "chi",
        
        startsCombat = false,
        texture = 611417,
        
        toggle = "defensives",
        
        handler = function()
            applyBuff("guard")
        end,
    },
      keg_smash = {
        id = 121253,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        startsCombat = true,
        texture = 594274,
        
        handler = function()
            applyDebuff("target", "keg_smash")
            applyDebuff("target", "weakened_blows")
            
            -- Generate 2 Chi - core mechanic for Brewmaster
            gain(2, "chi")
            
            -- Chance to proc Elusive Brew stack on crit
            if crit_chance > 0 then
                addStack("elusive_brew_stack", nil, 1)
            end
        end,
    },
    
    purifying_brew = {
        id = 119582,
        cast = 0,
        cooldown = 1,
        charges = 3,
        recharge = 15,
        gcd = "off",
        
        spend = 1,
        spendType = "chi",
        
        startsCombat = false,
        texture = 595276,
        
        toggle = "defensives",
        
        handler = function()
            -- Purifies 50% of staggered damage when used
        end,
    },
    
    shuffle = {
        id = 115307,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 2,
        spendType = "chi",
        
        startsCombat = false,
        texture = 634317,
        
        handler = function()
            applyBuff("shuffle")
        end,
    },
    
    summon_black_ox_statue = {
        id = 115315,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        startsCombat = false,
        texture = 627606,
        
        handler = function()
            -- Summons a statue for 15 mins
        end,
    },
    
    zen_meditation = {
        id = 115176,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 642414,
        
        handler = function()
            applyBuff("zen_meditation")
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
            -- Applies group buff for crit and 5% stats
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
        cooldown = 15,
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
        
        spend = 0,
        spendType = "energy",
        
        startsCombat = true,
        texture = 606551,
        
        handler = function()
            -- Builds stack of Tiger Power
            addStack("tiger_power", nil, 1)
            -- Power Guard in defensive stance
            applyBuff("power_guard")
            
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

-- Specific to Xuen and Black Ox
spec:RegisterPet( "xuen_the_white_tiger", 73967, "invoke_xuen", 45 )
spec:RegisterTotem( "black_ox_statue", 627607 )

-- State Expressions
spec:RegisterStateExpr( "stagger_pct", function()
    if buff.heavy_stagger.up then return 0.6
    elseif buff.moderate_stagger.up then return 0.4
    elseif buff.light_stagger.up then return 0.2
    else return 0 end
end )

spec:RegisterStateExpr( "stagger_amount", function()
    if health.current == 0 then return 0 end
    local base_amount = health.max * 0.05 -- Base stagger amount
    if buff.heavy_stagger.up then return base_amount * 3
    elseif buff.moderate_stagger.up then return base_amount * 2
    elseif buff.light_stagger.up then return base_amount
    else return 0 end
end )

spec:RegisterStateExpr( "effective_stagger", function()
    local amount = stagger_amount
    if buff.shuffle.up then
        amount = amount * 1.2 -- 20% more stagger with Shuffle
    end
    return amount
end )

spec:RegisterStateExpr( "chi_cap", function()
    if talent.ascension.enabled then return 5 else return 4 end
end )

spec:RegisterStateExpr( "energy_regen_rate", function()
    local base_rate = 10 -- Base energy per second
    if talent.ascension.enabled then
        base_rate = base_rate * 1.15 -- 15% increase from Ascension
    end
    return base_rate
end )

spec:RegisterStateExpr( "should_purify", function()
    return stagger_amount > health.max * 0.08 and chi.current > 0
end )

-- Range
spec:RegisterRanges( "keg_smash", "paralysis", "provoke", "crackling_jade_lightning" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "virmen_bite_potion",
    
    package = "Brewmaster",
} )

-- Register default pack for MoP Brewmaster Monk
spec:RegisterPack( "Brewmaster", 20250517, [[Hekili:T3vBVTTnu4FldiHr5osojoRZh7KvA3KRJvA2jDLA2jz1yvfbpquu6iqjvswkspfePtl6VGQIQUnbJeHAVQDcOWrbE86CaE4GUwDBB4CvC5m98jdNZzDX6w)v)V(i)h(jDV7GFWEh)9T6rhFQVnSVzsmypSlD2OXqskYJCKfpPWXt87zPkZGZVRSLAXYUYORTmYLwaXlyc8LkGusGO7469JwjTfTH0PwPbJaeivvLsvrfoeQtcGbWlG0A)Ff9)8jPyqXgkz5Qkz5kLRyR12Uco1veB5MUOfIMXnV2Nw8UqEkeUOLXMFtKUOMcEvjzmqssgiE37NuLYlP5NnNgEE5(vJDjgvCeXmQVShsbh(AfIigS2JOmiUeXm(KJ0JkOtQu0Ky)iYcJvqQrthQ(5Fcu5ILidEZjQ0CoYXj)USIip9kem)i81l2cOFLlk9cKGk5nuuDXZes)SEHXiZdLP1gpb968CvpxbSVDaPzgwP6ahsQWnRs)uOKnc0)]] )

-- Register pack selector for Brewmaster
spec:RegisterPackSelector( "brewmaster", "Brewmaster", "|T608951:0|t Brewmaster",
    "Handles all aspects of Brewmaster Monk tanking rotation with focus on survival and mitigation.",
    nil )
