-- Classes.lua
-- Updated May 28, 2025 - Modern Structure  
-- Mists of Pandaria module for Classes loading

local addon, ns = ...
local Hekili = _G[ addon ]
local class = Hekili.Class
local all = Hekili.Class.specs[0]

if Hekili.CurrentBuild < 50400 then return end



-- spellFilters[ instanceID ][ npcID ][ spellID ] = { name = ..., interrupt = true, ... }
-- For Mists of Pandaria specific dungeon and raid encounters
local spellFilters = {
    -- Mogu'shan Vaults
    [ 1008 ] = {
        name = "Mogu'shan Vaults",
        -- Stone Guard
        [ 60051 ] = {
            name = "Jade Guardian",
            [ 115840 ] = {
                interrupt = true,
            }, -- Cobalt Mine
        },
        [ 60043 ] = {
            name = "Amethyst Guardian",
            [ 115844 ] = {
                spell_reflection = true,
            }, -- Amethyst Pool
        },
        -- Feng the Accursed
        [ 60009 ] = {
            name = "Feng the Accursed",
            [ 116157 ] = {
                spell_reflection = true,
            }, -- Lightning Fists
            [ 116018 ] = {
                interrupt = true,
            }, -- Epicenter
        },
    },
    
    -- Heart of Fear
    [ 1009 ] = {
        name = "Heart of Fear",
        -- Imperial Vizier Zor'lok
        [ 62980 ] = {
            name = "Imperial Vizier Zor'lok",
            [ 122336 ] = {
                spell_reflection = true,
            }, -- Sonic Ring
        },
        -- Blade Lord Ta'yak
        [ 62543 ] = {
            name = "Blade Lord Ta'yak",
            [ 122949 ] = {
                interrupt = true,
            }, -- Unseen Strike
        },
    },
    
    -- Terrace of Endless Spring
    [ 996 ] = {
        name = "Terrace of Endless Spring",
        -- Protector Kaolan
        [ 60583 ] = {
            name = "Protector Kaolan",
            [ 117519 ] = {
                spell_reflection = true,
            }, -- Touch of Sha
        },
        -- Tsulong
        [ 62442 ] = {
            name = "Tsulong",
            [ 122752 ] = {
                interrupt = true,
            }, -- Shadow Breath
        },
    },
    
    -- Throne of Thunder
    [ 1098 ] = {
        name = "Throne of Thunder",
        -- Horridon
        [ 68476 ] = {
            name = "Horridon",
            [ 136740 ] = {
                spell_reflection = true,
            }, -- Double Swipe
        },
        -- Council of Elders
        [ 69078 ] = {
            name = "Frost King Malakk",
            [ 136992 ] = {
                interrupt = true,
            }, -- Frostbite
        },
    },
    
    -- Siege of Orgrimmar
    [ 1136 ] = {
        name = "Siege of Orgrimmar",
        -- Immerseus
        [ 71543 ] = {
            name = "Immerseus",
            [ 143436 ] = {
                spell_reflection = true,
            }, -- Corrosive Blast
        },
        -- Norushen
        [ 72276 ] = {
            name = "Manifestation of Corruption",
            [ 144639 ] = {
                interrupt = true,
            }, -- Corruption
        },
    },
    
    -- MoP Dungeons
    [ 962 ] = {
        name = "Gate of the Setting Sun",
        [ 56906 ] = {
            name = "Saboteur Kip'tilak",
            [ 107268 ] = {
                spell_reflection = true,
            }, -- Sabotage
        },
    },
    
    [ 994 ] = {
        name = "Mogu'shan Palace",
        [ 61444 ] = {
            name = "Ming the Cunning",
            [ 118312 ] = {
                interrupt = true,
            }, -- Magnetic Field
        },
    },
    
    [ 959 ] = {
        name = "Shado-Pan Monastery",
        [ 56541 ] = {
            name = "Master Snowdrift",
            [ 106434 ] = {
                spell_reflection = true,
            }, -- Tornado Kick
        },
    },
    
    [ 960 ] = {
        name = "Temple of the Jade Serpent",
        [ 56448 ] = {
            name = "Wise Mari",
            [ 106055 ] = {
                interrupt = true,
            }, -- Hydrolance
        },
    },
    
    [ 961 ] = {
        name = "Stormstout Brewery",
        [ 56637 ] = {
            name = "Ook-Ook",
            [ 106807 ] = {
                spell_reflection = true,
            }, -- Barrel Toss
        },
    },
    
    [ 1011 ] = {
        name = "Siege of Niuzao Temple",
        [ 61567 ] = {
            name = "General Pa'valak",
            [ 124255 ] = {
                interrupt = true,
            }, -- Blade Rush
        },
    },
}

