-- RogueCombat.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Rogue: Combat spec

if UnitClassBase( 'player' ) ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 260 ) -- Combat spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
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
    deadly_throw               = { 4911, 1, 26679 },
    nerve_strike               = { 4912, 1, 108210 },
    combat_readiness           = { 4913, 1, 74001 },
    
    -- Tier 3 (Level 45)
    cheat_death                = { 4914, 1, 31230 },
    leeching_poison            = { 4915, 1, 108211 },
    elusiveness                = { 4916, 1, 79008 },
    
    -- Tier 4 (Level 60)
    preparation                = { 4917, 1, 14185 },
    shadowstep                 = { 4918, 1, 36554 },
    burst_of_speed             = { 4919, 1, 108212 },    
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

-- Glyphs
spec:RegisterGlyphs( {
    -- Major glyphs (Combat-specific)
    [56808] = "adrenaline_rush",    -- Increases the duration of Adrenaline Rush by 5 sec.
    [56818] = "blade_flurry",       -- Blade Flurry has no energy cost, but no longer generates combo points.
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
    [56809] = "gouge",              -- Reduces the energy cost of Gouge by 25.
    [56805] = "kick",               -- Reduces the cooldown of Kick by 2 sec.
    [63252] = "killing_spree",      -- Reduces the cooldown of Killing Spree by 45 sec.
    [58027] = "pick_lock",          -- Pick Lock no longer requires Thieves' Tools.
    [58017] = "pick_pocket",        -- Allows Pick Pocket to be used while in combat.
    [58038] = "poisons",            -- Your weapon enchantments no longer have a time restriction.
    [56819] = "preparation",        -- Adds Dismantle, Kick, and Smoke Bomb to the abilities reset by Preparation.
    [56814] = "revealing_strike",   -- Your Revealing Strike increases the damage of your finishing moves by an additional 10%.
    [58033] = "safe_fall",          -- Reduces the damage taken from falling by 30%.
    [56798] = "sap",                -- Increases the duration of Sap by 20 sec.
    [56821] = "sinister_strike",    -- Your Sinister Strike has a 20% chance to generate an additional combo point.
    [56810] = "slice_and_dice",     -- Your Slice and Dice ability costs no energy.
    [56811] = "sprint",             -- Increases the duration of Sprint by 1 sec.
    [63256] = "tricks_of_the_trade",-- Your Tricks of the Trade lasts an additional 4 sec.
    [89758] = "vanish",             -- When you Vanish, your threat is reset on all enemies.
    
    -- Minor glyphs
    [63415] = "blinding_powder",    -- Your Blind ability no longer requires a reagent.
    [57115] = "detection",          -- Increases the range at which you can detect stealthed or invisible enemies.
    [57114] = "distract",           -- Increases the range of Distract by 5 yards.
    [58037] = "hemorrhaging_veins", -- Your Hemorrhage ability now trails blood on the floor.
    [57112] = "pick_pocket",        -- Increases the range of Pick Pocket by 5 yards.
    [58036] = "poisons",            -- Applying poisons to your weapons grants a 50% chance to apply that poison to your other weapon as well.
    [57113] = "safe_fall",          -- Reduces the damage taken from falling by 30%.
    [57118] = "tricks_of_the_trade",-- When you use Tricks of the Trade, you gain 10% increased movement speed for 6 sec.
    [57117] = "vanish",             -- Reduces the cooldown of your Vanish ability by 30 sec.
} )

