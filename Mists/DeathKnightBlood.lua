-- DeathKnightBlood.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Death Knight: Blood spec

if UnitClassBase( 'player' ) ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 250 ) -- Blood spec ID for MoP

local strformat = string.format
local UA_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.RunicPower )
spec:RegisterResource( Enum.PowerType.Runes )

-- Tier sets
spec:RegisterGear( "tier14", 86919, 86920, 86921, 86922, 86923 ) -- T14 Battleplate of the Lost Cataphract
spec:RegisterGear( "tier15", 95225, 95226, 95227, 95228, 95229 ) -- T15 Battleplate of the All-Consuming Maw

-- Talents (MoP talent system and Blood spec-specific talents)
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
    [59336] = "blood_boil",          -- Blood Boil also affects friendly targets, healing them.
    [58647] = "blood_tap",           -- Blood Tap no longer costs health but now costs 15 Runic Power.
    [63330] = "dancing_rune_weapon", -- Increases the duration of Dancing Rune Weapon by 5 sec.
    [58657] = "dark_succor",         -- Death Strike heals for 20% of your health when used while not in Blood Presence.
    [58629] = "death_and_decay",     -- Increases damage done by Death and Decay by 15%.
    [58677] = "death_coil",          -- Death Coil also heals your pets for 1% of the Death Knight's health.
    [58686] = "death_grip",          -- When you deal a killing blow to a target that yields experience or honor, the cooldown of Death Grip is reset.
    [59337] = "death_strike",        -- Reduces the cost of Death Strike by 8 Runic Power.
    [58635] = "festering_blood",     -- Your Blood Boil causes undead and demons to be unable to attack or cast spells for 5 sec.
    [58616] = "horn_of_winter",      -- Horn of Winter no longer generates Runic Power, but lasts 1 hour.
    [58631] = "icebound_fortitude",  -- Reduces the cooldown of Icebound Fortitude by 60 sec but also reduces its duration by 2 sec.
    [63335] = "pillar_of_frost",     -- Pillar of Frost can no longer be dispelled but has a 1-min cooldown.
    [58671] = "plague_strike",       -- Plague Strike does an additional 20% damage against targets who are above 90% health.
    [58649] = "soul_reaper",         -- When Soul Reaper strikes a target below 35% health, you gain 5% haste for 5 sec.
    [58620] = "vampiric_blood",      -- Vampiric Blood no longer increases your maximum health, but its healing increase is 50% greater.
    
    -- Minor Glyphs
    [60200] = "death_gate",          -- Reduces cast time of Death Gate by 60%.
    [58642] = "foul_menagerie",      -- Your Raise Dead spell summons a random ghoul companion.
    [63332] = "path_of_frost",       -- Your Army of the Dead ghouls explode when they die or expire.
    [58680] = "resilient_grip",      -- Your Death Grip refunds its cooldown when used on a target immune to grip effects.
    [59307] = "the_geist",           -- Your Raise Dead spell summons a geist instead of a ghoul.
    [60108] = "tranquil_grip",       -- Your Death Grip no longer taunts targets.
} )

