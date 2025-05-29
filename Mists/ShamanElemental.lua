-- ShamanElemental.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Shaman: Elemental spec

if UnitClassBase( 'player' ) ~= 'SHAMAN' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 262 ) -- Elemental spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )

-- Tier sets
spec:RegisterGear( "tier14", 85289, 85290, 85291, 85292, 85293 ) -- T14 Shaman Set
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- T15 Shaman Set

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Survivability
    nature_guardian            = { 2260, 1, 30884  }, -- Instant heal for 20% health when below 30%
    stone_bulwark_totem        = { 2261, 1, 108270 }, -- Absorb totem that regenerates shield
    astral_shift               = { 2262, 1, 108271 }, -- 40% damage shifted to DoT for 6 sec

    -- Tier 2 (Level 30) - Utility/Control
    frozen_power               = { 2263, 1, 108196 }, -- Frost Shock roots targets for 5 sec
    earthgrab_totem            = { 2264, 1, 51485  }, -- Totem roots nearby enemies
    windwalk_totem             = { 2265, 1, 108273 }, -- Removes movement impairing effects

    -- Tier 3 (Level 45) - Totem Enhancement
    call_of_the_elements       = { 2266, 1, 108285 }, -- Reduces totem cooldowns by 50% for 1 min
    totemic_restoration        = { 2267, 1, 108284 }, -- Destroyed totems get 50% cooldown reduction
    totemic_projection         = { 2268, 1, 108287 }, -- Relocate totems to target location

    -- Tier 4 (Level 60) - DPS Enhancement
    elemental_mastery          = { 2269, 1, 16166  }, -- Instant cast and 30% spell damage buff
    ancestral_swiftness        = { 2270, 1, 16188  }, -- 5% haste passive, instant cast active
    echo_of_the_elements       = { 2271, 1, 108283 }, -- 6% chance to cast spell twice

    -- Tier 5 (Level 75) - Healing/Support
    healing_tide_totem         = { 2272, 1, 108280 }, -- Raid healing totem for 10 sec
    ancestral_guidance         = { 2273, 1, 108281 }, -- For 10 sec, 40% of your damage or healing is copied as healing to a nearby injured party or raid member.
    conductivity               = { 2274, 1, 108282 }, -- When you cast Healing Rain, you may cast Lightning Bolt, Chain Lightning, Lava Burst, or Elemental Blast on enemies standing in the area to heal all allies in the Healing Rain for 20% of the damage dealt.    ancestral_guidance         = { 2273, 1, 108281 }, -- Heals lowest health ally for 25% of damage dealt
    conductivity               = { 2274, 1, 108282 }, -- Chain Lightning spread to 2 additional targets
    
    -- Tier 6 (Level 90) - Ultimate
    unleashed_fury             = { 2275, 1, 117012 }, -- Enhances Unleash Elements effects
    primal_elementalist        = { 2276, 1, 117013 }, -- Gain control over elementals, 10% more damage
    elemental_blast            = { 2277, 1, 117014 }  -- High damage + random stat buff
} )

-- Elemental-specific Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [55445] = "chain_lightning",     -- Your Chain Lightning strikes 1 additional target, but deals 10% less damage to all targets.
    [55447] = "fire_elemental_totem", -- Increases the duration of your Fire Elemental Totem by 1 min, but increases the cooldown by 2.5 min.
    [55455] = "flame_shock",         -- Increases the duration of Flame Shock by 6 sec.
    [55456] = "frost_shock",         -- Your Frost Shock no longer slows your enemies, but also no longer shares a cooldown with other shock spells.
    [55440] = "healing_stream_totem", -- Your Healing Stream Totem also reduces damage taken by 10% for allies within its radius.
    [55441] = "healing_wave",        -- Your Healing Wave also heals you for 20% of the amount when you heal someone else.
    [55442] = "lava_burst",          -- Your Lava Burst doesn't need to hit a target with your Flame Shock to cause a critical strike.
    [63291] = "lightning_shield",    -- Increases the damage of your Lightning Shield orbs by 30%, but your Lightning Shield no longer restores mana through the Static Shock talent.
    [55444] = "shamanistic_rage",    -- Your Shamanistic Rage ability no longer reduces damage taken.
    [55449] = "totemic_recall",      -- Your Totemic Recall spell no longer restores mana when recalling totems.
    [55451] = "thunder",             -- Increases the radius of Thunderstorm by 5 yards.
    [55438] = "thunderstorm",        -- Your Thunderstorm no longer knocks enemies back.
    [55443] = "unstable_earth",      -- Your Earth Shock also causes your target to be vulnerable to critical strikes for 5 sec.
    
    -- Minor Glyphs
    [58059] = "arctic_wolf",         -- Your Ghost Wolf form appears as an Arctic Wolf.
    [63270] = "astral_recall",       -- Reduces the cooldown on your Astral Recall spell by 2 min.
    [63271] = "astral_fixation",     -- Your Far Sight ability now casts instantly.
    [55454] = "capacitor_totem",     -- Reduces the time before your Capacitor Totem detonates by 2 sec, but increases the cooldown by 15 sec.
    [58057] = "deluge",              -- Increases the range of your Chain Lightning and Chain Heal spells by 5 yards.
    [58058] = "elemental_familiars", -- Your totems no longer have Taunt abilities.
    [58063] = "lava_lash",           -- Your Lava Lash no longer increases damage when your offhand weapon is enchanted with Flametongue, but instead generates one stack of Searing Flame, increasing the damage of your next Searing Totem by 5%, stacking up to 5 times.
    [57720] = "reach_of_the_elements", -- Increases the range of your totems by 5 yards.
    [55461] = "spirit_wolf",         -- Each of your Spirit Wolves attacks add a stack of Spirit Hunt to your target, increasing the healing you receive by 1% for 10 sec and stacking up to 5 times.
    [55437] = "thunderstorm",        -- Your Thunderstorm knocks enemies back a shorter distance.
    [58056] = "totemic_vigor",       -- Increases the health of your totems by 5%.
    [55439] = "water_walking",       -- Your Water Walking spell no longer cancels when recipients take damage.
} )

