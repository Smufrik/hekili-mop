-- DruidFeral.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Druid: Feral spec

if UnitClassBase( 'player' ) ~= 'DRUID' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 103 ) -- Feral spec ID for MoP

local strformat = string.format
local FindUnitBuffByID = ns.FindUnitBuffByID
local FindUnitDebuffByID = ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Track bleeds table
local tracked_bleeds = {
    rip = {
        last_tick = {},
        tick_time = {},
        haste = {}
    },
    rake = {
        last_tick = {},
        tick_time = {},
        haste = {}
    },
    thrash_cat = {
        last_tick = {},
        tick_time = {},
        haste = {}
    }
}

-- Register resources
spec:RegisterResource( Enum.PowerType.Energy )
spec:RegisterResource( Enum.PowerType.ComboPoints )

-- Tier sets
spec:RegisterGear( "tier13", 78699, 78700, 78701, 78702, 78703, 78704, 78705, 78706, 78707, 78708 ) -- T13 Obsidian Arborweave
spec:RegisterGear( "tier14", 85304, 85305, 85306, 85307, 85308 ) -- T14 Eternal Blossom Vestment
spec:RegisterGear( "tier15", 95941, 95942, 95943, 95944, 95945 ) -- T15 Battlegear of the Haunted Forest

-- Talents (MoP talent system and Feral spec-specific talents)
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
    incarnation             = { 4918, 1, 102543 },
    force_of_nature         = { 4919, 1, 106731 },
    
    -- Tier 5 (Level 75)
    disorienting_roar       = { 4920, 1, 99, 102359 },
    ursols_vortex           = { 4921, 1, 102793 },
    mighty_bash             = { 4922, 1, 5211 },    -- Tier 6 (Level 90)
    heart_of_the_wild       = { 4923, 1, 108288 },
    dream_of_cenarius       = { 4924, 1, 108373 },
    natures_vigil           = { 4925, 1, 124974 },
    
    -- Feral-specific passive talents
    primal_fury             = { 1000, 1, 37116 }, -- Crits have chance to generate additional combo point
    stampede                = { 1001, 1, 78892 }, -- Feral Charge grants Ravage proc
    blood_in_the_water      = { 1002, 2, 80862 }, -- Ferocious Bite extends Rip on targets below 25% health
    leader_of_the_pack      = { 1003, 1, 17007 }, -- Party/raid critical strike chance bonus
    survival_instincts      = { 1004, 1, 61336 }, -- Damage reduction cooldown
    bloodtalons             = { 1005, 1, 145152 }, -- Healing spells increase damage by 50% for next 2 attacks
} )

