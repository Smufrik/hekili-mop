-- RogueSubtlety.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Rogue: Subtlety spec

if UnitClassBase( 'player' ) ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 261 ) -- Subtlety spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local UA_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

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
    shuriken_toss              = { 4923, 1, 114014 }, -- Ranged attack that generates combo points    marked_for_death           = { 4924, 1, 137619 }, -- Target gains 5 combo points
    anticipation               = { 4925, 1, 115189 }  -- Store up to 10 combo points
} )

-- Glyphs
spec:RegisterGlyphs( {
    -- Major glyphs (Subtlety-specific)
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
    [58027] = "pick_lock",          -- Pick Lock no longer requires Thieves' Tools.
    [58017] = "pick_pocket",        -- Allows Pick Pocket to be used while in combat.
    [58038] = "poisons",            -- Your weapon enchantments no longer have a time restriction.
    [56819] = "preparation",        -- Adds Dismantle, Kick, and Smoke Bomb to the abilities reset by Preparation.
    [56801] = "rupture",            -- Your Rupture ability no longer has a range limitation.
    [58033] = "safe_fall",          -- Reduces the damage taken from falling by 30%.
    [56798] = "sap",                -- Increases the duration of Sap by 20 sec.
    [63253] = "shadow_dance",       -- Increases the duration of Shadow Dance by 2 sec.
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
    [57116] = "poisons",            -- Applying poisons to your weapons grants a 50% chance to apply that poison to your other weapon as well.
    [57113] = "safe_fall",          -- Reduces the damage taken from falling by 30%.
    [57118] = "tricks_of_the_trade",-- When you use Tricks of the Trade, you gain 10% increased movement speed for 6 sec.
    [57117] = "vanish",             -- Reduces the cooldown of your Vanish ability by 30 sec.
} )

-- Subtlety specific auras
spec:RegisterAuras( {
    -- Shadow Dance: Allows use of abilities requiring stealth.
    shadow_dance = {
        id = 51713,
        duration = function() return glyph.shadow_dance.enabled and 10 or 8 end,
        max_stack = 1,
    },
    -- Premeditation: Adds 2 combo points.
    premeditation = {
        id = 73651, -- Buff ID
        duration = 20,
        max_stack = 1,
    },
    -- Hemorrhage: Increases physical damage, bleeds target.
    hemorrhage = {
        id = 16511,
        duration = 24,
        max_stack = 1,
        tick_time = 3,
    },
    -- Energetic Recovery: Your finishers restore energy over time.
    energetic_recovery = {
        id = 79152, -- This is a passive talent, so just tracking the aura
        duration = 3600, 
        max_stack = 1,
    },    -- Find Weakness: Bypass 70% of armor for 10 sec after stealth abilities.
    find_weakness = {
        id = 91021,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 91021, "PLAYER" )
            
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
    -- Master of Subtlety: Increased damage for 6 sec after leaving stealth.
    master_of_subtlety = {
        id = 31665,
        duration = 6,
        max_stack = 1,
    },
    -- Honor Among Thieves: Chance to gain combo points when allies crit.
    honor_among_thieves = {
        id = 51698,
        duration = 3600, -- This is a passive ability
        max_stack = 1,
    },
    -- Sanguinary Vein: Target takes 16% more damage while bleeding.
    sanguinary_vein = {
        id = 79147,
        duration = 3600, -- This is a passive ability
        max_stack = 1,
    }
} )

-- Base Rogue auras added directly to Subtlety spec
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
        max_stack = 1,
    }
} )

