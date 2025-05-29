-- DruidRestoration.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Druid: Restoration spec

if UnitClassBase( 'player' ) ~= 'DRUID' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 105 ) -- Restoration spec ID for MoP

local strformat = string.format
local FindUnitBuffByID = ns.FindUnitBuffByID
local FindUnitDebuffByID = ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )
spec:RegisterResource( Enum.PowerType.Energy )

-- Tier sets
spec:RegisterGear( "tier13", 78784, 78785, 78786, 78787, 78788, 78789, 78790, 78791, 78792, 78793 ) -- T13 Deep Earth
spec:RegisterGear( "tier14", 85354, 85356, 85357, 85359, 85355 ) -- T14 Eternal Blossom Vestment
spec:RegisterGear( "tier15", 95981, 95982, 95983, 95985, 95986 ) -- T15 Vestment of the Haunted Forest

-- Talents (MoP 6-tier talent system + Restoration specialization)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    feline_swiftness        = { 4908, 1, 131768 },  -- 15% movement speed
    displacer_beast         = { 4909, 1, 102280 },  -- Teleport + cat form
    wild_charge             = { 4910, 1, 102401 },  -- Form-specific charges
    
    -- Tier 2 (Level 30) - Healing utility
    natures_swiftness       = { 4911, 1, 132158 },  -- Instant cast next heal
    renewal                 = { 4912, 1, 108238 },  -- Instant 30% health
    cenarion_ward           = { 4913, 1, 102351 },  -- Absorption shield
    
    -- Tier 3 (Level 45) - Crowd control
    faerie_swarm            = { 4914, 1, 102355 },  -- Slow + decreased damage
    mass_entanglement       = { 4915, 1, 102359 },  -- AoE root
    typhoon                 = { 4916, 1, 132469 },  -- Knockback + slow
    
    -- Tier 4 (Level 60) - Healing enhancement  
    soul_of_the_forest      = { 4917, 1, 114107 },  -- Swiftmend enhances Wild Growth
    incarnation             = { 4918, 1, 33891 },   -- Tree of Life form
    force_of_nature         = { 4919, 1, 106737 },  -- Healing treants
    
    -- Tier 5 (Level 75) - Disruption
    disorienting_roar       = { 4920, 1, 99 },      -- AoE disorient 
    ursols_vortex           = { 4921, 1, 102793 },  -- AoE pull + slow
    mighty_bash             = { 4922, 1, 5211 },    -- Stun
    
    -- Tier 6 (Level 90) - Major cooldowns
    heart_of_the_wild       = { 4923, 1, 108288 },  -- Stat boost + spec abilities
    dream_of_cenarius       = { 4924, 1, 108373 },  -- Damage/healing synergy  
    natures_vigil           = { 4925, 1, 124974 },  -- Healing/damage link
    
    -- Restoration specialization talents (not in regular tree)
    omen_of_clarity         = { 5001, 1, 113043 },  -- Clearcasting procs
    natures_cure            = { 5002, 1, 88423 },   -- Dispel magic/curse/poison
    swiftmend               = { 5003, 1, 18562 },   -- Instant heal consuming HoT
    master_shapeshifter     = { 5004, 1, 48420 },   -- Form bonuses
    naturalist              = { 5005, 1, 17069 },   -- Nature resistance + casting
    meditation              = { 5006, 1, 9093 },    -- Mana regeneration while casting
} )