-- Elemental Shaman specific auras
spec:RegisterAuras( {
    -- Core mechanics
    lightning_shield = {
        id = 324,
        duration = 1800,
        max_stack = 6,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 324 )
            
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
        end,
    },
    fulmination = {
        id = 88766,
        duration = 30,
        max_stack = 1,
    },
    lava_surge = {
        id = 77762,
        duration = 6,
        max_stack = 1,
    },
    
    -- Talents
    echo_of_the_elements = {
        id = 108283,
        duration = 10,
        max_stack = 1,
    },
    ascendance = {
        id = 114049,
        duration = 15,
        max_stack = 1,
    },
    elemental_mastery = {
        id = 16166,
        duration = 20,
        max_stack = 1,
    },
    unleash_flame = {
        id = 73683,
        duration = 10,
        max_stack = 1,
    },
    
    -- Totems
    capacitor_totem = {
        id = 118905,
        duration = 5,
        max_stack = 1,
    },
    earthbind_totem = {
        id = 2484,
        duration = 30,
        max_stack = 1,
    },
    earthgrab_totem = {
        id = 51485,
        duration = 20,
        max_stack = 1,
    },
    fire_elemental_totem = {
        id = 2894,
        duration = function() return glyph.fire_elemental_totem.enabled and 120 or 60 end,
        max_stack = 1,
    },
    grounding_totem = {
        id = 8177,
        duration = 15,
        max_stack = 1,
    },
    healing_stream_totem = {
        id = 5394,
        duration = 15,
        max_stack = 1,
    },
    healing_tide_totem = {
        id = 108280,
        duration = 10,
        max_stack = 1,
    },
    magma_totem = {
        id = 8190,
        duration = 60,
        max_stack = 1,
    },
    mana_tide_totem = {
        id = 16190,
        duration = 12,
        max_stack = 1,
    },
    searing_totem = {
        id = 3599,
        duration = 60,
        max_stack = 1,
    },
    spirit_link_totem = {
        id = 98008,
        duration = 6,
        max_stack = 1,
    },
    stone_bulwark_totem = {
        id = 108270,
        duration = 30,
        max_stack = 1,
    },
    stoneclaw_totem = {
        id = 5730,
        duration = 15,
        max_stack = 1,
    },
    stoneskin_totem = {
        id = 8071,
        duration = 15,
        max_stack = 1,
    },
    stormlash_totem = {
        id = 120668,
        duration = 10,
        max_stack = 1,
    },
    tremor_totem = {
        id = 8143,
        duration = 10,
        max_stack = 1,
    },
    windwalk_totem = {
        id = 108273,
        duration = 6,
        max_stack = 1,
    },
    
    -- Debuffs
    flame_shock = {
        id = 8050,
        duration = function() return glyph.flame_shock.enabled and 27 or 21 end,
        tick_time = 3,
        max_stack = 1,
    },
    frost_shock = {
        id = 8056,
        duration = 8,
        max_stack = 1,
    },
    frozen = {
        id = 94794,
        duration = 5,
        max_stack = 1,
    },
    earthgrab = {
        id = 64695,
        duration = 5,
        max_stack = 1,
    },
    
    -- Defensives
    astral_shift = {
        id = 108271,
        duration = 6,
        max_stack = 1,
    },
    stone_bulwark_absorb = {
        id = 114893,
        duration = 30,
        max_stack = 1,
    },
    shamanistic_rage = {
        id = 30823,
        duration = 15,
        max_stack = 1,
    },
    
    -- Utility
    ancestral_swiftness = {
        id = 16188,
        duration = 10,
        max_stack = 1,
    },
    spiritwalkers_grace = {
        id = 79206,
        duration = 15,
        max_stack = 1,
    },
    ghost_wolf = {
        id = 2645,
        duration = 3600,
        max_stack = 1,
    },
    water_walking = {
        id = 546,
        duration = 600,
        max_stack = 1,
    },
    water_breathing = {
        id = 131,
        duration = 600,
        max_stack = 1,
    },
    
    -- MoP-specific talents
    ancestral_guidance = {
        id = 108281,
        duration = 10,
        max_stack = 1,
    },
    conductivity = {
        id = 108282,
        duration = 10,
        max_stack = 1,
    },
} )

