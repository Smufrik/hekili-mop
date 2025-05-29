-- WarlockDemonology.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Warlock: Demonology spec

if UnitClassBase( 'player' ) ~= 'WARLOCK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 266 ) -- Demonology spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )
spec:RegisterResource( Enum.PowerType.DemonicFury, {
    max = 1000,
    
    regen = 0,
    regenRate = function( state )
        return 0 -- Demonic Fury generates from abilities, not passively
    end,
    
    generate = function( amount, overcap )
        local cur = state.demonic_fury.current
        local max = state.demonic_fury.max
        
        amount = amount or 0
        
        if overcap then
            state.demonic_fury.current = cur + amount
        else
            state.demonic_fury.current = math.min( max, cur + amount )
        end
        
        if state.demonic_fury.current > cur then
            state.gain( amount, "demonic_fury" )
        end
    end,
    
    spend = function( amount )
        local cur = state.demonic_fury.current
        
        if cur >= amount then
            state.demonic_fury.current = cur - amount
            state.spend( amount, "demonic_fury" )
            return true
        end
        
        return false
    end,
} )

-- Tier sets
spec:RegisterGear( "tier14", 85373, 85374, 85375, 85376, 85377 ) -- T14 Warlock Set
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- T15 Warlock Set

-- Talents (MoP talent system - ID, enabled, spell_id)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Crowd Control/Utility
    dark_regeneration         = { 2225, 1, 108359 }, -- Instantly restores 30% of your maximum health. Restores an additional 6% of your maximum health for each of your damage over time effects on hostile targets within 20 yards. 2 min cooldown.
    soul_leech                = { 2226, 1, 108370 }, -- When you deal damage with Malefic Grasp, Drain Soul, Shadow Bolt, Touch of Chaos, Chaos Bolt, Incinerate, Fel Flame, Haunt, or Soul Fire, you create a shield that absorbs (45% of Spell power) damage for 15 sec.
    harvest_life               = { 2227, 1, 108371 }, -- Drains the health from up to 3 nearby enemies within 20 yards, causing Shadow damage and gaining 2% of maximum health per enemy every 1 sec.

    -- Tier 2 (Level 30) - Mobility/Survivability
    howl_of_terror            = { 2228, 1, 5484   }, -- Causes all nearby enemies within 10 yards to flee in terror for 8 sec. Targets are disoriented for 3 sec. 40 sec cooldown.
    mortal_coil               = { 2229, 1, 6789   }, -- Horrifies an enemy target, causing it to flee in fear for 3 sec. The caster restores 11% of maximum health when the effect successfully horrifies an enemy. 30 sec cooldown.
    shadowfury                = { 2230, 1, 30283  }, -- Stuns all enemies within 8 yards for 3 sec. 30 sec cooldown.

    -- Tier 3 (Level 45) - DPS Cooldowns
    soul_link                 = { 2231, 1, 108415 }, -- 20% of all damage taken by the Warlock is redirected to your demon pet instead. While active, both your demon and you will regenerate 3% of maximum health each second. Lasts as long as your demon is active.
    sacrificial_pact          = { 2232, 1, 108416 }, -- Sacrifice your summoned demon to prevent 300% of your maximum health in damage divided among all party and raid members within 40 yards. Lasts 8 sec.
    dark_bargain              = { 2233, 1, 110913 }, -- Prevents all damage for 8 sec. When the shield expires, 50% of the total amount of damage prevented is dealt to the caster over 8 sec. 3 min cooldown.

    -- Tier 4 (Level 60) - Pet Enhancement
    blood_fear                = { 2234, 1, 111397 }, -- When you use Healthstone, enemies within 15 yards are horrified for 4 sec. 45 sec cooldown.
    burning_rush              = { 2235, 1, 111400 }, -- Increases your movement speed by 50%, but also deals damage to you equal to 4% of your maximum health every 1 sec.
    unbound_will             = { 2236, 1, 108482 }, -- Removes all Magic, Curse, Poison, and Disease effects and makes you immune to controlling effects for 6 sec. 2 min cooldown.

    -- Tier 5 (Level 75) - AoE Damage
    grimoire_of_supremacy     = { 2237, 1, 108499 }, -- Your demons deal 20% more damage and are transformed into more powerful demons.
    grimoire_of_service       = { 2238, 1, 108501 }, -- Summons a second demon with 100% increased damage for 15 sec. 2 min cooldown.
    grimoire_of_sacrifice     = { 2239, 1, 108503 }, -- Sacrifices your demon to grant you an ability depending on the demon you sacrificed, and increases your damage by 15%. Lasts 15 sec.

    -- Tier 6 (Level 90) - DPS
    archimondes_vengeance     = { 2240, 1, 108505 }, -- When you take direct damage, you reflect 15% of the damage taken back at the attacker. For the next 10 sec, you reflect 45% of all direct damage taken. This ability has 3 charges. 30 sec cooldown per charge.
    kiljaedens_cunning        = { 2241, 1, 108507 }, -- Your Malefic Grasp, Drain Life, and Drain Soul can be cast while moving.
    mannoroths_fury           = { 2242, 1, 108508 }  -- Your Rain of Fire, Hellfire, and Immolation Aura have no cooldown and require no Soul Shards to cast. They also no longer apply a damage over time effect.
} )

