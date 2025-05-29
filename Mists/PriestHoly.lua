-- PriestHoly.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Priest: Holy spec

if UnitClassBase( 'player' ) ~= 'PRIEST' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 257 ) -- Holy spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )

-- Tier sets
spec:RegisterGear( "tier14", 85316, 85317, 85318, 85319, 85320 ) -- T14 Holy Priest Set
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- T15 Holy Priest Set

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Healing/Utility
    void_tendrils             = { 2295, 1, 108920 }, -- Shadowy tendrils immobilize all enemies for 8 sec
    psyfiend                  = { 2296, 1, 108921 }, -- Pet that fears target every 4 sec for 20 sec
    dominate_mind             = { 2297, 1, 108968 }, -- Controls enemy for 8 sec

    -- Tier 2 (Level 30) - Movement
    body_and_soul             = { 2298, 1, 64129  }, -- Power Word: Shield increases movement speed by 60%
    angelic_feather           = { 2299, 1, 121536 }, -- Places feather that grants 80% movement speed
    phantasm                  = { 2300, 1, 108942 }, -- Fade grants immunity to movement impairing effects

    -- Tier 3 (Level 45) - Survivability
    from_darkness_comes_light = { 2301, 1, 109186 }, -- Damage spells have chance to reset Flash Heal
    mindbender                = { 2302, 1, 123040 }, -- Shadowfiend that returns 4% mana per hit
    archangel                 = { 2303, 1, 81700  }, -- Consumes Evangelism for healing/damage increase

    -- Tier 4 (Level 60) - Control
    desperate_prayer          = { 2304, 1, 19236  }, -- Instantly heals for 30% of max health
    spectral_guise            = { 2305, 1, 112833 }, -- Instantly become invisible for 6 sec
    angelic_bulwark           = { 2306, 1, 108945 }, -- Shield absorbs when health drops below 30%

    -- Tier 5 (Level 75) - Healing Enhancement
    twist_of_fate             = { 2307, 1, 109142 }, -- +20% damage/healing to targets below 35% health
    power_infusion            = { 2308, 1, 10060  }, -- +40% spell haste for 15 sec
    serenity                  = { 2309, 1, 14914  }, -- Reduces all spell cooldowns by 4 sec

    -- Tier 6 (Level 90) - Ultimate
    cascade                   = { 2310, 1, 121135 }, -- Healing/damaging bolt that bounces to targets
    divine_star               = { 2311, 1, 110744 }, -- Projectile travels forward and back, healing/damaging
    halo                      = { 2312, 1, 120517 }  -- Ring of light expands outward, healing/damaging
} )

-- Glyphs (MoP system)
spec:RegisterGlyphs( {
    [55672] = "circle_of_healing",
    [55680] = "dispel_magic", 
    [42408] = "fade",
    [55677] = "fear_ward",
    [120581] = "focused_mending",
    [55684] = "fortitude",
    [56161] = "guardian_spirit",
    [55675] = "holy_nova",
    [63248] = "hymn_of_hope",
    [55678] = "inner_fire",
    [42414] = "levitate",
    [55682] = "mass_dispel",
    [42415] = "mind_control",
    [55679] = "mind_spike",
    [42409] = "power_word_barrier",
    [55685] = "power_word_shield",
    [42417] = "prayer_of_healing",
    [42410] = "prayer_of_mending",
    [55674] = "psychic_horror",
    [55681] = "psychic_scream",
    [42412] = "renew",
    [42411] = "scourge_imprisonment",
    [42413] = "shadow_word_death",
    [55676] = "shadow_word_pain",
    [42416] = "spirit_of_redemption",
    [55673] = "weakened_soul",
} )