-- Combat specific auras
spec:RegisterAuras( {
    -- Energy regeneration increased by 20%.
    adrenaline_rush = {
        id = 13750,
        duration = function() return glyph.adrenaline_rush.enabled and 20 or 15 end,
        max_stack = 1,
    },
    -- Revealing Strike: Increases the effectiveness of your finishing moves by 35%.
    revealing_strike = {
        id = 84617,
        duration = 24,
        max_stack = 1,
    },
    -- Blade Flurry: Strikes enemies within 8 yards with normalized attacks.
    blade_flurry = {
        id = 13877,
        duration = 3600,
        max_stack = 1,
    },
    -- Killing Spree: Teleporting between enemies, dealing damage over 3 sec.
    killing_spree = {
        id = 51690,
        duration = 3,
        max_stack = 1,
    },
    -- Restless Blades: Finishing moves reduce cooldowns
    restless_blades = {
        id = 79096,
        duration = 3600,
        max_stack = 1,
    },
    -- Bandit's Guile: Three stacks of insight increasing damage
    shallow_insight = {
        id = 84745,
        duration = 15,
        max_stack = 1,
    },
    -- Shared rogue auras
    -- Stealth-related
    stealth = {
        id = 1784,
        duration = 3600,
        max_stack = 1,
    },
    vanish = {
        id = 11327,
        duration = 3,
        max_stack = 1,
    },
    -- Poisons
    crippling_poison = {
        id = 3408,
        duration = 3600,
        max_stack = 1,
    },
    deadly_poison = {
        id = 2823,
        duration = 3600,
        max_stack = 1,
    },
    deadly_poison_dot = {
        id = 2818,
        duration = function () return 12 * haste end,
        tick_time = 3,
        max_stack = 5,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.deadly_poison_dot.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.deadly_poison_dot.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.deadly_poison_dot.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },
    mind_numbing_poison = {
        id = 5761,
        duration = 3600,
        max_stack = 1,
    },
    wound_poison = {
        id = 8679,
        duration = 3600,
        max_stack = 1,
    },
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1,
    },
    paralytic_poison = {
        id = 108215,
        duration = 3600,
        max_stack = 1,
    },
    -- Bleeds
    garrote = {
        id = 703,
        duration = function() return glyph.garrote.enabled and 21 or 18 end,
        tick_time = 3,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.garrote.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 3 end
                local hasteMod = tracked_bleeds.garrote.haste[ target.unit ]
                hasteMod = 3 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.garrote.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },
    rupture = {
        id = 1943,
        duration = function() 
            if combo_points.current == 0 then return 8
            elseif combo_points.current == 1 then return 10
            elseif combo_points.current == 2 then return 12
            elseif combo_points.current == 3 then return 14
            elseif combo_points.current == 4 then return 16
            else return 18 end
        end,
        tick_time = 2,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.rupture.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.rupture.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.rupture.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },
    moderate_insight = {
        id = 84746,
        duration = 15,
        max_stack = 1,
    },
    deep_insight = {
        id = 84747,
        duration = 15,
        max_stack = 1,
    },
    -- Redirect: Transfers combo points from one target to another
    redirect = {
        id = 73981,
        duration = 3600, -- It's an active ability without a buff duration
        max_stack = 1,
    },
    -- Combat Potency: Chance to generate Energy on off-hand attacks
    combat_potency = {
        id = 35553,
        duration = 3600, -- It's a passive ability
        max_stack = 1,
    },
} )

-- Base Rogue auras added directly to Combat spec
spec:RegisterAuras( {
    -- Base abilities
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
        max_stack = 1,
    }
} )

-- Utility functions
local tracked_bleeds = {}
local function NewBleed(key, id)
    tracked_bleeds[key] = {
        id = id,
        last_seen = 0,
        duration = 0
    }
end

local function UpdateBleed(key, present, expirationTime)
    if not tracked_bleeds[key] then return end
    
    local now = GetTime()
    local bleed = tracked_bleeds[key]
    
    if present and expirationTime then
        bleed.last_seen = now
        bleed.duration = expirationTime - now
    end
end

-- Combat Rogue abilities
spec:RegisterAbilities({
    adrenaline_rush = {
        id = 13750,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136206,
        
        handler = function ()
            applyBuff("adrenaline_rush")
        end,
    },
    
    ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 60,
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            gain(glyph.ambush.enabled and 3 or 1, "combo_points")
            removeBuff("stealth")
        end,
    },
    
    blade_flurry = {
        id = 13877,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        spend = function() return glyph.blade_flurry.enabled and 0 or 10 end,
        spendType = "energy",
        
        handler = function ()
            if buff.blade_flurry.up then
                removeBuff("blade_flurry")
            else
                applyBuff("blade_flurry")
            end
        end,
    },
    
    eviscerate = {
        id = 2098,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        handler = function ()
            spend(combo_points, "combo_points")
        end,
    },
    
    killing_spree = {
        id = 51690,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236277,
        
        handler = function ()
            applyBuff("killing_spree")
        end,
    },
    
    redirect = {
        id = 73981,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = false,
        texture = 236286,
        
        handler = function ()
            -- Just applies the effect; no buff to track
        end,
    },
    
    revealing_strike = {
        id = 84617,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        startsCombat = true,
        texture = 132298,
        
        handler = function ()
            applyDebuff("target", "revealing_strike")
        end,
    },
    
    sinister_strike = {
        id = 1752,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        handler = function ()
            gain(1 + (glyph.sinister_strike.enabled and math.random() < 0.2 and 1 or 0), "combo_points")
        end,
    }
})

