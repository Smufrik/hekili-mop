-- WarlockDestruction.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Warlock: Destruction spec

if UnitClassBase( 'player' ) ~= 'WARLOCK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 267 ) -- Destruction spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )
spec:RegisterResource( Enum.PowerType.BurningEmbers, {
    max = 4,
    
    regen = 0,
    regenRate = function( state )
        return 0 -- Burning Embers generate from abilities, not passively
    end,
    
    generate = function( amount, overcap )
        local cur = state.burning_embers.current
        local max = state.burning_embers.max
        
        amount = amount or 0.1 -- Default to 0.1 (partial ember)
        
        if overcap then
            state.burning_embers.current = cur + amount
        else
            state.burning_embers.current = math.min( max, cur + amount )
        end
        
        if state.burning_embers.current > cur then
            state.gain( amount, "burning_embers" )
        end
    end,
    
    spend = function( amount )
        local cur = state.burning_embers.current
        
        if cur >= amount then
            state.burning_embers.current = cur - amount
            state.spend( amount, "burning_embers" )
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
    harvest_life              = { 2227, 1, 108371 }, -- Drains the health from up to 3 nearby enemies within 20 yards, causing Shadow damage and gaining 2% of maximum health per enemy every 1 sec.

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
    unbound_will              = { 2236, 1, 108482 }, -- Removes all Magic, Curse, Poison, and Disease effects and makes you immune to controlling effects for 6 sec. 2 min cooldown.

    -- Tier 5 (Level 75) - AoE Damage
    grimoire_of_supremacy     = { 2237, 1, 108499 }, -- Your demons deal 20% more damage and are transformed into more powerful demons.
    grimoire_of_service       = { 2238, 1, 108501 }, -- Summons a second demon with 100% increased damage for 15 sec. 2 min cooldown.
    grimoire_of_sacrifice     = { 2239, 1, 108503 }, -- Sacrifices your demon to grant you an ability depending on the demon you sacrificed, and increases your damage by 15%. Lasts 15 sec.

    -- Tier 6 (Level 90) - DPS
    archimondes_vengeance     = { 2240, 1, 108505 }, -- When you take direct damage, you reflect 15% of the damage taken back at the attacker. For the next 10 sec, you reflect 45% of all direct damage taken. This ability has 3 charges. 30 sec cooldown per charge.
    kiljaedens_cunning        = { 2241, 1, 108507 }, -- Your Malefic Grasp, Drain Life, and Drain Soul can be cast while moving.
    mannoroths_fury           = { 2242, 1, 108508 }  -- Your Rain of Fire, Hellfire, and Immolation Aura have no cooldown and require no Soul Shards to cast. They also no longer apply a damage over time effect.
} )

-- Destruction-specific Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [56232] = "dark_soul",         -- Your Dark Soul also increases the critical strike damage bonus of your critical strikes by 10%.
    [56249] = "drain_life",         -- When using Drain Life, your Mana regeneration is increased by 10% of spirit.
    [56212] = "fear",               -- Your Fear spell no longer causes the target to run in fear. Instead, the target is disoriented for 8 sec or until they take damage.
    [56234] = "havoc",              -- Increases the range of your Havoc spell by 8 yards.
    [56231] = "health_funnel",      -- When using Health Funnel, your demon takes 25% less damage.
    [56242] = "healthstone",        -- Your Healthstone provides 20% additional healing.
    [56248] = "life_tap",           -- Your Life Tap no longer costs health, but now summons a Sacrificial Blood elemental which damages you over time.
    [56233] = "nightmares",         -- The cooldown of your Fear spell is reduced by 8 sec, but it no longer deals damage.
    [56218] = "shadowflame",        -- Your Shadowflame also causes enemies to be slowed by 70% for 3 sec.
    [56219] = "siphon_life",        -- Your Corruption now also heals you for 0.5% of your maximum health every 3 sec.
    [56247] = "soul_consumption",   -- Your Soul Fire now consumes 800 health, but its damage is increased by 20%.
    [56241] = "soul_leech",         -- Your Soul Leech now also affects Drain Life.
    
    -- Minor Glyphs
    [57259] = "conflagrate",       -- Your Conflagrate spell no longer consumes Immolate from the target.
    [56228] = "demonic_circle",     -- Your Demonic Circle: Teleport spell no longer clears your Soul Shards.
    [56246] = "eye_of_kilrogg",     -- Increases the vision radius of your Eye of Kilrogg by 30 yards.
    [58068] = "falling_meteor",     -- Your Meteor Strike now creates a surge of fire outward from the demon's position.
    [58094] = "felguard",           -- Increases the size of your Felguard, making him appear more intimidating.
    [56245] = "imp",                -- Increases the movement speed of your Imp by 50%.
    [58079] = "searing_pain",      -- Decreases the cooldown of your Searing Pain by 2 sec.
    [58081] = "shadow_bolt",        -- Your Shadow Bolt now creates a column of fire that damages all enemies in its path.
    [56244] = "succubus",           -- Increases the movement speed of your Succubus by 50%.
    [58093] = "voidwalker",         -- Increases the size of your Voidwalker, making him appear more intimidating.
} )

