-- RogueAssassination.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Rogue: Assassination spec

if UnitClassBase( 'player' ) ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 259 ) -- Assassination spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

local tracked_bleeds = {}

spec:RegisterResource( Enum.PowerType.ComboPoints )
spec:RegisterResource( Enum.PowerType.Energy )

-- Tier sets
spec:RegisterGear( "tier14", 85299, 85300, 85301, 85302, 85303 ) -- T14 Rogue Set
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- T15 Rogue Set

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Stealth/Opener
    nightstalker               = { 4908, 1, 14062  }, -- Damage increased by 50% while stealthed
    subterfuge                 = { 4909, 1, 108208 }, -- Abilities usable for 3 sec after breaking stealth
    shadow_focus               = { 4910, 1, 108209 }, -- Abilities cost 75% less energy while stealthed
    
    -- Tier 2 (Level 30) - Ranged/Utility
    deadly_throw               = { 4911, 1, 26679  }, -- Throws knife to interrupt and slow
    nerve_strike               = { 4912, 1, 108210 }, -- Reduces healing by 50% for 10 sec
    combat_readiness           = { 4913, 1, 74001  }, -- Stacks reduce damage taken
    
    -- Tier 3 (Level 45) - Survivability
    cheat_death                = { 4914, 1, 31230  }, -- Fatal damage instead leaves you at 7% health
    leeching_poison            = { 4915, 1, 108211 }, -- Poisons heal you for 10% of damage dealt
    elusiveness                = { 4916, 1, 79008  }, -- Feint and Cloak reduce damage by additional 30%
    
    -- Tier 4 (Level 60) - Mobility
    preparation                = { 4917, 1, 14185  }, -- Resets cooldowns of finishing moves
    shadowstep                 = { 4918, 1, 36554  }, -- Teleport behind target
    burst_of_speed             = { 4919, 1, 108212 }, -- Sprint that breaks movement impairing effects
    
    -- Tier 5 (Level 75) - Crowd Control
    prey_on_the_weak           = { 4920, 1, 51685  }, -- +20% damage to movement impaired targets
    paralytic_poison           = { 4921, 1, 108215 }, -- Poisons apply stacking slow and eventual stun
    dirty_tricks               = { 4922, 1, 108216 }, -- Blind and Gouge no longer break on damage
    
    -- Tier 6 (Level 90) - Ultimate
    shuriken_toss              = { 4923, 1, 114014 }, -- Ranged attack that generates combo points
    marked_for_death           = { 4924, 1, 137619 }, -- Target gains 5 combo points
    anticipation               = { 4925, 1, 115189 }  -- Store up to 10 combo points
} )

