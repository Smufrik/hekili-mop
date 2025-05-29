-- DruidBalance.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Druid: Balance spec

if UnitClassBase( 'player' ) ~= 'DRUID' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 102 ) -- Balance spec ID for MoP

local strformat = string.format
local FindUnitBuffByID = ns.FindUnitBuffByID
local FindUnitDebuffByID = ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.Mana )
spec:RegisterResource( Enum.PowerType.Energy )
spec:RegisterResource( Enum.PowerType.LunarPower, {
    eclipse = {
        last = function ()
            return state.swing.last_taken
        end,

        interval = function ()
            return state.swing.swing_time
        end,

        stop = function ()
            return state.swing.last_taken == 0
        end,

        value = 0,
    }
} )

-- Tier sets
spec:RegisterGear( "tier13", 78709, 78710, 78711, 78712, 78713, 78714, 78715, 78716, 78717, 78718 ) -- T13 Obsidian Arborweave
spec:RegisterGear( "tier14", 85304, 85305, 85306, 85307, 85308 ) -- T14 Eternal Blossom Vestment
spec:RegisterGear( "tier15", 95941, 95942, 95943, 95944, 95945 ) -- T15 Battlegear of the Haunted Forest

-- Talents (MoP talent system and Balance spec-specific talents)
spec:RegisterTalents( {
    -- Common MoP talent system (Tier 1-6)
    -- Tier 1 (Level 15)
    feline_swiftness        = { 4908, 1, 131768 },
    displacer_beast         = { 4909, 1, 102280 },
    wild_charge             = { 4910, 1, 102401 },
    
    -- Tier 2 (Level 30)
    natures_swiftness       = { 4911, 1, 132158 },
    renewal                 = { 4912, 1, 108238 },
    cenarion_ward           = { 4913, 1, 102351 },
    
    -- Tier 3 (Level 45)
    faerie_swarm            = { 4914, 1, 102355 },
    mass_entanglement       = { 4915, 1, 102359 },
    typhoon                 = { 4916, 1, 132469 },
    
    -- Tier 4 (Level 60)
    soul_of_the_forest      = { 4917, 1, 114107 },
    incarnation             = { 4918, 1, 106731 },
    force_of_nature         = { 4919, 1, 106737 },
    
    -- Tier 5 (Level 75)
    disorienting_roar       = { 4920, 1, 102359 },
    ursols_vortex           = { 4921, 1, 102793 },
    mighty_bash             = { 4922, 1, 5211 },
      -- Tier 6 (Level 90)
    heart_of_the_wild       = { 4923, 1, 108288 },
    dream_of_cenarius       = { 4924, 1, 108373 },
    natures_vigil           = { 4925, 1, 124974 },
} )

-- Glyphs
spec:RegisterGlyphs( {
    -- Major glyphs (Balance-specific)
    [54733] = "hurricane",           -- Hurricane now also slows the movement of enemies by 50%.
    [54829] = "master_shapeshifter", -- Your healing spells increase the amount of healing done on the target by 2% for 6 sec after entering Moonkin Form.
    [54830] = "moonbeast",           -- Your Moonkin Form now appears as an Astral Form.
    [59219] = "rebirth",             -- Increases the amount of health gained when resurrected by Rebirth.
    [54743] = "stampede",            -- When you shift into Cat Form, your movement speed is increased by 100% for 5 sec.
    [54753] = "stampeding_roar",     -- Reduces the cooldown of Stampeding Roar by 60 sec.
    [54825] = "stars",               -- Increases the radius of Starfall by 5 yards.
    [54760] = "starsurge",           -- Starsurge now launches one smaller bolt directly at your target instead of launching multiple small bolts.
    [54770] = "thorns",              -- Thorns now has a 10 sec cooldown but lasts only 6 sec.
    [54815] = "treant",              -- You now appear as a Treant while in Travel Form.
    [54821] = "typhoon",             -- Reduces the cooldown of your Typhoon spell by 3 sec.
    [54818] = "wild_growth",         -- Wild Growth now affects 1 additional target.
    [54756] = "wrath",               -- Increases the range of your Wrath spell by 5 yards.
    
    -- Minor glyphs
    [57856] = "aquatic_form",        -- Allows you to stand upright on the water surface while in Aquatic Form.
    [57862] = "challenging_roar",    -- Your Challenging Roar takes on the form of your current shapeshift form.
    [57863] = "charm_woodland_creature", -- Allows you to cast Charm Woodland Creature on critters, allowing them to follow you for 10 min.
    [57855] = "dash",                -- Your Dash leaves behind a glowing trail.
    [57861] = "grace",               -- Your death causes nearby enemies to flee in trepidation for 4 sec.
    [57857] = "mark_of_the_wild",    -- Your Mark of the Wild spell now transforms you into a Stag when cast on yourself.
    [57858] = "master_shapeshifter", -- Your healing spells increase the amount of healing done on the target by 2%.
    [57860] = "unburdened_rebirth",  -- Rebirth no longer requires a reagent.
} )