-- Elemental Shaman abilities
spec:RegisterAbilities( {
    -- Core rotational abilities    lightning_bolt = {
        id = 403,
        cast = function() return 2.5 * haste * (buff.elemental_mastery.up and 0.7 or 1) end,  -- Corrected: MoP authentic 2.5s cast time
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136048,
        
        handler = function()
            -- MoP 5.3.0+: Lightning Bolt can be cast while moving
            if buff.elemental_mastery.up then
                buff.elemental_mastery.expires = buff.elemental_mastery.expires - 1
                if buff.elemental_mastery.expires <= query_time then
                    removeBuff("elemental_mastery")
                end
            end
            if talent.echo_of_the_elements.enabled and math.random() < 0.06 then
                -- Simulate Echo of the Elements proc with a 6% chance
                applyBuff("echo_of_the_elements")
            end
        end,
    },
    
    chain_lightning = {
        id = 421,
        cast = function() return 2.5 * haste * (buff.elemental_mastery.up and 0.7 or 1) end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136015,
        
        handler = function()
            if buff.elemental_mastery.up then
                buff.elemental_mastery.expires = buff.elemental_mastery.expires - 1
                if buff.elemental_mastery.expires <= query_time then
                    removeBuff("elemental_mastery")
                end
            end
            if talent.echo_of_the_elements.enabled and math.random() < 0.06 then
                -- Simulate Echo of the Elements proc with a 6% chance
                applyBuff("echo_of_the_elements")
            end
        end,
    },
    
    lava_burst = {
        id = 51505,
        cast = function() 
            if buff.lava_surge.up then return 0 end
            return 2 * haste * (buff.elemental_mastery.up and 0.7 or 1)
        end,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 237582,
        
        handler = function()
            removeBuff("lava_surge")
            if talent.echo_of_the_elements.enabled and math.random() < 0.06 then
                -- Simulate Echo of the Elements proc with a 6% chance
                applyBuff("echo_of_the_elements")
            end
        end,
    },
    
    flame_shock = {
        id = 8050,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135813,
        
        handler = function()
            applyDebuff("target", "flame_shock")
            -- Lava Surge mechanic
            if math.random() < 0.15 then -- 15% chance per cast
                applyBuff("lava_surge")
                cooldown.lava_burst.reset = true
            end
        end,
    },
    
    earth_shock = {
        id = 8042,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136026,
        
        usable = function() return buff.lightning_shield.stack >= 1, "requires lightning shield" end,
        
        handler = function()
            -- Fulmination mechanic in MoP
            if buff.lightning_shield.stack >= 7 then
                applyBuff("fulmination")
                buff.lightning_shield.stack = 1
            else
                buff.lightning_shield.stack = 1
            end
        end,
    },
    
    frost_shock = {
        id = 8056,
        cast = 0,
        cooldown = function() return glyph.frost_shock.enabled and 0 or 6 end,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135849,
        
        handler = function()
            applyDebuff("target", "frost_shock")
            if talent.frozen_power.enabled then
                applyDebuff("target", "frozen")
            end
        end,
    },
    
    -- Totems
    searing_totem = {
        id = 3599,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135824,
        
        handler = function()
            applyBuff("searing_totem")
        end,
    },
    
    fire_elemental_totem = {
        id = 2894,
        cast = 0,
        cooldown = function() return glyph.fire_elemental_totem.enabled and 450 or 300 end,
        gcd = "totem",
        
        spend = 0.23,
        spendType = "mana",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 135790,
        
        handler = function()
            applyBuff("fire_elemental_totem")
        end,
    },
    
    magma_totem = {
        id = 8190,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135826,
        
        handler = function()
            applyBuff("magma_totem")
        end,
    },
    
    earthbind_totem = {
        id = 2484,
        cast = 0,
        cooldown = 30,
        gcd = "totem",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136102,
        
        handler = function()
            applyBuff("earthbind_totem")
        end,
    },
    
    capacitor_totem = {
        id = 108269,
        cast = 0,
        cooldown = function() return glyph.capacitor_totem.enabled and 60 or 45 end,
        gcd = "totem",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136013,
        
        handler = function()
            applyBuff("capacitor_totem")
        end,
    },
    
    healing_stream_totem = {
        id = 5394,
        cast = 0,
        cooldown = 30,
        gcd = "totem",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135127,
        
        handler = function()
            applyBuff("healing_stream_totem")
        end,
    },
    
    -- Defensives and utility
    lightning_shield = {
        id = 324,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.2,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136051,
        
        handler = function()
            applyBuff("lightning_shield")
            buff.lightning_shield.stack = 1
        end,
    },
    
    ghost_wolf = {
        id = 2645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136095,
        
        handler = function()
            applyBuff("ghost_wolf")
        end,
    },
    
    spiritwalkers_grace = {
        id = 79206,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 451170,
        
        handler = function()
            applyBuff("spiritwalkers_grace")
        end,
    },
    
    astral_shift = {
        id = 108271,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 538565,
        
        handler = function()
            applyBuff("astral_shift")
        end,
    },
    
    -- Talents
    elemental_mastery = {
        id = 16166,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136115,
        
        handler = function()
            applyBuff("elemental_mastery")
        end,
    },
    
    ancestral_swiftness = {
        id = 16188,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136076,
        
        handler = function()
            applyBuff("ancestral_swiftness")
        end,
    },
    
    stone_bulwark_totem = {
        id = 108270,
        cast = 0,
        cooldown = 60,
        gcd = "totem",
        
        toggle = "defensives",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135861,
        
        handler = function()
            applyBuff("stone_bulwark_totem")
            applyBuff("stone_bulwark_absorb")
        end,
    },
    
    shamanistic_rage = {
        id = 30823,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 136088,
        
        handler = function()
            applyBuff("shamanistic_rage")
        end,
    },
    
    elemental_blast = {
        id = 117014,
        cast = function() return 2 * haste * (buff.elemental_mastery.up and 0.7 or 1) end,
        cooldown = 12,
        gcd = "spell",
        
        spend = 0.15,
        spendType = "mana",
        
        startsCombat = true,
        texture = 651244,
        
        handler = function()
            if talent.echo_of_the_elements.enabled and math.random() < 0.06 then
                -- Simulate Echo of the Elements proc with a 6% chance
                applyBuff("echo_of_the_elements")
            end
        end,
    },
    
    ancestral_guidance = {
        id = 108281,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 538564,
        
        handler = function()
            applyBuff("ancestral_guidance")
        end,
    },
    
    healing_tide_totem = {
        id = 108280,
        cast = 0,
        cooldown = 180,
        gcd = "totem",
        
        toggle = "defensives",
        
        spend = 0.18,
        spendType = "mana",
        
        startsCombat = false,
        texture = 538569,
        
        handler = function()
            applyBuff("healing_tide_totem")
        end,
    },
    
    unleash_elements = {
        id = 73680,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = false,
        texture = 462650,
        
        handler = function()
            applyBuff("unleash_flame")
        end,
    },
} )