-- Glyphs (MoP system)
spec:RegisterGlyphs( {
    -- Major glyphs (Assassination-specific)
    [56813] = "ambush",             -- Your Ambush generates 2 additional combo points.
    [56800] = "backstab",           -- Backstab deals 20% additional damage when used on stunned targets.
    [91299] = "blind",              -- Removes damage over time effects from the target of your Blind.
    [58039] = "blurred_speed",      -- Sprint can be used while stealthed, but reduces the duration by 5 sec.
    [63269] = "cloak_of_shadows",   -- Cloak of Shadows now removes harmful magic effects when used.
    [56820] = "crippling_poison",   -- Crippling Poison reduces movement speed by an additional 20%.
    [56806] = "deadly_throw",       -- Your Deadly Throw now interrupts spellcasting for 3 sec.
    [58032] = "distract",           -- Reduces the cooldown of Distract by 10 sec.
    [56799] = "evasion",            -- Increases the duration of Evasion by 5 sec.
    [56802] = "eviscerate",         -- Your Eviscerate critical strikes have a 50% chance to refund 1 combo point.
    [56803] = "expose_armor",       -- Your Expose Armor lasts 24 sec longer.
    [63254] = "fan_of_knives",      -- Increases the range of Fan of Knives by 5 yards.
    [56804] = "feint",              -- Increases the duration of Feint by 2 sec.
    [56812] = "garrote",            -- Your Garrote silences the target for 3 sec.
    [56809] = "gouge",              -- Reduces the energy cost of Gouge by 25.
    [56807] = "hemorrhage",         -- Your Hemorrhage deals 40% additional damage.
    [56805] = "kick",               -- Reduces the cooldown of Kick by 2 sec.
    [63268] = "mutilate",           -- Reduces the energy cost of Mutilate by 5.
    [58027] = "pick_lock",          -- Pick Lock no longer requires Thieves' Tools.
    [58017] = "pick_pocket",        -- Allows Pick Pocket to be used while in combat.
    [58038] = "poisons",            -- Your weapon enchantments no longer have a time restriction.
    [56819] = "preparation",        -- Adds Dismantle, Kick, and Smoke Bomb to the abilities reset by Preparation.
    [56801] = "rupture",            -- Your Rupture ability no longer has a range limitation.
    [58033] = "safe_fall",          -- Reduces the damage taken from falling by 30%.
    [56798] = "sap",                -- Increases the duration of Sap by 20 sec.
    [56810] = "slice_and_dice",     -- Your Slice and Dice ability costs no energy.
    [56811] = "sprint",             -- Increases the duration of Sprint by 1 sec.
    [63256] = "tricks_of_the_trade",-- Your Tricks of the Trade lasts an additional 4 sec.
    [89758] = "vanish",             -- When you Vanish, your threat is reset on all enemies.
    [63249] = "vendetta",           -- Reduces the cooldown of Vendetta by 30 sec.
    
    -- Minor glyphs
    [63415] = "blinding_powder",    -- Your Blind ability no longer requires a reagent.
    [57115] = "detection",          -- Increases the range at which you can detect stealthed or invisible enemies.
    [57114] = "distract",           -- Increases the range of Distract by 5 yards.
    [58037] = "hemorrhaging_veins", -- Your Hemorrhage ability now trails blood on the floor.
    [57112] = "pick_pocket",        -- Increases the range of Pick Pocket by 5 yards.
    [63420] = "poisons",            -- Applying poisons to your weapons grants a 50% chance to apply that poison to your other weapon as well.
    [57113] = "safe_fall",          -- Reduces the damage taken from falling by 30%.
    [57118] = "tricks_of_the_trade",-- When you use Tricks of the Trade, you gain 10% increased movement speed for 6 sec.
    [57117] = "vanish",             -- Reduces the cooldown of your Vanish ability by 30 sec.
} )

-- Assassination specific auras
spec:RegisterAuras( {    -- MoP: Envenom increases poison application chance by 30%
    envenom = {
        id = 32645,
        duration = function() return 1 + state.combo_points end,  -- 1 + CP seconds
        max_stack = 1,
    },
    -- Energy regeneration increased by 10%.
    venomous_wounds = {
        id = 79134, 
        duration = 3600,
        max_stack = 1,
    },
    -- Vendetta: Target takes 30% more damage from your attacks
    vendetta = {
        id = 79140,
        duration = 20,
        max_stack = 1,
    },
    -- Master Poisoner: Increases poison application chance and damage
    master_poisoner = {
        id = 93068,
        duration = 3600,
        max_stack = 1,
    },
    -- Cut to the Chase: Keeps up Slice and Dice when using Envenom
    cut_to_the_chase = {
        id = 51667,
        duration = 3600,
        max_stack = 1,
    },
    -- Assassination specific poison tracking
    deadly_poison = {
        id = 2818,
        duration = 12,
        max_stack = 5,
        tick_time = 3,
    },
    wound_poison = {
        id = 8679,
        duration = 15,
        max_stack = 5,
    },
    crippling_poison = {
        id = 3409,
        duration = 12,
        max_stack = 1,
    },
    mind_numbing_poison = {
        id = 5760,
        duration = 10,
        max_stack = 1,
    },
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1,
    },
    paralytic_poison = {
        id = 113952,
        duration = 3600,
        max_stack = 1,
    },
} )