-- Balance specific auras
spec:RegisterAuras( {
    -- Eclipse
    lunar_eclipse = {
        id = 48518,
        duration = 15,
        max_stack = 1,
    },
    solar_eclipse = {
        id = 48517,
        duration = 15,
        max_stack = 1,
    },
    eclipse_energy = {
        duration = 3600,
        max_stack = 1,
    },
    eclipse_lunar = {
        id = 48518,
        duration = 3600,
        max_stack = 1,
    },
    eclipse_solar = {
        id = 48517,
        duration = 3600,
        max_stack = 1,
    },
    eclipse_lunar_back = {
        duration = 3600,
        max_stack = 1,
    },
    eclipse_solar_back = {
        duration = 3600,
        max_stack = 1,
    },
    celestial_alignment_cooldown = {
        id = 112071,
        duration = 15,
        max_stack = 1,
    },    -- DoTs
    moonfire = {
        id = 8921,
        duration = 12, -- Authentic MoP duration (6 ticks * 2s = 12s)
        tick_time = 2, -- Authentic MoP tick frequency
        max_stack = 1,
    },    sunfire = {
        id = 93402,
        duration = 12, -- Authentic MoP duration (6 ticks * 2s = 12s)
        tick_time = 2, -- Authentic MoP tick frequency
        max_stack = 1,
    },    insect_swarm = {
        id = 5570,
        duration = 12, -- Authentic MoP duration (6 ticks * 2s = 12s)
        tick_time = 2, -- Authentic MoP tick frequency
        max_stack = 1,
    },    hurricane = {
        id = 16914,
        duration = 10, -- Channeled for 10 seconds (10 ticks * 1s each)
        tick_time = 1, -- Authentic MoP tick frequency
        max_stack = 1,
    },
    wild_mushroom_stacks = {
        id = 88747,
        duration = 600, -- Lasts until detonated or replaced
        max_stack = 3, -- Maximum 3 mushrooms
    },
    -- Procs
    shooting_stars = {
        id = 93399,
        duration = 12,
        max_stack = 1,
    },
    owlkin_frenzy = {
        id = 16864,
        duration = 10,
        max_stack = 3,
    },
    euphoria = {
        id = 81070,
        duration = 4,
        max_stack = 1,
    },
    lunar_shower = {
        id = 33603,
        duration = 3,
        max_stack = 3,
    },
    -- Cooldowns
    starfall = {
        id = 48505,
        duration = 10,
        max_stack = 1,
    },
    incarnation_chosen_of_elune = {
        id = 102560,
        duration = 30,
        max_stack = 1,
    },
    celestial_alignment = {
        id = 112071,
        duration = 15,
        max_stack = 1,
    },
    -- Shared Druid auras
    innervate = {
        id = 29166,
        duration = 20,
        max_stack = 1,
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
    druids_swiftness = {
        id = 118922,
        duration = 8,
        max_stack = 3,
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
    
    -- Additional common druid auras
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
    },
    feral_form = {   -- For compatibility with some older content
        id = 768,
        duration = 3600,
        max_stack = 1,
    },
    thorns = {
        id = 467,
        duration = function() return glyph.thorns.enabled and 6 or 20 end,
        max_stack = 1,
    },
    wild_growth = {
        id = 48438,
        duration = 7,
        max_stack = 1,
    },
    savage_roar = {
        id = 52610,
        duration = function() return 12 + (talent.endless_carnage.enabled and 6 or 0) end,
        max_stack = 1,
    },
    swiftmend = {
        id = 18562,
        duration = 6,
        max_stack = 1,
    },
    wild_charge = {
        id = 102401,
        duration = 0.5,
        max_stack = 1,
    },
    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1,
    },
    renewal = {
        id = 108238,
        duration = 5,
        max_stack = 1,
    },
    displacer_beast = {
        id = 102280,
        duration = 4,
        max_stack = 1,
    },
    natures_swiftness = {
        id = 132158,
        duration = 10,
        max_stack = 1,
    },
    survival_instincts = {
        id = 61336,
        duration = 6,
        max_stack = 1,
    },
    stampeding_roar = {
        id = 77764,
        duration = 8,
        max_stack = 1,
    },
    heart_of_the_wild = {
        id = 108288,
        duration = 45,
        max_stack = 1,
    },
    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
    },
    dream_of_cenarius = {
        id = 108373,
        duration = 30,
        max_stack = 1,
    },
    frenzied_regeneration = {
        id = 22842,
        duration = 6,
        max_stack = 1,
    },
    predatory_swiftness = {
        id = 69369,
        duration = 10,
        max_stack = 1,
    },
    rejuvenation = {
        id = 774,
        duration = function() return 12 + (glyph.rejuvenation.enabled and 3 or 0) end,
        tick_time = 3,
        max_stack = 1,
    },
    regrowth = {
        id = 8936,
        duration = 6,
        tick_time = 2,
        max_stack = 1,
    },
    lifebloom = {
        id = 33763,
        duration = 10,
        tick_time = 1,
        max_stack = 3,
    },
} )

