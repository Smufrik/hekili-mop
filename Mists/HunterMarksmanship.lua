-- HunterMarksmanship.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Hunter: Marksmanship spec
-- Enhanced with comprehensive MoP mechanics, talent integration, and optimal rotation priorities

if UnitClassBase( 'player' ) ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced helper functions for Marksmanship mechanics
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetPetBuffByID(spellID)
    return FindUnitBuffByID("pet", spellID)
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID)
end

-- Marksmanship specific combat log tracking
local mm_combat_log_events = {}

local function RegisterMMCombatLogEvent(event, callback)
    if not mm_combat_log_events[event] then
        mm_combat_log_events[event] = {}
    end
    table.insert(mm_combat_log_events[event], callback)
end

-- Hook into combat log for Marksmanship-specific tracking
local mmCombatLogFrame = CreateFrame("Frame")
mmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mmCombatLogFrame:SetScript("OnEvent", function(self, event)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    
    if sourceGUID == UnitGUID("player") then
        if mm_combat_log_events[subevent] then
            for _, callback in ipairs(mm_combat_log_events[subevent]) do
                callback(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
            end
        end
    end
end)

local spec = Hekili:NewSpecialization( 254 ) -- Marksmanship spec ID for MoP

-- Enhanced Resource System for Marksmanship
spec:RegisterResource( Enum.PowerType.Focus, {
    -- Steady Shot focus generation (Marksmanship signature focus builder)
    steady_shot = {
        aura = "steady_focus",
        debuff = false,
        
        last = function()
            local app = state.buff.steady_focus.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1.5 ) * 1.5
        end,
        
        interval = function() return 1.5 / state.haste end,
        value = 14, -- Steady Shot generates 14 focus in MoP
    },
    
    -- Cobra Shot focus generation (alternative builder for MM)
    cobra_shot = {
        aura = "cobra_shot_regen",
        debuff = false,
        
        last = function()
            local app = state.buff.cobra_shot_regen.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1.5 ) * 1.5
        end,
        
        interval = function() return 1.5 / state.haste end,
        value = 14, -- Cobra Shot generates 14 focus in MoP
    },
    
    -- Dire Beast focus generation (if talented)
    dire_beast = {
        aura = "dire_beast",
        debuff = false,
        
        last = function()
            local app = state.buff.dire_beast.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2 ) * 2
        end,
        
        interval = 2,
        value = 2, -- Dire Beast generates 2 focus every 2 seconds
    },
    
    -- Rapid Recuperation focus regen (talent enhancement)
    rapid_recuperation = {
        aura = "rapid_recuperation",
        debuff = false,
        
        last = function()
            local app = state.buff.rapid_recuperation.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 3 ) * 3
        end,
        
        interval = 3,
        value = function() return state.buff.rapid_recuperation.up and 6 or 0 end,
    },
    
    -- Thrill of the Hunt proc focus
    thrill_proc = {
        aura = "thrill_of_the_hunt",
        debuff = false,
        
        last = function()
            return state.buff.thrill_of_the_hunt.applied
        end,
        
        interval = 60,
        value = function() return state.buff.thrill_of_the_hunt.up and 20 or 0 end,
    },
}, {
    -- Base focus regeneration with haste scaling (MoP mechanic)
    haste_scaling = true,
    base_regen = 6, -- Base 6 focus per second in MoP
    
    -- Enhanced focus regen calculation
    regenerates = function()
        local base = 6 * state.haste
        local bonus = 0
        
        -- Aspect bonuses
        if state.buff.aspect_of_the_iron_hawk.up then
            bonus = bonus + 0.3 -- 30% increased focus regen
        end
          -- Talent bonuses (MoP proper talents only)
        
        -- Rapid Fire bonus
        if state.buff.rapid_fire.up then
            bonus = bonus + 0.5 -- 50% increased focus regen during Rapid Fire
        end
        
        return base * (1 + bonus)
    end,
} )

-- Enhanced Tier Sets with proper bonuses
spec:RegisterGear( 13, 8, { -- Tier 14 - Heart of Fear / Terrace of Endless Spring
    { 88183, head = 86098, shoulder = 86101, chest = 86096, hands = 86097, legs = 86099 }, -- LFR
    { 88184, head = 85251, shoulder = 85254, chest = 85249, hands = 85250, legs = 85252 }, -- Normal
    { 88185, head = 87003, shoulder = 87006, chest = 87001, hands = 87002, legs = 87004 }, -- Heroic
} )

spec:RegisterGear( 14, 8, { -- Tier 15 - Throne of Thunder
    { 96548, head = 95101, shoulder = 95104, chest = 95099, hands = 95100, legs = 95102 }, -- LFR
    { 96549, head = 95608, shoulder = 95611, chest = 95606, hands = 95607, legs = 95609 }, -- Normal
    { 96550, head = 96004, shoulder = 96007, chest = 96002, hands = 96003, legs = 96005 }, -- Heroic
} )

spec:RegisterGear( 15, 8, { -- Tier 16 - Siege of Orgrimmar
    { 99548, head = 99101, shoulder = 99104, chest = 99099, hands = 99100, legs = 99102 }, -- LFR
    { 99549, head = 99608, shoulder = 99611, chest = 99606, hands = 99607, legs = 99609 }, -- Normal
    { 99550, head = 99004, shoulder = 99007, chest = 99002, hands = 99003, legs = 99005 }, -- Heroic
    { 99551, head = 99804, shoulder = 99807, chest = 99802, hands = 99803, legs = 99805 }, -- Mythic
} )

-- Tier set bonuses
spec:RegisterGearBonus( "tier14_2pc", 88183, 88184, 88185 )
spec:RegisterGearBonus( "tier14_4pc", 88183, 88184, 88185 )
spec:RegisterGearBonus( "tier15_2pc", 96548, 96549, 96550 )
spec:RegisterGearBonus( "tier15_4pc", 96548, 96549, 96550 )
spec:RegisterGearBonus( "tier16_2pc", 99548, 99549, 99550, 99551 )
spec:RegisterGearBonus( "tier16_4pc", 99548, 99549, 99550, 99551 )