-- Destruction Warlock specific auras
spec:RegisterAuras( {
    -- Core Buffs/Debuffs
    immolate = {
        id = 348,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
    },
    conflagrate = {
        id = 17962,
        duration = 10,
        max_stack = 1,
    },
    havoc = {
        id = 80240,
        duration = 15,
        max_stack = 1,
    },
    shadowburn = {
        id = 17877,
        duration = 5,
        max_stack = 1,
    },
    backdraft = {
        id = 117828,
        duration = 15,
        max_stack = 3,
    },
    
    -- Procs and Talents
    dark_soul_instability = {
        id = 113858,
        duration = 20,
        max_stack = 1,
    },
    
    -- Rain of Fire DoT effect
    rain_of_fire = {
        id = 5740,
        duration = 8,
        tick_time = 1,
        max_stack = 1,
    },
    
    -- Defensives
    dark_bargain = {
        id = 110913,
        duration = 8,
        max_stack = 1,
    },
    dark_bargain_dot = {
        id = 110914,
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

-- Destruction Warlock abilities
spec:RegisterAbilities( {
    -- Core Rotational Abilities
    incinerate = {
        id = 29722,
        cast = function() 
            if buff.backdraft.up then 
                return (2.5 * haste) * 0.7 -- 30% cast speed increase with Backdraft
            end
            return 2.5 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.075,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135789,
        
        handler = function()
            -- Generate Burning Embers
            generate( 0.1, "burning_embers" ) -- 0.1 fragment per cast
            
            -- Consume Backdraft
            if buff.backdraft.up then
                if buff.backdraft.stack > 1 then
                    removeStack( "backdraft" )
                else
                    removeBuff( "backdraft" )
                end
            end
        end,
    },
    
    immolate = {
        id = 348,
        cast = function() return 1.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135817,
        
        handler = function()
            applyDebuff( "target", "immolate" )
            -- Generate Burning Embers over time
            -- This is handled via periodic ticks in MoP
        end,
    },
    
    conflagrate = {
        id = 17962,
        cast = 0,
        charges = 2,
        cooldown = 12,
        recharge = 12,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135807,
        
        usable = function()
            return debuff.immolate.up or glyph.conflagrate.enabled, "requires immolate on target"
        end,
        
        handler = function()
            -- Generate Backdraft
            applyBuff( "backdraft" )
            buff.backdraft.stack = 3
            
            -- Generate Burning Embers
            generate( 0.1, "burning_embers" )
            
            -- Remove Immolate if not using the glyph
            if not glyph.conflagrate.enabled then
                removeDebuff( "target", "immolate" )
            end
        end,
    },
    
    chaos_bolt = {
        id = 116858,
        cast = function() 
            if buff.backdraft.up then 
                return (3 * haste) * 0.7 -- 30% cast speed increase with Backdraft
            end
            return 3 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "burning_embers",
        
        startsCombat = true,
        texture = 135808,
        
        handler = function()
            -- Consume Backdraft if active
            if buff.backdraft.up then
                if buff.backdraft.stack > 1 then
                    removeStack( "backdraft" )
                else
                    removeBuff( "backdraft" )
                end
            end
        end,
    },
    
    shadowburn = {
        id = 17877,
        cast = 0,
        cooldown = 12,
        gcd = "spell",
        
        spend = 1,
        spendType = "burning_embers",
        
        startsCombat = true,
        texture = 136191,
        
        usable = function()
            return target.health_pct < 20, "requires target below 20% health"
        end,
        
        handler = function()
            applyDebuff( "target", "shadowburn" )
            
            -- If target dies with Shadowburn, refund 2 Burning Embers
            -- This is handled separately based on target death events
        end,
    },
    
    rain_of_fire = {
        id = 5740,
        cast = 0,
        cooldown = function() return talent.mannoroths_fury.enabled and 0 or 8 end,
        gcd = "spell",
        
        spend = function() return talent.mannoroths_fury.enabled and 0 or 1 end,
        spendType = "burning_embers",
        
        startsCombat = true,
        texture = 135804,
        
        handler = function()
            applyDebuff( "target", "rain_of_fire" )
        end,
    },
    
    fel_flame = {
        id = 77799,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 236253,
        
        handler = function()
            -- Extend Immolate by 6 seconds
            if debuff.immolate.up then
                debuff.immolate.expires = debuff.immolate.expires + 6
                -- Cap at maximum duration
                if debuff.immolate.expires > query_time + 15 then
                    debuff.immolate.expires = query_time + 15
                end
            end
            
            -- Generate Burning Embers
            generate( 0.1, "burning_embers" )
        end,
    },
    
    havoc = {
        id = 80240,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 460695,
        
        handler = function()
            applyDebuff( "target", "havoc" )
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
    
    -- Cooldowns
    dark_soul = {
        id = 113858,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 538042,
        
        handler = function()
            applyBuff( "dark_soul_instability" )
        end,
    },
    
    summon_imp = {
        id = 688,
        cast = 6,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.11,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136218,
        
        handler = function()
            -- Summon imp pet
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

-- State Expressions for Destruction
spec:RegisterStateExpr( "burning_embers", function()
    return burning_embers.current
end )

-- Range
spec:RegisterRanges( "incinerate", "immolate", "conflagrate" )

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
    
    package = "Destruction",
} )

-- Default pack for MoP Destruction Warlock
spec:RegisterPack( "Destruction", 20250515, [[Hekili:T3vBVTTn04FldjHr9LSgR2e75XVc1cbKzKRlvnTo01OEckA2IgxVSbP5cFcqifitljsBPIYPKQbbXQPaX0YCRwRNFAxBtwR37pZUWZB3SZ0Zbnu(ndREWP)8dyNF3BhER85x(jym5nymTYnv0drHbpz5IW1vZgbo1P)MM]] )

-- Register pack selector for Destruction
spec:RegisterPackSelector( "destruction", "Destruction", "|T136186:0|t Destruction",
    "Handles all aspects of Destruction Warlock DPS with focus on Burning Ember generation and Chaos Bolt usage.",
    nil )