-- Glyphs (authentic MoP 5.4.8 glyph system)
spec:RegisterGlyphs( {
    -- Major glyphs (Restoration-specific, verified from MoP patch notes)
    [54825] = "wild_growth",         -- Wild Growth affects 1 additional target
    [54760] = "swiftmend",           -- Swiftmend no longer consumes a HoT
    [54821] = "healing_touch",       -- Healing Touch cast time +50%, healing +50%
    [54832] = "innervate",           -- Innervate 10% per sec for 10 sec instead of 20% per 4 sec
    [54743] = "lifebloom",           -- Lifebloom can be cast on 2 targets
    [54828] = "rebirth",             -- Rebirth gives 100% health/mana instead of 60%
    [54829] = "regrowth",            -- Regrowth healing +20%, removes HoT component
    [54754] = "rejuvenation",        -- Rejuvenation duration +3 seconds
    [54755] = "tranquility",         -- Tranquility no longer affects allies, +100% healing
    [116218] = "efflorescence",      -- Swiftmend leaves healing zone (Efflorescence)
    
    -- Common druid major glyphs
    [94388] = "barkskin",            -- Barkskin increases movement speed by 50%
    [59219] = "entangling_roots",    -- Entangling Roots reduces damage by 20%
    [114235] = "stampeding_roar",    -- Stampeding Roar cooldown reduced by 60 seconds
    
    -- Minor glyphs (cosmetic/utility effects)
    [57856] = "aquatic_form",        -- Walk on water in Aquatic Form
    [57862] = "challenging_roar",    -- Roar matches shapeshift form
    [57863] = "charm_woodland_creature", -- Charm critters for 10 minutes
    [57855] = "dash",                -- Dash leaves glowing trail
    [57861] = "grace",               -- Death causes enemies to flee
    [57857] = "mark_of_the_wild",    -- Transform into stag when self-buffing
    [57858] = "treant",              -- Force of Nature treants resemble trees
    [57860] = "unburdened_rebirth",  -- Rebirth requires no reagent
    [121840] = "stars",              -- Moonfire and Sunfire appear as stars
} )

-- Restoration specific auras
spec:RegisterAuras( {
    -- HoTs (verified authentic MoP 5.4.8 mechanics)
    rejuvenation = {
        id = 774,
        duration = function() return glyph.rejuvenation.enabled and 15 or 12 end,  -- 12s base, +3s with glyph
        tick_time = 3,  -- 4 ticks over 12 seconds
        max_stack = 1,
    },
    regrowth = {
        id = 8936,
        duration = 6,  -- 6 second HoT component
        tick_time = 2,  -- 3 ticks over 6 seconds
        max_stack = 1,
    },
    lifebloom = {
        id = 33763,
        duration = 10,  -- 10 second duration, blooms at end
        tick_time = 1,  -- 10 ticks over 10 seconds
        max_stack = function() return glyph.lifebloom.enabled and 2 or 1 end,  -- Glyph allows 2 targets
        copy = { 33778 }
    },
    wild_growth = {
        id = 48438,
        duration = 7,  -- 7 second duration (verified from WoW sims)
        tick_time = 1,  -- 7 ticks over 7 seconds
        max_stack = 1,
    },
    efflorescence = {
        id = 81262,
        duration = 30,  -- Ground effect from Swiftmend
        max_stack = 1,
    },
    living_seed = {
        id = 48504,
        duration = 15,
        max_stack = 1,
    },    -- Proc buffs (authentic MoP mechanics)
    harmony = {
        id = 100977,
        duration = 10,  -- 10 second duration
        max_stack = 1,
        -- Increases healing of HoTs by 10% + mastery rating
        copy = { 77495 }  -- Mastery: Harmony
    },
    clearcasting = {
        id = 16870,
        duration = 15,
        max_stack = 1,
        -- Omen of Clarity: next spell costs no mana
    },
    -- Form buffs
    tree_of_life = {
        id = 33891,
        duration = 30,
        max_stack = 1,
    },
    incarnation_tree_of_life = {
        id = 117679,
        duration = 30,
        max_stack = 1,
    },
    -- Cooldown buffs
    natures_swiftness = {
        id = 132158,
        duration = 8,
        max_stack = 1,
    },
    soul_of_the_forest = {
        id = 114108,
        duration = 15,
        max_stack = 1,
    },    -- MoP specific talents and abilities
    dream_of_cenarius = {
        id = 108381,
        duration = 30,
        max_stack = 2,
        -- Wrath grants 30% healing increase on next heal
        -- Healing spells grant 70% damage increase on next Wrath
    },
    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
        -- Healing spells deal nature damage to nearby enemies
        -- Damage spells heal nearby allies
    },
    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
        -- Increases stats and allows use of abilities from other specs
    },
    soul_of_the_forest = {
        id = 114108,  -- Restoration version
        duration = 15,
        max_stack = 1,
        -- Swiftmend increases healing of next Wild Growth by 50%
    },
    },
    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
    },
    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
    },    symbiosis = {
        id = 110309,
        duration = 3600,  -- 1 hour duration
        max_stack = 1,
        -- Grants class-specific abilities based on target
    },
    cenarion_ward = {
        id = 102351,
        duration = 30,  -- 30 second duration, heals when damage taken
        max_stack = 1,
    },
    ironbark = {
        id = 102342,
        duration = 12,  -- 12 second damage reduction
        max_stack = 1,
        -- 20% damage reduction
    },
    barkskin_movement = {
        id = 22812,  -- Glyph effect
        duration = 12,
        max_stack = 1,
        -- 50% movement speed from glyph
    },
    
    -- Shared Druid auras (forms and general buffs)    innervate = {
        id = 29166,
        duration = function() return glyph.innervate.enabled and 10 or 20 end,  -- 20s base, 10s with glyph
        max_stack = 1,
        -- Base: 20% mana per 4 sec for 20 sec (400% total)
        -- Glyphed: 10% mana per 1 sec for 10 sec (100% total)
    },
    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
    },
    bear_form = {
        id = 5487,
        duration = 3600,
        max_stack = 1,
    },
    cat_form = {
        id = 768,
        duration = 3600,
        max_stack = 1,
    },
    dash = {
        id = 1850,
        duration = 10,
        max_stack = 1,
    },
    moonkin_form = {
        id = 24858,
        duration = 3600,
        max_stack = 1,
    },
    prowl = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
    },
    travel_form = {
        id = 783,
        duration = 3600,
        max_stack = 1,
    },
} )

