-- PriestShadow.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Priest: Shadow spec

if UnitClassBase( 'player' ) ~= 'PRIEST' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 258 ) -- Shadow spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )

-- Shadow Orbs resource system
spec:RegisterStateTable( "shadow_orb", setmetatable({}, {
    __index = function( t, k )
        if k == "count" then
            return FindUnitBuffByID("player", 77487) and FindUnitBuffByID("player", 77487).count or 0
        end
        return 0
    end,
}))

-- Tier sets
spec:RegisterGear( "tier14", 85316, 85317, 85318, 85319, 85320 ) -- T14 Shadow Priest Set
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- T15 Shadow Priest Set

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

    -- Tier 5 (Level 75) - Shadow Enhancement
    twist_of_fate             = { 2307, 1, 109142 }, -- +20% damage/healing to targets below 35% health
    power_infusion            = { 2308, 1, 10060  }, -- +40% spell haste for 15 sec
    divine_insight            = { 2309, 1, 109175 }, -- Shadow Word: Pain periodic damage has chance to reset Mind Blast

    -- Tier 6 (Level 90) - Ultimate
    cascade                   = { 2310, 1, 121135 }, -- Healing/damaging bolt that bounces to targets
    divine_star               = { 2311, 1, 110744 }, -- Projectile travels forward and back, healing/damaging
    halo                      = { 2312, 1, 120517 }  -- Ring of light expands outward, healing/damaging
} )

-- Glyphs (MoP system)
spec:RegisterGlyphs( {
    [55687] = "dispersion",
    [55680] = "dispel_magic", 
    [42408] = "fade",
    [55684] = "fortitude",
    [55675] = "holy_nova",
    [55678] = "inner_fire",
    [42414] = "levitate",
    [55682] = "mass_dispel",
    [42415] = "mind_control",
    [55688] = "mind_flay",
    [55679] = "mind_spike",
    [55689] = "psychic_horror",
    [55681] = "psychic_scream",
    [42413] = "shadow_word_death",
    [55676] = "shadow_word_pain",
    [42416] = "spirit_of_redemption",
    [55690] = "vampiric_embrace",
} )

