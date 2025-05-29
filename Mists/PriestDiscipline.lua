-- PriestDiscipline.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Priest: Discipline spec

if UnitClassBase( 'player' ) ~= 'PRIEST' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 256 ) -- Discipline spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )

-- Tier sets
spec:RegisterGear( "tier14", 85316, 85317, 85318, 85319, 85320 ) -- T14 Discipline Priest Set
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- T15 Discipline Priest Set

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

-- Discipline specific auras
spec:RegisterAuras( {
    -- Power Word: Shield
    power_word_shield = {
        id = 17,
        duration = 15,
        max_stack = 1,
    },
    
    -- Weakened Soul (prevents shield reapplication)
    weakened_soul = {
        id = 6788,
        duration = 15,
        max_stack = 1,
    },
    
    -- Grace (increases healing received)
    grace = {
        id = 77613,
        duration = 8,
        max_stack = 3,
    },
    
    -- Evangelism (stacks for Archangel)
    evangelism = {
        id = 81661,
        duration = 20,
        max_stack = 5,
    },
    
    -- Archangel (healing/damage buff)
    archangel = {
        id = 81700,
        duration = 18,
        max_stack = 1,
    },
    
    -- Borrowed Time (haste after shield cast)
    borrowed_time = {
        id = 59889,
        duration = 6,
        max_stack = 1,
    },
    
    -- Inner Fire
    inner_fire = {
        id = 588,
        duration = 1800,
        max_stack = 1,
    },
    
    -- Prayer of Mending
    prayer_of_mending = {
        id = 33076,
        duration = 10,
        max_stack = 1,
    },
    
    -- Rapture (mana return from shield absorption)
    rapture = {
        id = 47755,
        duration = 8,
        max_stack = 1,
    },
} )

-- Abilities
spec:RegisterAbilities( {
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
            applyBuff( "borrowed_time" )
        end,
    },
    
    -- Greater Heal
    greater_heal = {
        id = 2060,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.32,
        spendType = "mana",
        
        handler = function ()
            if debuff.grace.up then
                applyDebuff( "target", "grace", nil, min( 3, debuff.grace.stack + 1 ) )
            else
                applyDebuff( "target", "grace" )
            end
        end,
    },
    
    -- Flash Heal
    flash_heal = {
        id = 2061,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.30,
        spendType = "mana",
        
        handler = function ()
            if debuff.grace.up then
                applyDebuff( "target", "grace", nil, min( 3, debuff.grace.stack + 1 ) )
            else
                applyDebuff( "target", "grace" )
            end
        end,
    },
    
    -- Heal
    heal = {
        id = 2050,
        cast = 3.0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.25,
        spendType = "mana",
        
        handler = function ()
            if debuff.grace.up then
                applyDebuff( "target", "grace", nil, min( 3, debuff.grace.stack + 1 ) )
            else
                applyDebuff( "target", "grace" )
            end
        end,
    },
    
    -- Prayer of Healing
    prayer_of_healing = {
        id = 596,
        cast = 3.0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.48,
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
    
    -- Penance
    penance = {
        id = 47540,
        cast = 2.0,
        cooldown = 10,
        gcd = "spell",
        
        spend = 0.16,
        spendType = "mana",
        
        handler = function ()
            if buff.evangelism.up then
                applyBuff( "evangelism", nil, min( 5, buff.evangelism.stack + 1 ) )
            else
                applyBuff( "evangelism" )
            end
        end,
    },
    
    -- Smite
    smite = {
        id = 585,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.16,
        spendType = "mana",
        
        handler = function ()
            if buff.evangelism.up then
                applyBuff( "evangelism", nil, min( 5, buff.evangelism.stack + 1 ) )
            else
                applyBuff( "evangelism" )
            end
        end,
    },
    
    -- Holy Fire
    holy_fire = {
        id = 14914,
        cast = 2.5,
        cooldown = 10,
        gcd = "spell",
        
        spend = 0.11,
        spendType = "mana",
        
        handler = function ()
            if buff.evangelism.up then
                applyBuff( "evangelism", nil, min( 5, buff.evangelism.stack + 1 ) )
            else
                applyBuff( "evangelism" )
            end
            applyDebuff( "target", "holy_fire" )
        end,
    },
    
    -- Archangel
    archangel = {
        id = 81700,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        talent = "archangel",
        
        usable = function () return buff.evangelism.stack > 0 end,
        
        handler = function ()
            local stacks = buff.evangelism.stack
            removeBuff( "evangelism" )
            applyBuff( "archangel", nil, stacks )
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
    
    -- Power Word: Barrier
    power_word_barrier = {
        id = 62618,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0.44,
        spendType = "mana",
    },
    
    -- Pain Suppression
    pain_suppression = {
        id = 33206,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
    },
    
    -- Guardian Spirit
    guardian_spirit = {
        id = 47788,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
    },
} )

-- Register default pack for MoP Discipline Priest
spec:RegisterPack( "Discipline", 20250528, [[Hekili:T1PBVTTn04FlXjHj0Ofnr0i4Lvv9n0KxkzPORkyzyV1ikA2mzZ(fQ1Hm8kkjjjjlvQKKQKYfan1Y0YPpNvFupNLJLhum9DbDps9yVDJnLHrdlRJsrkzpNISnPnkTkUk(qNGYXnENRNpnS2)YBFm(nEF5(wB5OxZ)m45MyiytnisgMPzJfW2vZYwbpzw0aD6w)aW]] )

-- Register pack selector for Discipline
spec:RegisterPackSelector( "discipline", "Discipline", "|T135940:0|t Discipline",
    "Handles all aspects of Discipline Priest healing with focus on shield usage and Atonement healing.",
    nil )