-- Base Rogue auras added directly to Assassination spec
spec:RegisterAuras( {
    -- Basic abilities
    stealth = {
        id = 1784,
        duration = 3600,
        max_stack = 1,
    },
    slice_and_dice = {
        id = 5171,
        duration = function() return 12 + 3 * state.combo_points end,
        max_stack = 1,
    },
    rupture = {
        id = 1943,
        duration = function() return 6 + 4 * state.combo_points end,
        max_stack = 1,
        tick_time = 2,
    },
    feint = {
        id = 1966,
        duration = function() return glyph.feint.enabled and 7 or 5 end,
        max_stack = 1,
    },
    vanish = {
        id = 1856,
        duration = 3,
        max_stack = 1,
    },
    sprint = {
        id = 2983,
        duration = function() return glyph.sprint.enabled and 9 or 8 end,
        max_stack = 1,
    },
    evasion = {
        id = 5277,
        duration = function() return glyph.evasion.enabled and 15 or 10 end,
        max_stack = 1,
    },
    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1,
    },
    
    -- MoP-specific shared abilities
    subterfuge = {
        id = 115191,
        duration = 3,
        max_stack = 1,
    },
    anticipation = {
        id = 115189,
        duration = 15,
        max_stack = 5,
    },
    burst_of_speed = {
        id = 108212,
        duration = 4,
        max_stack = 1,
    },
    shadow_focus = {
        id = 108209,
        duration = 3600,  -- Passive talent
        max_stack = 1,    }
} )