-- Shadow specific auras
spec:RegisterAuras( {
    -- Shadow Orbs
    shadow_orb = {
        id = 77487,
        duration = 3600,
        max_stack = 3,
    },
    
    -- Shadowform
    shadowform = {
        id = 15473,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Shadow Word: Pain
    shadow_word_pain = {
        id = 589,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
    },
    
    -- Vampiric Touch
    vampiric_touch = {
        id = 34914,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
    },
    
    -- Devouring Plague
    devouring_plague = {
        id = 2944,
        duration = 24,
        tick_time = 3,
        max_stack = 1,
    },
    
    -- Mind Flay (channeled)
    mind_flay = {
        id = 15407,
        duration = 3,
        tick_time = 1,
        max_stack = 1,
    },
    
    -- Dispersion
    dispersion = {
        id = 47585,
        duration = 6,
        max_stack = 1,
    },
    
    -- Vampiric Embrace
    vampiric_embrace = {
        id = 15286,
        duration = 15,
        max_stack = 1,
    },
    
    -- Inner Fire
    inner_fire = {
        id = 588,
        duration = 1800,
        max_stack = 1,
    },
    
    -- Power Word: Shield
    power_word_shield = {
        id = 17,
        duration = 15,
        max_stack = 1,
    },
    
    -- Weakened Soul
    weakened_soul = {
        id = 6788,
        duration = 15,
        max_stack = 1,
    },
    
    -- Surge of Darkness (instant Mind Spike)
    surge_of_darkness = {
        id = 87160,
        duration = 10,
        max_stack = 3,
    },
    
    -- Mind Melt (Mind Spike stacks)
    mind_melt = {
        id = 81292,
        duration = 10,
        max_stack = 3,
    },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Shadowform
    shadowform = {
        id = 15473,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        handler = function ()
            if buff.shadowform.up then
                removeBuff( "shadowform" )
            else
                applyBuff( "shadowform" )
            end
        end,
    },
    
    -- Shadow Word: Pain
    shadow_word_pain = {
        id = 589,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.22,
        spendType = "mana",
        
        handler = function ()
            applyDebuff( "target", "shadow_word_pain" )
        end,
    },
    
    -- Vampiric Touch
    vampiric_touch = {
        id = 34914,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.20,
        spendType = "mana",
        
        handler = function ()
            applyDebuff( "target", "vampiric_touch" )
        end,
    },
    
    -- Devouring Plague
    devouring_plague = {
        id = 2944,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 3,
        spendType = "shadow_orb",
        
        usable = function () return shadow_orb.count >= 3 end,
        
        handler = function ()
            applyDebuff( "target", "devouring_plague" )
            shadow_orb.count = 0
        end,
    },
    
    -- Mind Blast
    mind_blast = {
        id = 8092,
        cast = 1.5,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        handler = function ()
            if shadow_orb.count < 3 then
                shadow_orb.count = shadow_orb.count + 1
            end
        end,
    },
    
    -- Mind Flay
    mind_flay = {
        id = 15407,
        cast = 3,
        channeled = true,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        start = function ()
            applyDebuff( "target", "mind_flay" )
        end,
        
        tick = function ()
            if shadow_orb.count < 3 then
                shadow_orb.count = shadow_orb.count + 1
            end
        end,
    },
    
    -- Mind Spike
    mind_spike = {
        id = 73510,
        cast = function () return buff.surge_of_darkness.up and 0 or 1.5 end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function () return buff.surge_of_darkness.up and 0 or 0.18 end,
        spendType = "mana",
        
        handler = function ()
            if buff.surge_of_darkness.up then
                removeBuff( "surge_of_darkness" )
            end
            
            if buff.mind_melt.up then
                applyBuff( "mind_melt", nil, min( 3, buff.mind_melt.stack + 1 ) )
            else
                applyBuff( "mind_melt" )
            end
            
            -- Remove DoTs
            removeDebuff( "target", "shadow_word_pain" )
            removeDebuff( "target", "vampiric_touch" )
        end,
    },
    
    -- Shadow Word: Death
    shadow_word_death = {
        id = 32379,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        handler = function ()
            if shadow_orb.count < 3 then
                shadow_orb.count = shadow_orb.count + 1
            end
        end,
    },
    
    -- Psychic Horror
    psychic_horror = {
        id = 64044,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
    },
    
    -- Psychic Scream
    psychic_scream = {
        id = 8122,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.15,
        spendType = "mana",
    },
    
    -- Dispersion
    dispersion = {
        id = 47585,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        handler = function ()
            applyBuff( "dispersion" )
        end,
    },
    
    -- Vampiric Embrace
    vampiric_embrace = {
        id = 15286,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        handler = function ()
            applyBuff( "vampiric_embrace" )
        end,
    },
    
    -- Power Word: Shield
    power_word_shield = {
        id = 17,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.23,
        spendType = "mana",
        
        handler = function ()
            applyBuff( "power_word_shield" )
            applyDebuff( "target", "weakened_soul" )
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
    
    -- Shadowfiend
    shadowfiend = {
        id = 34433,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
    },
    
    -- Fade
    fade = {
        id = 586,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
    },
} )

-- Register default pack for MoP Shadow Priest
spec:RegisterPack( "Shadow", 20250528, [[Hekili:T1PBVTTn04FlXjHj0Ofnr0i4Lvv9n0KxkzPORkyzyV1ikA2mzZ(fQ1Hm8kkjjjjlvQKKQKYfan1Y0YPpNvFupNLJLhum9DbDps9yVDJnLHrdlRJsrkzpNISnPnkTkUk(qNGYXnENRNpnS2)YBFm(nEF5(wB5OxZ)m45MyiytnisgMPzJfW2vZYwbpzw0aD6w)aW]] )

-- Register pack selector for Shadow
spec:RegisterPackSelector( "shadow", "Shadow", "|T136207:0|t Shadow",
    "Handles all aspects of Shadow Priest DPS with focus on DoT management and Shadow Orb generation.",
    nil )
