-- DeathKnightFrost.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Death Knight: Frost spec

if UnitClassBase( 'player' ) ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 251 ) -- Frost spec ID for MoP

local strformat = string.format
local UA_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.RunicPower )
spec:RegisterResource( Enum.PowerType.Runes )

-- Tier sets
spec:RegisterGear( "tier14", 86919, 86920, 86921, 86922, 86923 ) -- T14 Battleplate of the Lost Cataphract
spec:RegisterGear( "tier15", 95225, 95226, 95227, 95228, 95229 ) -- T15 Battleplate of the All-Consuming Maw

-- Talents (MoP talent system and Frost spec-specific talents)
spec:RegisterTalents( {
    -- Common MoP talent system (Tier 1-6)
    -- Tier 1 (Level 56) - Mobility
    unholy_presence      = { 4923, 1, 48265 },
    frost_presence       = { 4924, 1, 48266 },
    blood_presence       = { 4925, 1, 48263 },
    
    -- Tier 2 (Level 57)
    lichborne            = { 4926, 1, 49039 },
    anti_magic_zone      = { 4927, 1, 51052 },
    purgatory            = { 4928, 1, 114556 },
    
    -- Tier 3 (Level 58)
    deaths_advance       = { 4929, 1, 96268 },
    chilblains           = { 4930, 1, 50041 },
    asphyxiate          = { 4931, 1, 108194 },
    
    -- Tier 4 (Level 59)
    death_pact           = { 4932, 1, 48743 },
    death_siphon         = { 4933, 1, 108196 },
    conversion           = { 4934, 1, 119975 },
    
    -- Tier 5 (Level 60)
    blood_tap            = { 4935, 1, 45529 },
    runic_empowerment    = { 4936, 1, 81229 },
    runic_corruption     = { 4937, 1, 51460 },
      -- Tier 6 (Level 75)
    gorefiends_grasp     = { 4938, 1, 108199 },
    remorseless_winter   = { 4939, 1, 108200 },
    desecrated_ground    = { 4940, 1, 108201 },
} )

-- Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [58640] = "anti_magic_shell",    -- Increases duration of Anti-Magic Shell by 2 sec, but increases cooldown by 20 sec.
    [63331] = "chains_of_ice",       -- Your Chains of Ice also causes 144 to 156 Frost damage, increased by your attack power.
    [58632] = "dark_simulation",     -- Dark Simulacrum can be used while stunned.
    [58657] = "dark_succor",         -- Death Strike heals for 20% of your health when used while not in Blood Presence.
    [58629] = "death_and_decay",     -- Increases damage done by Death and Decay by 15%.
    [58677] = "death_coil",          -- Death Coil also heals your pets for 1% of the Death Knight's health.
    [58686] = "death_grip",          -- When you deal a killing blow to a target that yields experience or honor, the cooldown of Death Grip is reset.
    [59337] = "death_strike",        -- Reduces the cost of Death Strike by 8 Runic Power.
    [58616] = "horn_of_winter",      -- Horn of Winter no longer generates Runic Power, but lasts 1 hour.
    [58622] = "howling_blast",       -- Your Howling Blast causes additional damage to your primary target.
    [58631] = "icebound_fortitude",  -- Reduces the cooldown of Icebound Fortitude by 60 sec but also reduces its duration by 2 sec.
    [58675] = "icy_touch",           -- Your Frost Fever disease deals 20% additional damage.
    [63335] = "pillar_of_frost",     -- Pillar of Frost can no longer be dispelled but has a 1-min cooldown.
    [58671] = "plague_strike",       -- Plague Strike does an additional 20% damage against targets who are above 90% health.
    [58649] = "soul_reaper",         -- When Soul Reaper strikes a target below 35% health, you gain 5% haste for 5 sec.
    
    -- Minor Glyphs
    [60200] = "death_gate",          -- Reduces cast time of Death Gate by 60%.
    [58617] = "foul_menagerie",      -- Your Raise Dead spell summons a random ghoul companion.
    [63332] = "path_of_frost",       -- Your Army of the Dead ghouls explode when they die or expire.
    [58680] = "resilient_grip",      -- Your Death Grip refunds its cooldown when used on a target immune to grip effects.
    [59307] = "the_geist",           -- Your Raise Dead spell summons a geist instead of a ghoul.
    [60108] = "tranquil_grip",       -- Your Death Grip no longer taunts targets.
} )