-- Enhanced Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, 102247, 102248 ) -- Legendary cloak variations
spec:RegisterGear( "lfr_weapon", 86905, 87171, 89678 ) -- Notable MoP weapons
spec:RegisterGear( "normal_weapon", 86399, 86893, 89649 )
spec:RegisterGear( "heroic_weapon", 87164, 87183, 89678 )

-- Enhanced Talent System - MoP Complete Integration
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Movement/Escape Talents
    posthaste              = { 109248, 109248, 1 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 50% for 4 sec.
    narrow_escape          = { 109259, 109259, 1 }, -- When you Disengage, you leave behind a web trap that snares all targets within 8 yards, reducing their movement speed by 70% for 8 sec.
    crouching_tiger        = { 120679, 120679, 1 }, -- Reduces the cooldown of Disengage by 6 sec and reduces the cooldown of Deterrence by 10 sec.
    
    -- Tier 2 (Level 30) - Crowd Control Talents
    silencing_shot         = { 109297, 34490, 1 }, -- Silences the target, preventing any spellcasting for 3 sec.
    wyvern_sting           = { 109304, 19386, 1 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, the Sting causes 2,345 Nature damage over 6 sec. Only one Sting can be active on the target at a time.
    binding_shot           = { 109301, 109248, 1 }, -- Fires a magical projectile, tethering the enemy and any other enemies within 5 yds for 10 sec, stunning them for 5 sec if they move more than 5 yds from the arrow.
    
    -- Tier 3 (Level 45) - Defensive/Utility Talents
    exhilaration           = { 109298, 109304, 1 }, -- Instantly heals you and your pet for 22% of total health.
    aspect_of_the_iron_hawk = { 109260, 109260, 1 }, -- You take 15% less damage and your Aspect of the Hawk increases attack power by an additional 10%.
    spirit_bond            = { 120361, 117902, 1 }, -- You and your pet heal for 2% of total health every 10 sec. This effect persists for 10 sec after your pet dies.
    
    -- Tier 4 (Level 60) - Pet Enhancement Talents
    murder_of_crows        = { 131894, 131894, 1 }, -- Summons a murder of crows to attack your target over the next 30 sec. If your target dies while under attack, the cooldown on this ability will reset.
    blink_strikes          = { 117050, 130392, 1 }, -- Your pet's Basic Attacks deal 50% more damage, have a 30 yard range, and instantly teleport your pet behind the target.
    lynx_rush              = { 120697, 120697, 1 }, -- Commands your pet to attack your target 9 times over 4 sec for 115% normal damage.
    
    -- Tier 5 (Level 75) - Focus Management Talents
    fervor                 = { 109306, 82726, 1 }, -- Instantly restores 50 Focus to you and your pet, and then an additional 50 Focus over 10 sec.
    dire_beast             = { 120364, 120679, 1 }, -- Summons a powerful wild beast that attacks the target for 15 sec. Each time the beast deals damage, you gain 2 Focus.
    thrill_of_the_hunt     = { 118455, 34497, 1 }, -- Your Arcane Shot and Multi-Shot have a 30% chance to instantly restore 20 Focus.
    
    -- Tier 6 (Level 90) - AoE/Ranged Talents
    glaive_toss            = { 109215, 109215, 1 }, -- Throw a glaive at your target and another nearby enemy within 10 yards for 7,750 to 8,750 damage, and reduce their movement speed by 70% for 3 sec.
    powershot              = { 117049, 109259, 1 }, -- A powerful attack that deals 100% weapon damage to all targets in front of you, knocking them back.
    barrage                = { 121818, 120360, 1 }, -- Rapidly fires a spray of shots for 3 sec, dealing 60% weapon damage to all enemies in front of you.
} )