-- Balance core abilities
spec:RegisterAbilities( {    starfire = {
        id = 2912,
        cast = function() 
            local base_cast = 3.2 -- Authentic MoP cast time
            
            -- Celestial Alignment: 50% faster casting
            if buff.celestial_alignment.up then 
                base_cast = base_cast * 0.5
            -- Incarnation: 50% faster casting
            elseif buff.incarnation_chosen_of_elune.up then 
                base_cast = base_cast * 0.5
            -- Lunar Eclipse: 50% faster casting
            elseif buff.lunar_eclipse.up then 
                base_cast = base_cast * 0.5
            end
            
            -- Nature's Swiftness: Instant cast
            if buff.natures_swiftness.up then 
                return 0 
            end
            
            return base_cast * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = 0.11 -- Authentic MoP mana cost (11% base mana)
            -- Celestial Alignment: 50% mana reduction
            if buff.celestial_alignment.up then
                base_cost = base_cost * 0.5
            end
            -- Owlkin Frenzy: No mana cost
            if buff.owlkin_frenzy.up then
                return 0
            end
            return base_cost
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135753,
        
        handler = function ()
            -- Remove Nature's Swiftness if used
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            
            -- Remove Owlkin Frenzy stack
            if buff.owlkin_frenzy.up then
                removeStack("owlkin_frenzy")
            end
            
            -- Eclipse power generation (Starfire moves toward Lunar Eclipse)
            if not buff.lunar_eclipse.up and not buff.solar_eclipse.up and not buff.celestial_alignment.up then
                local power_gain = 20
                
                -- Euphoria talent: +5 Eclipse Energy generation
                if talent.euphoria.enabled then
                    power_gain = power_gain + 5
                end
                
                -- Apply Eclipse power
                if eclipse.power <= 0 then
                    eclipse.power = eclipse.power + power_gain
                    eclipse.direction = "lunar"
                    eclipse.starfire_counter = eclipse.starfire_counter + 1
                    
                    -- Check for Lunar Eclipse threshold (100 power)
                    if eclipse.power >= 100 then
                        eclipse.power = 100
                        applyBuff("lunar_eclipse")
                        removeBuff("solar_eclipse")
                        eclipse.lunar_next = false
                        eclipse.solar_next = true
                    end
                end
            end
            
            -- Euphoria talent: Extra power when casting against current eclipse
            if talent.euphoria.enabled and buff.solar_eclipse.up then
                eclipse.power = eclipse.power + 25 -- Moves faster out of wrong eclipse
                if eclipse.power >= 100 then
                    eclipse.power = 100
                    applyBuff("lunar_eclipse")
                    removeBuff("solar_eclipse")
                end
            end
            
            -- Shooting Stars proc chance from active DoTs
            if talent.shooting_stars.enabled then
                local proc_chance = 0
                
                -- Base proc chance per DoT tick
                if debuff.moonfire.up then 
                    proc_chance = proc_chance + 0.04 -- 4% per DoT
                end
                if debuff.sunfire.up then 
                    proc_chance = proc_chance + 0.04 -- 4% per DoT
                end
                
                -- Additional chance during eclipses
                if buff.lunar_eclipse.up or buff.solar_eclipse.up then
                    proc_chance = proc_chance * 1.5 -- 50% more likely during eclipse
                end
                
                if proc_chance > 0 and math.random() < proc_chance then
                    gainCharges("starsurge", 1)
                    applyBuff("shooting_stars")
                end
            end
            
            -- Eclipse transition tracking
            eclipse.last_spell = "starfire"
        end,
    },      wrath = {
        id = 5176,
        cast = function() 
            local base_cast = 2.5 -- Authentic MoP cast time
            
            -- Celestial Alignment: 50% faster casting
            if buff.celestial_alignment.up then 
                base_cast = base_cast * 0.5 
            -- Incarnation: 50% faster casting
            elseif buff.incarnation_chosen_of_elune.up then 
                base_cast = base_cast * 0.5 
            -- Solar Eclipse: 50% faster casting
            elseif buff.solar_eclipse.up then 
                base_cast = base_cast * 0.5 
            end
            
            -- Nature's Swiftness: Instant cast
            if buff.natures_swiftness.up then 
                return 0 
            end
            
            return base_cast * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = 0.09 -- Authentic MoP mana cost (9% base mana)
            -- Celestial Alignment: 50% mana reduction
            if buff.celestial_alignment.up then
                base_cost = base_cost * 0.5
            end
            -- Owlkin Frenzy: No mana cost
            if buff.owlkin_frenzy.up then
                return 0
            end
            return base_cost
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136006,
        
        handler = function ()
            -- Remove Nature's Swiftness if used
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            
            -- Remove Owlkin Frenzy stack
            if buff.owlkin_frenzy.up then
                removeStack("owlkin_frenzy")
            end
            
            -- Eclipse power generation (Wrath moves toward Solar Eclipse)
            if not buff.lunar_eclipse.up and not buff.solar_eclipse.up and not buff.celestial_alignment.up then
                local power_loss = -13 -- Negative value moves toward Solar
                
                -- Euphoria talent: Enhanced Eclipse generation
                if talent.euphoria.enabled then
                    power_loss = power_loss - 4 -- -17 total
                end
                
                -- Apply Eclipse power change
                if eclipse.power >= 0 then
                    eclipse.power = eclipse.power + power_loss
                    eclipse.direction = "solar"
                    eclipse.wrath_counter = eclipse.wrath_counter + 1
                    
                    -- Check for Solar Eclipse threshold (-100 power)
                    if eclipse.power <= -100 then
                        eclipse.power = -100
                        applyBuff("solar_eclipse")
                        removeBuff("lunar_eclipse")
                        eclipse.solar_next = false
                        eclipse.lunar_next = true
                    end
                end
            end
            
            -- Euphoria talent: Extra power when casting against current eclipse
            if talent.euphoria.enabled and buff.lunar_eclipse.up then
                eclipse.power = eclipse.power - 25 -- Moves faster out of wrong eclipse
                if eclipse.power <= -100 then
                    eclipse.power = -100
                    applyBuff("solar_eclipse")
                    removeBuff("lunar_eclipse")
                end
            end
            
            -- Shooting Stars proc chance from active DoTs
            if talent.shooting_stars.enabled then
                local proc_chance = 0
                
                -- Base proc chance per DoT tick
                if debuff.moonfire.up then 
                    proc_chance = proc_chance + 0.04 -- 4% per DoT
                end
                if debuff.sunfire.up then 
                    proc_chance = proc_chance + 0.04 -- 4% per DoT
                end
                
                -- Additional chance during eclipses
                if buff.lunar_eclipse.up or buff.solar_eclipse.up then
                    proc_chance = proc_chance * 1.5 -- 50% more likely during eclipse
                end
                
                if proc_chance > 0 and math.random() < proc_chance then
                    gainCharges("starsurge", 1)
                    applyBuff("shooting_stars")
                end
            end
            
            -- Eclipse transition tracking
            eclipse.last_spell = "wrath"
        end,
    },      starsurge = {
        id = 78674,
        cast = function() 
            -- Shooting Stars: Instant cast
            if buff.shooting_stars.up then 
                return 0 
            end
            
            local base_cast = 2.0 -- Authentic MoP cast time
            
            -- Celestial Alignment: 50% faster casting
            if buff.celestial_alignment.up then 
                base_cast = base_cast * 0.5 
            -- Incarnation: 50% faster casting  
            elseif buff.incarnation_chosen_of_elune.up then 
                base_cast = base_cast * 0.5 
            end
            
            -- Nature's Swiftness: Instant cast
            if buff.natures_swiftness.up then 
                return 0 
            end
            
            return base_cast * haste 
        end,
        charges = function()
            -- Celestial Focus talent increases charges
            if talent.celestial_focus.enabled then
                return 3
            end
            return 2
        end,
        cooldown = 15, -- Authentic MoP cooldown
        recharge = function()
            -- Celestial Focus talent reduces recharge time
            if talent.celestial_focus.enabled then
                return 12 -- 20% faster recharge
            end
            return 15
        end,
        gcd = "spell",
        
        spend = function()
            local base_cost = 0.11 -- Authentic MoP mana cost (11% base mana)
            -- Celestial Alignment: 50% mana reduction
            if buff.celestial_alignment.up then
                base_cost = base_cost * 0.5
            end
            -- Shooting Stars: No mana cost
            if buff.shooting_stars.up then
                return 0
            end
            return base_cost
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135730,
        
        handler = function ()
            -- Remove buffs used
            if buff.shooting_stars.up then
                removeBuff("shooting_stars")
            end
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            
            -- Eclipse-specific effects
            if buff.lunar_eclipse.up then
                -- During Lunar Eclipse: Apply Sunfire to target
                applyDebuff("target", "sunfire")
                
                -- Lunar Shower stacks
                if talent.lunar_shower.enabled then
                    applyBuff("lunar_shower", 3, 1)
                end
            elseif buff.solar_eclipse.up then
                -- During Solar Eclipse: Apply Moonfire to target  
                applyDebuff("target", "moonfire")
                
                -- Lunar Shower stacks
                if talent.lunar_shower.enabled then
                    applyBuff("lunar_shower", 3, 1)
                end
            end
            
            -- Eclipse direction change
            if not buff.celestial_alignment.up then
                if eclipse.direction == "lunar" then
                    eclipse.direction = "solar"
                    eclipse.solar_next = true
                    eclipse.lunar_next = false
                elseif eclipse.direction == "solar" then
                    eclipse.direction = "lunar"
                    eclipse.lunar_next = true
                    eclipse.solar_next = false
                end
            end
            
            -- Reset Eclipse counters on direction change
            eclipse.wrath_counter = 0
            eclipse.starfire_counter = 0
        end,    },
    
    moonfire = {
        id = 8921,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.09, -- Authentic MoP mana cost (9% base mana)
        spendType = "mana",
        
        startsCombat = true,
        texture = 136096,
        
        handler = function ()
            applyDebuff("target", "moonfire")
            -- Remove Sunfire if applied (mutually exclusive in MoP)
            if debuff.sunfire.up then
                removeDebuff("target", "sunfire")
            end
            if buff.lunar_shower.up then
                addStack("lunar_shower")
            end
        end,
    },    sunfire = {
        id = 93402,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.09, -- Authentic MoP mana cost (9% base mana)
        spendType = "mana",
        
        startsCombat = true,
        texture = 236216,
        
        handler = function ()
            applyDebuff("target", "sunfire")
            -- Remove Moonfire if applied (mutually exclusive in MoP)
            if debuff.moonfire.up then
                removeDebuff("target", "moonfire")
            end
            if buff.lunar_shower.up then
                addStack("lunar_shower")
            end
        end,
    },
      insect_swarm = {
        id = 5570,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.08, -- Authentic MoP mana cost (8% base mana)
        spendType = "mana",
        
        startsCombat = true,
        texture = 136045,
        
        handler = function ()
            applyDebuff("target", "insect_swarm")
        end,
    },
      hurricane = {
        id = 16914,
        cast = 10, -- Channeled for 10 seconds (10 ticks * 1s each)
        channeled = true,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.81, -- Authentic MoP mana cost (81% base mana)
        spendType = "mana",
        
        startsCombat = true,
        texture = 236170,
        
        handler = function ()
            applyBuff("hurricane")
        end,
    },
    
    wild_mushroom = {
        id = 88747,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.11, -- Authentic MoP mana cost (11% base mana)
        spendType = "mana",
        
        startsCombat = false,
        texture = 134222,
        
        handler = function ()
            if buff.wild_mushroom_stacks.stack < 3 then
                addStack("wild_mushroom_stacks")
            end
        end,
    },
    
    wild_mushroom_detonate = {
        id = 88751,
        cast = 0,
        cooldown = 10, -- Authentic MoP cooldown
        gcd = "spell",
        
        startsCombat = true,
        texture = 134222,
        
        usable = function () return buff.wild_mushroom_stacks.stack > 0 end,
        
        handler = function ()
            removeStack("wild_mushroom_stacks", buff.wild_mushroom_stacks.stack)
        end,
    },
    
    starfall = {
        id = 48505,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.35,
        spendType = "mana",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236168,
        
        handler = function ()
            applyBuff("starfall")
        end,
    },
    
    celestial_alignment = {
        id = 112071,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136060,
        
        handler = function ()
            applyBuff("celestial_alignment")
            applyBuff("lunar_eclipse")
            applyBuff("solar_eclipse")
        end,
    },
    
    incarnation_chosen_of_elune = {
        id = 102560,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 571586,
        
        handler = function ()
            applyBuff("incarnation_chosen_of_elune")
        end,
    },
    
    moonkin_form = {
        id = 24858,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132117,
        
        handler = function ()
            applyBuff("moonkin_form")
            removeBuff("cat_form")
            removeBuff("bear_form")
        end,
    },
    
    innervate = {
        id = 29166,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136048,
        
        handler = function ()
            applyBuff("innervate")
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
        end,
    },
    
    -- Common Druid abilities
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.27,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136078,
        
        handler = function ()
            applyBuff("mark_of_the_wild")
            if glyph.mark_of_the_wild.enabled then
                applyBuff("stag_form")
            end
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
            if talent.feline_swiftness.enabled and not buff.prowl.up then
                applyBuff("dash")
            end
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
    
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        
        startsCombat = false,
        texture = 132089,
        
        usable = function ()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyBuff("prowl")
        end,
    },
    
    dash = {
        id = 1850,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        startsCombat = false,
        texture = 132120,
        
        usable = function ()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyBuff("dash")
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
    
    cenarion_ward = {
        id = 102351,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = false,
        texture = 616077,
        
        handler = function ()
            applyBuff("cenarion_ward")
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
            -- Cat: Charge to target
            -- Bear: Charge and root
            -- Moonkin: Disengage
            -- No form: Leap forward
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
            removeBuff("bear_form")
            removeBuff("moonkin_form")
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
    
    faerie_swarm = {
        id = 102355,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 538516,
        
        handler = function ()
            applyDebuff("target", "faerie_swarm")
        end,
    },
    
    healing_touch = {
        id = 5185,
        cast = 2,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.22,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136041,
        
        handler = function ()
            -- Heals target
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            if buff.predatory_swiftness.up then
                removeBuff("predatory_swiftness")
            end
        end,
    },
    
    hurricane = {
        id = 16914,
        cast = function() return 10 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        channeled = true,
        
        spend = 0.2,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136018,
        
        handler = function ()
            -- Channeled spell
        end,
    },
    
    mass_entanglement = {
        id = 102359,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 538515,
        
        handler = function ()
            applyDebuff("target", "mass_entanglement")
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
    
    nature_cure = {
        id = 88423,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.14,
        spendType = "mana",
        
        startsCombat = false,
        texture = 236288,
        
        handler = function ()
            -- Remove 1 magic, curse, or poison effect
        end,
    },
    
    heart_of_the_wild = {
        id = 108288,
        cast = 0,
        cooldown = 360,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 464342,
        
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
        texture = 461113,
        
        handler = function ()
            applyBuff("natures_vigil")
        end,
    },
    
    tranquility = {
        id = 740,
        cast = function() return 8 * haste end,
        cooldown = 480,
        gcd = "spell",
        
        channeled = true,
        
        spend = 0.56,
        spendType = "mana",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136107,
        
        handler = function ()
            -- Channeled AoE healing
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
    
    wild_growth = {
        id = 48438,
        cast = 1.5,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.22,
        spendType = "mana",
        
        startsCombat = false,
        texture = 236153,
        
        handler = function ()
            -- AoE HoT
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
} )

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
    
    -- Track Eclipse power
    spec:RegisterStateTable( "eclipse", {
        direction = function()
            if state.eclipse.power < 0 then return "lunar"
            elseif state.eclipse.power > 0 then return "solar"
            elseif state.eclipse.solar_next then return "solar"
            else return "lunar" end
        end,
        
        power = 0,
        
        solar_next = false,
        lunar_next = false,
        
        wrath_counter = 0,
        starfire_counter = 0
    } )
    
    -- Track HOTs for wild mushroom and swiftmend mechanics
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
end

-- Register default pack for MoP Balance Druid
spec:RegisterPack( "Balance", 20250515, [[Hekili:TzTBVTTnu4FlXSwQZzfn6t7wGvv9vpr8KvAm7nYn9DAMQ1ijxJZwa25JdwlRcl9dglLieFL52MpyzDoMZxhF7b)MFd9DjdLtuRdh7iiRdxGt)8h6QN0xHgyR37F)5dBEF5(yJ9Np)1hgn3dB4(l)ofv5k3HbNcO8zVcGqymUvZYwbVBdY0P)MM]]  )

-- Register pack selector for Balance
spec:RegisterPackSelector( "balance", "Balance", "|T136060:0|t Balance",
    "Handles all aspects of Balance Druid rotation with focus on Eclipse cycles and DoT management.",
    nil )