-- State Expressions for Elemental
spec:RegisterStateExpr( "fulmination_stacks", function()
    return buff.lightning_shield.stack
end )

-- Range
spec:RegisterRanges( "lightning_bolt", "flame_shock", "earth_shock", "frost_shock", "wind_shear" )

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
    
    package = "Elemental",
} )

-- Default pack for MoP Elemental Shaman
spec:RegisterPack( "Elemental", 20250515, [[Hekili:T1vBVTTnu4FlXiPaQWKrdpvIbKmEbvJRLwwxP2rI1mzQiQ1GIugwwtyQsyBvHnYJP6LP56NHJUHX2Z)OnRXYQZl6R)UNB6QL(zhdkr9bQlG(tB8L4Wdpb3NNVh(GWdFOdpNFpdO8Hdm6Tw(acm2nDWZ5MjsXyJKCtj3cU5sIVOd8jkzPsMLIX65MuLY1jrwLkKWrZA3CluOKCvId8LHIyyIeLSr1WIJ1jPr7cYeKwrJIuWXRKtFDlYkLmCPFJr(4OsZQR]] )

-- Register pack selector for Elemental
spec:RegisterPackSelector( "elemental", "Elemental", "|T136048:0|t Elemental",
    "Handles all aspects of Elemental Shaman DPS with focus on Lightning Bolt/Chain Lightning and Lava Burst usage.",
    nil )