-- Holy specific auras
spec:RegisterAuras( {
    -- Chakra states
    chakra_serenity = {
        id = 81208,
        duration = 3600,
        max_stack = 1,
    },
    
    chakra_sanctuary = {
        id = 81206,
        duration = 3600,
        max_stack = 1,
    },
    
    chakra_chastise = {
        id = 81209,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Serendipity (faster heals after binding heal/flash heal)
    serendipity = {
        id = 63733,
        duration = 20,
        max_stack = 2,
    },
    
    -- Surge of Light (free instant Flash Heal)
    surge_of_light = {
        id = 33151,
        duration = 10,
        max_stack = 2,
    },
    
    -- Spirit of Redemption
    spirit_of_redemption = {
        id = 27827,
        duration = 15,
        max_stack = 1,
    },
    
    -- Inspiration (damage reduction after crit heal)
    inspiration = {
        id = 390,
        duration = 15,
        max_stack = 1,
    },
    
    -- Guardian Spirit
    guardian_spirit = {
        id = 47788,
        duration = 10,
        max_stack = 1,
    },
    
    -- Circle of Healing
    circle_of_healing = {
        id = 34861,
        duration = 0,
        max_stack = 1,
    },
    
    -- Prayer of Mending
    prayer_of_mending = {
        id = 33076,
        duration = 10,
        max_stack = 1,
    },
    
    -- Renew
    renew = {
        id = 139,
        duration = 15,
        max_stack = 1,
    },
    
    -- Inner Fire
    inner_fire = {
        id = 588,
        duration = 1800,
        max_stack = 1,
    },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Chakra
    chakra = {
        id = 14751,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        handler = function ()
            -- Chakra state depends on next spell cast
        end,
    },
    
    -- Heal (enters Chakra: Serenity)
    heal = {
        id = 2050,
        cast = 3.0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.25,
        spendType = "mana",
        
        handler = function ()
            if buff.chakra.up then
                applyBuff( "chakra_serenity" )
            end
            if buff.serendipity.up then
                removeBuff( "serendipity" )
            end
        end,
    },
    
    -- Greater Heal
    greater_heal = {
        id = 2060,
        cast = function () return buff.serendipity.up and ( 2.5 - 0.5 * buff.serendipity.stack ) or 2.5 end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.32,
        spendType = "mana",
        
        handler = function ()
            if buff.serendipity.up then
                removeBuff( "serendipity" )
            end
        end,
    },
    
    -- Flash Heal
    flash_heal = {
        id = 2061,
        cast = function () return buff.surge_of_light.up and 0 or 1.5 end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function () return buff.surge_of_light.up and 0 or 0.30 end,
        spendType = "mana",
        
        handler = function ()
            if buff.surge_of_light.up then
                removeBuff( "surge_of_light" )
            else
                if buff.serendipity.up then
                    applyBuff( "serendipity", nil, min( 2, buff.serendipity.stack + 1 ) )
                else
                    applyBuff( "serendipity" )
                end
            end
        end,
    },
    
    -- Prayer of Healing (enters Chakra: Sanctuary)
    prayer_of_healing = {
        id = 596,
        cast = 3.0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.48,
        spendType = "mana",
        
        handler = function ()
            if buff.chakra.up then
                applyBuff( "chakra_sanctuary" )
            end
        end,
    },
    
    -- Circle of Healing
    circle_of_healing = {
        id = 34861,
        cast = 0,
        cooldown = function () return buff.chakra_sanctuary.up and 10 or 15 end,
        gcd = "spell",
        
        spend = 0.31,
        spendType = "mana",
    },
    
    -- Prayer of Mending
    prayer_of_mending = {
        id = 33076,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.24,
        spendType = "mana",
        
        handler = function ()
            applyBuff( "prayer_of_mending" )
        end,
    },
    
    -- Renew
    renew = {
        id = 139,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        handler = function ()
            applyDebuff( "target", "renew" )
        end,
    },
    
    -- Guardian Spirit
    guardian_spirit = {
        id = 47788,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        handler = function ()
            applyBuff( "guardian_spirit" )
        end,
    },
    
    -- Smite (enters Chakra: Chastise)
    smite = {
        id = 585,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.16,
        spendType = "mana",
        
        handler = function ()
            if buff.chakra.up then
                applyBuff( "chakra_chastise" )
            end
        end,
    },
    
    -- Holy Fire
    holy_fire = {
        id = 14914,
        cast = 2.5,
        cooldown = function () return buff.chakra_chastise.up and 6 or 10 end,
        gcd = "spell",
        
        spend = 0.11,
        spendType = "mana",
        
        handler = function ()
            applyDebuff( "target", "holy_fire" )
        end,
    },
    
    -- Inner Fire
    inner_fire = {
        id = 588,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.13,
        spendType = "mana",
        
        handler = function ()
            applyBuff( "inner_fire" )
        end,
    },
    
    -- Binding Heal
    binding_heal = {
        id = 32546,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.27,
        spendType = "mana",
        
        handler = function ()
            if buff.serendipity.up then
                applyBuff( "serendipity", nil, min( 2, buff.serendipity.stack + 1 ) )
            else
                applyBuff( "serendipity" )
            end
        end,
    },
    
    -- Divine Hymn
    divine_hymn = {
        id = 64843,
        cast = 8,
        cooldown = 480,
        gcd = "spell",
        
        spend = 0.36,
        spendType = "mana",
    },
    
    -- Hymn of Hope
    hymn_of_hope = {
        id = 64901,
        cast = 8,
        cooldown = 360,
        gcd = "spell",
    },
} )

-- Register default pack for MoP Holy Priest
spec:RegisterPack( "Holy", 20250528, [[Hekili:T1PBVTTn04FlXjHj0Ofnr0i4Lvv9n0KxkzPORkyzyV1ikA2mzZ(fQ1Hm8kkjjjjlvQKKQKYfan1Y0YPpNvFupNLJLhum9DbDps9yVDJnLHrdlRJsrkzpNISnPnkTkUk(qNGYXnENRNpnS2)YBFm(nEF5(wB5OxZ)m45MyiytnisgMPzJfW2vZYwbpzw0aD6w)aW]] )

-- Register pack selector for Holy
spec:RegisterPackSelector( "holy", "Holy", "|T135920:0|t Holy",
    "Handles all aspects of Holy Priest healing with focus on AoE healing and chakra states.",
    nil )