-- Assassination Rogue abilities
spec:RegisterAbilities( {    mutilate = {
        id = 1329,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 50,  -- Corrected: MoP authentic energy cost
        spendType = "energy",
        
        handler = function ()
            -- MoP: Mutilate always generates 2 combo points (attacks with both weapons)
            local cp_gain = 2
            
            -- Seal Fate can add 1 CP per weapon if both crits (max 4 total)
            if talent.seal_fate.enabled and state.stat.crit > 0 then
                local crit_chance = state.stat.crit / 100
                -- Each weapon can crit independently
                if math.random() < crit_chance then
                    cp_gain = cp_gain + 1
                end
                if math.random() < crit_chance then
                    cp_gain = cp_gain + 1
                end
            end
            
            gain(cp_gain, "combo_points")
        end,
    },
      envenom = {
        id = 32645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,  -- Verified: MoP authentic energy cost
        spendType = "energy",
        
        handler = function ()
            local cp = combo_points.current
            spend(cp, "combo_points")
            
            -- MoP: Envenom duration is 1 + cp seconds, increases poison chance by 30%
            applyBuff("envenom", 1 + cp)
            
            -- Cut to the Chase talent refreshes SnD to max duration
            if talent.cut_to_the_chase.enabled and buff.slice_and_dice.up then
                applyBuff("slice_and_dice", 21) -- 5 CP duration: 6 + 3*5 = 21 sec
            end
        end,
    },
      garrote = {
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 45,  -- Verified: MoP authentic energy cost
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            applyDebuff("target", "garrote")
            gain(1, "combo_points")
            
            -- MoP: Garrote silences for 3 sec with glyph
            if glyph.garrote.enabled then
                applyDebuff("target", "garrote_silence", 3)
            end
            
            if not buff.shadow_dance.up then
                removeBuff("stealth")
            end
        end,
    },
    
    vendetta = {
        id = 79140,
        cast = 0,
        cooldown = function() return glyph.vendetta.enabled and 90 or 120 end,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        handler = function ()
            applyDebuff("target", "vendetta")
        end,
    },
    
    rupture = {
        id = 1943,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "energy",
        
        handler = function ()
            local cp = combo_points.current
            spend(cp, "combo_points")
            
            applyDebuff("target", "rupture")
        end,
    },
    
    slice_and_dice = {
        id = 5171,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if glyph.slice_and_dice.enabled then return 0 end
            return 25
        end,
        spendType = "energy",
        
        handler = function ()
            local cp = combo_points.current
            spend(cp, "combo_points")
            
            applyBuff("slice_and_dice", 12 + (3 * cp))
        end,
    },
      ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 60,  -- Verified: MoP authentic energy cost
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            -- MoP: Ambush generates 2 CP (3 with glyph)
            gain(glyph.ambush.enabled and 3 or 2, "combo_points")
            
            if not buff.shadow_dance.up then
                removeBuff("stealth")
            end
        end,
    },
    
    vanish = {
        id = 1856,
        cast = 0,
        cooldown = function() return glyph.vanish.enabled and 150 or 180 end,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        handler = function ()
            applyBuff("vanish")
            applyBuff("stealth")
            -- Remove all threat
        end,
    },
    
    kick = {
        id = 1766,
        cast = 0,
        cooldown = function() return glyph.kick.enabled and 13 or 15 end,
        gcd = "off",
        
        handler = function ()
            -- Interrupt target and lock out that school for 5 sec
        end,
    },
    
    redirect = {
        id = 73981,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        handler = function ()
            -- Transfer combo points to new target
        end,
    },
    
    fan_of_knives = {
        id = 51723,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        handler = function ()
            gain(1, "combo_points")
        end,
    },
    
    shuriken_toss = {
        id = 114014,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        talent = "shuriken_toss",
        
        handler = function ()
            gain(1, "combo_points")
        end,
    },
    
    shadowstep = {
        id = 36554,
        cast = 0,
        cooldown = 24,
        gcd = "spell",
        
        talent = "shadowstep",
        
        handler = function ()
            -- Teleport behind target and increase next damage ability
            applyBuff("shadowstep")
        end,
    },
    
    preparation = {
        id = 14185,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        talent = "preparation",
        
        handler = function ()
            -- Reset cooldowns of various abilities
            setCooldown("vanish", 0)
            setCooldown("sprint", 0)
            setCooldown("shadowstep", 0)
            
            -- If glyphed, also reset these
            if glyph.preparation.enabled then
                setCooldown("kick", 0)
                setCooldown("dismantle", 0) -- Not usually in MoP but included for completeness
                setCooldown("smoke_bomb", 0)
            end
        end,
    },
    
    burst_of_speed = {
        id = 108212,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 60,
        spendType = "energy",
        
        talent = "burst_of_speed",
        
        handler = function ()
            applyBuff("burst_of_speed")
            -- Remove movement impairing effects
        end,
    },
    
    tricks_of_the_trade = {
        id = 57934,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        handler = function ()
            applyBuff("tricks_of_the_trade")
        end,
    },
    
    distract = {
        id = 1725,
        cast = 0,
        cooldown = function() return glyph.distract.enabled and 20 or 30 end,
        gcd = "spell",
        
        spend = 30,
        spendType = "energy",
        
        handler = function ()
            -- Distracts targets, causing them to face away
        end,
    },
    
    feint = {
        id = 1966,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 20,
        spendType = "energy",
        
        handler = function ()
            applyBuff("feint")
        end,
    },
    
    blind = {
        id = 2094,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 15,
        spendType = "energy",
        
        handler = function ()
            applyDebuff("target", "blind")
        end,
    },
    
    evasion = {
        id = 5277,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "defensives",
        
        handler = function ()
            applyBuff("evasion")
        end,
    },
    
    cloak_of_shadows = {
        id = 31224,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "defensives",
        
        handler = function ()
            applyBuff("cloak_of_shadows")
            -- Remove magical debuffs
        end,
    },
    
    sap = {
        id = 6770,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            applyDebuff("target", "sap")
        end,
    },
    
    sprint = {
        id = 2983,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        handler = function ()
            applyBuff("sprint")
        end,
    },
    
    apply_poison = {
        id = 2823, -- Deadly Poison
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        handler = function ()
            -- Apply poison to weapons
        end,
    },
} )

