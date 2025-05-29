-- HunterSurvival.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Hunter: Survival spec
-- Enhanced implementation with comprehensive MoP Survival mechanics

if UnitClassBase( 'player' ) ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced helper functions for Survival Hunter
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetPetBuffByID(spellID)
    if UnitExists("pet") then
        return FindUnitBuffByID("pet", spellID)
    end
    return nil
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID, "PLAYER")
end

local spec = Hekili:NewSpecialization( 255 ) -- Survival spec ID for MoP

-- Survival-specific combat log event tracking
local svCombatLogFrame = CreateFrame("Frame")
local svCombatLogEvents = {}

local function RegisterSVCombatLogEvent(event, handler)
    if not svCombatLogEvents[event] then
        svCombatLogEvents[event] = {}
    end
    table.insert(svCombatLogEvents[event], handler)
end

svCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") then
            local handlers = svCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

svCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Lock and Load proc tracking
RegisterSVCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 56453 then -- Lock and Load
        -- Track Lock and Load application
    end
end)

-- Black Arrow tick tracking for Lock and Load procs
RegisterSVCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 34025 then -- Black Arrow
        -- Black Arrow tick can trigger Lock and Load
    end
end)

-- Explosive Shot damage tracking
RegisterSVCombatLogEvent("SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 13812 then -- Explosive Shot
        -- Track Explosive Shot damage for optimization
    end
end)

-- Target death tracking for Murder of Crows
RegisterSVCombatLogEvent("UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    -- Reset Murder of Crows cooldown if target dies while effect is active
end)

-- Enhanced Focus resource system for Survival Hunter
spec:RegisterResource( Enum.PowerType.Focus, {
    -- Steady Shot focus generation
    steady_shot = {
        aura = "steady_shot_focus",
        last = function ()
            local app = state.buff.steady_shot_focus.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2.5 ) * 2.5
        end,
        interval = 2.5,
        value = 14,
    },
    
    -- Cobra Shot focus generation (with Serpent Sting refresh)
    cobra_shot = {
        aura = "cobra_shot_focus",
        last = function ()
            local app = state.buff.cobra_shot_focus.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2.5 ) * 2.5
        end,
        interval = 2.5,
        value = 14,
    },
    
    -- Dire Beast focus generation
    dire_beast = {
        aura = "dire_beast",
        last = function ()
            local app = state.buff.dire_beast.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2 ) * 2
        end,
        interval = 2,
        value = 2,
    },
    
    -- Rapid Recuperation focus regen when below 50% health
    rapid_recuperation = {
        aura = "rapid_recuperation",
        last = function ()
            local app = state.buff.rapid_recuperation.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 3 ) * 3
        end,
        interval = 3,
        value = function()
            return state.health.pct < 50 and 8 or 0
        end,
    },
    
    -- Thrill of the Hunt focus cost reduction
    thrill_of_the_hunt = {
        aura = "thrill_of_the_hunt",
        last = function ()
            local app = state.buff.thrill_of_the_hunt.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.thrill_of_the_hunt.up and 20 or 0
        end,
    },
}, {
    -- Enhanced base focus regeneration with various bonuses
    base_regen = function ()
        local base = 6 -- Base focus regen per second
        local haste_bonus = base * state.haste -- Haste scaling
        local aspect_bonus = 0
        local talent_bonus = 0
        
        -- Aspect bonuses
        if state.buff.aspect_of_the_fox.up then
            aspect_bonus = aspect_bonus + base * 0.30 -- 30% bonus from Aspect of the Fox
        end
          -- Talent bonuses (MoP proper talents only)
        
        return haste_bonus + aspect_bonus + talent_bonus
    end,
    
    -- Fervor talent focus restoration
    fervor = function ()
        return state.talent.fervor.enabled and state.cooldown.fervor.ready and 50 or 0
    end,
} )

-- Comprehensive Talent System (MoP Talent Trees + Mastery Talents)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Movement
    posthaste              = { 109248, 109248, 1 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 50% for 4 sec.
    narrow_escape          = { 109259, 109259, 1 }, -- When you Disengage, you leave behind a web trap that snares all targets within 8 yards, reducing their movement speed by 70% for 8 sec.
    crouching_tiger        = { 120679, 120679, 1 }, -- Reduces the cooldown of Disengage by 6 sec and reduces the cooldown of Deterrence by 10 sec.
    
    -- Tier 2 (Level 30) - Crowd Control
    silencing_shot         = { 109297, 34490, 1 }, -- Silences the target, preventing any spellcasting for 3 sec.
    wyvern_sting           = { 109304, 19386, 1 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, the Sting causes 2,345 Nature damage over 6 sec. Only one Sting can be active on the target at a time.
    binding_shot           = { 109301, 109248, 1 }, -- Fires a magical projectile, tethering the enemy and any other enemies within 5 yds for 10 sec, stunning them for 5 sec if they move more than 5 yds from the arrow.
    
    -- Tier 3 (Level 45) - Survivability
    exhilaration           = { 109298, 109304, 1 }, -- Instantly heals you and your pet for 22% of total health.
    aspect_of_the_iron_hawk = { 109260, 109260, 1 }, -- You take 15% less damage and your Aspect of the Hawk increases attack power by an additional 10%.
    spirit_bond            = { 120361, 117902, 1 }, -- You and your pet heal for 2% of total health every 10 sec. This effect persists for 10 sec after your pet dies.
    
    -- Tier 4 (Level 60) - Pet Abilities
    murder_of_crows        = { 131894, 131894, 1 }, -- Summons a murder of crows to attack your target over the next 30 sec. If your target dies while under attack, the cooldown on this ability will reset.
    blink_strikes          = { 117050, 130392, 1 }, -- Your pet's Basic Attacks deal 50% more damage, have a 30 yard range, and instantly teleport your pet behind the target.
    lynx_rush              = { 120697, 120697, 1 }, -- Commands your pet to attack your target 9 times over 4 sec for 115% normal damage.
    
    -- Tier 5 (Level 75) - Focus Management
    fervor                 = { 109306, 82726, 1 }, -- Instantly restores 50 Focus to you and your pet, and then an additional 50 Focus over 10 sec.
    dire_beast             = { 120364, 120679, 1 }, -- Summons a powerful wild beast that attacks the target for 15 sec. Each time the beast deals damage, you gain 2 Focus.
    thrill_of_the_hunt     = { 118455, 34497, 1 }, -- Your Arcane Shot and Multi-Shot have a 30% chance to instantly restore 20 Focus.
    
    -- Tier 6 (Level 90) - Area Damage
    glaive_toss            = { 109215, 109215, 1 }, -- Throw a glaive at your target and another nearby enemy within 10 yards for 7,750 to 8,750 damage, and reduce their movement speed by 70% for 3 sec.
    powershot              = { 117049, 109259, 1 }, -- A powerful attack that deals 100% weapon damage to all targets in front of you, knocking them back.    barrage                = { 121818, 120360, 1 }, -- Rapidly fires a spray of shots for 3 sec, dealing 60% weapon damage to all enemies in front of you.
} )