-- Blood DK specific auras
spec:RegisterAuras( {
    -- Blood Presence: Increased armor, health, and threat generation. Reduced damage taken.
    blood_presence = {
        id = 48263,
        duration = 3600, -- Long duration buff
        max_stack = 1,
    },
    -- Dancing Rune Weapon: Summons a copy of your weapon that mirrors your attacks.
    dancing_rune_weapon = {
        id = 49028,
        duration = function() return glyph.dancing_rune_weapon.enabled and 17 or 12 end,
        max_stack = 1,
    },
    -- Crimson Scourge: Free Death and Decay proc
    crimson_scourge = {
        id = 81141,
        duration = 15,
        max_stack = 1,
    },
    -- Bone Shield: Reduces damage taken
    bone_shield = {
        id = 49222,
        duration = 300,
        max_stack = 10,
    },
    -- Blood Shield: Absorb from Death Strike
    blood_shield = {
        id = 77513,
        duration = 10,
        max_stack = 1,
    },
    -- Vampiric Blood: Increases health and healing received
    vampiric_blood = {
        id = 55233,
        duration = 10,
        max_stack = 1,
    },
    -- Veteran of the Third War: Passive health increase
    veteran_of_the_third_war = {
        id = 48263,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    -- Death Grip Taunt
    death_grip = {
        id = 49560,
        duration = 3,
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
    frost_presence = {
        id = 48266,
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
    
    -- Missing important auras for Blood DK
    scarlet_fever = {
        id = 81132,
        duration = 30,
        max_stack = 1,
        type = "Magic",
    },
    
    -- Mastery: Blood Shield (passive)
    mastery_blood_shield = {
        id = 77513,
        duration = 3600, -- Passive
        max_stack = 1,
    },
    
    -- Blade Barrier (from Blade Armor talent)
    blade_barrier = {
        id = 64859,
        duration = 3600, -- Passive
        max_stack = 1,
    },
    
    -- Death and Decay ground effect
    death_and_decay = {
        id = 43265,
        duration = 10,
        max_stack = 1,
    },
} )

-- Blood DK core abilities
spec:RegisterAbilities( {    death_strike = {
        id = 49998,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return glyph.death_strike.enabled and 32 or 40 end,
        spendType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
            -- Death Strike heals based on damage taken in last 5 seconds
            local heal_amount = min(health.max * 0.25, health.max * 0.07) -- 7-25% of max health
            heal(heal_amount)
            
            -- Apply Blood Shield absorb
            local shield_amount = heal_amount * 0.5 -- 50% of heal as absorb
            applyBuff("blood_shield")
            
            -- Mastery: Blood Shield increases absorb amount
            if mastery.blood_shield.enabled then
                shield_amount = shield_amount * (1 + mastery_value * 0.062) -- 6.2% per mastery point
            end
        end,
    },
      heart_strike = {
        id = 55050,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "death_runes", -- Heart Strike uses Death Runes in MoP
        
        startsCombat = true,
        
        usable = function() return runes.death.count > 0 or runes.blood.count > 0 end,
        
        handler = function ()
            gain(10, "runicpower")
            -- Heart Strike hits multiple targets and spreads diseases
            if active_enemies > 1 then
                -- Spread diseases to nearby enemies
                if debuff.blood_plague.up then
                    applyDebuff("target", "blood_plague")
                end
                if debuff.frost_fever.up then
                    applyDebuff("target", "frost_fever")
                end
            end
        end,
    },
      dancing_rune_weapon = {
        id = 49028,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        spend = 60,
        spendType = "runicpower",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            local duration = glyph.dancing_rune_weapon.enabled and 17 or 12
            applyBuff("dancing_rune_weapon", duration)
            
            -- Dancing Rune Weapon generates threat and copies abilities
            -- While active, all melee abilities are mirrored by the weapon
        end,
    },
    
    vampiric_blood = {
        id = 55233,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("vampiric_blood")
        end,
    },
    
    bone_shield = {
        id = 49222,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("bone_shield", nil, 10) -- 10 charges
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
            -- Rune Strike: Enhanced weapon strike with high threat
            -- 1.8x weapon damage + 10% Attack Power
            -- 1.75x threat multiplier for tanking
            
            -- High threat generation for Blood tanking
            -- Main-hand + off-hand if dual wielding
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
        
        spend = function() return buff.crimson_scourge.up and 0 or 1 end,
        spendType = function() return buff.crimson_scourge.up and nil or "unholy_runes" end,
        
        startsCombat = true,
        
        usable = function() 
            return buff.crimson_scourge.up or runes.unholy.count > 0 or runes.death.count > 0
        end,
        
        handler = function ()
            -- If Crimson Scourge is active, don't consume runes
            if buff.crimson_scourge.up then
                removeBuff("crimson_scourge")
            end
            
            -- Death and Decay does AoE damage in targeted area
            gain(15, "runicpower") -- Generates more RP for AoE situations
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
      -- Initialize the rune tracking system for MoP
    spec:RegisterStateTable( "runes", {
        blood = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        frost = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        unholy = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        death = { count = 0, actual = 0, max = 6, cooldown = 10, recharge_time = 10 }, -- Death runes created from conversions
    } )
    
    -- Rune regeneration mechanics for MoP
    spec:RegisterStateFunction( "spend_runes", function( rune_type, amount )
        amount = amount or 1
        
        if rune_type == "blood" and runes.blood.count >= amount then
            runes.blood.count = runes.blood.count - amount
            -- Start rune cooldown
        elseif rune_type == "frost" and runes.frost.count >= amount then
            runes.frost.count = runes.frost.count - amount
        elseif rune_type == "unholy" and runes.unholy.count >= amount then
            runes.unholy.count = runes.unholy.count - amount
        elseif rune_type == "death" and runes.death.count >= amount then
            runes.death.count = runes.death.count - amount
        end
        
        -- Handle Runic Empowerment and Runic Corruption procs
        if talent.runic_empowerment.enabled then
            -- 45% chance to refresh a random rune
            if math.random() < 0.45 then
                applyBuff("runic_empowerment")
            end
        end
        
        if talent.runic_corruption.enabled then
            -- 45% chance to increase rune regeneration by 100% for 3 seconds
            if math.random() < 0.45 then
                applyBuff("runic_corruption")
            end
        end
    end )
    
    -- Convert runes to death runes (Blood Tap, etc.)
    spec:RegisterStateFunction( "convert_to_death_rune", function( rune_type, amount )
        amount = amount or 1
        
        if rune_type == "blood" and runes.blood.count >= amount then
            runes.blood.count = runes.blood.count - amount
            runes.death.count = runes.death.count + amount
        elseif rune_type == "frost" and runes.frost.count >= amount then
            runes.frost.count = runes.frost.count - amount
            runes.death.count = runes.death.count + amount
        elseif rune_type == "unholy" and runes.unholy.count >= amount then
            runes.unholy.count = runes.unholy.count - amount
            runes.death.count = runes.death.count + amount
        end
    end )
    
    -- Add function to check runic power generation
    spec:RegisterStateFunction( "gain_runic_power", function( amount )
        -- Logic to gain runic power
        gain( amount, "runicpower" )
    end )
end

-- State Expressions for Blood Death Knight
spec:RegisterStateExpr( "blood_shield_absorb", function()
    return buff.blood_shield.v1 or 0 -- Amount of damage absorbed
end )

spec:RegisterStateExpr( "diseases_ticking", function()
    local count = 0
    if debuff.blood_plague.up then count = count + 1 end
    if debuff.frost_fever.up then count = count + 1 end
    return count
end )

spec:RegisterStateExpr( "bone_shield_charges", function()
    return buff.bone_shield.stack or 0
end )

spec:RegisterStateExpr( "total_runes", function()
    return runes.blood.count + runes.frost.count + runes.unholy.count + runes.death.count
end )

spec:RegisterStateExpr( "runes_on_cd", function()
    return 6 - total_runes -- How many runes are on cooldown
end )

spec:RegisterStateExpr( "rune_deficit", function()
    return 6 - total_runes -- Same as runes_on_cd but clearer name
end )

spec:RegisterStateExpr( "death_strike_heal", function()
    -- Estimate Death Strike healing based on recent damage taken
    local base_heal = health.max * 0.07 -- Minimum 7%
    local max_heal = health.max * 0.25 -- Maximum 25%
    -- In actual gameplay, this would track damage taken in last 5 seconds
    return math.min(max_heal, math.max(base_heal, health.max * 0.15)) -- Estimate 15% average
end )

-- Register default pack for MoP Blood Death Knight
spec:RegisterPack( "Blood", 20250515, [[Hekili:T3vBVTTnu4FlXnHr9LsojdlJE7Kf7K3KRLvAm7njb5L0Svtla8Xk20IDngN7ob6IPvo9CTCgbb9DZJdAtP8dOn3zoIHy(MWDc)a5EtbWaVdFz6QvBB5Q(HaNUFxdH8c)y)QvNRCyPKU2k9yQ1qkE5nE)waT58Pw(aFm0P)MM]]  )

-- Register pack selector for Blood
spec:RegisterPackSelector( "blood", "Blood", "|T237517:0|t Blood",
    "Handles all aspects of Blood Death Knight tanking with priority on survivability and threat generation.",
    nil )