-- Glyphs
spec:RegisterGlyphs( {
    -- Major glyphs (Feral-specific)
    [45602] = "berserk",             -- Berserk generates 20 Energy when used.
    [54733] = "cat_form",            -- Increases movement speed in Cat Form by 10%.
    [54810] = "feral_charge",        -- Your Feral Charge ability's cooldown is reduced by 2 sec.
    [54813] = "ferocious_bite",      -- Your Ferocious Bite ability heals you for 2% of maximum health for each 10 Energy used.
    [67494] = "frenzied_regeneration", -- Your Frenzied Regeneration ability no longer costs Energy.
    [54799] = "maul",                -- Increases the damage of your Maul ability by 20% but Maul no longer hits a second target.
    [46372] = "mangle",              -- Mangle generates 8 Rage instead of 6 in Bear Form, and increases Energy by 4 instead of 3 in Cat Form.
    [54812] = "pounce",              -- Increases the range of your Pounce ability by 3 yards.
    [54814] = "prowl",               -- Increases your movement while stealthed in Cat Form by 40%.
    [54818] = "rip",                 -- Your Rip ability deals 15% more damage.
    [59219] = "savage_roar",         -- Your Savage Roar ability also increases the damage of your bleed effects by 25%.
    [54815] = "shred",               -- You deal 20% increased damage to targets with Mangle, Trauma, Gore, or Blood Frenzy on the target.
    [63055] = "skull_bash",          -- Increases the range of Skull Bash by 3 yards.
    [54821] = "survival_instincts",  -- Your Survival Instincts ability no longer requires Bear Form and now increases all healing received by 20%.
    [71013] = "tiger_fury",          -- Tiger's Fury no longer increases damage but now generates 60 Energy.
    
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

-- Feral specific auras
spec:RegisterAuras( {
    -- DoTs and bleeds    rake = {
        id = 1822,
        duration = 9,
        tick_time = 3,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.rake.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 3 end
                local hasteMod = tracked_bleeds.rake.haste[ target.unit ]
                hasteMod = 3 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.rake.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },    rip = {
        id = 1079,
        duration = 16, -- Authentic MoP: Fixed 16s duration (8 ticks at 2s intervals)
        tick_time = 2,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.rip.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.rip.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.rip.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },
    thrash_cat = {
        id = 106830,
        duration = 6,
        tick_time = 2,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.thrash_cat.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.thrash_cat.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.thrash_cat.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },
    -- Buffs
    savage_roar = {
        id = 52610,
        duration = function() return 12 + combo_points.current * 6 end,
        max_stack = 1,
    },
    tigers_fury = {
        id = 5217,
        duration = 6,
        max_stack = 1,
    },
    berserk = {
        id = 50334,
        duration = 15,
        max_stack = 1,
    },
    predatory_swiftness = {
        id = 69369,
        duration = 10,
        max_stack = 1,
    },
    omen_of_clarity = {
        id = 16870,
        duration = 15,
        max_stack = 1,
    },
    incarnation_king_of_the_jungle = {
        id = 102543,
        duration = 30,
        max_stack = 1,
    },
    -- MoP specific talents
    dream_of_cenarius = {
        id = 108381,
        duration = 30,
        max_stack = 2,
    },
    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
    },    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
    },
      -- Stampede buff from Feral Charge
    stampede_cat = {
        id = 81022,
        duration = 10,
        max_stack = 1,
    },
    
    -- Leader of the Pack - party/raid crit buff
    leader_of_the_pack = {
        id = 17007,
        duration = 3600,
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
    frenzied_regeneration = {
        id = 22842,
        duration = 6,
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

    -- Additional important buffs and debuffs
    savage_roar_glyph = {
        id = 127538, -- Glyph effect for increased bleed damage
        duration = function() return buff.savage_roar.remains end,
        max_stack = 1,    },
    clearcasting = {
        id = 135700,
        duration = 15,
        max_stack = 1,
    },
    
    -- Debuffs    mangle = {
        id = 33876,
        duration = 60,
        max_stack = 1,
    },
    
    -- Form buffs
    prowl = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Talent-specific auras
    stampeding_roar = {
        id = 77764,
        duration = 8,
        max_stack = 1,
    },
    survival_instincts = {
        id = 61336,
        duration = 12,
        max_stack = 1,
    },
    -- Bloodtalons: Critical MoP talent buff (50% increased damage)
    bloodtalons = {
        id = 145152,
        duration = 30,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 145152 )
            
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

-- Advanced MoP Bleed Snapshotting System
spec:RegisterStateFunction( "snapshot_stats", function()
    -- Capture current stats for bleed snapshotting (MoP mechanic)
    local snapshot = {
        attack_power = stat.attack_power,
        crit_chance = stat.crit,
        mastery_value = stat.mastery_value,
        versatility = stat.versatility or 0,
        savage_roar_multiplier = buff.savage_roar.up and 1.4 or 1.0,
        tigers_fury_multiplier = buff.tigers_fury.up and 1.15 or 1.0,
        trinket_multipliers = 1.0, -- Would need to track active trinket procs
        bloodtalons_multiplier = buff.bloodtalons.up and 1.5 or 1.0,
    }
    
    -- Calculate total multiplier for this snapshot
    snapshot.total_multiplier = snapshot.savage_roar_multiplier * 
                               snapshot.tigers_fury_multiplier * 
                               snapshot.bloodtalons_multiplier
    
    return snapshot
end )

-- Enhanced bleed application with snapshotting
spec:RegisterStateFunction( "apply_bleed", function( target, bleed_name, duration, snapshot_data )
    -- Store snapshot data with the bleed for authentic MoP behavior
    local debuff_data = {
        snapshot = snapshot_data or snapshot_stats(),
        original_duration = duration,
        applied = query_time
    }
    
    applyDebuff( target, bleed_name, duration, 1, debuff_data )
end )

-- Feral core abilities
spec:RegisterAbilities( {    -- Enhanced Shred with positioning and critical hit effects
    shred = {
        id = 5221,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.clearcasting.up then return 0 end
            if buff.berserk.up then return 25 end
            return 40 -- Authentic MoP energy cost
        end,
        spendType = "energy",
        
        startsCombat = true,
        texture = 136231,
        
        usable = function()
            return buff.cat_form.up and not settings.front_of_target, "requires cat form and behind target"
        end,
        
        handler = function ()
            gain(1, "combo_points")
            removeStack("clearcasting")
            
            -- Primal Fury - chance for extra combo point on crit
            if talent.primal_fury.enabled and math.random() < 0.25 then
                gain(1, "combo_points")
            end
        end,
    },
      -- Enhanced Rake with proper DoT mechanics
    rake = {
        id = 1822,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
          spend = function()
            if buff.clearcasting.up then return 0 end
            if buff.berserk.up then return 17 end -- Verified authentic MoP cost in Berserk
            return 35 -- Authentic MoP energy cost from WoW Sims
        end,
        spendType = "energy",
        
        startsCombat = true,
        texture = 132122,
        
        usable = function()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            gain(1, "combo_points")
            
            -- Apply rake with authentic MoP duration (9s, 3 ticks at 3s intervals)
            local duration = 9
            applyDebuff("target", "rake", duration)
            removeStack("clearcasting")
        end,
    },
    
    -- Enhanced Mangle with proper debuff application
    mangle_cat = {
        id = 33876,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
          spend = function()
            if buff.clearcasting.up then return 0 end
            if buff.berserk.up then return 17 end -- Reduced cost in Berserk
            -- Glyph of Mangle provides 4 energy back instead of 3
            if glyph.mangle.enabled then
                return 31 -- 35 - 4 = 31 effective cost
            end
            return 35 -- Authentic MoP energy cost verified against WoW Sims
        end,
        spendType = "energy",
        
        startsCombat = true,
        texture = 132135,
        
        usable = function()
            return buff.cat_form.up, "requires cat form"
        end,
          handler = function ()
            gain(1, "combo_points")
            applyDebuff("target", "mangle", 60)
            removeStack("clearcasting")
        end,
    },
      -- Enhanced Tiger's Fury with authentic MoP mechanics
    tigers_fury = {
        id = 5217,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        startsCombat = false,
        texture = 132242,
        
        usable = function()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyBuff("tigers_fury", 6)
            
            -- Glyph effect - generate energy instead of damage bonus
            if glyph.tigers_fury.enabled then
                gain(60, "energy") -- Glyph provides 60 energy
            else
                gain(60, "energy") -- Base Tiger's Fury also provides 60 energy in MoP
            end
        end,
    },
    
    -- Enhanced Berserk with proper mechanics
    berserk = {
        id = 50334,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236149,
        
        usable = function()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyBuff("berserk", 15)
            
            -- Glyph of Berserk provides energy
            if glyph.berserk.enabled then
                gain(20, "energy")
            end
        end,
    },
      rip = {
        id = 1079,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.berserk.up then return 15 end
            return 30 -- Authentic MoP energy cost
        end,
        spendType = "energy",
        
        startsCombat = true,
        texture = 132152,
        
        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,
        
        handler = function ()
            local cp = combo_points.current
            -- Authentic MoP Rip: 8 base ticks (16s duration) with 2s tick frequency
            local duration = 16 -- Fixed 16s duration regardless of combo points
            
            -- Apply with proper duration and snapshot current stats
            applyDebuff("target", "rip", duration)
            
            -- Glyph of Rip increases damage by 15%
            if glyph.rip.enabled then
                debuff.rip.multiplier = (debuff.rip.multiplier or 1) * 1.15
            end
            
            spend(cp, "combo_points")
        end,
    },    ferocious_bite = {
        id = 22568,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = buff.berserk.up and 12 or 25
            -- Can consume up to 25 additional energy for bonus damage
            local available_energy = energy.current - base_cost
            local bonus_energy = min(25, max(0, available_energy))
            return base_cost + bonus_energy
        end,
        spendType = "energy",
        
        startsCombat = true,
        texture = 132127,
        
        usable = function() 
            return combo_points.current > 0, "requires combo points"
        end,
        
        handler = function ()
            -- Blood in the Water talent - extend Rip on targets below 25% health
            if talent.blood_in_the_water.enabled and target.health.pct < 25 and debuff.rip.up then
                debuff.rip.expires = debuff.rip.expires + 2
            end
            
            -- Glyph of Ferocious Bite - heal for 2% max health per 10 energy used
            if glyph.ferocious_bite.enabled then
                local energy_used = action.ferocious_bite.spend
                health.current = min(health.max, health.current + (health.max * 0.002 * energy_used / 10))
            end
            
            spend(combo_points.current, "combo_points")
        end,
    },
      savage_roar = {
        id = 52610,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.berserk.up then return 12 end
            return 25
        end,
        spendType = "energy",
        
        startsCombat = false,
        texture = 236167,
        
        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,
        
        handler = function ()
            local cp = combo_points.current
            -- Base duration: 12 + 6 seconds per combo point
            local duration = 12 + (cp * 6)
            
            -- Glyph of Savage Roar increases bleed damage by 25%
            if glyph.savage_roar.enabled then
                applyBuff("savage_roar", duration)
                applyBuff("savage_roar_glyph", duration)
            else
                applyBuff("savage_roar", duration)
            end
            
            spend(cp, "combo_points")
        end,
    },
    
    tigers_fury = {
        id = 5217,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        startsCombat = false,
        texture = 132242,
        
        handler = function ()
            applyBuff("tigers_fury")
            gain(60, "energy")
        end,
    },
    
    berserk = {
        id = 50334,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236149,
        
        handler = function ()
            applyBuff("berserk")
            if glyph.berserk.enabled then
                gain(20, "energy")
            end
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
        end,
    },
    
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132089,
        
        handler = function ()
            applyBuff("prowl")
        end,
    },
    
    dash = {
        id = 1850,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132120,
        
        handler = function ()
            applyBuff("dash")
        end,
    },
      ravage = {
        id = 6785,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.clearcasting.up then return 0 end
            if buff.berserk.up then return 25 end -- Reduced cost in Berserk
            return 45 -- Authentic MoP energy cost
        end,
        spendType = "energy",
        
        startsCombat = true,
        texture = 132141,
        
        usable = function()
            return buff.cat_form.up and (buff.prowl.up or buff.stampede_cat.up), "requires cat form and prowl or stampede"
        end,
        
        handler = function ()
            gain(1, "combo_points")
            removeStack("clearcasting")
            removeBuff("prowl")
            removeBuff("stampede_cat") -- Consumes Stampede proc
        end,
    },
    
    pounce = {
        id = 9005,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 50,
        spendType = "energy",
        
        startsCombat = true,
        texture = 132142,
        
        handler = function ()
            applyDebuff("target", "pounce_bleed")
            gain(1, "combo_points")
            removeBuff("prowl")
        end,
    },
    
    skull_bash = {
        id = 106839,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        startsCombat = true,
        texture = 236946,
        
        handler = function ()
            applyDebuff("target", "skull_bash")
        end,
    },
      incarnation_king_of_the_jungle = {
        id = 102543,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 571586,
        
        handler = function ()
            applyBuff("incarnation_king_of_the_jungle")
        end,
    },
    
    -- Leader of the Pack - passive group buff
    leader_of_the_pack = {
        id = 17007,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        texture = 136112,
        
        usable = function()
            return buff.cat_form.up or buff.bear_form.up, "requires cat or bear form"
        end,
        
        handler = function ()
            applyBuff("leader_of_the_pack")
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
    
    -- AoE abilities
    thrash_cat = {
        id = 106830,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.clearcasting.up then return 0 end
            if buff.berserk.up then return 25 end
            return 50
        end,
        spendType = "energy",
        
        startsCombat = true,
        texture = 451161,
        
        usable = function()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyDebuff("target", "thrash_cat")
            removeStack("clearcasting")
        end,
    },
    
    swipe_cat = {
        id = 62078,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.clearcasting.up then return 0 end
            if buff.berserk.up then return 22 end
            return 45
        end,
        spendType = "energy",
        
        startsCombat = true,
        texture = 134296,
        
        usable = function()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            removeStack("clearcasting")
        end,
    },
    
    -- Utility and defensive abilities    skull_bash = {
        id = 106839,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        spend = 15,
        spendType = "energy",
        
        startsCombat = true,
        texture = 236946,
        
        toggle = "interrupts",
        
        usable = function()
            return target.casting, "target must be casting"
        end,
        
        handler = function ()
            interrupt()
        end,
    },
    
    -- Feral Charge - authentic MoP ability for gap closing
    feral_charge_cat = {
        id = 49376,
        cast = 0,
        cooldown = function()
            if glyph.feral_charge.enabled then return 28 end -- Glyph reduces CD by 2 sec
            return 30
        end,
        gcd = "off",
        
        range = 25,
        min_range = 8,
        
        startsCombat = true,
        texture = 132138,
        
        usable = function()
            return buff.cat_form.up and target.distance >= 8, "requires cat form and target 8+ yards away"
        end,
        
        handler = function ()
            -- Generates energy and grants Ravage proc (Stampede talent)
            if talent.stampede.enabled then
                applyBuff("stampede_cat", 10) -- Allows next Ravage to be used regardless of stealth
            end
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
    
    innervate = {
        id = 29166,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        startsCombat = false,
        texture = 136048,
        
        handler = function ()
            applyBuff("innervate")
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
        end,
    },
    
    healing_touch = {
        id = 5185,
        cast = function() 
            if buff.predatory_swiftness.up then return 0 end
            return 2.5 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.predatory_swiftness.up then return 0 end
            return 0.18
        end,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136041,
        
        handler = function ()
            removeBuff("predatory_swiftness")
            if talent.dream_of_cenarius.enabled then
                applyBuff("dream_of_cenarius")
            end
        end,
    },
    
    rejuvenation = {
        id = 774,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136081,
        
        handler = function ()
            applyDebuff("target", "rejuvenation")
        end,
    },
    
    -- Utility
    faerie_fire = {
        id = 770,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136033,
        
        handler = function ()
            applyDebuff("target", "faerie_fire")
            applyDebuff("target", "weakened_armor")
        end,
    },
} )

-- Priority lists
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    damage = true,
    damageExpiration = 8,
      package = "Feral",
} )

-- Events and combat log tracking
spec:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED", function( event )
    local _, subtype, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName = CombatLogGetCurrentEventInfo()

    if sourceGUID == state.GUID then
        if subtype == "SPELL_AURA_APPLIED" or subtype == "SPELL_AURA_REFRESH" then
            -- Track bleed applications for snapshotting
            if spellID == 1822 then -- Rake
                tracked_bleeds.rake.haste[ destGUID ] = 100 / state.haste
                tracked_bleeds.rake.last_tick[ destGUID ] = GetTime()
            elseif spellID == 1079 then -- Rip  
                tracked_bleeds.rip.haste[ destGUID ] = 100 / state.haste
                tracked_bleeds.rip.last_tick[ destGUID ] = GetTime()
            elseif spellID == 106830 then -- Thrash (Cat)
                tracked_bleeds.thrash_cat.haste[ destGUID ] = 100 / state.haste
                tracked_bleeds.thrash_cat.last_tick[ destGUID ] = GetTime()
            end
        elseif subtype == "SPELL_AURA_REMOVED" then
            -- Clean up tracking when bleeds fall off
            if spellID == 1822 then
                tracked_bleeds.rake.haste[ destGUID ] = nil
                tracked_bleeds.rake.last_tick[ destGUID ] = nil
            elseif spellID == 1079 then
                tracked_bleeds.rip.haste[ destGUID ] = nil  
                tracked_bleeds.rip.last_tick[ destGUID ] = nil
            elseif spellID == 106830 then
                tracked_bleeds.thrash_cat.haste[ destGUID ] = nil
                tracked_bleeds.thrash_cat.last_tick[ destGUID ] = nil
            end
        elseif subtype == "SPELL_PERIODIC_DAMAGE" then
            -- Track actual tick times
            if spellID == 1822 and tracked_bleeds.rake.last_tick[ destGUID ] then
                tracked_bleeds.rake.last_tick[ destGUID ] = GetTime()
            elseif spellID == 1079 and tracked_bleeds.rip.last_tick[ destGUID ] then
                tracked_bleeds.rip.last_tick[ destGUID ] = GetTime()
            elseif spellID == 106830 and tracked_bleeds.thrash_cat.last_tick[ destGUID ] then
                tracked_bleeds.thrash_cat.last_tick[ destGUID ] = GetTime()
            end
        end
    end
end )

-- State expressions for Feral rotation logic
spec:RegisterStateExpr("energy_regen", function()
    local base_regen = 10
    if buff.tigers_fury.up then
        base_regen = base_regen + 2
    end
    if talent.king_of_the_jungle.enabled and buff.king_of_the_jungle.up then
        base_regen = base_regen + 2
    end
    return base_regen * haste
end)

spec:RegisterStateExpr("combo_points_max", function()
    return 5
end)

spec:RegisterStateExpr("time_to_max_energy", function()
    local current_energy = energy.current
    local max_energy = energy.max
    if current_energy >= max_energy then return 0 end
    return (max_energy - current_energy) / energy_regen
end)

spec:RegisterStateExpr("energy_time_to_cap", function()
    return time_to_max_energy
end)

-- Check if we should refresh Savage Roar
spec:RegisterStateExpr("should_refresh_roar", function()
    if not buff.savage_roar.up then return true end
    if combo_points.current == 0 then return false end
    
    local remaining = buff.savage_roar.remains
    local new_duration = 12 + (combo_points.current * 6)
    
    -- Refresh if less than 6 seconds remain or if we can extend significantly
    return remaining < 6 or (remaining < new_duration * 0.3 and combo_points.current >= 2)
end)

-- Check if we should use Rip
spec:RegisterStateExpr("should_rip", function()
    if combo_points.current < 1 then return false end
    if target.time_to_die < 6 then return false end
    
    if not debuff.rip.up then
        return combo_points.current >= 5 or target.time_to_die < 15
    end
    
    local remaining = debuff.rip.remains
    local new_duration = 12 + (combo_points.current * 2)
    
    -- Refresh if less than 25% duration remains and we have good combo points
    return remaining < new_duration * 0.25 and combo_points.current >= 4
end)

-- Check if we should use Ferocious Bite
spec:RegisterStateExpr("should_bite", function()
    if combo_points.current < 1 then return false end
    
    -- Use when target is low health and has Rip
    if target.health.pct < 25 and debuff.rip.up then return true end
    
    -- Use when at max combo points and Rip doesn't need refresh
    if combo_points.current == 5 and debuff.rip.up and debuff.rip.remains > 10 then
        return true
    end
    
    return false
end)

-- Check if we should use Rake
spec:RegisterStateExpr("should_rake", function()
    if not debuff.rake.up then return true end
    
    local remaining = debuff.rake.remains
    -- Refresh with 4.5 seconds or less remaining
    return remaining <= 4.5
end)

-- Check energy pooling needs
spec:RegisterStateExpr("pooling_for_finisher", function()
    if combo_points.current < 4 then return false end
    
    local finisher_cost = 30 -- Base Rip cost
    if buff.berserk.up then finisher_cost = 15 end
    
    local needed_energy = finisher_cost
    if should_refresh_roar and not buff.savage_roar.up then
        needed_energy = needed_energy + (buff.berserk.up and 12 or 25)
    end
    
    return energy.current < needed_energy
end)

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
    
    -- Track combo points
    spec:RegisterStateExpr( "combo_points", function ()
        return state.combo_points.current or 0
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
    
    -- Track bleed effect timers for next tick prediction
    spec:RegisterStateFunction( "calculate_tick_time", function( t, last_tick, tick_time, haste_pct )
        if not t.up then return 0 end
        
        -- Calculate the next tick based on haste at the time the DoT was applied
        local current_time = state.query_time
        local next_tick = last_tick + tick_time
        
        if next_tick <= current_time then
            local ticks = math.floor((current_time - last_tick) / tick_time)
            next_tick = last_tick + ((ticks + 1) * tick_time)
        end
        
        return next_tick - current_time
    end )
    
    -- Track active bleeds
    spec:RegisterStateTable( "active_bleeds", {
        count = function()
            local c = 0
            if debuff.rip.up then c = c + 1 end
            if debuff.rake.up then c = c + 1 end
            if debuff.thrash_cat.up then c = c + 1 end
            return c
        end
    } )
    
    -- Track healing HoTs for swiftmend mechanics
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

-- Register default pack for MoP Feral Druid
spec:RegisterPack( "Feral", 20250515, [[Hekili:TzTBVTTnu4FlXSwQZzfn6t7wGvv9vpr8KvAm7nYn9DAMQ1ijxJZwa25JdwlRcl9dglLieFL52MpyzDoMZxhF7b)MFd9DjdLtuRdh7iiRdxGt)8h6QN0xHgyR37F)5dBEF5(yJ9Np)1hgn3dB4(l)ofv5k3HbNcO8zVcGqymUvZYwbVBdY0P)MM]]  )

-- Register pack selector for Feral
spec:RegisterPackSelector( "feral", "Feral", "|T132115:0|t Feral",
    "Handles all aspects of Feral Druid rotation with focus on bleed management and energy usage.",
    nil )