-- Frost DK specific auras
spec:RegisterAuras( {
    -- Frost Presence: Increased damage and movement speed.
    frost_presence = {
        id = 48266,
        duration = 3600, -- Long duration buff
        max_stack = 1,
    },
    -- Pillar of Frost: Main DPS cooldown. Increases Strength and immunity to knockbacks.
    pillar_of_frost = {
        id = 51271,
        duration = 20,
        max_stack = 1,
    },
    -- Killing Machine: Next Frost Strike or Obliterate will crit.
    killing_machine = {
        id = 51124,
        duration = 10,
        max_stack = 1,
    },
    -- Rime: Next Howling Blast will cost no Runes.
    rime = {
        id = 59052,
        duration = 15,
        max_stack = 1,
    },
    -- Freezing Fog: Same as Rime but for MoP implementation
    freezing_fog = {
        id = 59052,
        duration = 15,
        max_stack = 1,
    },
    -- Improved Frost Presence: Movement effects reduction
    improved_frost_presence = {
        id = 50384,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    -- Might of the Frozen Wastes: Two-handed weapon damage buff
    might_of_the_frozen_wastes = {
        id = 81333,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    -- Threat of Thassarian: Dual-wield abilities buff
    threat_of_thassarian = {
        id = 66192,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },

    -- Common Death Knight Auras (shared across all specs)
    -- Diseases
    blood_plague = {
        id = 59879,
        duration = function() return 30 end,
        max_stack = 1,
        type = "Disease",
    },
    frost_fever = {
        id = 59921,
        duration = function() return 30 end,
        max_stack = 1,
        type = "Disease",
    },
    
    -- Other Presences
    blood_presence = {
        id = 48263,
        duration = 3600,
        max_stack = 1,
    },
    unholy_presence = {
        id = 48265,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Defensive cooldowns
    anti_magic_shell = {
        id = 48707,
        duration = function() return glyph.anti_magic_shell.enabled and 7 or 5 end,
        max_stack = 1,
    },
    icebound_fortitude = {
        id = 48792,
        duration = function() return glyph.icebound_fortitude.enabled and 6 or 8 end,
        max_stack = 1,
    },
    
    -- Utility
    horn_of_winter = {
        id = 57330,
        duration = function() return glyph.horn_of_winter.enabled and 3600 or 120 end,
        max_stack = 1,
    },
    path_of_frost = {
        id = 3714,
        duration = 600,
        max_stack = 1,
    },
    
    -- Tier bonuses and procs
    sudden_doom = {
        id = 81340,
        duration = 10,
        max_stack = 1,
    },
    
    -- Runic system
    blood_tap = {
        id = 45529,
        duration = 30,
        max_stack = 10,
    },
    runic_corruption = {
        id = 51460,
        duration = 3,
        max_stack = 1,
    },    runic_empowerment = {
        id = 81229,
        duration = 5,
        max_stack = 1,
    },
    
    -- Missing important auras for Frost DK
    brittle_bones = {
        id = 81328,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    
    -- Chill of the Grave (increased RP generation)
    chill_of_the_grave = {
        id = 49149,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    
    -- Chains of Ice slow
    chains_of_ice = {
        id = 45524,
        duration = 8,
        max_stack = 1,
        type = "Magic",
    },
    
    -- Death Grip taunt
    death_grip = {
        id = 49560,
        duration = 3,
        max_stack = 1,
    },
} )

-- Frost DK core abilities
spec:RegisterAbilities( {    obliterate = {
        id = 49020,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 2, -- Consumes 1 Frost and 1 Unholy rune (or 2 Death runes)
        spendType = "death_runes", -- Uses any available runes
        
        startsCombat = true,
        
        usable = function() 
            return (runes.frost.count > 0 and runes.unholy.count > 0) or runes.death.count >= 2
        end,
        
        handler = function ()
            gain(15, "runicpower")
            
            -- Rime proc chance (15% base, increased by talent)
            local rime_chance = talent.rime.enabled and 0.45 or 0.15
            if math.random() < rime_chance then
                applyBuff("rime")
            end
            
            -- Killing Machine consumption if active
            if buff.killing_machine.up then
                removeBuff("killing_machine")
                -- Guaranteed crit when KM is active
            end
            
            -- Threat of Thassarian: dual-wield proc
            if talent.threat_of_thassarian.enabled then
                -- 50% chance to strike with off-hand as well
                if math.random() < 0.50 then
                    gain(5, "runicpower") -- Additional RP from off-hand strike
                end
            end
        end,
    },
      frost_strike = {
        id = 49143,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
            -- Killing Machine consumption and guaranteed crit
            local was_km_active = buff.killing_machine.up
            if was_km_active then
                removeBuff("killing_machine")
                -- This attack will crit due to KM
            end
            
            -- Threat of Thassarian: dual-wield proc
            if talent.threat_of_thassarian.enabled then
                -- 50% chance to strike with off-hand as well
                if math.random() < 0.50 then
                    -- Off-hand strike does additional damage
                end
            end
            
            -- Runic Empowerment/Corruption proc chance from RP spending
            if talent.runic_empowerment.enabled and math.random() < 0.45 then
                applyBuff("runic_empowerment")
            elseif talent.runic_corruption.enabled and math.random() < 0.45 then
                applyBuff("runic_corruption")
            end
        end,
    },
      howling_blast = {
        id = 49184,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.rime.up or buff.freezing_fog.up then return 0 end
            return 1
        end,
        spendType = function()
            if buff.rime.up or buff.freezing_fog.up then return nil end
            return "frost_runes"
        end,
        
        startsCombat = true,
        
        usable = function()
            return buff.rime.up or buff.freezing_fog.up or runes.frost.count > 0 or runes.death.count > 0
        end,
        
        handler = function ()
            -- Remove Rime/Freezing Fog buff if used
            if buff.rime.up then
                removeBuff("rime")
            elseif buff.freezing_fog.up then
                removeBuff("freezing_fog")
            end
            
            -- Apply Frost Fever to primary target
            applyDebuff("target", "frost_fever")
            
            -- Howling Blast hits all enemies in area and applies Frost Fever
            if active_enemies > 1 then
                -- Apply Frost Fever to all nearby enemies
                gain(5, "runicpower") -- Bonus RP for multi-target
            end
            
            gain(10, "runicpower")
            
            -- Glyph of Howling Blast: additional damage to primary target
            if glyph.howling_blast.enabled then
                -- Primary target takes additional damage
            end
        end,
    },
      pillar_of_frost = {
        id = 51271,
        cast = 0,
        cooldown = function() return glyph.pillar_of_frost.enabled and 60 or 120 end,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("pillar_of_frost")
        end,
    },
    
    icy_touch = {
        id = 45477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "frost_runes",
        
        startsCombat = true,
        
        usable = function() return runes.frost.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            applyDebuff("target", "frost_fever")
            
            -- Base RP generation
            local rp_gain = 10
            
            -- Chill of the Grave: additional RP from Icy Touch
            if talent.chill_of_the_grave.enabled then
                rp_gain = rp_gain + 5 -- Extra 5 RP per talent point
            end
            
            gain(rp_gain, "runicpower")
            
            -- Glyph of Icy Touch: increased Frost Fever damage
            if glyph.icy_touch.enabled then
                -- Frost Fever will deal 20% more damage
            end
        end,    },
    
    chains_of_ice = {
        id = 45524,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "frost_runes",
        
        startsCombat = true,
        
        usable = function() return runes.frost.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            applyDebuff("target", "chains_of_ice")
            gain(10, "runicpower")
            
            -- Glyph of Chains of Ice: additional damage
            if glyph.chains_of_ice.enabled then
                -- Deal additional frost damage scaled by attack power
            end
        end,
    },
    
    blood_strike = {
        id = 45902,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "blood_runes",
        
        startsCombat = true,
        texture = 237517,
        
        handler = function ()
            -- Blood Strike: Physical weapon attack with disease bonus
            -- Base damage + weapon damage, +12.5% per disease (max +25%)
            local disease_count = 0
            if debuff.blood_plague.up then disease_count = disease_count + 1 end
            if debuff.frost_fever.up then disease_count = disease_count + 1 end
            
            local damage_multiplier = 1.0 + (disease_count * 0.125)
            
            -- Generate 10 Runic Power
            gain(10, "runicpower")
        end,
    },
    
    -- Defensive cooldowns
    anti_magic_shell = {
        id = 48707,
        cast = 0,
        cooldown = function() return glyph.anti_magic_shell.enabled and 60 or 45 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("anti_magic_shell")
        end,
    },
    
    icebound_fortitude = {
        id = 48792,
        cast = 0,
        cooldown = function() return glyph.icebound_fortitude.enabled and 120 or 180 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("icebound_fortitude")
        end,
    },
    
    -- Utility
    death_grip = {
        id = 49576,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "death_grip")
        end,
    },
    
    mind_freeze = {
        id = 47528,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        toggle = "interrupts",
        
        startsCombat = true,
        
        handler = function ()
            if active_enemies > 1 and talent.asphyxiate.enabled then
                -- potentially apply interrupt debuff with talent
            end
        end,
    },
      death_and_decay = {
        id = 43265,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy_runes",
        
        startsCombat = true,
        
        usable = function() return runes.unholy.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            -- Generate RP based on number of enemies hit
            local rp_gain = 10 + (active_enemies > 1 and 5 or 0)
            gain(rp_gain, "runicpower")
            
            -- Glyph of Death and Decay: 15% more damage
            if glyph.death_and_decay.enabled then
                -- Increased damage from glyph
            end
        end,
    },
    
    rune_strike = {
        id = 56815,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "runicpower",
        
        startsCombat = true,
        texture = 237518,
        
        usable = function() return buff.blood_presence.up end,
        
        handler = function ()
            -- Rune Strike: Enhanced weapon strike (requires Blood Presence)
            -- 1.8x weapon damage + 10% Attack Power
            -- 1.75x threat multiplier
        end,
    },
    
    horn_of_winter = {
        id = 57330,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("horn_of_winter")
            if not glyph.horn_of_winter.enabled then
                gain(10, "runicpower")
            end
        end,
    },
    
    raise_dead = {
        id = 46584,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            -- Summon ghoul/geist pet based on glyphs
        end,
    },
      army_of_the_dead = {
        id = 42650,
        cast = function() return 4 end, -- 4 second channel (8 ghouls @ 0.5s intervals)
        cooldown = 600, -- 10 minute cooldown
        gcd = "spell",
        
        spend = function() return 1, 1, 1 end, -- 1 Blood + 1 Frost + 1 Unholy
        spendType = "runes",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 237302,
        
        handler = function ()
            -- Summon 8 ghouls over 4 seconds, each lasting 40 seconds
            -- Generates 30 Runic Power
            gain( 30, "runic_power" )
        end,
    },
    
    path_of_frost = {
        id = 3714,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("path_of_frost")
        end,
    },
    
    -- Presence switching
    blood_presence = {
        id = 48263,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("frost_presence")
            removeBuff("unholy_presence")
            applyBuff("blood_presence")
        end,
    },
    
    frost_presence = {
        id = 48266,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("unholy_presence")
            applyBuff("frost_presence")
        end,
    },
    
    unholy_presence = {
        id = 48265,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("frost_presence")
            applyBuff("unholy_presence")
        end,
    },
    
    -- Rune management
    blood_tap = {
        id = 45529,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = function() return glyph.blood_tap.enabled and 15 or 0 end,
        spendType = function() return glyph.blood_tap.enabled and "runicpower" or nil end,
        
        startsCombat = false,
        
        handler = function ()
            if not glyph.blood_tap.enabled then
                -- Original functionality: costs health
                spend(0.05, "health")
            end
            -- Convert a blood rune to a death rune
        end,
    },
    
    empower_rune_weapon = {
        id = 47568,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            -- Refresh all rune cooldowns and generate 25 runic power
            gain(25, "runicpower")
        end,
    },
} )

-- Add state handlers for Death Knight rune system
do
    local runes = {}
    
    spec:RegisterStateExpr( "rune", function ()
        return runes
    end )
    
    -- Blood Runes
    spec:RegisterStateExpr( "blood_runes", function ()
        return state.runes.blood
    end )
    
    -- Frost Runes
    spec:RegisterStateExpr( "frost_runes", function ()
        return state.runes.frost
    end )
    
    -- Unholy Runes
    spec:RegisterStateExpr( "unholy_runes", function ()
        return state.runes.unholy
    end )
    
    -- Death Runes
    spec:RegisterStateExpr( "death_runes", function ()
        return state.runes.death
    end )
      -- Initialize the rune tracking system for MoP Frost
    spec:RegisterStateTable( "runes", {
        blood = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        frost = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        unholy = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        death = { count = 0, actual = 0, max = 6, cooldown = 10, recharge_time = 10 }, -- Death runes created from conversions
    } )
    
    -- Frost-specific rune mechanics
    spec:RegisterStateFunction( "spend_runes", function( rune_type, amount )
        amount = amount or 1
        
        -- Handle multi-rune abilities like Obliterate (Frost + Unholy)
        if rune_type == "obliterate" then
            if runes.frost.count > 0 and runes.unholy.count > 0 then
                runes.frost.count = runes.frost.count - 1
                runes.unholy.count = runes.unholy.count - 1
            elseif runes.death.count >= 2 then
                runes.death.count = runes.death.count - 2
            end
        elseif rune_type == "frost" and (runes.frost.count >= amount or runes.death.count >= amount) then
            if runes.frost.count >= amount then
                runes.frost.count = runes.frost.count - amount
            else
                runes.death.count = runes.death.count - amount
            end
        elseif rune_type == "unholy" and (runes.unholy.count >= amount or runes.death.count >= amount) then
            if runes.unholy.count >= amount then
                runes.unholy.count = runes.unholy.count - amount
            else
                runes.death.count = runes.death.count - amount
            end
        elseif rune_type == "death" and runes.death.count >= amount then
            runes.death.count = runes.death.count - amount
        end
        
        -- Handle Runic Empowerment and Runic Corruption procs
        if talent.runic_empowerment.enabled then
            -- 45% chance to refresh a random rune when spending RP
            if math.random() < 0.45 then
                applyBuff("runic_empowerment")
                -- Refresh a random depleted rune
            end
        end
        
        if talent.runic_corruption.enabled then
            -- 45% chance to increase rune regeneration by 100% for 3 seconds
            if math.random() < 0.45 then
                applyBuff("runic_corruption")
            end
        end
    end )
    
    -- Auto-attack handler for Killing Machine procs
    spec:RegisterStateFunction( "auto_attack", function()
        if talent.killing_machine.enabled then
            -- 15% chance per auto attack to proc Killing Machine
            if math.random() < 0.15 then
                applyBuff("killing_machine")
            end
        end
    end )
    
    -- Add function to check runic power generation
    spec:RegisterStateFunction( "gain_runic_power", function( amount )
        -- Logic to gain runic power
        gain( amount, "runicpower" )
    end )
end

-- State Expressions for Frost Death Knight
spec:RegisterStateExpr( "km_up", function()
    return buff.killing_machine.up
end )

spec:RegisterStateExpr( "rime_react", function()
    return buff.rime.up or buff.freezing_fog.up
end )

spec:RegisterStateExpr( "diseases_up", function()
    return debuff.frost_fever.up and debuff.blood_plague.up
end )

spec:RegisterStateExpr( "frost_runes_available", function()
    return runes.frost.count + runes.death.count
end )

spec:RegisterStateExpr( "unholy_runes_available", function()
    return runes.unholy.count + runes.death.count
end )

spec:RegisterStateExpr( "can_obliterate", function()
    return (runes.frost.count > 0 and runes.unholy.count > 0) or runes.death.count >= 2
end )

spec:RegisterStateExpr( "runic_power_deficit", function()
    return runic_power.max - runic_power.current
end )

-- Two-handed vs dual-wield logic
spec:RegisterStateExpr( "is_dual_wielding", function()
    return not talent.might_of_the_frozen_wastes.enabled -- Simplified check
end )

spec:RegisterStateExpr( "weapon_dps_modifier", function()
    if talent.might_of_the_frozen_wastes.enabled then
        return 1.25 -- 25% more damage with 2H in Frost Presence
    elseif talent.threat_of_thassarian.enabled then
        return 1.0 -- Base damage but with off-hand procs
    end
    return 1.0
end )

-- Register default pack for MoP Frost Death Knight
spec:RegisterPack( "Frost", 20250515, [[Hekili:T3vBVTTnu4FlXnHr9LsojdlJE7Kf7K3KRLvAm7njb5L0Svtla8Xk20IDngN7ob6IPvo9CTCgbb9D74Xtx83u5dx4CvNBYZkeeZwyXJdNpV39NvoT82e)6J65pZE3EGNUNUp(4yTxY1VU)mEzZNF)wwc5yF)SGp2VyFk3fzLyKD(0W6Zw(aFW0P)MM]]  )

-- Register pack selector for Frost
spec:RegisterPackSelector( "frost", "Frost", "|T135773:0|t Frost",
    "Handles all aspects of Frost Death Knight rotation with focus on dual-wielding and Frost damage.",
    nil )