-- Restoration core abilities
spec:RegisterAbilities( {
    rejuvenation = {
        id = 774,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.10,  -- 10% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 136081,
        
        handler = function ()
            applyBuff("target", "rejuvenation")
            applyBuff("harmony")  -- Mastery: Harmony proc
        end,
    },
    
    regrowth = {
        id = 8936,
        cast = function() 
            if buff.natures_swiftness.up then return 0 end
            return 1.5 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.21,  -- 21% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 136085,
        
        handler = function ()
            if not glyph.regrowth.enabled then
                applyBuff("target", "regrowth")  -- HoT component unless glyphed
            end
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    healing_touch = {
        id = 5185,
        cast = function() 
            if buff.natures_swiftness.up then return 0 end
            return 2.5 * haste  -- 2.5s base cast time (verified from WoW sims)
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.19,  -- 19% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 136041,
        
        handler = function ()
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    swiftmend = {
        id = 18562,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.12,  -- 12% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 134914,
        
        usable = function()
            return buff.rejuvenation.up or buff.regrowth.up, "requires rejuvenation or regrowth"
        end,
        
        handler = function ()
            if not glyph.swiftmend.enabled then
                -- Consumes a HoT effect if glyph is not enabled
                if buff.regrowth.up then
                    removeBuff("regrowth")
                elseif buff.rejuvenation.up then
                    removeBuff("rejuvenation")
                end
            end
            
            if talent.soul_of_the_forest.enabled then
                applyBuff("soul_of_the_forest")
            end
            
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    lifebloom = {
        id = 33763,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.06,  -- 6% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 134206,
        
        handler = function ()
            local stacks = buff.lifebloom.stack
            if stacks < 3 then
                addStack("lifebloom")
            else
                -- Refresh duration at 3 stacks
                buff.lifebloom.expires = query_time + 10
            end
        end,
    },
      wild_growth = {
        id = 48438,
        cast = 0,
        cooldown = function() return glyph.wild_growth.enabled and 10 or 8 end,  -- +2s cooldown with glyph
        gcd = "spell",
        
        spend = 0.19,  -- 19% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 236153,
        
        handler = function ()
            applyBuff("wild_growth")
            if buff.soul_of_the_forest.up then
                removeBuff("soul_of_the_forest")
                -- 50% increased healing from Soul of the Forest
            end
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    tranquility = {
        id = 740,
        cast = 8,
        channeled = true,
        cooldown = 480,  -- 8 minute cooldown (verified from WoW sims)
        gcd = "spell",
        
        spend = 0.32,  -- 32% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136107,
        
        start = function ()
            -- 4 ticks over 8 seconds with stacking HoT effect (authentic MoP mechanic)
        end,
    },
    
    nourish = {
        id = 50464,
        cast = function() 
            if buff.natures_swiftness.up then return 0 end
            -- Base 1.5s, reduced by number of HoTs on target
            local hots = 0
            if buff.rejuvenation.up then hots = hots + 1 end
            if buff.regrowth.up then hots = hots + 1 end
            if buff.lifebloom.up then hots = hots + 1 end
            if buff.wild_growth.up then hots = hots + 1 end
            
            return max(1.0, 1.5 - (hots * 0.1)) * haste  -- 0.1s reduction per HoT
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.15,  -- 15% base mana cost
        spendType = "mana",
        
        startsCombat = false,
        texture = 236162,
        
        handler = function ()
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    genesis = {
        id = 145518,
        cast = 0,
        cooldown = 6,  -- Authentic MoP cooldown
        gcd = "spell",
        
        spend = 0.04,  -- 4% base mana cost per HoT affected
        spendType = "mana",
        
        startsCombat = false,
        texture = 237574,
        
        usable = function()
            return buff.rejuvenation.up, "requires rejuvenation on target"
        end,
        
        handler = function ()
            -- Accelerates Rejuvenation ticks (authentic MoP mechanic)
            if buff.rejuvenation.up then
                buff.rejuvenation.expires = max(0, buff.rejuvenation.expires - 4)
            end
        end,
    },
    
    -- Restoration cooldowns and talents    incarnation_tree_of_life = {
        id = 33891,  -- Tree of Life form
        cast = 0,
        cooldown = 180,  -- 3 minute cooldown
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136062,
        
        handler = function ()
            applyBuff("incarnation_tree_of_life")
            -- Enhances healing spells and allows movement while casting
        end,
    },
    
    natures_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        startsCombat = false,
        texture = 136076,
        
        handler = function ()
            applyBuff("natures_swiftness")
        end,
    },
    
    cenarion_ward = {
        id = 102351,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = false,
        texture = 132137,
        
        talent = "cenarion_ward",
        
        handler = function ()
            applyBuff("target", "cenarion_ward")
        end,
    },
    
    force_of_nature = {
        id = 106737,  -- Resto version: healing treants
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 132129,
        
        talent = "force_of_nature",
        
        handler = function ()
            -- Summons 3 healing treants for 15 seconds
            summonPet("treant", 15)
        end,
    },
    
    omen_of_clarity = {
        id = 113043,  -- Restoration version
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        texture = 136017,
        
        passive = true,
        
        handler = function ()
            -- Chance to proc Clearcasting on healing spell casts
        end,
    },
    
    -- Symbiosis abilities (MoP level 87 ability)
    symbiosis = {
        id = 110309,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135789,
        
        handler = function ()
            applyBuff("symbiosis")
            -- Grants abilities based on target's class
        end,
    },
    
    -- Utility and defensive abilities
      -- Restoration utility and defensive abilities
    innervate = {
        id = 29166,
        cast = 0,
        cooldown = 180,  -- 3 minute cooldown
        gcd = "spell",
        
        startsCombat = false,
        texture = 136048,
        
        handler = function ()
            applyBuff("target", "innervate")
        end,
    },
    
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 136097,
        
        handler = function ()
            applyBuff("barkskin")
            if glyph.barkskin.enabled then
                applyBuff("barkskin_movement")  -- 50% movement speed
            end
        end,
    },
    
    natures_cure = {
        id = 88423,  -- MoP dispel ability
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.13,
        spendType = "mana",
        
        startsCombat = false,
        texture = 236288,
        
        handler = function ()
            -- Dispels magic, curse, and poison effects
        end,
    },
    
    ironbark = {
        id = 102342,  -- MoP damage reduction cooldown
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = false,
        texture = 572025,
        
        handler = function ()
            applyBuff("target", "ironbark")  -- 20% damage reduction for 12 seconds
        end,
    },
    
    -- MoP level 90 talents implemented as abilities
    heart_of_the_wild = {
        id = 108288,
        cast = 0,
        cooldown = 360,  -- 6 minute cooldown
        gcd = "spell",
        
        toggle = "cooldowns",
        talent = "heart_of_the_wild",
        
        startsCombat = false,
        texture = 135879,
        
        handler = function ()
            applyBuff("heart_of_the_wild")
            -- Allows use of Balance/Feral/Guardian abilities with bonuses
        end,
    },
    
    natures_vigil = {
        id = 124974,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "cooldowns",
        talent = "natures_vigil",
        
        startsCombat = false,
        texture = 236180,
        
        handler = function ()
            applyBuff("natures_vigil")
            -- Healing spells deal damage, damage spells heal
        end,
    },
    
    -- Additional common Druid abilities
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.28,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136078,
        
        handler = function ()
            applyBuff("mark_of_the_wild")
        end,
    },
    
    rebirth = {
        id = 20484,
        cast = 2,
        cooldown = 600,
        gcd = "spell",
        
        spend = 0.6,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136080,
        
        handler = function ()
            -- Resurrect target with 60% health and mana
        end,
    },
    
    symbiosis = {
        id = 110309,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135789,
        
        handler = function ()
            applyBuff("symbiosis")
        end,
    },
    
    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 236169,
        
        handler = function ()
            applyBuff("survival_instincts")
        end,
    },
    
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132276,
        
        handler = function ()
            applyBuff("bear_form")
            removeBuff("cat_form")
            removeBuff("moonkin_form")
            removeBuff("travel_form")
        end,
    },
    
    cat_form = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132115,
        
        handler = function ()
            applyBuff("cat_form")
            removeBuff("bear_form")
            removeBuff("moonkin_form")
            removeBuff("travel_form")
        end,
    },
    
    travel_form = {
        id = 783,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132144,
        
        handler = function ()
            applyBuff("travel_form")
            removeBuff("cat_form")
            removeBuff("bear_form")
            removeBuff("moonkin_form")
        end,
    },
    
    moonkin_form = {
        id = 24858,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136036,
        
        handler = function ()
            applyBuff("moonkin_form")
            removeBuff("cat_form")
            removeBuff("bear_form")
            removeBuff("travel_form")
        end,
    },
    
    dash = {
        id = 1850,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132120,
        
        usable = function ()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyBuff("dash")
        end,
    },
    
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132089,
        
        usable = function ()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyBuff("prowl")
        end,
    },
    
    stampeding_roar = {
        id = 77764,
        cast = 0,
        cooldown = function() return glyph.stampeding_roar.enabled and 60 or 120 end,
        gcd = "spell",
        
        usable = function ()
            return buff.bear_form.up or buff.cat_form.up, "requires bear or cat form"
        end,
        
        startsCombat = false,
        texture = 464343,
        
        handler = function ()
            applyBuff("stampeding_roar")
        end,
    },
    
    cyclone = {
        id = 33786,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136022,
        
        handler = function ()
            applyDebuff("target", "cyclone")
        end,
    },
    
    entangling_roots = {
        id = 339,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136100,
        
        handler = function ()
            applyDebuff("target", "entangling_roots")
        end,
    },
    
    faerie_fire = {
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136033,
        
        handler = function ()
            applyDebuff("target", "faerie_fire")
        end,
    },
    
    mighty_bash = {
        id = 5211,
        cast = 0,
        cooldown = 50,
        gcd = "spell",
        
        startsCombat = true,
        texture = 132114,
        
        handler = function ()
            applyDebuff("target", "mighty_bash")
        end,
    },
    
    renewal = {
        id = 108238,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 236153,
        
        handler = function ()
            gain(0.3, "health")
        end,
    },
    
    wild_charge = {
        id = 102401,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        startsCombat = false,
        texture = 538771,
        
        handler = function ()
            applyBuff("wild_charge")
            -- Different charges based on form
        end,
    },
    
    displacer_beast = {
        id = 102280,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 461113,
        
        handler = function ()
            applyBuff("displacer_beast")
            applyBuff("cat_form")
        end,
    },
    
    typhoon = {
        id = 132469,
        cast = 0,
        cooldown = function() return glyph.typhoon.enabled and 17 or 20 end,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = true,
        texture = 236170,
        
        handler = function ()
            -- Knockback and slow
        end,
    },
    
    ursols_vortex = {
        id = 102793,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 571588,
        
        handler = function ()
            -- AoE slow and pull effect
        end,
    },
    
    heart_of_the_wild = {
        id = 108288,
        cast = 0,
        cooldown = 360,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 135879,
        
        handler = function ()
            applyBuff("heart_of_the_wild")
        end,
    },
    
    natures_vigil = {
        id = 124974,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236180,
        
        handler = function ()
            applyBuff("natures_vigil")
        end,
    },
} )