-- Demonology-specific Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [56232] = "dark_soul",         -- Your Dark Soul also increases the critical strike damage bonus of your critical strikes by 10%.
    [56249] = "drain_life",        -- When using Drain Life, your Mana regeneration is increased by 10% of spirit.
    [56212] = "fear",              -- Your Fear spell no longer causes the target to run in fear. Instead, the target is disoriented for 8 sec or until they take damage.
    [56238] = "felguard",          -- Your Felguard's special attack, Legion Strike, now hits all nearby enemies for 10% less damage.
    [56231] = "health_funnel",     -- When using Health Funnel, your demon takes 25% less damage.
    [56242] = "healthstone",       -- Your Healthstone provides 20% additional healing.
    [56226] = "imp_swarm",         -- Your Summon Imp spell now summons 4 Wild Imps. The cooldown of your Summon Imp ability is increased by 20 sec.
    [56248] = "life_tap",          -- Your Life Tap no longer costs health, but now summons a Sacrificial Blood elemental which damages you over time.
    [56233] = "nightmares",        -- The cooldown of your Fear spell is reduced by 8 sec, but it no longer deals damage.
    [56243] = "shadow_bolt",       -- Increases the travel speed of your Shadow Bolt by 100%.
    [56218] = "shadowflame",       -- Your Shadowflame also causes enemies to be slowed by 70% for 3 sec.
    [56247] = "soul_consumption",  -- Your Soul Fire now consumes 800 health, but its damage is increased by 20%.
    
    -- Minor Glyphs
    [57259] = "conflagrate",      -- Your Conflagrate spell no longer consumes Immolate from the target.
    [56228] = "demonic_circle",    -- Your Demonic Circle: Teleport spell no longer clears your Soul Shards.
    [56246] = "eye_of_kilrogg",    -- Increases the vision radius of your Eye of Kilrogg by 30 yards.
    [58068] = "falling_meteor",    -- Your Meteor Strike now creates a surge of fire outward from the demon's position.
    [58094] = "felguard",          -- Increases the size of your Felguard, making him appear more intimidating.
    [56244] = "health_funnel",     -- Increases the effectiveness of your Health Funnel spell by 30%.
    [58079] = "hand_of_guldan",    -- Your Hand of Gul'dan creates a shadow explosion that can damage up to 5 nearby enemies.
    [58081] = "shadow_bolt",       -- Your Shadow Bolt now creates a column of fire that damages all enemies in its path.
    [45785] = "verdant_spheres",   -- Changes the appearance of your Shadow Orbs to 3 floating green fel spheres.
    [58093] = "voidwalker",        -- Increases the size of your Voidwalker, making him appear more intimidating.
} )