-- Register default pack for MoP Assassination Rogue
spec:RegisterPack( "Assassination", 20250517, [[Hekili:T1tBVTnUr8pkEYV8iQu0j)Nf5aP38KYDXtl9i5rPjbJPNH1YAksY(OkvoS5Q2O5vbgdIUw2dejxvLvuPzQdxiMmmpFmShjl3ZxaeHTWwodzLbh7(Gg35W)IVxtdNmTzpF(S)T3BtPS8wtpA5CELlztZQeX0BP8kaOBcbpNFgmrW68YHL0pCc6uzVqBNsxIxMTmppQKlu5lpdVMXHrMVNtSM(6awj4Mjdq1Q5lhhpZIWUq6jYBzNxZFs2dk6VtCzItwKJFriiKsOFJ0iBjzvQxEReb4KGkAwLYoTkELuUKyEPbzR4kWKV9zhHjevQi5Qemi93kj8QBdH3(S86R1viPsvoMqv0imVScGvGnml2CkD7OJkpz7LfbATIYs0ccnTZvmM(4cfS0dpEPTw3jEasRlSyqUoJdlsNzYX0LiKpyihcDJYiLza9admWK8I3hb4aUAHkoJ62ZA1cfUDO9vcOF1]])

-- Register pack selector for Assassination
spec:RegisterPackSelector( "assassination", "Assassination", "|T132292:0|t Assassination",
    "Handles all aspects of Assassination Rogue rotation with focus on poison and bleed damage.",
    nil )

-- Assassination-specific state tables
spec:RegisterStateTable("stealthed", { all = false, rogue = false })

-- Handle stealth state tracking
spec:RegisterHook("reset_preprocess", function()
    if buff.stealth.up or buff.vanish.up or buff.subterfuge.up then
        stealthed.all = true
        stealthed.rogue = true
    else
        stealthed.all = false
        stealthed.rogue = false
    end
    
    -- MoP stealth detection for abilities
    if talent.shadow_focus.enabled and stealthed.all then
        -- Shadow Focus reduces energy costs by 75% in stealth
        for action_name, action in pairs(state.actions) do
            if action.spendType == "energy" then
                action.spend = action.spend * 0.25
            end
        end
    end
end)

-- Register ranges for Assassination
spec:RegisterRanges(
    "mutilate",           -- 5 yards (melee)
    "garrote",            -- 5 yards (melee)
    "throw",              -- 30 yards
    "blind",              -- 15 yards
    "shuriken_toss"       -- 30 yards
)

-- Register options for Assassination
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 2,
    
    gcd = "spell",
    
    package = "Assassination",
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 3,
    
    potion = "virmen_bite_potion",
    
    -- Assassination-specific options
    envenom_pool_pct = 50,       -- Energy percentage to pool before Envenom
    priority_rotation = false,   -- Ignore energy pooling
    use_rupture = true,          -- Use Rupture in rotation
    use_garrote = true,          -- Use Garrote in rotation
    maintain_garrote = true,     -- Keep Garrote up in single target
    vendetta_duration = 20,      -- Vendetta duration (for sync calculations)
} )

-- Assassination-specific settings
spec:RegisterSetting("envenom_pool_pct", 50, {
    name = "Envenom Energy Pool %",
    desc = "Set the percentage of energy the addon should recommend to pool up to before using Envenom in non-priority rotations.",
    type = "range",
    min = 0,
    max = 100,
    step = 5,
    width = "full"
})

spec:RegisterSetting("priority_rotation", false, {
    name = "Use Priority Rotation",
    desc = "If checked, the addon will prioritize using abilities immediately instead of waiting for energy pools and buff alignments.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("maintain_garrote", true, {
    name = "Maintain |T132297:0|t Garrote",
    desc = "If checked, the addon will recommend keeping |T132297:0|t Garrote active on the target in single-target scenarios.",
    type = "toggle",
    width = "full"
})