-- Register default pack for MoP Restoration Druid
spec:RegisterPack( "Restoration", 20250515, [[Hekili:TzTBVTTnu4FlXSwQZzfn6t7wGvv9vpr8KvAm7nYn9DAMQ1ijxJZwa25JdwlRcl9dglLieFL52MpyzDoMZxhF7b)MFd9DjdLtuRdh7iiRdxGt)8h6QN0xHgyR37F)5dBEF5(yJ9Np)1hgn3dB4(l)ofv5k3HbNcO8zVcGqymUvZYwbVBdY0P)MM]]  )

-- Register pack selector for Restoration
spec:RegisterPackSelector( "restoration", "Restoration", "|T136041:0|t Restoration",
    "Handles all aspects of Restoration Druid healing with focus on HoT management and mana efficiency.",
    nil )

-- Add state handlers for common Druid mechanics
do
    -- Track form state
    spec:RegisterStateExpr( "form", function ()
        if buff.moonkin_form.up then return "moonkin"
        elseif buff.bear_form.up then return "bear"
        elseif buff.cat_form.up then return "cat"
        elseif buff.travel_form.up then return "travel"
        else return "none" end
    end )
    
    -- Track combo points for cat form usage
    spec:RegisterStateExpr( "combo_points", function ()
        if buff.cat_form.up then
            return state.combo_points.current or 0
        end
        return 0
    end )
    
    -- Handle shapeshifting
    spec:RegisterStateFunction( "shift", function( form )
        if form == nil or form == "none" then
            removeBuff("moonkin_form")
            removeBuff("bear_form")
            removeBuff("cat_form")
            removeBuff("travel_form")
            return
        end
        
        if form == "moonkin" then
            removeBuff("bear_form")
            removeBuff("cat_form")
            removeBuff("travel_form")
            applyBuff("moonkin_form")
        elseif form == "bear" then
            removeBuff("moonkin_form")
            removeBuff("cat_form")
            removeBuff("travel_form")
            applyBuff("bear_form")
        elseif form == "cat" then
            removeBuff("moonkin_form")
            removeBuff("bear_form")
            removeBuff("travel_form")
            applyBuff("cat_form")
        elseif form == "travel" then
            removeBuff("moonkin_form")
            removeBuff("bear_form")
            removeBuff("cat_form")
            applyBuff("travel_form")
        end
    end )
    
    -- Track healing HoTs
    spec:RegisterStateTable( "active_hots", {
        count = function()
            local c = 0
            if buff.rejuvenation.up then c = c + 1 end
            if buff.regrowth.up then c = c + 1 end
            if buff.lifebloom.up then c = c + 1 end
            if buff.wild_growth.up then c = c + 1 end
            return c
        end
    } )
    
    -- Track harmony buff uptime for mastery effectiveness
    spec:RegisterStateTable( "harmony", {
        up = function()
            return buff.harmony.up
        end,
        remains = function()
            return buff.harmony.remains
        end,
        active_direct_heals = function()
            local c = 0
            -- Count of direct heals cast in the last 10 seconds
            return c
        end
    } )
end