-- Demonology Warlock specific auras
spec:RegisterAuras( {
    -- Core Buffs/Debuffs
    corruption = {
        id = 172,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
    },
    doom = {
        id = 603,
        duration = 60,
        tick_time = 15,
        max_stack = 1,
    },
    hand_of_guldan = {
        id = 86040,
        duration = 6,
        tick_time = 2,
        max_stack = 1,
    },
    immolation_aura = {
        id = 104025,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
    },
    hellfire = {
        id = 1949,
        duration = 16,
        tick_time = 1,
        max_stack = 1,
    },
    shadowflame = {
        id = 47960,
        duration = 8,
        tick_time = 2,
        max_stack = 1,
    },
    bane_of_doom = {
        id = 603,
        duration = 60,
        tick_time = 15,
        max_stack = 1,
    },
    bane_of_agony = {
        id = 980,
        duration = 24,
        max_stack = 10,
    },
      -- Metamorphosis and related
    metamorphosis = {
        id = 103958,
        duration = 30, -- Maximum duration, but limited by Demonic Fury
        max_stack = 1,
        tick_time = 1, -- Drains Demonic Fury every second
        
        meta = {
            -- In MoP, Metamorphosis drains 40 Demonic Fury per second
            tick = function()
                if demonic_fury.current >= 40 then
                    spend(40, "demonic_fury")
                else
                    -- Not enough Demonic Fury, end Metamorphosis
                    removeBuff("metamorphosis")
                end
            end,
        },
    },
    dark_apotheosis = {
        id = 114168,
        duration = 3600,
        max_stack = 1,
    },
    molten_core = {
        id = 122355,
        duration = 15,
        max_stack = 5,
    },
    
    -- Procs and Talents
    dark_soul_knowledge = {
        id = 113861,
        duration = 20,
        max_stack = 1,
    },
    demonic_rebirth = {
        id = 89140,
        duration = 15,
        max_stack = 1,
    },
    demonic_calling = {
        id = 119904,
        duration = 20,
        max_stack = 1,
    },
    
    -- Wild Imps
    wild_imps = {
        duration = 20,
        max_stack = 4,
    },
    
    -- Defensives
    dark_bargain = {
        id = 110913,
        duration = 8,
        max_stack = 1,
    },
    soul_link = {
        id = 108415,
        duration = 3600,
        max_stack = 1,
    },
    unbound_will = {
        id = 108482,
        duration = 6,
        max_stack = 1,
    },
    
    -- Pet-related
    grimoire_of_sacrifice = {
        id = 108503,
        duration = 15,
        max_stack = 1,
    },
    
    -- Utility
    dark_regeneration = {
        id = 108359,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    unending_breath = {
        id = 5697,
        duration = 600,
        max_stack = 1,
    },
    unending_resolve = {
        id = 104773,
        duration = 8,
        max_stack = 1,
    },
    demonic_circle = {
        id = 48018,
        duration = 900,
        max_stack = 1,
    },
    demonic_gateway = {
        id = 113900,
        duration = 15,
        max_stack = 1,
    },
} )

-- Demonology Warlock abilities
spec:RegisterAbilities( {
    -- Core Rotational Abilities
    shadow_bolt = {
        id = 686,
        cast = function() return 2.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.075,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136197,
        
        handler = function()
            -- Generate Demonic Fury
            gain( 25, "demonic_fury" )
            
            -- Chance to proc Molten Core
            if math.random() < 0.1 then -- 10% chance
                if buff.molten_core.stack < 5 then
                    addStack( "molten_core" )
                end
            end
        end,
    },
    
    touch_of_chaos = {
        id = 103964,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "demonic_fury",
        
        startsCombat = true,
        texture = 615099,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            -- Replaces Shadow Bolt in Meta form
        end,
    },
    
    corruption = {
        id = 172,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136118,
        
        handler = function()
            applyDebuff( "target", "corruption" )
            -- Generate Demonic Fury
            gain( 6, "demonic_fury" )
        end,
    },
    
    doom = {
        id = 603,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 10,
        spendType = "demonic_fury",
        
        startsCombat = true,
        texture = 136122,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            applyDebuff( "target", "doom" )
        end,
    },
    
    hand_of_guldan = {
        id = 105174,
        cast = function() return 1.5 * haste end,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = true,
        texture = 537432,
        
        handler = function()
            applyDebuff( "target", "hand_of_guldan" )
            -- Generate Demonic Fury
            gain( 5 * 3, "demonic_fury" ) -- 5 per target hit, assuming 3 targets
            
            -- Summon Wild Imps
            if not buff.wild_imps.up then
                applyBuff( "wild_imps" )
                buff.wild_imps.stack = 1
            else
                addStack( "wild_imps", nil, 1 )
            end
        end,
    },
    
    soul_fire = {
        id = 6353,
        cast = function() 
            if buff.molten_core.up then return 0 end
            return 4 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135808,
        
        handler = function()
            -- Generate Demonic Fury
            gain( 30, "demonic_fury" )
            
            -- Consume Molten Core if active
            if buff.molten_core.up then
                if buff.molten_core.stack > 1 then
                    removeStack( "molten_core" )
                else
                    removeBuff( "molten_core" )
                end
            end
        end,
    },
    
    fel_flame = {
        id = 77799,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 132402,
        
        handler = function()
            -- Generate Demonic Fury
            gain( 10, "demonic_fury" )
        end,
    },
    
    life_tap = {
        id = 1454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            -- Costs 15% health, returns 15% mana
            local health_cost = health.max * 0.15
            local mana_return = mana.max * 0.15
            
            spend( health_cost, "health" )
            gain( mana_return, "mana" )
        end,
    },
    
    curse_of_the_elements = {
        id = 1490,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136130,
        
        handler = function()
            -- Apply debuff
        end,
    },
      -- Metamorphosis
    metamorphosis = {
        id = 103958,
        cast = 0,
        cooldown = 0, -- No cooldown in MoP
        gcd = "spell",
        
        spend = 400, -- Requires minimum 400 Demonic Fury to activate
        spendType = "demonic_fury",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 530482,
        
        usable = function()
            return not buff.metamorphosis.up and demonic_fury.current >= 400, "requires at least 400 demonic fury and not already in metamorphosis"
        end,
        
        handler = function()
            applyBuff( "metamorphosis" )
            -- In MoP, Metamorphosis drains 40 Demonic Fury per second while active
            -- This will be handled by the buff's tick mechanics
        end,
    },
    
    cancel_metamorphosis = {
        id = 103958,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        texture = 530482,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis active"
        end,
        
        handler = function()
            removeBuff( "metamorphosis" )
        end,
    },
    
    immolation_aura = {
        id = 104025,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 50,
        spendType = "demonic_fury",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 135817,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            applyBuff( "immolation_aura" )
        end,
    },
    
    void_ray = {
        id = 115422,
        cast = function() return 3 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        channeled = true,
        
        spend = 24,
        spendType = "demonic_fury",
        
        startsCombat = true,
        texture = 530707,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            -- Meta channeled spell
        end,
    },
    
    dark_apotheosis = {
        id = 114168,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 473510,
        
        toggle = "defensives",
        
        handler = function()
            applyBuff( "dark_apotheosis" )
        end,
    },
    
    hellfire = {
        id = 1949,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        channeled = true,
        
        spend = 0.64,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135818,
        
        handler = function()
            applyBuff( "hellfire" )
            
            -- Generate Demonic Fury per tick
            -- Assuming 4 ticks over 4 seconds (1 per second)
            for i = 1, 4 do
                gain( 10, "demonic_fury" )
            end
        end,
    },
    
    -- Cooldowns
    dark_soul = {
        id = 113861,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 538042,
        
        handler = function()
            applyBuff( "dark_soul_knowledge" )
        end,
    },
    
    summon_felguard = {
        id = 30146,
        cast = 6,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136216,
        
        handler = function()
            -- Summon pet
        end,
    },
    
    command_demon = {
        id = 119898,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 134400,
        
        handler = function()
            -- Command current demon based on demon type
        end,
    },
    
    summon_doomguard = {
        id = 18540,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 603013,
        
        handler = function()
            -- Summon Doomguard for 1 minute
        end,
    },
    
    summon_infernal = {
        id = 1122,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136219,
        
        handler = function()
            -- Summon Infernal for 1 minute
        end,
    },
    
    -- Defensive and Utility
    dark_bargain = {
        id = 110913,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 538038,
        
        handler = function()
            applyBuff( "dark_bargain" )
        end,
    },
    
    unending_resolve = {
        id = 104773,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 136150,
        
        handler = function()
            applyBuff( "unending_resolve" )
        end,
    },
    
    demonic_circle_summon = {
        id = 48018,
        cast = 0.5,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            applyBuff( "demonic_circle" )
        end,
    },
    
    demonic_circle_teleport = {
        id = 48020,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 607512,
        
        handler = function()
            -- Teleport to circle
        end,
    },
    
    -- Talent abilities
    howl_of_terror = {
        id = 5484,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607510,
        
        handler = function()
            -- Fear all enemies in 10 yards
        end,
    },
    
    mortal_coil = {
        id = 6789,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607514,
        
        handler = function()
            -- Fear target and heal 11% of max health
            local heal_amount = health.max * 0.11
            gain( heal_amount, "health" )
        end,
    },
    
    shadowfury = {
        id = 30283,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 457223,
        
        handler = function()
            -- Stun all enemies in 8 yards
        end,
    },
    
    grimoire_of_sacrifice = {
        id = 108503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 538443,
        
        handler = function()
            applyBuff( "grimoire_of_sacrifice" )
        end,
    },
} )

-- State Expressions for Demonology
spec:RegisterStateExpr( "demonic_fury", function()
    return demonic_fury.current
end )

-- Range
spec:RegisterRanges( "shadow_bolt", "corruption", "hand_of_guldan" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent",
    
    package = "Demonology",
} )

-- Default pack for MoP Demonology Warlock
spec:RegisterPack( "Demonology", 20250515, [[Hekili:T3vBVTTn04FldjHr9LSgR2e75XVc1cbKzKRlvnTo01OEckA2IgxVSbP5cFcqifitljsBPIYPKQbbXQPaX0YCRwRNFAxBtwR37pZUWZB3SZ0Zbnu(ndREWP)8dyNF3BhER85x(jym5nymTYnv0drHbpz5IW1vZgbo1P)MM]] )

-- Register pack selector for Demonology
spec:RegisterPackSelector( "demonology", "Demonology", "|T136172:0|t Demonology",
    "Handles all aspects of Demonology Warlock DPS with focus on Metamorphosis and demonic summons.",
    nil )