-- Subtlety specific abilities
spec:RegisterAbilities( {
    backstab = {
        id = 53,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        -- Must be behind the target
        usable = function() return state.position.behind, "must be behind target" end,
        
        handler = function ()
            gain(1, "combo_points")
        end,
    },
    
    hemorrhage = {
        id = 16511,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "energy",
        
        handler = function ()
            applyDebuff("target", "hemorrhage")
            gain(1, "combo_points")
        end,
    },
    
    premeditation = {
        id = 14183,
        cast = 0,
        cooldown = 20,
        gcd = "off",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            gain(2, "combo_points")
            applyBuff("premeditation")
        end,
    },
    
    shadow_dance = {
        id = 51713,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        handler = function ()
            applyBuff("shadow_dance")
            -- In MoP, Shadow Dance puts you in stealth state for its duration
            applyBuff("stealth", shadow_dance.duration)
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
            local cp = combo_points.current
            spend(cp, "combo_points")
            
            -- Restless Blades reduces cooldowns based on combo points spent
            if talent.restless_blades.enabled then
                local reduction = cp * 2
                cooldown.shadow_dance.expires = cooldown.shadow_dance.expires - reduction
                -- Add other cooldowns that get reduced
            end
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
            local cp_gain = 1
            if talent.initiative.enabled or glyph.ambush.enabled then
                cp_gain = cp_gain + 2
            end
            gain(cp_gain, "combo_points")
            
            -- MoP Subtlety specific: Apply Find Weakness after ambush
            applyDebuff("target", "find_weakness")
            
            if not buff.shadow_dance.up then
                removeBuff("stealth")
            end
        end,
    },
    
    garrote = {
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 45,
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
          handler = function ()
            applyDebuff("target", "garrote")
            gain(1, "combo_points")
            
            -- MoP Subtlety specific: Apply Find Weakness after garrote (core passive)
            applyDebuff("target", "find_weakness")
            
            if not buff.shadow_dance.up then
                removeBuff("stealth")
            end
        end,
    },
    
    cheap_shot = {
        id = 1833,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            applyDebuff("target", "cheap_shot")
            gain(2, "combo_points")
            
            -- MoP Subtlety specific: Apply Find Weakness after cheap shot
            if talent.find_weakness.enabled then
                applyDebuff("target", "find_weakness")
            end
            
            if not buff.shadow_dance.up then
                removeBuff("stealth")
            end
        end,
    },
    
    vanish = {
        id = 1856,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        handler = function ()
            applyBuff("vanish")
            applyBuff("stealth")
            applyBuff("master_of_subtlety")
            -- Remove all threat
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
            
            if talent.restless_blades.enabled then
                local reduction = cp * 2
                cooldown.shadow_dance.expires = cooldown.shadow_dance.expires - reduction
            end
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
            
            if talent.restless_blades.enabled then
                local reduction = cp * 2
                cooldown.shadow_dance.expires = cooldown.shadow_dance.expires - reduction
            end
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
    
    recuperate = {
        id = 73651,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "energy",
        
        handler = function ()
            local cp = combo_points.current
            spend(cp, "combo_points")
            
            applyBuff("recuperate", 6 + (4 * cp))
            
            if talent.restless_blades.enabled then
                local reduction = cp * 2
                cooldown.shadow_dance.expires = cooldown.shadow_dance.expires - reduction
            end
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
} )

-- Subtlety specific state setup
spec:RegisterStateTable("stealthed", { 
    all = false, 
    rogue = false,
    shadowdance = false
})

-- Track combo point consumers
spec:RegisterStateExpr("cp_max_spend", function()
    return talent.anticipation.enabled and 5 or combo_points.current
end)

-- Track how long we can maintain Hemorrhage
spec:RegisterStateExpr("hemo_remains", function()
    return debuff.hemorrhage.remains
end)

-- Track Find Weakness debuff
spec:RegisterStateExpr("find_weakness_remains", function()
    return debuff.find_weakness.remains
end)

-- Handle stealth state tracking
spec:RegisterHook("reset_preprocess", function()
    if buff.shadow_dance.up then
        stealthed.all = true
        stealthed.shadowdance = true
    elseif buff.stealth.up or buff.vanish.up or buff.subterfuge.up then
        stealthed.all = true
        stealthed.rogue = true
    else
        stealthed.all = false
        stealthed.rogue = false
        stealthed.shadowdance = false
    end
    
    -- MoP stealth detection for Subtlety abilities
    if talent.shadow_focus.enabled and stealthed.all then
        -- Shadow Focus reduces energy costs by 75% in stealth
        for action_name, action in pairs(state.actions) do
            if action.spendType == "energy" then
                action.spend = action.spend * 0.25
            end
        end
    end
end)

-- Apply positional requirements
spec:RegisterStateExpr("position", function()
    return {
        behind = true -- We assume the player is always behind the target
    }
end)

-- Track if the target is bleeding (for Sanguinary Vein)
spec:RegisterStateExpr("target_is_bleeding", function()
    return debuff.garrote.up or debuff.rupture.up or debuff.crimson_tempest.up
end)

-- Combo point handling
spec:RegisterHook("spend", function(amt, resource)
    if resource == "combo_points" then
        -- Handle Honor Among Thieves mechanic
        if talent.honor_among_thieves.enabled then
            -- In a real implementation, this would require raid members to crit
            -- For simulation purposes, assume it procs periodically
        end
    end
end)

-- Handle Master of Subtlety buff
spec:RegisterHook("PLAYER_REGEN_ENABLED", function()
    -- This would typically happen when leaving combat
    if buff.master_of_subtlety.up then
        -- The buff persists for 6 seconds after leaving stealth
        removeBuff("master_of_subtlety")
    end
end)

-- Register ranges for Subtlety
spec:RegisterRanges(
    "backstab",       -- 5 yards (melee)
    "garrote",        -- 5 yards (melee)
    "shadowstep",     -- 25 yards
    "shuriken_toss",  -- 30 yards
    "sap"             -- 10 yards
)

-- Register default pack for MoP Subtlety Rogue
spec:RegisterPack( "Subtlety", 20250517, [[Hekili:T1tBpTTns4FltyjIygn00MRy5YZIrvnPl8yFUydPeWbQJejirpgIZ6qa2V976UQUKurNvbcEmW30La6aG)YzZJ1jvZRXUfZQpggfhxGXbhRh7iiRdhN9HFVhVFVxtGrWcZE3YtFENRDh)YhnzWhIGEeDtmXyD(AMfuPRUFkEfyoJ1KcvMJlwkLjPe1aj7uRQvgMKcSakswuzEK4Q4TCnjxjVHc1RG9wyPv(vmQQfgSKfe4YrTQabtH(l18KCoIHIQi5QeiGsjkHlQkkzfjl1aNaHELinmjjgZwQHqgVucyzgeYTV3T1wYJGEAj8wiHwBPmiXxiGigxieIUaKqc5qUuMRTasiqHdHKkxYWcOeQvPXXMkff62tZtvPQx(N9ztKO8FnGdLnqrlMTu4mk2tcTggnBswdjCacVVmSWSNz9vzyRkGfD11rYlM4wb0g0rZPPA8fY9pxbtO4eBm9TCvM)]])

-- Register pack selector for Subtlety
spec:RegisterPackSelector( "subtlety", "Subtlety", "|T132320:0|t Subtlety",
    "Handles all aspects of Subtlety Rogue rotation with focus on stealth and positional abilities.",
    nil )

-- Register options for Subtlety
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 2,
    
    gcd = "spell",
    
    package = "Subtlety",
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 3,
    
    potion = "virmen_bite_potion",
    
    -- Subtlety-specific options
    optimize_premeditation = true,   -- Try to use Premeditation optimally
    fps_reports = false,            -- Hide first-person stealth reports
    mfd_waste = false,              -- Use Marked for Death even if at max CPs
    priority_rotation = false,      -- Ignore energy pooling
    shadow_dance_allowed = true,    -- Allow Shadow Dance usage
    hemorrhage_uptime = true,       -- Try to maintain Hemorrhage
    mode = "normal",                -- normal, funnel, or aoe
    
    -- Stealth options
    stealth_action = "ambush",       -- Default action out of stealth
    stealth_threshold = 3,           -- Required seconds remaining on Slice and Dice to use Stealth actions
    vanish_rupture_threshold = 5,    -- Required seconds remaining on Rupture to use Vanish
} )

-- Subtlety-specific settings
spec:RegisterSetting("allow_shadowmeld", false, {
    name = "Allow |T132089:0|t Shadowmeld Usage",
    desc = "If checked and your character is a Night Elf, the addon will include |T132089:0|t Shadowmeld in recommendations to allow usage of Stealth abilities.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("priority_rotation", false, {
    name = "Use Priority Rotation",
    desc = "If checked, the addon will prioritize using abilities immediately instead of waiting for energy pools and buff alignments.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("hemorrhage_uptime", true, {
    name = "Maintain |T132134:0|t Hemorrhage",
    desc = "If checked, the addon will recommend using |T132134:0|t Hemorrhage to maintain the bleed effect when appropriate.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("optimize_shadow_dance", true, {
    name = "Optimize |T132296:0|t Shadow Dance",
    desc = "If checked, the addon will recommend optimal usage of |T132296:0|t Shadow Dance and stealth abilities during the window.",
    type = "toggle",
    width = "full"
})
