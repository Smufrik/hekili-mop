-- DeathKnightUnholy.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Death Knight: Unholy spec

if UnitClassBase( 'player' ) ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 252 ) -- Unholy spec ID for MoP

local strformat = string.format
local UA_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Register resources
spec:RegisterResource( Enum.PowerType.RunicPower )
spec:RegisterResource( Enum.PowerType.Runes )

-- Tier sets
spec:RegisterGear( "tier14", 86919, 86920, 86921, 86922, 86923 ) -- T14 Battleplate of the Lost Cataphract
spec:RegisterGear( "tier15", 95225, 95226, 95227, 95228, 95229 ) -- T15 Battleplate of the All-Consuming Maw

-- Talents (MoP talent system and Unholy spec-specific talents)
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
    [58618] = "festering_strike",    -- Your Festering Strike increases the duration of diseases on the target by 6 additional seconds.
    [58616] = "horn_of_winter",      -- Horn of Winter no longer generates Runic Power, but lasts 1 hour.
    [58631] = "icebound_fortitude",  -- Reduces the cooldown of Icebound Fortitude by 60 sec but also reduces its duration by 2 sec.
    [58671] = "plague_strike",       -- Plague Strike does an additional 20% damage against targets who are above 90% health.
    [58673] = "raise_dead",          -- Your Ghoul summoned by Raise Dead receives 40% of your Strength and 40% of your Stamina.
    [58642] = "scourge_strike",      -- Your Scourge Strike has 10% increased chance to critically strike.
    [58649] = "soul_reaper",         -- When Soul Reaper strikes a target below 35% health, you gain 5% haste for 5 sec.
    [58669] = "unholy_frenzy",       -- Your Unholy Frenzy ability no longer damages the target.
    
    -- Minor Glyphs
    [60200] = "death_gate",          -- Reduces cast time of Death Gate by 60%.
    [58617] = "foul_menagerie",      -- Your Raise Dead spell summons a random ghoul companion.
    [63332] = "path_of_frost",       -- Your Army of the Dead ghouls explode when they die or expire.
    [58680] = "resilient_grip",      -- Your Death Grip refunds its cooldown when used on a target immune to grip effects.
    [59307] = "the_geist",           -- Your Raise Dead spell summons a geist instead of a ghoul.
    [60108] = "tranquil_grip",       -- Your Death Grip no longer taunts targets.
} )