-- Now define Combat spec states and expressions
spec:RegisterStateExpr("cp_max_spend", function()
    return combo_points.max
end)

-- Combat Potency passive for off-hand energy regen
spec:RegisterHook("reset_postinit", function()
    if state.talent.combat_potency.enabled then
        state:RegisterAuraTracking("combat_potency", {
            aura = "combat_potency",
            state = "combat_potency",
            onApply = function() 
                gain(3, "energy") -- Combat Potency proc (modified for MoP version)
            end,
        })
    end
end)

-- Finish the spec setup for Combat
spec:RegisterStateTable("stealthed", { all = false, rogue = false })
spec:RegisterStateTable("opener_done", { sinister_strike = false, revealing_strike = false })

-- Register ranges for Combat
spec:RegisterRanges(
    "sinister_strike",    -- 5 yards (melee)
    "garrote",            -- 5 yards (melee)
    "shuriken_toss",      -- 30 yards
    "throw",              -- 30 yards
    "blind"               -- 15 yards
)

-- Register default pack for MoP Combat Rogue
spec:RegisterPack( "Combat", 20250517, [[Hekili:T1vBVTTnu4FlbiQSZfnsajQtA2cBlSTJvAm7njo5i5bYqjRtasiik)vfdC9d7tLsksKRceSacS73n7dNjgfORdxKuofvkQXWghRdh7iih7ii)m5rJg9H1SxJw(qAiih(7FAJRyDF9)9EU7VsCgF)upgdVgM)P8HposKXisCicp7(ob2ZXdpixyxvynaLeWZA67v)OBP5fV9IDgOJvzNJVky08ejfY6Fk5cpMPzlPift10fZQMrbrTe)GkbJb(KuIztYJ1YJkuS0LuPitvI1wPcMQZ9w68ttCwc3fj2OUia3wKYLf1wUksoeD5WyKpYpTtn(qbjlGGwaYJCJ6kPCbvrYhSKibHsXEhtYCbuuiP5Iwjr4f0Mn4r)ZhOrqfacFyjXM1TK4JbLD27PVzAcKpTrqLiWkjGdHv(oguYcq(IMwbQajGbbonWfynQh0KVsK)kTDMaHhdiJG6IT2Ot6Ng6G7Z61J6X(JN8GaLPpxluG3xi8)]])

-- Register pack selector for Combat
spec:RegisterPackSelector( "combat", "Combat", "|T132090:0|t Combat",
    "Handles all aspects of Combat Rogue rotation with appropriate AoE, cleave and ST priorities.",
    nil )

-- Register options for Combat
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 2,
    
    gcd = "spell",
    
    package = "Combat",
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 3,
    
    potion = "virmen_bite_potion",
    
    -- Combat-specific options
    blade_flurry_targets = 2,    -- Number of targets for Blade Flurry to be worth using
    priority_rotation = false,   -- Ignore energy pooling
    allow_ads = false,           -- Permit usage of Adrenaline Rush if add waves are coming soon
    use_revealing_strike = true, -- Use Revealing Strike in rotation
    use_slice_and_dice = true,   -- Use Slice and Dice in rotation
    use_rupture = true,          -- Use Rupture in rotation
    killing_spree_allowed = true, -- Allow Killing Spree usage
} )

-- Combat-specific settings
spec:RegisterSetting("priority_rotation", false, {
    name = "Use Priority Rotation",
    desc = "If checked, the addon will prioritize using abilities immediately instead of waiting for energy pools and buff alignments.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("use_revealing_strike", true, {
    name = "Use |T132298:0|t Revealing Strike",
    desc = "If checked, the addon will recommend using |T132298:0|t Revealing Strike to increase the effectiveness of your finishers.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("blade_flurry_targets", 2, {
    name = "Blade Flurry Target Threshold",
    desc = "Set the number of targets required for the addon to recommend using Blade Flurry.",
    type = "range",
    min = 2,
    max = 10,
    step = 1,
    width = "full"
})