-- Enhanced Glyphs System (MoP Complete)
spec:RegisterGlyphs( {
    -- Major Glyphs (affect gameplay mechanics)
    [109261] = "Glyph of Aimed Shot", -- Reduces the cast time of Aimed Shot by 0.2 sec
    [109262] = "Glyph of Animal Bond", -- Increases healing done to your pet by 20%
    [109263] = "Glyph of Arcane Shot", -- Arcane Shot reduces target's movement speed by 50% for 6 sec
    [109264] = "Glyph of Camouflage", -- Increases movement speed by 25% while Camouflage is active
    [109265] = "Glyph of Chimera Shot", -- Reduces focus cost of Chimera Shot by 10
    [109266] = "Glyph of Deterrence", -- Deterrence also reduces magic damage taken by 40%
    [109267] = "Glyph of Disengage", -- Increases the distance traveled by Disengage by 8 yards
    [109268] = "Glyph of Distracting Shot", -- Increases damage of Distracting Shot by 250%
    [109269] = "Glyph of Hunter's Mark", -- Hunter's Mark increases your pet's damage by 10%
    [109270] = "Glyph of Explosive Trap", -- Increases Explosive Trap damage by 20%
    [109271] = "Glyph of Freezing Trap", -- Reduces cooldown of Freezing Trap by 5 sec
    [109272] = "Glyph of Ice Trap", -- Increases area of Ice Trap by 100%
    [109273] = "Glyph of Kill Shot", -- Reduces cooldown of Kill Shot by 6 sec
    [109274] = "Glyph of Marked for Death", -- Hunter's Mark spreads to nearest enemy when target dies
    [109275] = "Glyph of Master's Call", -- Reduces cooldown of Master's Call by 20 sec
    [109276] = "Glyph of Mending", -- Increases healing done by Mend Pet by 25%
    [109277] = "Glyph of Misdirection", -- Reduces cooldown of Misdirection by 10 sec
    [109278] = "Glyph of Multi-Shot", -- Multi-Shot has no range limit
    [109279] = "Glyph of Pathfinding", -- Increases speed bonus of Aspect of the Cheetah by 20%
    [109280] = "Glyph of Scatter Shot", -- Increases range of Scatter Shot by 5 yards
    [109281] = "Glyph of Snake Trap", -- Snakes from Snake Trap reduce healing by 25%
    [109282] = "Glyph of Steady Shot", -- Increases Steady Shot damage by 10% when standing still
    [109283] = "Glyph of Tranquilizing Shot", -- Reduces cooldown of Tranquilizing Shot by 4 sec
    [109284] = "Glyph of Rapid Fire", -- Reduces focus cost of shots by 50% during Rapid Fire
    [109285] = "Glyph of Serpent Sting", -- Increases duration of Serpent Sting by 6 sec
    [109286] = "Glyph of Trueshot Aura", -- Trueshot Aura increases crit chance by 5%
    
    -- Minor Glyphs (cosmetic/convenience effects)
    [109287] = "Glyph of Aspect of the Cheetah", -- Aspect of the Cheetah appears as different animals
    [109288] = "Glyph of Aspect of the Hawk", -- Aspect of the Hawk has different visual effect
    [109289] = "Glyph of Fetch", -- Your pet can retrieve items from 50 yards away
    [109290] = "Glyph of Fireworks", -- Multi-Shot produces firework effects
    [109291] = "Glyph of Lesser Proportion", -- Your pet appears 25% smaller
    [109292] = "Glyph of Revive Pet", -- Reduces cast time of Revive Pet by 50%
    [109293] = "Glyph of Stampede", -- Animals from Stampede appear as different creatures
    [109294] = "Glyph of Tame Beast", -- Reduces cast time of Tame Beast by 50%
    [109295] = "Glyph of the Dire Stable", -- Allows storing 6 pets instead of 5
    [109296] = "Glyph of the Lean Pack", -- Aspect of the Pack appears sleeker
    [109297] = "Glyph of the Loud Horn", -- Horn of Winter creates louder sound
    [109298] = "Glyph of the Solstice", -- Track Humanoids shows different races
} )