-- Unholy DK specific auras
spec:RegisterAuras( {
    -- Unholy Presence: Increases attack and spell haste
    unholy_presence = {
        id = 48265,
        duration = 3600, -- Long duration buff
        max_stack = 1,
    },
    -- Dark Transformation: Ghoul transformation into super ghoul
    dark_transformation = {
        id = 63560,
        duration = 30,
        max_stack = 1,
    },
    -- Sudden Doom: Next Death Coil will cost no Runic Power
    sudden_doom = {
        id = 81340,
        duration = 10,
        max_stack = 1,
    },
    -- Master of Ghouls: Permanent ghoul
    master_of_ghouls = {
        id = 52143,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    -- Improved Unholy Presence: Movement and haste boost
    improved_unholy_presence = {
        id = 50392,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    -- Virulence: Increased chance for diseases
    virulence = {
        id = 48965,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    -- Blood Plague: Unholy disease
    blood_plague = {
        id = 59879,
        duration = function() 
            local base_duration = 30
            if talent.epidemic.enabled then
                base_duration = base_duration * 1.5 -- 50% longer with Epidemic
            end
            return base_duration
        end,
        max_stack = 1,
        tick_time = 3,
    },
    -- Frost Fever: Frost disease
    frost_fever = {
        id = 59921,
        duration = function() 
            local base_duration = 30
            if talent.epidemic.enabled then
                base_duration = base_duration * 1.5 -- 50% longer with Epidemic
            end
            return base_duration
        end,
        max_stack = 1,
        tick_time = 3,
    },
    -- Ebon Plaguebringer: Magic damage taken debuff
    ebon_plaguebringer = {
        id = 51161,
        duration = function() 
            local base_duration = 30
            if talent.epidemic.enabled then
                base_duration = base_duration * 1.5 -- 50% longer with Epidemic
            end
            return base_duration
        end,
        max_stack = 1,
    },
    -- Necrotic Strike: Healing absorption shield
    necrotic_strike = {
        id = 73975,
        duration = 15,
        max_stack = 1,
    },
    -- Soul Reaper: Death mark
    soul_reaper = {
        id = 130735,
        duration = 5,
        max_stack = 1,
    },
    -- Soul Reaper Haste buff (from glyph)
    soul_reaper_haste = {
        id = 130736,
        duration = 5,
        max_stack = 1,
    },
    -- Corpse Explosion (if available)
    corpse_explosion = {
        id = 127344,
        duration = 0.1, -- Instant effect
        max_stack = 1,
    },

    -- Common Death Knight Auras (shared across all specs)
    -- Other Presences
    blood_presence = {
        id = 48263,
        duration = 3600,
        max_stack = 1,
    },
    frost_presence = {
        id = 48266,
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
    },
    runic_empowerment = {
        id = 81229,
        duration = 5,
        max_stack = 1,
    },
} )

-- Unholy DK core abilities
spec:RegisterAbilities( {    scourge_strike = {
        id = 55090,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = 1
            -- Enhanced Runic Corruption reduces rune costs by 10%
            if talent.runic_corruption.enabled then
                base_cost = base_cost * 0.9
            end
            return base_cost
        end,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            -- Scourge Strike gains significant damage based on diseases present
            local rp_gain = 15 -- Base RP generation
            local disease_count = 0
            
            -- Check for diseases on target
            if debuff.blood_plague.up then disease_count = disease_count + 1 end
            if debuff.frost_fever.up then disease_count = disease_count + 1 end
            if debuff.ebon_plaguebringer.up then disease_count = disease_count + 1 end
            
            -- Additional RP per disease (MoP mechanic)
            rp_gain = rp_gain + (disease_count * 5)
            
            -- Glyph of Scourge Strike: 10% increased crit chance
            if glyph.scourge_strike.enabled then
                -- Enhanced critical strike chance handled in damage calculation
            end
            
            -- Vicious Strikes talent increases damage
            if talent.vicious_strikes.enabled then
                -- Damage bonus handled in damage calculation
            end
            
            gain(rp_gain, "runicpower")
            
            -- Trigger Runic Empowerment/Corruption procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.45 then -- 45% proc chance
                    applyBuff("runic_empowerment")
                    -- Instantly refresh one depleted rune
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.45 then -- 45% proc chance  
                    applyBuff("runic_corruption")
                    -- Increase rune regeneration by 100% for 3 seconds
                end
            end
            
            -- Check for Sudden Doom proc
            check_sudden_doom()
        end,
    },
      festering_strike = {
        id = 85948,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = 1 -- Changed from 2 to 1 for MoP
            if talent.runic_corruption.enabled then
                base_cost = base_cost * 0.9
            end
            return base_cost
        end,
        spendType = "blood",
        
        startsCombat = true,
        
        handler = function ()
            local rp_gain = 15
            gain(rp_gain, "runicpower")
            
            -- Extend diseases by 6 seconds base
            local extension = 6
            if glyph.festering_strike.enabled then 
                extension = extension + 6 -- Glyph adds additional 6 seconds
            end
            
            -- Only extend if diseases are present
            if debuff.blood_plague.up then
                debuff.blood_plague.expires = debuff.blood_plague.expires + extension
            end
            if debuff.frost_fever.up then
                debuff.frost_fever.expires = debuff.frost_fever.expires + extension
            end
            if debuff.ebon_plaguebringer.up then
                debuff.ebon_plaguebringer.expires = debuff.ebon_plaguebringer.expires + extension
            end
            
            -- Trigger Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.45 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.45 then
                    applyBuff("runic_corruption")
                end
            end
            
            -- Check for Sudden Doom proc
            check_sudden_doom()
        end,
    },
      death_coil = {
        id = 47541,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if buff.sudden_doom.up then return 0 end
            return 40 
        end,
        spendType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
            local is_sudden_doom = buff.sudden_doom.up
            removeBuff("sudden_doom")
            
            -- Death Coil can heal undead allies or damage enemies
            -- In Unholy spec, it's primarily used for damage
            
            -- Glyph of Death Coil: heals pets for 1% of DK's health
            if glyph.death_coil.enabled and pet.active then
                -- Pet healing effect
            end
            
            -- Enhanced damage when used with Sudden Doom
            if is_sudden_doom then
                -- Free Death Coil from Sudden Doom proc
                -- Deals increased damage (handled in damage calculation)
            end
            
            -- Dark Transformation synergy - reduces cooldown when used on transformed ghoul
            if pet.active and buff.dark_transformation.up then
                -- Synergy with transformed ghoul
            end
        end,
    },
      dark_transformation = {
        id = 63560,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        requires = function()
            -- Requires an active ghoul pet
            return pet.active, "requires active ghoul"
        end,
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("dark_transformation")
            
            -- Dark Transformation significantly enhances the ghoul:
            -- - Increases damage by 80%
            -- - Ghoul gains new abilities (Gnaw, Monstrous Blow, etc.)
            -- - Duration: 30 seconds
            
            -- The transformed ghoul becomes immune to many CC effects
            -- and gains significant stat increases
        end,
    },

    -- Common Death Knight Abilities (shared across all specs)
    -- Diseases
    outbreak = {
        id = 77575,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "blood_plague")
            applyDebuff("target", "frost_fever")
            applyDebuff("target", "ebon_plaguebringer")
        end,
    },
      plague_strike = {
        id = 45462,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "blood_plague")
            applyDebuff("target", "ebon_plaguebringer")
            
            local rp_gain = 10
            
            -- Vicious Strikes talent increases damage
            if talent.vicious_strikes.enabled then
                -- Enhanced damage and RP generation
                rp_gain = rp_gain + 5
            end
            
            -- Virulence talent increases disease application chance
            if talent.virulence.enabled then
                -- Higher chance to apply diseases (already applied above)
                -- Could add chance for additional disease effects
            end
            
            -- Glyph of Plague Strike: 20% additional damage vs >90% health targets
            if glyph.plague_strike.enabled then
                -- Enhanced damage vs high-health targets
            end
            
            gain(rp_gain, "runicpower")
            
            -- Trigger Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.35 then -- Lower proc chance for Plague Strike
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_corruption")
                end
            end
        end,
    },
    
    icy_touch = {
        id = 45477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "frost_runes", -- FUB runes
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "frost_fever")
            gain(10, "runicpower")
        end,
    },      blood_boil = {
        id = 48721,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "blood",
        
        startsCombat = true,
        texture = 237513,
        
        handler = function ()
            -- Blood Boil: Shadow damage AoE that spreads diseases
            -- Base damage + 8% Attack Power, 1.5x damage if diseases active
            local damage_multiplier = 1.0
            if debuff.blood_plague.up or debuff.frost_fever.up or debuff.ebon_plaguebringer.up then
                damage_multiplier = 1.5
            end
            
            local rp_gain = 10
            
            -- Spread diseases to nearby targets if they exist on primary target
            if debuff.blood_plague.up then
                applyDebuff("target", "blood_plague", nil, debuff.blood_plague.remains)
            end
            
            if debuff.frost_fever.up then
                applyDebuff("target", "frost_fever", nil, debuff.frost_fever.remains)
            end
            
            if debuff.ebon_plaguebringer.up then
                applyDebuff("target", "ebon_plaguebringer", nil, debuff.ebon_plaguebringer.remains)
            end
            
            -- Generate 10 Runic Power (only if targets are hit)
            gain(rp_gain, "runicpower")
            
            -- Trigger Runic procs (35% chance each)
            if talent.runic_empowerment.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_corruption")
                end
            end
        end,
    },
    
    blood_strike = {
        id = 45902,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "blood",
        
        startsCombat = true,
        texture = 237517,
        
        handler = function ()
            -- Blood Strike: Physical weapon attack with disease bonus
            -- Base damage + weapon damage, +12.5% per disease (max +25%)
            local disease_count = 0
            if debuff.blood_plague.up then disease_count = disease_count + 1 end
            if debuff.frost_fever.up then disease_count = disease_count + 1 end
            if debuff.ebon_plaguebringer.up then disease_count = disease_count + 1 end
            
            local damage_multiplier = 1.0 + (disease_count * 0.125)
            
            -- Generate 10 Runic Power
            gain(10, "runicpower")
            
            -- Reaping talent for Unholy: Blood rune converts to Death rune on use
            if talent.reaping.enabled then
                -- Blood rune becomes Death rune, allowing more flexibility
            end
            
            -- Trigger potential Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_corruption")
                end
            end
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
            
            -- Trigger potential Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_corruption")
                end
            end
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
        cooldown = function() 
            local base_cd = 30
            -- Morbidity talent reduces cooldown
            if talent.morbidity.enabled then
                base_cd = base_cd - (5 * talent.morbidity.rank) -- 5/10/15 sec reduction
            end
            return base_cd
        end,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            -- Death and Decay creates a pool of shadow damage
            -- Lasts 10 seconds, ticks every second
            
            local damage_bonus = 0
            -- Glyph of Death and Decay: 15% increased damage
            if glyph.death_and_decay.enabled then
                damage_bonus = damage_bonus + 0.15
            end
            
            -- Morbidity talent increases damage
            if talent.morbidity.enabled then
                damage_bonus = damage_bonus + (0.05 * talent.morbidity.rank) -- 5/10/15% bonus
            end
            
            -- Ebon Plaguebringer increases magic damage taken by targets
            if debuff.ebon_plaguebringer.up then
                -- Additional damage from magic vulnerability
            end
            
            gain(15, "runicpower") -- Base RP gain
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
        cooldown = function() 
            -- Master of Ghouls makes this instant and no cooldown for permanent ghoul
            if talent.master_of_ghouls.enabled then return 0 end
            return 120
        end,
        gcd = "spell",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            -- Summon ghoul/geist pet based on glyphs and talents
            if talent.master_of_ghouls.enabled then
                -- Permanent ghoul with Master of Ghouls talent
                -- Requires Unholy Presence to be maintained
                if not buff.unholy_presence.up then
                    applyBuff("unholy_presence")
                end
            else
                -- Temporary ghoul (60 second duration)
            end
            
            -- Glyph of Raise Dead: ghoul gains 40% of DK's Strength and Stamina
            if glyph.raise_dead.enabled then
                -- Enhanced ghoul stats
            end
            
            -- Glyph of Foul Menagerie: random ghoul appearance
            if glyph.foul_menagerie.enabled then
                -- Cosmetic variation
            end
            
            -- Glyph of the Geist: summons geist instead of ghoul
            if glyph.the_geist.enabled then
                -- Different pet model, same mechanics
            end
        end,
    },
    
    -- Unholy-specific spell: Necrotic Strike (if available in MoP)
    necrotic_strike = {
        id = 73975,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            -- Necrotic Strike applies a healing absorption shield
            -- Shield amount based on Attack Power
            local shield_amount = stat.attack_power * 0.7 -- Rough calculation
            
            applyDebuff("target", "necrotic_strike", nil, nil, shield_amount)
            gain(15, "runicpower")
            
            -- Trigger Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.45 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.45 then
                    applyBuff("runic_corruption")
                end
            end
        end,
    },
    
    -- Soul Reaper (if available in MoP)
    soul_reaper = {
        id = 130735,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            -- Soul Reaper marks target for death after 5 seconds
            -- If target is below 35% health when it explodes, deals massive damage
            applyDebuff("target", "soul_reaper")
            
            -- Glyph of Soul Reaper: gain 5% haste for 5 sec when used on low health target
            if glyph.soul_reaper.enabled and target.health.pct < 35 then
                applyBuff("soul_reaper_haste")
            end
            
            gain(10, "runicpower")
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
        return state.runes.blood.current
    end )
    
    -- Frost Runes
    spec:RegisterStateExpr( "frost_runes", function ()
        return state.runes.frost.current
    end )
    
    -- Unholy Runes
    spec:RegisterStateExpr( "unholy_runes", function ()
        return state.runes.unholy.current
    end )
    
    -- Death Runes
    spec:RegisterStateExpr( "death_runes", function ()
        return state.runes.death.current
    end )
    
    -- Total available runes
    spec:RegisterStateExpr( "total_runes", function ()
        return state.runes.blood.current + state.runes.frost.current + 
               state.runes.unholy.current + state.runes.death.current
    end )
    
    -- Disease-related expressions
    spec:RegisterStateExpr( "diseases_up", function ()
        return debuff.blood_plague.up and debuff.frost_fever.up
    end )
    
    spec:RegisterStateExpr( "diseases_ticking", function ()
        local count = 0
        if debuff.blood_plague.up then count = count + 1 end
        if debuff.frost_fever.up then count = count + 1 end
        if debuff.ebon_plaguebringer.up then count = count + 1 end
        return count
    end )
    
    spec:RegisterStateExpr( "diseases_will_expire", function ()
        local expires_soon = 6 -- Consider diseases that expire within 6 seconds
        return (debuff.blood_plague.up and debuff.blood_plague.remains < expires_soon) or
               (debuff.frost_fever.up and debuff.frost_fever.remains < expires_soon)
    end )
    
    -- Unholy-specific expressions
    spec:RegisterStateExpr( "sudden_doom_react", function ()
        return buff.sudden_doom.up
    end )
    
    spec:RegisterStateExpr( "ghoul_active", function ()
        return pet.active and pet.ghoul.active
    end )
    
    spec:RegisterStateExpr( "dark_transformation_ready", function ()
        return cooldown.dark_transformation.remains == 0 and pet.active
    end )
    
    spec:RegisterStateExpr( "can_festering_strike", function ()
        return diseases_up and (blood_runes >= 1 or death_runes >= 1)
    end )
    
    spec:RegisterStateExpr( "runic_power_deficit", function ()
        return runic_power.max - runic_power.current
    end )
    
    spec:RegisterStateExpr( "rune_regeneration_rate", function ()
        local base_rate = 10 -- Base 10 second rune regeneration
        local rate = base_rate
        
        -- Improved Unholy Presence reduces rune regeneration time
        if buff.improved_unholy_presence.up then
            rate = rate * 0.85 -- 15% faster regeneration
        end
        
        -- Runic Corruption doubles rune regeneration speed
        if buff.runic_corruption.up then
            rate = rate * 0.5 -- 100% faster (half the time)
        end
        
        return rate
    end )
    
    -- Initialize the enhanced rune tracking system
    spec:RegisterStateTable( "runes", {
        blood = { current = 2, max = 2, cooldown = {}, time = {} },
        frost = { current = 2, max = 2, cooldown = {}, time = {} },
        unholy = { current = 2, max = 2, cooldown = {}, time = {} },
        death = { current = 0, max = 6, cooldown = {}, time = {} },
    } )
    
    -- Enhanced rune spending function
    spec:RegisterStateFunction( "spend_runes", function( blood, frost, unholy )
        local spent = { blood = blood or 0, frost = frost or 0, unholy = unholy or 0 }
        
        for rune_type, amount in pairs(spent) do
            if amount > 0 then
                -- First try to spend death runes if available
                if state.runes.death.current >= amount then
                    state.runes.death.current = state.runes.death.current - amount
                    amount = 0
                end
                
                -- Then spend the specific rune type
                if amount > 0 and state.runes[rune_type].current >= amount then
                    state.runes[rune_type].current = state.runes[rune_type].current - amount
                    -- Convert spent runes to death runes after use
                    state.runes.death.current = math.min(state.runes.death.max, 
                                                         state.runes.death.current + amount)
                end
            end
        end
    end )
    
    -- Enhanced Sudden Doom checking with proper proc rates
    spec:RegisterStateFunction( "check_sudden_doom", function()
        if talent.sudden_doom.enabled then
            -- Sudden Doom proc chance based on talent rank
            local base_chance = 0.05 * talent.sudden_doom.rank -- 5/10/15% per rank
            
            -- Auto-attacks have a chance to trigger Sudden Doom
            if math.random() < base_chance then
                applyBuff("sudden_doom")
            end
        end
    end )
    
    -- Function to check if we should use Death Coil
    spec:RegisterStateFunction( "should_death_coil", function()
        -- Use Death Coil if:
        -- 1. Sudden Doom is active (free cast)
        -- 2. Runic Power is near cap (>80)
        -- 3. Need to prevent RP overcap
        return buff.sudden_doom.up or runic_power.current >= 80 or 
               (runic_power.current >= 60 and runic_power_deficit <= 20)
    end )
    
    -- Function to determine optimal disease application method
    spec:RegisterStateFunction( "disease_application_method", function()
        local method = "individual" -- Default to Plague Strike + Icy Touch
        
        -- Use Outbreak if both diseases are down and it's available
        if not diseases_up and cooldown.outbreak.remains == 0 then
            method = "outbreak"
        -- Use Festering Strike if diseases need extension and are already up
        elseif diseases_up and diseases_will_expire then
            method = "festering_strike"
        end
        
        return method
    end )
end

-- Register pet handler for Unholy's ghoul
spec:RegisterStateHandler( "ghoul", function()
    if pet.active then
        -- Handle ghoul pet logic here
    end
end )

-- Register default pack for MoP Unholy Death Knight
spec:RegisterPack( "Unholy", 20250515, [[Hekili:T3vBVTTnu4FlXnHr9LsojdlJE7Kf7K3KRLvAm7njb5L0Svtla8Xk20IDngN7ob6IPvo9CTCgbb9D74Xtx83u5dx4CvNBYZkeeZwyXJdNpV39NvoT82e)6J65pZE3EGNUNUp(4yTxY1VU)mEzZNF)wwc5yF)SGp2VyFk3fzLyKD(0W6Zw(aFW0P)MM]]  )

-- Register pack selector for Unholy
spec:RegisterPackSelector( "unholy", "Unholy", "|T237526:0|t Unholy",
    "Handles all aspects of Unholy Death Knight rotation with focus on diseases, pet management, and Unholy damage.",
    nil )