class.spellFilters = spellFilters

do
    local interruptibleFilters = {}

    for zoneID, zoneData in pairs( spellFilters ) do
        for npcID, npcData in pairs( zoneData ) do
            if type(npcID) == "number" and type(npcData) == "table" then
                for spellID, spellData in pairs( npcData ) do
                    if type(spellID) == "number" and type(spellData) == "table" and spellData.interrupt then
                        interruptibleFilters[spellID] = true
                    end
                end
            end
        end
    end    class.interruptibleFilters = interruptibleFilters
end

-- Register Mists of Pandaria shared auras
all:RegisterAuras({
    -- Legendary Cloak Procs
    spirit_of_chi_ji = {
        id = 146198,
        duration = 10,
        max_stack = 1,
    },

    endurance_of_niuzao = {
        id = 146197,
        duration = 10,
        max_stack = 5,
    },

    essence_of_yulon = {
        id = 146199,
        duration = 10,
        max_stack = 10,
    },

    flurry_of_xuen = {
        id = 146200,
        duration = 10,
        max_stack = 10,
    },

    -- Bloodlust effects
    bloodlust = {
        id = 2825,
        duration = 40,
        max_stack = 1,
        shared = "player",
    },

    heroism = {
        id = 32182,
        duration = 40,
        max_stack = 1,
        shared = "player",
    },

    time_warp = {
        id = 80353,
        duration = 40,
        max_stack = 1,
        shared = "player",
    },

    ancient_hysteria = {
        id = 90355,
        duration = 40,
        max_stack = 1,
        shared = "player",
    },

    -- Exhaustion effects
    exhaustion = {
        id = 57723,
        duration = 600,
        max_stack = 1,
        shared = "player",
    },

    sated = {
        id = 57724,
        duration = 600,
        max_stack = 1,
        shared = "player",
    },

    temporal_displacement = {
        id = 80354,
        duration = 600,
        max_stack = 1,
        shared = "player",
    },

    insanity = {
        id = 95809,
        duration = 600,
        max_stack = 1,
        shared = "player",
    },

    -- Tier Set Bonuses
    -- T14 - MSV, HoF, ToES
    tier14_2pc_agility = {
        id = 123157,
        duration = 15,
        max_stack = 1,
    },
    
    tier14_2pc_strength = {
        id = 123154,
        duration = 15,
        max_stack = 1,
    },
    
    tier14_2pc_intellect = {
        id = 123156,
        duration = 15,
        max_stack = 1,
    },

    -- T15 - ToT
    tier15_2pc_agility = {
        id = 138216,
        duration = 15,
        max_stack = 3,
    },
    
    tier15_2pc_strength = {
        id = 138217,
        duration = 15,
        max_stack = 3,
    },
    
    tier15_2pc_intellect = {
        id = 138218,
        duration = 15,
        max_stack = 3,
    },

    -- T16 - SoO
    tier16_2pc_agility = {
        id = 144654,
        duration = 10,
        max_stack = 1,
    },
    
    tier16_2pc_strength = {
        id = 144653,
        duration = 10,
        max_stack = 1,
    },
    
    tier16_2pc_intellect = {
        id = 144865,
        duration = 10,
        max_stack = 1,
    },

    -- Trinket Procs
    vicious_talisman_of_the_shado_pan_assault = {
        id = 138699,
        duration = 20,
        max_stack = 1,
    },
    
    renatakis_soul_charm = {
        id = 138729,
        duration = 20,
        max_stack = 1,
    },
    
    restless_spirit = {
        id = 138728,
        duration = 10,
        max_stack = 1,
    },
    
    breath_of_hydra = {
        id = 138963,
        duration = 10,
        max_stack = 1,
    },
    
    wushoolays_final_choice = {
        id = 138703,
        duration = 15,
        max_stack = 1,
    },
    
    feather_of_ji_kun = {
        id = 138759,
        duration = 10,
        max_stack = 1,
    },
    
    rune_of_reorigination = {
        id = 139120,
        duration = 10,
        max_stack = 1,
    },
    
    -- SoO Trinkets
    amplification = {
        id = 146046,
        duration = 20,
        max_stack = 1,
    },
    
    cleave = {
        id = 146048,
        duration = 20,
        max_stack = 1,
    },
    
    multistrike = {
        id = 146051,
        duration = 20,
        max_stack = 1,
    },
    
    readiness = {
        id = 146047,
        duration = 20,
        max_stack = 1,
    },
})