-- Comprehensive Aura System for Marksmanship (40+ auras)
spec:RegisterAuras( {
    -- === MARKSMANSHIP SIGNATURE AURAS ===
    master_marksman = {
        id = 82899,
        duration = 30,
        max_stack = 5,
        generate = function( t )
            local name, _, count, _, duration, expires, caster = UA_GetPlayerAuraBySpellID( 82899 )
            if name then
                t.name = name
                t.count = count
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    aimed_shot_instant = {
        id = 82925,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name = UA_GetPlayerAuraBySpellID( 82925 )
            if name then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    careful_aim = {
        id = 82926,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.talent.careful_aim.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    piercing_shots = {
        id = 82924,
        duration = 8,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name = GetTargetDebuffByID( 82924 )
            if name then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    rapid_recuperation = {
        id = 53228,
        duration = 9,
        tick_time = 3,
        max_stack = 1,
    },
    
    lock_and_load = {
        id = 82914,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.talent.lock_and_load.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    steady_focus = {
        id = 82923,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name = UA_GetPlayerAuraBySpellID( 82923 )
            if name then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    improved_steady_shot = {
        id = 82927,
        duration = 12,
        max_stack = 1,
    },
    
    -- === TALENT-SPECIFIC AURAS ===
    thrill_of_the_hunt = {
        id = 34720,
        duration = 10,
        max_stack = 3,
    },
    
    lynx_rush = {
        id = 120697,
        duration = 4,
        max_stack = 1,
    },
    
    a_murder_of_crows = {
        id = 131894,
        duration = 30,
        tick_time = 1,
        max_stack = 1,
    },
    
    posthaste = {
        id = 118922,
        duration = 4,
        max_stack = 1,
    },
    
    dire_beast = {
        id = 120679,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name = UA_GetPlayerAuraBySpellID( 120679 )
            if name then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    fervor = {
        id = 82726,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    
    spirit_bond = {
        id = 117902,
        duration = 3600,
        tick_time = 10,
        max_stack = 1,
        generate = function( t )
            if state.talent.spirit_bond.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- === ASPECT AURAS ===
    aspect_of_the_hawk = {
        id = 13165,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_cheetah = {
        id = 5118,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_pack = {
        id = 13159,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_iron_hawk = {
        id = 109260,
        duration = 3600,
        max_stack = 1,
    },
    
    -- === DEFENSIVE AURAS ===
    deterrence = {
        id = 19263,
        duration = 5,
        max_stack = 1,
    },
    
    camouflage = {
        id = 51755,
        duration = 6,
        max_stack = 1,
    },
    
    feign_death = {
        id = 5384,
        duration = 6,
        max_stack = 1,
    },
    
    -- === UTILITY AURAS ===
    hunters_mark = {
        id = 1130,
        duration = 300,
        max_stack = 1,
    },
    
    misdirection = {
        id = 34477,
        duration = 8,
        max_stack = 1,
    },
    
    rapid_fire = {
        id = 3045,
        duration = 15,
        max_stack = 1,
    },
    
    readiness = {
        id = 23989,
        duration = 2,
        max_stack = 1,
    },
    
    trueshot_aura = {
        id = 19506,
        duration = 3600,
        max_stack = 1,
    },
    
    -- === TARGET DEBUFFS ===
    serpent_sting = {
        id = 118253,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
    },
    
    concussive_shot = {
        id = 5116,
        duration = 6,
        max_stack = 1,
    },
    
    explosive_shot = {
        id = 53301,
        duration = 2,
        tick_time = 1,
        max_stack = 1,
    },
    
    wyvern_sting = {
        id = 19386,
        duration = 30,
        max_stack = 1,
    },
    
    scatter_shot = {
        id = 19503,
        duration = 4,
        max_stack = 1,
    },
    
    -- === PET AURAS ===
    mend_pet = {
        id = 136,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name, _, count, _, duration, expires, caster = GetPetBuffByID( 136 )
            if name then
                t.name = name
                t.count = count
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    call_pet = {
        duration = 3600,
        max_stack = 1,
    },
    
    blink_strikes = {
        id = 130392,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.talent.blink_strikes.enabled and state.pet.alive then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- === CONSUMABLE/EXTERNAL AURAS ===
    flask_of_spring_blossoms = {
        id = 105698,
        duration = 3600,
        max_stack = 1,
    },
    
    potion_of_the_tolvir = {
        id = 80496,
        duration = 25,
        max_stack = 1,
    },
    
    drums_of_rage = {
        id = 35476,
        duration = 30,
        max_stack = 1,
    },
    
    -- === GLYPH EFFECTS ===
    glyph_of_aimed_shot = {
        id = 109261,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.glyph.aimed_shot.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    glyph_of_chimera_shot = {
        id = 109265,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.glyph.chimera_shot.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    glyph_of_rapid_fire = {
        id = 109284,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.glyph.rapid_fire.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
} )

-- Enhanced Pet System for Marksmanship
spec:RegisterPets( {
    -- Primary stable pets
    tenacity = { -- Tank pet
        id = 1,
        spell = "call_pet_1",
        health = function() return health.max * 1.0 end,
        damage = function() return stat.attack_power * 0.6 end,
    },
    ferocity = { -- DPS pet (optimal for MM)
        id = 2,
        spell = "call_pet_2",
        health = function() return health.max * 0.85 end,
        damage = function() return stat.attack_power * 0.75 end,
    },
    cunning = { -- Utility pet
        id = 3,
        spell = "call_pet_3",
        health = function() return health.max * 0.9 end,
        damage = function() return stat.attack_power * 0.65 end,
    },
    
    -- Dire Beast (talent summon)
    dire_beast_cat = { -- Most common dire beast
        id = 4,
        spell = "dire_beast",
        duration = 15,
        health = function() return health.max * 0.8 end,
        damage = function() return stat.attack_power * 0.7 end,
    },
    
    -- A Murder of Crows
    murder_of_crows = {
        id = 5,
        spell = "a_murder_of_crows",
        duration = 30,
        health = 1,
        damage = function() return stat.attack_power * 0.4 end,
    },
} )

-- Comprehensive Abilities System for Marksmanship (35+ abilities)
spec:RegisterAbilities( {
    -- === CORE MARKSMANSHIP SIGNATURE ABILITIES ===
    aimed_shot = {
        id = 19434,
        cast = function() 
            local base_cast = 2.4
            if buff.aimed_shot_instant.up or buff.master_marksman.stack == 5 then 
                return 0 
            end
            if glyph.aimed_shot.enabled then
                base_cast = base_cast - 0.2
            end
            if talent.focused_aim.enabled then
                base_cast = base_cast * 0.85 -- 15% faster cast with talent
            end
            return base_cast / haste 
        end,
        cooldown = 10,
        gcd = "spell",
        school = "physical",
        
        spend = function() 
            if buff.aimed_shot_instant.up or buff.master_marksman.stack == 5 then 
                return 0 
            else 
                local cost = 50
                if talent.focused_aim.enabled then
                    cost = cost - (talent.focused_aim.rank * 5) -- Reduces cost by 5/10/15
                end
                if talent.efficiency.enabled then
                    cost = cost - talent.efficiency.rank -- Reduces cost by 1/2/3
                end
                if glyph.rapid_fire.enabled and buff.rapid_fire.up then
                    cost = cost * 0.5 -- 50% cost reduction during Rapid Fire
                end
                return cost
            end
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Remove instant proc
            if buff.aimed_shot_instant.up then
                removeBuff( "aimed_shot_instant" )
            end
            if buff.master_marksman.stack == 5 then
                removeBuff( "master_marksman" )
            end
            
            -- Apply Piercing Shots if talented and crit
            if talent.piercing_shots.enabled and action.aimed_shot.lastCast and action.aimed_shot.lastCrit then
                applyDebuff( "target", "piercing_shots", 8 )
            end
            
            -- Careful Aim bonus damage for first 2 shots after kill
            if buff.careful_aim.up then
                -- Enhanced damage, tracked by combat log
            end
            
            -- Lock and Load chance to reset cooldown
            if talent.lock_and_load.enabled and math.random() <= (talent.lock_and_load.rank * 0.05) then
                setCooldown( "aimed_shot", 0 )
            end
        end,
    },
      
    chimera_shot = {
        id = 53209,
        cast = 0,
        cooldown = 9,
        gcd = "spell",
        school = "nature",
        
        spend = function()
            local cost = 35
            if talent.efficiency.enabled then
                cost = cost - talent.efficiency.rank
            end
            if glyph.chimera_shot.enabled then
                cost = cost - 10
            end
            return cost
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Refresh Serpent Sting if present
            if debuff.serpent_sting.up then
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 9
                if debuff.serpent_sting.expires > query_time + 18 then
                    debuff.serpent_sting.expires = query_time + 18
                end
                -- Heal for 5% max health
                gain( 0.05 * health.max, "health" )
            end
            
            -- Master Marksman chance (passive in MoP)
            if math.random() <= 0.2 then
                addStack( "master_marksman" )
                if buff.master_marksman.stack == 5 then
                    removeBuff( "master_marksman" )
                    applyBuff( "aimed_shot_instant" )
                end
            end
        end,
    },
    
    -- === FOCUS BUILDERS ===
    steady_shot = {
        id = 56641,
        cast = function() return 1.5 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local regen = -14
            if talent.improved_steady_shot.enabled then
                regen = regen - (talent.improved_steady_shot.rank * 2) -- Additional 2/4/6 focus
            end
            if glyph.steady_shot.enabled and not moving then
                regen = regen - 2 -- Additional 2 focus when standing still
            end
            return regen
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Rapid Recuperation trigger
            if (buff.rapid_fire.up or buff.readiness.up) and talent.rapid_recuperation.enabled then
                applyBuff( "rapid_recuperation" )
            end
            
            -- Improved Steady Shot buff
            if talent.improved_steady_shot.enabled then
                applyBuff( "improved_steady_shot", 12 )
            end
            
            -- Steady Focus management
            if not buff.steady_focus.up then
                applyBuff( "steady_focus" )
            else
                buff.steady_focus.expires = query_time + 3600 -- Refresh
            end
            
            -- Master Marksman chance
            if math.random() <= 0.2 then
                addStack( "master_marksman" )
                if buff.master_marksman.stack == 5 then
                    removeBuff( "master_marksman" )
                    applyBuff( "aimed_shot_instant" )
                end
            end
            
            -- Careful Aim consumption
            if buff.careful_aim.up then
                if buff.careful_aim.stack == 1 then
                    removeBuff( "careful_aim" )
                else
                    removeStack( "careful_aim" )
                end
            end
        end,
    },
    
    cobra_shot = {
        id = 77767,
        cast = function () return 1.5 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        spend = -14,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Extend Serpent Sting duration
            if debuff.serpent_sting.up then
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                if debuff.serpent_sting.expires > query_time + 21 then
                    debuff.serpent_sting.expires = query_time + 21
                end
            end
            
            -- Careful Aim consumption
            if buff.careful_aim.up then
                if buff.careful_aim.stack == 1 then
                    removeBuff( "careful_aim" )
                else
                    removeStack( "careful_aim" )
                end
            end
        end,
    },
    
    -- === SHOT ROTATION ABILITIES ===
    arcane_shot = {
        id = 3044,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        
        spend = function()
            local cost = 30
            if talent.improved_arcane_shot.enabled then
                cost = cost - (talent.improved_arcane_shot.rank * 2) -- Reduces cost by 2/4/6
            end
            if talent.efficiency.enabled then
                cost = cost - talent.efficiency.rank
            end
            if glyph.rapid_fire.enabled and buff.rapid_fire.up then
                cost = cost * 0.5
            end
            return cost
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Thrill of the Hunt proc chance
            if talent.thrill_of_the_hunt.enabled and math.random() <= 0.3 then
                gain( 20, "focus" )
                addStack( "thrill_of_the_hunt" )
            end
            
            -- Improved Arcane Shot damage bonus handled by talent system
        end,
    },
    
    multi_shot = {
        id = 2643,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local cost = 40
            if talent.improved_multi_shot.enabled then
                cost = cost - (talent.improved_multi_shot.rank * 5) -- Reduces cost by 5/10/15
            end
            if talent.scattered_shots.enabled then
                cost = cost - talent.scattered_shots.rank -- Reduces cost by 1/2/3
            end
            if talent.efficiency.enabled then
                cost = cost - talent.efficiency.rank
            end
            if glyph.rapid_fire.enabled and buff.rapid_fire.up then
                cost = cost * 0.5
            end
            return cost
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Thrill of the Hunt proc chance
            if talent.thrill_of_the_hunt.enabled and math.random() <= 0.3 then
                gain( 20, "focus" )
                addStack( "thrill_of_the_hunt" )
            end
            
            -- Scattered Shots damage bonus per target (handled by talent system)
        end,
    },
    
    kill_shot = {
        id = 53351,
        cast = 0,
        cooldown = function() 
            local cd = 10
            if glyph.kill_shot.enabled then
                cd = cd - 6 -- Reduces cooldown by 6 sec
            end
            return cd
        end,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local cost = 35
            if talent.efficiency.enabled then
                cost = cost - talent.efficiency.rank
            end
            return cost
        end,
        spendType = "focus",
        
        startsCombat = true,
        usable = function() return target.health_pct < 20, "target must be below 20% health" end,
        
        handler = function ()
            -- Significant damage to low health targets
        end,
    },
    
    explosive_shot = {
        id = 53301,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "fire",
        
        spend = 40,
        spendType = "focus",
        
        talent = "explosive_shot",
        startsCombat = true,
        
        handler = function ()
            applyDebuff( "target", "explosive_shot", 2 )
        end,
    },    
    -- === TALENT ABILITIES ===
    -- Tier 4 (Level 60) Talents
    a_murder_of_crows = {
        id = 131894,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "shadow",
        
        spend = 60,
        spendType = "focus",
        
        talent = "murder_of_crows",
        startsCombat = true,
        
        toggle = "cooldowns",
        
        handler = function ()
            applyDebuff( "target", "a_murder_of_crows", 30 )
            summonPet( "murder_of_crows", 30 )
        end,
    },
    
    lynx_rush = {
        id = 120697,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        school = "physical",
        
        talent = "lynx_rush",
        startsCombat = true,
        
        toggle = "cooldowns",
        
        usable = function() return pet.alive, "requires active pet" end,
        
        handler = function ()
            applyBuff( "lynx_rush" )
        end,
    },
    
    blink_strikes = {
        id = 130392,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",
        
        talent = "blink_strikes",
        startsCombat = false,
        
        handler = function ()
            if pet.alive then
                applyBuff( "blink_strikes" )
            end
        end,
    },
    
    -- Tier 5 (Level 75) Talents  
    fervor = {
        id = 82726,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        
        talent = "fervor",
        startsCombat = false,
        
        handler = function ()
            gain( 50, "focus" )
            applyBuff( "fervor", 10 ) -- HoT component
            if pet.alive then
                pet.focus = min( pet.focus + 50, pet.focus.max )
            end
        end,
    },
    
    dire_beast = {
        id = 120679,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        
        talent = "dire_beast",
        startsCombat = true,
        
        handler = function ()
            applyBuff( "dire_beast", 15 )
            summonPet( "dire_beast_cat", 15 )
        end,
    },
    
    -- Tier 6 (Level 90) Talents
    glaive_toss = {
        id = 117050,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "physical",
        
        spend = 15,
        spendType = "focus",
        
        talent = "glaive_toss",
        startsCombat = true,
        
        handler = function ()
            -- Hits primary target + 1 additional within 10 yards
        end,
    },
    
    powershot = {
        id = 109259,
        cast = 2,
        cooldown = 45,
        gcd = "spell",
        school = "physical",
        
        talent = "powershot",
        startsCombat = true,
        
        usable = function() return active_enemies > 2, "more effective with multiple targets" end,
        
        handler = function ()
            -- AoE knockback effect
        end,
    },
    
    barrage = {
        id = 120360,
        cast = 3,
        cooldown = 30,
        gcd = "spell",
        school = "physical",
        
        spend = 60,
        spendType = "focus",
        
        talent = "barrage",
        startsCombat = true,
        
        usable = function() return active_enemies > 3, "most effective with 4+ targets" end,
        
        handler = function ()
            -- Channel for 3 seconds, AoE damage
        end,
    },
    
    -- === UTILITY AND DEBUFF ABILITIES ===
    serpent_sting = {
        id = 118253,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        spend = 25,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            local duration = 15
            if glyph.serpent_sting.enabled then
                duration = duration + 6 -- Glyph increases duration by 6 sec
            end
            applyDebuff( "target", "serpent_sting", duration )
        end,
    },
    
    hunters_mark = {
        id = 1130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        
        startsCombat = false,
        
        handler = function ()
            applyDebuff( "target", "hunters_mark", 300 )
        end,
    },
    
    concussive_shot = {
        id = 5116,
        cast = 0,
        cooldown = 5,
        gcd = "spell",
        school = "nature",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff( "target", "concussive_shot", 6 )
            -- Improved Concussive Shot stun chance
            if talent.improved_concussive_shot.enabled and math.random() <= (talent.improved_concussive_shot.rank * 0.05) then
                applyDebuff( "target", "concussive_stun", 3 )
            end
        end,
    },
    
    -- === CROWD CONTROL ABILITIES ===
    silencing_shot = {
        id = 34490,
        cast = 0,
        cooldown = 20,
        gcd = "off",
        school = "physical",
        
        talent = "silencing_shot",
        startsCombat = true,
        
        toggle = "interrupts",
        
        usable = function() return target.casting, "target must be casting" end,
        
        handler = function ()
            interrupt()
            applyDebuff( "target", "silencing_shot", 3 )
        end,
    },
    
    wyvern_sting = {
        id = 19386,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",
        
        talent = "wyvern_sting",
        startsCombat = true,
        
        handler = function ()
            applyDebuff( "target", "wyvern_sting", 30 )
        end,
    },
    
    binding_shot = {
        id = 109248,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",
        
        talent = "binding_shot",
        startsCombat = false,
        
        handler = function ()
            -- Tether effect not directly modeled
        end,
    },
    
    scatter_shot = {
        id = 19503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff( "target", "scatter_shot", 4 )
        end,
    },
    
    -- === DEFENSIVE ABILITIES ===
    deterrence = {
        id = 19263,
        cast = 0,
        cooldown = function() 
            local cd = 180
            if talent.crouching_tiger.enabled then
                cd = cd - 10 -- Reduces cooldown by 10 sec
            end
            return cd
        end,
        charges = 2,
        recharge = function() 
            local cd = 180
            if talent.crouching_tiger.enabled then
                cd = cd - 10
            end
            return cd
        end,
        gcd = "off",
        school = "physical",
        
        toggle = "defensives",
        defensive = true,
        
        startsCombat = false,
        
        handler = function ()
            applyBuff( "deterrence", 5 )
        end,
    },
    
    disengage = {
        id = 781,
        cast = 0,
        cooldown = function() 
            local cd = 20
            if talent.crouching_tiger.enabled then
                cd = cd - 6 -- Reduces cooldown by 6 sec
            end
            return cd
        end,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            if talent.posthaste.enabled then 
                applyBuff( "posthaste", 4 ) 
            end
            if talent.narrow_escape.enabled then
                -- Web trap effect not directly modeled
            end
        end,
    },
    
    exhilaration = {
        id = 109304,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",
        
        talent = "exhilaration",
        startsCombat = false,
        
        toggle = "defensives",
        defensive = true,
        
        handler = function ()
            gain( 0.22 * health.max, "health" )
            if pet.alive then
                pet.health = min( pet.health + 0.22 * pet.health.max, pet.health.max )
            end
        end,
    },
    
    feign_death = {
        id = 5384,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff( "feign_death", 6 )
        end,
    },
    
    camouflage = {
        id = 51755,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff( "camouflage", 6 )
        end,
    },
    
    -- === MAJOR COOLDOWNS ===
    rapid_fire = {
        id = 3045,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff( "rapid_fire", 15 )
            if talent.rapid_recuperation.enabled then
                applyBuff( "rapid_recuperation", 9 )
            end
        end,
    },
    
    readiness = {
        id = 23989,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            -- Reset all cooldowns except Readiness
            for k, v in pairs( cooldown ) do
                if k ~= "readiness" and v.remains > 0 then 
                    setCooldown( k, 0 ) 
                end
            end
            applyBuff( "readiness", 2 )
        end,
    },
    
    trueshot_aura = {
        id = 19506,
        cast = 0,
        cooldown = 2,
        gcd = "spell",
        school = "physical",
        
        talent = "trueshot_aura",
        startsCombat = false,
        
        handler = function ()
            applyBuff( "trueshot_aura" )
        end,
    },
    
    -- === UTILITY ABILITIES ===
    misdirection = {
        id = 34477,
        cast = 0,
        cooldown = function()
            local cd = 30
            if glyph.misdirection.enabled then
                cd = cd - 10 -- Reduces cooldown by 10 sec
            end
            return cd
        end,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return pet.alive or group, "requires pet or group member" end,
        
        handler = function ()
            applyBuff( "misdirection", 8 )
        end,
    },
    
    -- === PET MANAGEMENT ===
    mend_pet = {
        id = 136,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "nature",
        
        spend = 35,
        spendType = "focus",
        
        startsCombat = false,
        
        usable = function() return pet.alive and pet.health_pct < 100, "pet must be alive and injured" end,
        
        handler = function ()
            applyBuff( "mend_pet", 10 )
        end,
    },
    
    call_pet_1 = {
        id = 883,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "no pet currently active" end,
        
        handler = function ()
            summonPet( "tenacity" )
        end,
    },
    
    call_pet_2 = {
        id = 83242,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "no pet currently active" end,
        
        handler = function ()
            summonPet( "ferocity" )
        end,
    },
    
    call_pet_3 = {
        id = 83243,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "no pet currently active" end,
        
        handler = function ()
            summonPet( "cunning" )
        end,
    },
    
    revive_pet = {
        id = 982,
        cast = function() 
            local cast_time = 10
            if glyph.revive_pet.enabled then
                cast_time = cast_time * 0.5 -- 50% faster cast time
            end
            return cast_time
        end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        spend = 50,
        spendType = "focus",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "pet must be dead" end,
        
        handler = function ()
            summonPet( "ferocity" ) -- Default to last active pet type
        end,
    },
    
    dismiss_pet = {
        id = 2641,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return pet.alive, "requires active pet" end,
        
        handler = function ()
            dismissPet()
        end,
    },
    
    -- === TRAPS ===
    freezing_trap = {
        id = 1499,
        cast = 0,
        cooldown = function()
            local cd = 30
            if glyph.freezing_trap.enabled then
                cd = cd - 5 -- Reduces cooldown by 5 sec
            end
            return cd
        end,
        gcd = "spell",
        school = "frost",
        
        startsCombat = false,
        
        handler = function ()
            -- Trap placement not modeled in simulation
        end,
    },
    
    ice_trap = {
        id = 13809,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "frost",
        
        startsCombat = false,
        
        handler = function ()
            -- Area effect trap not modeled in simulation
        end,
    },
    
    explosive_trap = {
        id = 13813,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "fire",
        
        startsCombat = false,
        
        handler = function ()
            -- Damage trap not modeled in simulation
            -- Glyph increases damage by 20%
        end,
    },
    
    snake_trap = {
        id = 34600,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",
        
        startsCombat = false,
        
        handler = function ()
            -- Snake summon trap not modeled in simulation
        end,
    },    
    -- === ASPECTS ===
    aspect_of_the_hawk = {
        id = 13165,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff( "aspect_of_the_cheetah" )
            removeBuff( "aspect_of_the_pack" )
            removeBuff( "aspect_of_the_iron_hawk" )
            applyBuff( "aspect_of_the_hawk" )
        end,
    },
    
    aspect_of_the_cheetah = {
        id = 5118,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff( "aspect_of_the_hawk" )
            removeBuff( "aspect_of_the_pack" )
            removeBuff( "aspect_of_the_iron_hawk" )
            applyBuff( "aspect_of_the_cheetah" )
        end,
    },
    
    aspect_of_the_pack = {
        id = 13159,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff( "aspect_of_the_hawk" )
            removeBuff( "aspect_of_the_cheetah" )
            removeBuff( "aspect_of_the_iron_hawk" )
            applyBuff( "aspect_of_the_pack" )
        end,
    },
    
    aspect_of_the_iron_hawk = {
        id = 109260,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        school = "physical",
        
        talent = "aspect_of_the_iron_hawk",
        startsCombat = false,
        
        handler = function ()
            removeBuff( "aspect_of_the_hawk" )
            removeBuff( "aspect_of_the_cheetah" )
            removeBuff( "aspect_of_the_pack" )
            applyBuff( "aspect_of_the_iron_hawk" )
        end,
    },
    
    -- === AUTO SHOT (PASSIVE) ===
    auto_shot = {
        id = 75,
        cast = 0,
        cooldown = function() return ranged_speed or 2.8 end,
        gcd = "off",
        school = "physical",
        
        startsCombat = true,
        
        handler = function ()
            -- Master Marksman proc chance (20% on all ranged attacks)
            if math.random() <= 0.2 then
                addStack( "master_marksman" )
                if buff.master_marksman.stack == 5 then
                    removeBuff( "master_marksman" )
                    applyBuff( "aimed_shot_instant" )
                end
            end
            
            -- Piercing Shots on crit
            if talent.piercing_shots.enabled and action.auto_shot.lastCrit then
                applyDebuff( "target", "piercing_shots", 8 )
            end
        end,
    },
} )

-- Enhanced State Expressions for Marksmanship optimization
spec:RegisterStateExpr( "focus_time_to_max", function()
    local regen_rate = 6 * haste
    if buff.aspect_of_the_iron_hawk.up then regen_rate = regen_rate * 1.3 end
    if buff.rapid_fire.up then regen_rate = regen_rate * 1.5 end
    if talent.improved_tracking.enabled then regen_rate = regen_rate * (1 + talent.improved_tracking.rank * 0.02) end
    
    return math.max( 0, ( focus.max - focus.current ) / regen_rate )
end )

spec:RegisterStateExpr( "master_marksman_ready", function()
    return buff.master_marksman.stack == 5 or buff.aimed_shot_instant.up
end )

spec:RegisterStateExpr( "aimed_shot_ready", function()
    return cooldown.aimed_shot.remains == 0 and (focus.current >= 50 or master_marksman_ready)
end )

spec:RegisterStateExpr( "chimera_shot_ready", function()
    return cooldown.chimera_shot.remains == 0 and focus.current >= 35
end )

spec:RegisterStateExpr( "serpent_sting_refreshable", function()
    return debuff.serpent_sting.remains < 4.5 or not debuff.serpent_sting.up
end )

spec:RegisterStateExpr( "steady_focus_active", function()
    return buff.steady_focus.up
end )

spec:RegisterStateExpr( "piercing_shots_ticking", function()
    return debuff.piercing_shots.up and debuff.piercing_shots.ticking
end )

spec:RegisterStateExpr( "careful_aim_available", function()
    return buff.careful_aim.up and buff.careful_aim.stack > 0
end )

spec:RegisterStateExpr( "rapid_fire_optimal", function()
    return not buff.rapid_fire.up and cooldown.rapid_fire.remains == 0 and focus.current < 30
end )

spec:RegisterStateExpr( "focus_dump_ready", function()
    return focus.current > 80 and not focus_time_to_max <= 3
end )

spec:RegisterStateExpr( "pet_focus_available", function()
    return pet.alive and pet.focus and pet.focus > 25
end )

spec:RegisterStateExpr( "thrill_proc_available", function()
    return talent.thrill_of_the_hunt.enabled and buff.thrill_of_the_hunt.stack > 0
end )

-- Combat Log Event Tracking for Marksmanship mechanics
RegisterMMCombatLogEvent( "SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    -- Track successful casts for Master Marksman procs
    local ranged_abilities = {
        [19434] = true, -- Aimed Shot
        [56641] = true, -- Steady Shot
        [77767] = true, -- Cobra Shot
        [3044] = true,  -- Arcane Shot
        [2643] = true,  -- Multi-Shot
        [75] = true,    -- Auto Shot
    }
    
    if ranged_abilities[spellID] then
        -- 20% chance to generate Master Marksman stack
        if math.random() <= 0.2 then
            state.addStack( "master_marksman" )
            if state.buff.master_marksman.stack >= 5 then
                state.removeBuff( "master_marksman" )
                state.applyBuff( "aimed_shot_instant", 10 )
            end
        end
    end
    
    -- Track Steady Shot/Cobra Shot for Careful Aim
    if spellID == 56641 or spellID == 77767 then
        if state.buff.careful_aim.up then
            if state.buff.careful_aim.stack == 1 then
                state.removeBuff( "careful_aim" )
            else
                state.removeStack( "careful_aim" )
            end
        end
    end
end )

RegisterMMCombatLogEvent( "SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand)
    -- Track critical strikes for Piercing Shots
    local piercing_abilities = {
        [19434] = true, -- Aimed Shot
        [56641] = true, -- Steady Shot
        [75] = true,    -- Auto Shot
    }
    
    if critical and piercing_abilities[spellID] and state.talent.piercing_shots.enabled then
        state.applyDebuff( "target", "piercing_shots", 8 )
    end
    
    -- Track Lock and Load proc chances
    if spellID == 82924 and state.talent.lock_and_load.enabled then -- Piercing Shots damage
        if math.random() <= (state.talent.lock_and_load.rank * 0.05) then
            state.setCooldown( "aimed_shot", 0 )
        end
    end
end )

RegisterMMCombatLogEvent( "UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    if destGUID == UnitGUID("target") then
        -- Apply Careful Aim buff for next 2 shots
        if state.talent.careful_aim.enabled then
            state.applyBuff( "careful_aim", 3600, 2 )
        end
        
        -- Reset Murder of Crows cooldown if target dies while under effect
        if state.debuff.a_murder_of_crows.up then
            state.setCooldown( "a_murder_of_crows", 0 )
        end
    end
end )

RegisterMMCombatLogEvent( "SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType)
    -- Track Thrill of the Hunt procs
    if spellID == 34720 and destGUID == UnitGUID("player") then
        state.addStack( "thrill_of_the_hunt" )
    end
    
    -- Track Dire Beast focus generation
    if spellID == 120679 and destGUID == UnitGUID("player") then
        state.applyBuff( "dire_beast", 15 )
    end
end )

spec:RegisterRanges( "arcane_shot", "concussive_shot", "scatter_shot" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = false,
    nameplateRange = 40,
    rangeFilter = false,

    damage = true,
    damageExpiration = 3,

    potion = "virmen_bite", -- MoP potion
    package = "Marksmanship",
} )

spec:RegisterSetting( "pet_healing", 0, {
    name = strformat( "%s Below Health %%", Hekili:GetSpellLinkWithTexture( spec.abilities.mend_pet.id ) ),
    desc = strformat( "If set above zero, %s may be recommended when your pet falls below this health percentage. Setting to |cFFFFd1000|r disables this feature.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.mend_pet.id ) ),
    icon = 132179,
    iconCoords = { 0.1, 0.9, 0.1, 0.9 },
    type = "range",
    min = 0,
    max = 100,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "mark_boss_only", true, {
    name = strformat( "%s Bosses Only", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    desc = strformat( "If checked, %s will be recommended for boss targets only.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    type = "toggle",
    width = "full"
} )

-- Register default pack for MoP Marksmanship Hunter
spec:RegisterPack( "Marksmanship", 20250515, [[Hekili:T1nBVTnUr8FlSnLLAWOoYHTO4yrwMQLf8SKPLynoS49AOPrRkvaN1HA2YIPvrsSsTkSiRKQfaLBYuZ1Ya3MFtFJpNvFtNLzZYvyeoKq)QL9aP6WLL3aUckUk(ifF9719nEY78dcN3w(GiIrD0H))scKuHteK0o1IrFIIS4mPxpw)mHkP8kHbFCGcQeDzGK9Sc9OVqTSdErLzLuXwvgnt0usg0y3OcvLsciToasrJIPzvzzyyHkFasw1us5czKzSkH1agzQu5Gunv0QOsnwCPl0bvzLKQ2YXKtvn...]] )

-- Register pack selector for Marksmanship
spec:RegisterPackSelector( "marksmanship", "Marksmanship", "|T132222:0|t Marksmanship",
    "Handles all aspects of Marksmanship Hunter rotation with focus on Aimed Shot and Chimera Shot.",
    nil )