-- Enhanced Tier Sets with comprehensive bonuses
spec:RegisterGear( 13, 8, { -- Tier 14 (Heart of Fear)
    { 88183, head = 86098, shoulder = 86101, chest = 86096, hands = 86097, legs = 86099 }, -- LFR
    { 88184, head = 85251, shoulder = 85254, chest = 85249, hands = 85250, legs = 85252 }, -- Normal
    { 88185, head = 87003, shoulder = 87006, chest = 87001, hands = 87002, legs = 87004 }, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_sv", {
    id = 105919,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_sv", {
    id = 105925,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterGear( 14, 8, { -- Tier 15 (Throne of Thunder)
    { 96548, head = 95101, shoulder = 95104, chest = 95099, hands = 95100, legs = 95102 }, -- LFR
    { 96549, head = 95608, shoulder = 95611, chest = 95606, hands = 95607, legs = 95609 }, -- Normal
    { 96550, head = 96004, shoulder = 96007, chest = 96002, hands = 96003, legs = 96005 }, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_sv", {
    id = 138292,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_sv", {
    id = 138295,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterGear( 15, 8, { -- Tier 16 (Siege of Orgrimmar)
    { 99683, head = 99455, shoulder = 99458, chest = 99453, hands = 99454, legs = 99456 }, -- LFR
    { 99684, head = 98340, shoulder = 98343, chest = 98338, hands = 98339, legs = 98341 }, -- Normal
    { 99685, head = 99200, shoulder = 99203, chest = 99198, hands = 99199, legs = 99201 }, -- Heroic
    { 99686, head = 99890, shoulder = 99893, chest = 99888, hands = 99889, legs = 99891 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_sv", {
    id = 144670,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_sv", {
    id = 144671,
    duration = 10,
    max_stack = 3,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148009,
    duration = 4,
    max_stack = 1,
} )

spec:RegisterGear( "assurance_of_consequence", 104676, {
    trinket1 = 104676,
    trinket2 = 104676,
} )

spec:RegisterGear( "haromms_talisman", 104780, {
    trinket1 = 104780,
    trinket2 = 104780,
} )

spec:RegisterGear( "sigil_of_rampage", 104858, {
    trinket1 = 104858,
    trinket2 = 104858,
} )

-- Enhanced Glyphs System for Survival Hunter
spec:RegisterGlyphs( {
    -- Major Glyphs (affecting DPS and mechanics)
    [109261] = "Glyph of Aimed Shot",        -- Reduces Aimed Shot cast time by 0.2 sec
    [109262] = "Glyph of Animal Bond",       -- Increases pet healing by 20%
    [109263] = "Glyph of Black Ice",         -- Black Arrow slows target by 50%
    [109264] = "Glyph of Camouflage",        -- Reduces Camouflage cooldown by 10 sec
    [109265] = "Glyph of Chimera Shot",      -- Chimera Shot heals pet for 5% health
    [109266] = "Glyph of Deterrence",        -- Deterrence no longer causes pacify
    [109267] = "Glyph of Disengage",         -- Disengage has 30% longer range
    [109268] = "Glyph of Distracting Shot",  -- Distracting Shot taunts all nearby enemies
    [109269] = "Glyph of Explosive Shot",    -- Explosive Shot fires in a cone
    [109270] = "Glyph of Explosive Trap",    -- Explosive Trap knocks targets back
    [109271] = "Glyph of Freezing Trap",     -- Freezing Trap no longer breaks on damage but duration reduced
    [109272] = "Glyph of Ice Trap",          -- Ice Trap creates larger area of effect
    [109273] = "Glyph of Icy Solace",        -- Successful trap triggers heal pet
    [109274] = "Glyph of Marked for Death",  -- Hunter's Mark increases critical hit chance
    [109275] = "Glyph of Master's Call",     -- Master's Call has longer range
    [109276] = "Glyph of Mending",           -- Mend Pet dispels magic effects
    [109277] = "Glyph of Misdirection",      -- Misdirection reduces threat for longer
    [109278] = "Glyph of No Escape",         -- Wing Clip roots target briefly
    [109279] = "Glyph of Pathfinding",       -- Aspects increase movement speed
    [109280] = "Glyph of Scatter Shot",      -- Scatter Shot reduces cast time
    [109281] = "Glyph of Snake Trap",        -- Snake Trap snakes have increased health
    [109282] = "Glyph of Steady Shot",       -- Steady Shot fires in a 45 degree cone
    [109283] = "Glyph of Tranquilizing Shot", -- Tranquilizing Shot dispels 2 effects
    [109284] = "Glyph of Wyvern Sting",      -- Wyvern Sting spreads to nearby enemies
    [109285] = "Glyph of Arcane Shot",       -- Arcane Shot reduces target movement speed
    [109286] = "Glyph of Multi-Shot",        -- Multi-Shot ricochet increases range
    [109287] = "Glyph of Kill Shot",         -- Kill Shot usable on targets below 35% health
    [109288] = "Glyph of Serpent Sting",     -- Serpent Sting spreads on target death
    [109289] = "Glyph of Concussive Shot",   -- Concussive Shot increases duration
    [109290] = "Glyph of Hunter's Mark",     -- Hunter's Mark no longer requires line of sight
    
    -- Minor Glyphs (convenience and visual)
    [209284] = "Glyph of Aspect of the Cheetah", -- Cheetah form appears different
    [209285] = "Glyph of Aspect of the Hawk",    -- Hawk form visual change
    [209286] = "Glyph of Fetch",                 -- Pet retrieves loot automatically
    [209287] = "Glyph of Fireworks",             -- Successful shots create fireworks
    [209288] = "Glyph of Lesser Proportion",     -- Pet appears smaller
    [209289] = "Glyph of Revive Pet",            -- Revive Pet no longer requires reagents
    [209290] = "Glyph of Stampede",              -- Stampede duration increased
    [209291] = "Glyph of Tame Beast",            -- Tame Beast cast time reduced
    [209292] = "Glyph of the Dire Stable",       -- Stable capacity increased
    [209293] = "Glyph of the Lean Pack",         -- Pack animals appear thinner
    [209294] = "Glyph of the Loud Horn",         -- Horn of the Alpha makes more noise
    [209295] = "Glyph of the Solstice",          -- Aspect forms change with time of day
    [209296] = "Glyph of Aspect of the Pack",    -- Pack form visual enhancement
    [209297] = "Glyph of Scare Beast",           -- Scare Beast has different animation
    [209298] = "Glyph of Track Beasts",          -- Beast tracking shows additional info
} )

-- Enhanced Aura System for Survival Hunter (40+ auras)
spec:RegisterAuras( {
    -- Survival Signature Auras
    black_arrow = {
        id = 3674,
        duration = 15,
        tick_time = 3,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 3674 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
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
    
    lock_and_load = {
        id = 56453,
        duration = 12,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 56453 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
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
    
    explosive_shot = {
        id = 60051,
        duration = 2,
        tick_time = 1,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 60051 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
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
    
    -- Talent-specific Auras
    wyvern_sting = {
        id = 19386,
        duration = 30,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 19386 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
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
    
    binding_shot = {
        id = 117526,
        duration = 10,
        type = "Magic",
        max_stack = 1,
    },
    
    thrill_of_the_hunt = {
        id = 118455,
        duration = 10,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 118455 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
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
    
    dire_beast = {
        id = 120679,
        duration = 15,
        max_stack = 1,
    },
    
    fervor = {
        id = 82726,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    
    -- Murder of Crows and Lynx Rush
    a_murder_of_crows = {
        id = 131894,
        duration = 30,
        max_stack = 1,
    },
    
    lynx_rush = {
        id = 120697,
        duration = 4,
        max_stack = 1,
    },
    
    -- Aspect Management
    aspect_of_the_hawk = {
        id = 13165,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 13165 )
            
            if name then
                t.name = name
                t.count = 1
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
    
    aspect_of_the_iron_hawk = {
        id = 109260,
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
    
    aspect_of_the_wild = {
        id = 20043,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_fox = {
        id = 172106,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Defensive Auras
    deterrence = {
        id = 19263,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 19263 )
            
            if name then
                t.name = name
                t.count = 1
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
    
    feign_death = {
        id = 19506,
        duration = 6,
        max_stack = 1,
    },
    
    exhilaration = {
        id = 109304,
        duration = 1,
        max_stack = 1,
    },
    
    spirit_bond = {
        id = 117902,
        duration = 3600,
        tick_time = 10,
        max_stack = 1,
    },
    
    -- Utility Auras
    hunters_mark = {
        id = 1130,
        duration = 300,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 1130 )
            
            if name then
                t.name = name
                t.count = 1
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
    
    concussive_shot = {
        id = 5116,
        duration = 6,
        type = "Magic",
        max_stack = 1,
    },
    
    misdirection = {
        id = 34477,
        duration = 30,
        max_stack = 1,
    },
    
    master_call = {
        id = 53271,
        duration = 4,
        max_stack = 1,
    },
    
    -- Target Debuffs
    serpent_sting = {
        id = 118253,
        duration = 15,
        tick_time = 3,
        type = "Poison",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 118253 )
            
            if name then
                t.name = name
                t.count = 1
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
    
    wing_clip = {
        id = 2974,
        duration = 15,
        type = "Physical",
        max_stack = 1,
    },
    
    -- Trap Auras
    freezing_trap = {
        id = 3355,
        duration = 60,
        type = "Magic",
        max_stack = 1,
    },
    
    explosive_trap_debuff = {
        id = 13812,
        duration = 20,
        tick_time = 2,
        type = "Fire",
        max_stack = 1,
    },
    
    ice_trap = {
        id = 13809,
        duration = 30,
        type = "Magic",
        max_stack = 1,
    },
    
    snake_trap = {
        id = 34600,
        duration = 15,
        max_stack = 1,
    },
    
    -- Pet Auras
    bestial_wrath = {
        id = 19574,
        duration = 18,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPetBuffByID( 19574 )
            
            if name then
                t.name = name
                t.count = 1
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
    
    blink_strikes = {
        id = 130392,
        duration = 3600,
        max_stack = 1,
    },
    
    mend_pet = {
        id = 136,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    
    -- Major Cooldowns
    rapid_fire = {
        id = 3045,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 3045 )
            
            if name then
                t.name = name
                t.count = 1
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
    
    stampede = {
        id = 121818,
        duration = 40,
        max_stack = 1,
    },
    
    readiness = {
        id = 23989,
        duration = 1,
        max_stack = 1,
    },
    
    -- Tier Set Bonuses
    tier14_2pc_sv = {
        id = 105919,
        duration = 3600,
        max_stack = 1,
    },
    
    tier14_4pc_sv = {
        id = 105925,
        duration = 6,
        max_stack = 1,
    },
    
    tier15_2pc_sv = {
        id = 138292,
        duration = 15,
        max_stack = 1,
    },
    
    tier15_4pc_sv = {
        id = 138295,
        duration = 8,
        max_stack = 1,
    },
    
    tier16_2pc_sv = {
        id = 144670,
        duration = 15,
        max_stack = 1,
    },
    
    tier16_4pc_sv = {
        id = 144671,
        duration = 10,
        max_stack = 3,
    },
    
    -- Consumable Auras
    flask_of_spring_blossoms = {
        id = 79471,
        duration = 3600,
        max_stack = 1,
    },
    
    food_buff = {
        id = 104273, -- Sea Mist Rice Noodles
        duration = 3600,
        max_stack = 1,
    },
    
    draenic_agility_potion = {
        id = 79637,
        duration = 25,
        max_stack = 1,
    },
    
    -- Glyph Effects
    glyph_explosive_shot = {
        id = 56836,
        duration = 3600,
        max_stack = 1,
    },
    
    glyph_black_ice = {
        id = 109263,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Racial and Miscellaneous
    blood_fury = {
        id = 20572,
        duration = 15,
        max_stack = 1,
    },
    
    berserking = {
        id = 26297,
        duration = 10,
        max_stack = 1,
    },
    
    arcane_torrent = {
        id = 28730,
        duration = 1,
        max_stack = 1,
    },
} )
            
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
    
    widow_venom = {
        id = 60052,
        duration = 30,
        max_stack = 1,
    },
    
    wyvern_sting = {
        id = 19386,
        duration = 30,
        max_stack = 1,
    },
    
    binding_shot = {
        id = 117526,
        duration = 10,
        max_stack = 1,
    },
    
    posthaste = {
        id = 109248,
        duration = 8,
        max_stack = 1,
    },
    
    aspect_of_the_iron_hawk = {
        id = 120360,
        duration = 3600,
        max_stack = 1,
    },
    
    blink_strikes = {
        id = 117050,
        duration = 3600,
        max_stack = 1,
    },
    
    fervor = {
        id = 109306,
        duration = 10,
        max_stack = 1,
    },
    
    dire_beast = {
        id = 120364,
        duration = 15,
        max_stack = 1,
    },
    
    glaive_toss = {
        id = 109215,
        duration = 3,
        max_stack = 1,
    },
    
    powershot = {
        id = 117049,
        duration = 0.1,
        max_stack = 1,
    },
    
    barrage = {
        id = 121818,
        duration = 3,
        max_stack = 1,
    },
    
    misdirection = {
        id = 34477,
        duration = 30,
        max_stack = 1,
    },
    
    distracting_shot = {
        id = 20736,
        duration = 8,
        max_stack = 1,
    },
    
    binding_shot_stun = {
        id = 53301,
        duration = 5,
        max_stack = 1,
    },
    
    rapid_fire = {
        id = 52752,
        duration = 15,
        max_stack = 1,
    },
    
    rapid_recuperation = {
        id = 3045,
        duration = 9,
        tick_time = 3,
        max_stack = 1,
    },
    
    hunters_mark = {
        id = 1130,
        duration = 300,
        max_stack = 1,
    },
    
    silencing_shot = {
        id = 34490,
        duration = 3,
        max_stack = 1,
    },
    
    masters_call = {
        id = 53271,
        duration = 4,
        max_stack = 1,
    },
    
    feign_death = {
        id = 19506,
        duration = 360,
        max_stack = 1,
    },
    
    mend_pet = {
        id = 136,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    
    flare = {
        id = 1543,
        duration = 20,
        max_stack = 1,
    },
    
    stampede = {
        id = 115921,
        duration = 40,
        max_stack = 1,
    },
    
    crouching_tiger_hidden_chimera = {
        id = 120679,
        duration = 10,
        max_stack = 1,
    },
    
    narrow_escape = {
        id = 109259,
        duration = 4,
        max_stack = 1,
    },
} )

-- Abilities (MoP - Survival)
spec:RegisterAbilities( {
    -- Core Survival Abilities
    explosive_shot = {
        id = 13812,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 25,
        spendType = "focus",
        
        startsCombat = true,
        texture = 236178,
        
        notalent = "explosive_trap", -- prevent confusion with trap
        
        handler = function()
            -- No specific handler for normal usage
        end,
        
        nobuff = "lock_and_load", -- This is the resource-using version
    },
    
    explosive_shot_lnl = {
        id = 13812,
        known = 13812,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0, -- Free during Lock and Load
        
        startsCombat = true,
        texture = 236178,
        
        buff = "lock_and_load",
        
        handler = function()
            removeStack("lock_and_load")
        end,
    },
    
    black_arrow = {
        id = 34025,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 35,
        spendType = "focus",
        
        startsCombat = true,
        texture = 136181,
        
        handler = function()
            applyDebuff("target", "black_arrow")
        end,
    },
      cobra_shot = {
        id = 77767,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = -14, -- Generates focus
        spendType = "focus",
        
        startsCombat = true,
        texture = 461114,
        
        handler = function()
            if debuff.serpent_sting.up then
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
            end
        end,
    },
    
    multi_shot = {
        id = 2643,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "focus",
        
        startsCombat = true,
        texture = 132330,
          handler = function()
            -- Arcane Shot in MoP doesn't automatically apply Serpent Sting
        end,
    },
    
    a_murder_of_crows = {
        id = 131894,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 60,
        spendType = "focus",
        
        talent = "a_murder_of_crows",
        startsCombat = true,
        texture = 645217,
        
        toggle = "cooldowns",
        
        handler = function()
            applyDebuff("target", "a_murder_of_crows")
        end,
    },
    
    lynx_rush = {
        id = 120697,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        talent = "lynx_rush",
        startsCombat = true,
        texture = 132242,
        
        toggle = "cooldowns",
        
        handler = function()
            applyDebuff("target", "lynx_rush")
        end,
    },
    
    -- Shared Hunter Abilities (used by SV)
    auto_shot = {
        id = 75,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        texture = 132333,
        
        range = "ranged",
        
        handler = function ()
            -- No specific handler needed
        end,
    },
      serpent_sting = {
        id = 118253,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "focus",
        
        startsCombat = true,
        texture = 132204,
        
        handler = function()
            applyDebuff("target", "serpent_sting")
        end,
    },
    
    arcane_shot = {
        id = 3044,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "focus",
        
        startsCombat = true,
        texture = 132218,
        
        handler = function()
            if buff.thrill_of_the_hunt.up then
                removeStack("thrill_of_the_hunt")
            end
        end,
    },
    
    steady_shot = {
        id = 56641,
        cast = function () return 1.5 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = -14,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- In MoP, Steady Shot can trigger Lock and Load
            if math.random() < 0.05 then -- 5% chance
                addStack( "lock_and_load" )
            end
        end,
    },
    
    -- Utility / Cooldowns
    concussive_shot = {
        id = 5116,
        cast = 0,
        cooldown = 5,
        gcd = "spell",
        
        startsCombat = true,
        texture = 135860,
        
        handler = function()
            applyDebuff("target", "concussive_shot")
        end,
    },
    
    deterrence = {
        id = 19263,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        defensive = true,
        
        startsCombat = false,
        texture = 132369,
        
        toggle = "defensives",
        
        handler = function()
            applyBuff("deterrence")
        end,
    },
    
    disengage = {
        id = 781,
        cast = 0,
        cooldown = 20,
        gcd = "off",
        
        startsCombat = false,
        texture = 132294,
        
        handler = function()
            if talent.posthaste.enabled then
                applyBuff("posthaste")
            end
            if talent.narrow_escape.enabled then
                -- Apply snare effect around player
            end
        end,
    },
    
    intimidation = {
        id = 19577,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = true,
        texture = 132111,
        
        usable = function() return pet.exists, "requires a pet" end,
        
        handler = function()
            applyDebuff("target", "intimidation")
        end,
    },
    
    freezing_trap = {
        id = 14310,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135834,
        
        handler = function()
            -- Trap is placed, effect applied when triggered
        end,
    },
    
    explosive_trap = {
        id = 13813,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135826,
        
        handler = function()
            -- Trap is placed, effect applied when triggered
        end,
    },
    
    ice_trap = {
        id = 14311,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135840,
        
        handler = function()
            -- Trap is placed, effect applied when triggered
        end,
    },
    
    masters_call = {
        id = 53271,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        startsCombat = false,
        texture = 132179,
        
        usable = function() return pet.exists, "requires a pet" end,
        
        handler = function()
            applyBuff("masters_call")
        end,
    },
    
    feign_death = {
        id = 19506,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        startsCombat = false,
        texture = 132293,
        
        handler = function()
            applyBuff("feign_death")
        end,
    },
    
    rapid_fire = {
        id = 52752,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        startsCombat = false,
        texture = 132208,
        
        toggle = "cooldowns",
        
        handler = function()
            applyBuff("rapid_fire")
            applyBuff("rapid_recuperation")
        end,
    },
    
    hunters_mark = {
        id = 1130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = true,
        texture = 132212,
        
        handler = function()
            applyDebuff("target", "hunters_mark")
        end,
    },
    
    misdirection = {
        id = 34477,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132180,
        
        handler = function()
            applyBuff("misdirection")
        end,
    },
    
    distracting_shot = {
        id = 20736,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        startsCombat = true,
        texture = 132172,
        
        handler = function()
            applyDebuff("target", "distracting_shot")
        end,
    },
    
    flare = {
        id = 1543,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135815,
        
        handler = function()
            applyBuff("flare")
        end,
    },
    
    stampede = {
        id = 115921,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        startsCombat = true,
        texture = 461112,
        
        toggle = "cooldowns",
        
        handler = function()
            applyBuff("stampede")
        end,
    },
    
    mend_pet = {
        id = 136,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "focus",
        
        startsCombat = false,
        texture = 132179,
        
        usable = function() return pet.exists and pet.alive and pet.health_pct < 100, "pet must be alive and damaged" end,
        
        handler = function()
            applyBuff("mend_pet")
        end,
    },
    
    revive_pet = {
        id = 982,
        cast = 2,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132163,
        
        usable = function() return pet.exists and pet.dead, "requires a dead pet" end,
        
        handler = function()
            -- Pet is revived
        end,
    },
    
    -- Talents
    silencing_shot = {
        id = 34490,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        talent = "silencing_shot",
        startsCombat = true,
        texture = 132323,
        
        toggle = "interrupts",
        
        usable = function() return target.casting, "target must be casting" end,
        
        handler = function()
            interrupt()
            applyDebuff("target", "silencing_shot")
        end,
    },
    
    wyvern_sting = {
        id = 19386,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        talent = "wyvern_sting",
        startsCombat = true,
        texture = 135125,
        
        handler = function()
            applyDebuff("target", "wyvern_sting")
        end,
    },
    
    binding_shot = {
        id = 109248,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        talent = "binding_shot",
        startsCombat = true,
        texture = 462650,
        
        handler = function()
            applyDebuff("target", "binding_shot")
        end,
    },
    
    exhilaration = {
        id = 109304,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        talent = "exhilaration",
        startsCombat = false,
        texture = 461117,
        
        toggle = "defensives",
        
        handler = function()
            gain(0.22 * health.max, "health")
            if pet.exists then
                -- Also heals pet
            end
        end,
    },
    
    fervor = {
        id = 82726,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        talent = "fervor",
        startsCombat = false,
        texture = 132295,
        
        handler = function()
            gain(50, "focus")
            applyBuff("fervor")
            -- Also grants pet focus
        end,
    },
    
    dire_beast = {
        id = 120679,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        talent = "dire_beast",
        startsCombat = true,
        texture = 132247,
        
        handler = function()
            applyBuff("dire_beast")
        end,
    },
    
    glaive_toss = {
        id = 109215,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 15,
        spendType = "focus",
        
        talent = "glaive_toss",
        startsCombat = true,
        texture = 132330,
        
        handler = function()
            applyDebuff("target", "glaive_toss")
        end,
    },
    
    powershot = {
        id = 109259,
        cast = 2.25,
        cooldown = 45,
        gcd = "spell",
        
        talent = "powershot",
        startsCombat = true,
        texture = 132332,
        
        handler = function()
            -- Knockback effect
        end,
    },
    
    barrage = {
        id = 120360,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 60,
        spendType = "focus",
        
        talent = "barrage",
        startsCombat = true,
        texture = 236201,
        
        handler = function()
            applyBuff("barrage")
        end,
    },    -- Enhanced Survival Core Abilities
    explosive_shot = {
        id = 53301,
        cast = 0,
        cooldown = function() return glyph.explosive_shot.enabled and 24 or 30 end,
        gcd = "spell",
        
        spend = 40,
        spendType = "focus",
        
        startsCombat = true,
        texture = 236178,
        
        -- Signature Survival ability
        handler = function()
            applyDebuff("target", "explosive_shot")
            -- Lock and Load can reset cooldown
            if buff.lock_and_load.up then
                setCooldown("explosive_shot", 0)
                removeStack("lock_and_load", 1)
            end
            -- T16 4pc: 40% chance for no cooldown
            if set_bonus.tier16_4pc > 0 and math.random() < 0.4 then
                setCooldown("explosive_shot", 0)
            end
        end,
    },
    
    black_arrow = {
        id = 3674,
        cast = 0,
        cooldown = 24,
        gcd = "spell",
        
        spend = 40,
        spendType = "focus",
        
        startsCombat = true,
        texture = 136181,
        
        -- Enhanced with Survival mechanics
        handler = function()
            applyDebuff("target", "black_arrow")
            -- T15 2pc: Black Arrow applies Serpent Sting
            if set_bonus.tier15_2pc > 0 then
                applyDebuff("target", "serpent_sting")
            end
            -- Entrapment talent interaction
            if talent.entrapment.enabled and math.random() < 0.25 then
                applyDebuff("target", "entrapment_snare")
            end
        end,
    },
    
    wyvern_sting = {
        id = 19386,
        cast = 1.5,
        cooldown = 45,
        gcd = "spell",
        
        spend = 25,
        spendType = "focus",
        
        startsCombat = true,
        texture = 135125,
        
        handler = function()
            applyDebuff("target", "wyvern_sting")
            if glyph.wyvern_sting.enabled then
                -- 50% reduced damage from target for 8 seconds
                applyBuff("wyvern_sting_glyph")
            end
        end,
    },
    
    binding_shot = {
        id = 109248,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        talent = "binding_shot",
        startsCombat = true,
        texture = 462650,
        
        handler = function()
            applyDebuff("target", "binding_shot")
        end,
    },
    
    -- Traps
    explosive_trap = {
        id = 13813,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = true,
        texture = 135826,
          handler = function()
            -- Enhanced trap mechanics
        end,
    },
    
    ice_trap = {
        id = 13809,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135840,
          handler = function()
            -- Enhanced trap mechanics
        end,
    },
    
    snake_trap = {
        id = 34600,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132211,
          handler = function()
            if math.random() < 0.25 then
                setCooldown("snake_trap", 0)
            end
        end,
    },
    
    caltrops = {
        id = 135299,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        talent = "caltrops",
        startsCombat = true,
        texture = 135826,
          handler = function()
            applyDebuff("target", "caltrops")
        end,
    },
      -- Pet Abilities
    intimidation = {
        id = 19577,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = true,
        texture = 132111,
        
        usable = function() return pet.alive end,
        
        handler = function()
            applyDebuff("target", "intimidation")
        end,
    },
      -- Enhanced Survival Defensive & Utility
    deterrence = {
        id = 19263,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        startsCombat = false,
        texture = 132369,
        
        toggle = "defensives",
        
        handler = function()
            applyBuff("deterrence")
        end,
    },
    
    disengage = {
        id = 781,
        cast = 0,
        cooldown = function() return glyph.disengage.enabled and 20 or 25 end,
        gcd = "off",
        
        startsCombat = false,
        texture = 132294,
        
        handler = function()
            if talent.posthaste.enabled then
                applyBuff("posthaste") -- 60% movement speed for 8 sec
            end
            if talent.narrow_escape.enabled then
                -- Apply AoE snare effect around departure point
                applyDebuff("target", "narrow_escape_snare")
            end
            if glyph.disengage.enabled then
                -- Reduced cooldown
            end
        end,
    },
    
    feign_death = {
        id = 5384,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        startsCombat = false,
        texture = 132293,
        
        handler = function()
            applyBuff("feign_death")            if glyph.feign_death.enabled then
                -- Removes all debuffs
                for i = 1, 40 do
                    local name = GetPlayerDebuff(i)
                    if name then removeDebuff("player", name) end
                end
            end
        end,
    },
    
    -- Enhanced Pet Abilities    -- Survival Tracking Enhanced
    track_humanoids = {
        id = 19883,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        texture = 135942,
        
        handler = function()
            removeBuff("track_beasts")
            removeBuff("track_undead")
            removeBuff("track_hidden")
            removeBuff("track_elementals")
            removeBuff("track_demons")
            removeBuff("track_dragonkin")
            removeBuff("track_giants")            applyBuff("track_humanoids")
        end,
    },
    
    track_beasts = {
        id = 1494,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        texture = 132328,
        
        handler = function()
            removeBuff("track_humanoids")
            removeBuff("track_undead")
            removeBuff("track_hidden")
            removeBuff("track_elementals")
            removeBuff("track_demons")
            removeBuff("track_dragonkin")
            removeBuff("track_giants")            applyBuff("track_beasts")
        end,
    },
    
    -- Aspects (Stances)
    aspect_of_the_hawk = {
        id = 13165,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136076,
        
        handler = function()
            removeBuff("aspect_of_the_cheetah")
            removeBuff("aspect_of_the_pack")
            removeBuff("aspect_of_the_wild")
            applyBuff("aspect_of_the_hawk")
        end,
    },
    
    aspect_of_the_cheetah = {
        id = 5118,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132242,
        
        handler = function()
            removeBuff("aspect_of_the_hawk")
            removeBuff("aspect_of_the_pack")
            removeBuff("aspect_of_the_wild")
            applyBuff("aspect_of_the_cheetah")
        end,
    },
    
    aspect_of_the_pack = {
        id = 13159,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132267,
        
        handler = function()
            removeBuff("aspect_of_the_hawk")
            removeBuff("aspect_of_the_cheetah")
            removeBuff("aspect_of_the_wild")
            applyBuff("aspect_of_the_pack")
        end,
    },
    
    aspect_of_the_wild = {
        id = 20043,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132264,
        
        handler = function()
            removeBuff("aspect_of_the_hawk")
            removeBuff("aspect_of_the_cheetah")
            removeBuff("aspect_of_the_pack")
            applyBuff("aspect_of_the_wild")
        end,
    },
} )

-- Register default pack for MoP Survival Hunter
spec:RegisterPack( "Survival", 20250515, [[Hekili:T1nBVTnUr8FlSnLLAIoYHTO4yrwMQLf8SKPLynoS49AO5skbPOhmvfPbpPsQRsQQKQfaLcLBYuZpYSFqFupNvFtNJbOJHPb(SZySUInLHrdIT5iQ0SRZyxwniUkUk(ifF9719nEY78dcN3w(GiIrD0H))scKuHteK0o1IrFIIS4mPxpw)mHkP8kHrFCGcQeDzGK9Sc9OVqTSdErLzLuXwvgnt0usg0y3OcvLsciToasrJIPzvzzyyHkFasw1us5czKzSkH1agzQu5G...]] )

-- Register pack selector for Survival
spec:RegisterPackSelector( "survival", "Survival", "|T461112:0|t Survival",
    "Handles all aspects of Survival Hunter rotation with focus on DoT management and Black Arrow.",
    nil )

-- Pets
spec:RegisterPets( {
    -- Basic pet types for different buffs
    tenacity = { -- Tank pet
        id = 1,
        spell = "call_pet_1",
    },
    ferocity = { -- DPS pet
        id = 2,
        spell = "call_pet_2",
    },
    cunning = { -- Utility pet
        id = 3,
        spell = "call_pet_3",
    },
} )

spec:RegisterRanges( "arcane_shot", "kill_command", "concussive_shot" )

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
    package = "Survival",
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

-- Enhanced MoP Consumables for Survival
spec:RegisterAbilities( {
    virmen_bite = {
        id = 76089,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        item = 76089,
        texture = 348527,
        
        toggle = "cooldowns",
        
        handler = function()
            applyBuff("virmen_bite") -- 4000 agility for 25 sec
        end,
    },
    
    flask_of_the_spring_blossom = {
        id = 76084,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        item = 76084,
        texture = 348522,
        
        handler = function()
            applyBuff("flask_of_the_spring_blossom") -- 1500 agility
        end,
    },
} )

-- Enhanced Survival Cooldowns
spec:RegisterAbilities( {    rapid_fire = {
        id = 3045,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        startsCombat = false,
        texture = 132208,
        
        toggle = "cooldowns",
        
        handler = function()
            applyBuff("rapid_fire") -- 40% haste, 40% focus regen
        end,
    },
    
    readiness = {
        id = 23989,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        talent = "readiness",
        startsCombat = false,
        texture = 132206,
        
        toggle = "cooldowns",
        
        handler = function()
            -- Reset all Hunter ability cooldowns
            setCooldown("explosive_shot", 0)
            setCooldown("black_arrow", 0)
            setCooldown("wyvern_sting", 0)
            setCooldown("intimidation", 0)
            setCooldown("deterrence", 0)
            setCooldown("rapid_fire", 0)
            setCooldown("explosive_trap", 0)
            setCooldown("ice_trap", 0)
            setCooldown("snake_trap", 0)
        end,
    },
    
    -- Enhanced Camouflage
    camouflage = {
        id = 51753,
        cast = 0,
        cooldown = function() return talent.improved_camouflage.enabled and 45 or 60 end,
        gcd = "off",
        
        startsCombat = false,
        texture = 461113,
        
        toggle = "defensives",
        
        handler = function()
            applyBuff("camouflage")
            if talent.improved_camouflage.enabled then
                -- Provides movement speed and longer duration
                applyBuff("camouflage_enhanced")
            end
        end,
    },
} )

-- State expressions specific to Survival Hunter gameplay
spec:RegisterStateExpr( "lock_and_load_ready", function()
    return buff.lock_and_load.up
end )

spec:RegisterStateExpr( "explosive_shot_ticking", function()
    return debuff.explosive_shot.up
end )

spec:RegisterStateExpr( "black_arrow_ticking", function()
    return debuff.black_arrow.up
end )

spec:RegisterStateExpr( "trap_ready", function()
    return not cooldown.explosive_trap.up and not cooldown.ice_trap.up
end )

spec:RegisterStateExpr( "in_melee_range", function()
    return target.distance <= 5
end )

spec:RegisterStateExpr( "focus_regen_rate", function()
    local base_regen = 4 -- Base focus per second
    local haste_mod = 1 + (stat.haste / 100)
    local aspect_mod = buff.aspect_of_the_hawk.up and 1.15 or 1
    local rapid_fire_mod = buff.rapid_fire.up and 1.4 or 1
    
    return base_regen * haste_mod * aspect_mod * rapid_fire_mod
end )

spec:RegisterStateExpr( "time_to_max_focus", function()
    if focus.current >= focus.max then return 0 end
    return (focus.max - focus.current) / focus_regen_rate
end )

spec:RegisterStateExpr( "explosive_shot_targets", function()
    -- Explosive Shot can hit multiple targets with proper positioning
    return active_enemies
end )

spec:RegisterStateExpr( "serpent_sting_refreshable", function()
    return debuff.serpent_sting.refreshable or debuff.serpent_sting.remains < 5
end )

spec:RegisterStateExpr( "survival_mastery_bonus", function()
    -- Essence of the Viper mastery increases damage of DoTs and debuffs
    return 1 + (mastery.essence_of_the_viper.value / 100)
end )

-- Advanced Survival state expressions
spec:RegisterStateExpr( "optimal_explosive_shot_timing", function()
    -- Check if we should delay Explosive Shot for Lock and Load
    if cooldown.explosive_shot.up then
        return false
    end
    
    -- Don't use if Lock and Load is about to proc and we're low on focus
    if buff.steady_aim.up and focus.current < 60 then
        return false
    end
    
    return true
end )

spec:RegisterStateExpr( "black_arrow_value", function()
    -- Higher value on fresh targets or when enhanced by tier bonuses
    local base_value = 1
    
    if set_bonus.tier15_2pc > 0 then
        base_value = base_value + 0.25 -- Also applies Serpent Sting
    end
    
    if not debuff.black_arrow.up then
        base_value = base_value + 0.5 -- Fresh application
    end
    
    return base_value
end )

spec:RegisterStateExpr( "trap_usage_priority", function()
    -- Determine which trap to use based on situation
    if target.is_boss then
        return "explosive_trap" -- Max DPS
    elseif active_enemies > 1 then
        return "explosive_trap" -- AoE damage
    else
        return "ice_trap" -- Utility/control
    end
end )

-- Pet state expressions
spec:RegisterStateExpr( "pet_focus_available", function()
    return pet.alive and pet.focus.current >= 25
end )

spec:RegisterStateExpr( "pet_special_ready", function()
    return pet.alive and not pet.special_ability.cooldown.up
end )

-- Survival mastery calculations
spec:RegisterStateExpr( "mastery_multiplier", function()
    -- MoP Survival mastery: Essence of the Viper
    return 1 + (stat.mastery_rating * 2.25 / 100 / 100)
end )
