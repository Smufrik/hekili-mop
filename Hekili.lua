-- Hekili.lua
-- April 2014

local addon, ns = ...
local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata
Hekili = LibStub("AceAddon-3.0"):NewAddon( "Hekili", "AceConsole-3.0", "AceSerializer-3.0" )
Hekili.Version = GetAddOnMetadata( "Hekili", "Version" )
Hekili.Flavor = GetAddOnMetadata( "Hekili", "X-Flavor" ) or "Retail"

local format = string.format
local insert, concat = table.insert, table.concat

if Hekili.Version == ( "@" .. "project-version" .. "@" ) then
    Hekili.Version = format( "Dev-%s (%s)", GetBuildInfo(), date( "%Y%m%d" ) )
end

Hekili.AllowSimCImports = true

Hekili.IsRetail = function()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and select(4, GetBuildInfo()) >= 80000
end

Hekili.IsWrath = function()
    return WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC or
        (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and select(4, GetBuildInfo()) >= 30000 and select(4, GetBuildInfo()) < 40000)
end

Hekili.IsCataclysm = function()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and select(4, GetBuildInfo()) >= 40000 and select(4, GetBuildInfo()) < 50000
end

Hekili.IsMists = function()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and select(4, GetBuildInfo()) >= 50000 and select(4, GetBuildInfo()) < 60000
end

Hekili.IsClassic = function()
    return Hekili.IsWrath() or Hekili.IsCataclysm() or Hekili.IsMists()
end

Hekili.IsDragonflight = function()
    return select( 4, GetBuildInfo() ) >= 100000
end

ns.PTR = false


ns.Patrons = "Abom, Abra, Abuna, Aern, Aggronaught, akh270, Alasha, alcaras, Amera, ApexPlatypus, aphoenix, Archxlock, Aristocles, aro725, Artoo, Ash, av8ordoc, Battle Hermit VIA, Belatar, Borelia, Brangeddon, Bsirk/Kris, Cele, Chimmi, Coan, Cortland, Daz, DB, Der Baron, Dez, Drako, Enemy, Eryx, fuon, Garumako, Graemec, Grayscale, guhbjs, Hambrick, Hexel, Himea, Hollaputt, Hungrypilot, Ifor, Ingrathis, intheyear, Jacii, jawj, Jenkz, Katurn, Kingreboot, Kittykiller, Lagertha, Leorus, Loraniden, Lord Corn, Lovien, Manni, Mirando, mr. jing0, Mr_Hunter, MrBean73, mrminus, Muffin, Mumrikk, Nelix, neurolawl, Nighteyez, nomiss, nqrse, Orcodamus, Parameshvar, Rage, Ramen, Ramirez (Jon), Rebdull, Ridikulus0510, rockschtar, Roodie, Rusah, Samuraiwillz501, sarrge, Sarthol, Scerick, Sebstar, Seniroth, seriallos, Shakeykev, Shuck, Skeletor, Slem, Smufrik,Spaten, Spy, Srata, Stevi, Strozzy, Tekfire, Tevka, Theda99, Thordros, Tic[Ã ]sentence, Tobi, todd, Torsti, tsukari, Tyazrael, Ulti.DTY, Val (Valdrath), Vaxum, Vsmit, Wargus (Shagus), Weedwalker, WhoaIsJustin, Wonder, zab, Zarggg, and zarrin-zuljin"


do
    local cpuProfileDB = {}

    function Hekili:ProfileCPU( name, func )
        cpuProfileDB[ name ] = func
    end

	ns.cpuProfile = cpuProfileDB


	local frameProfileDB = {}

	function Hekili:ProfileFrame( name, f )
		frameProfileDB[ name ] = f
	end

	ns.frameProfile = frameProfileDB
end


ns.lib = {
    Format = {}
}


-- 04072017:  Let's go ahead and cache aura information to reduce overhead.
ns.auras = {
    target = {
        buff = {},
        debuff = {}
    },
    player = {
        buff = {},
        debuff = {}
    }
}

Hekili.Class = {
    specs = {},
    num = 0,

    file = "NONE",

	resources = {},
	resourceAuras = {},
    talents = {},
    pvptalents = {},
	auras = {},
	auraList = {},
    powers = {},
    glyphs = {},
	gear = {},
    setBonuses = {},

	knownAuraAttributes = {},

    stateExprs = {},
    stateFuncs = {},
    stateTables = {},

	abilities = {},
	abilityByName = {},
    abilityList = {},
    itemList = {},
    itemMap = {},
    itemPack = {
        lists = {
            items = {}
        }
    },

    packs = {},

    pets = {},
    totems = {},

    potions = {},
    potionList = {},

	hooks = {},
    range = 8,
	settings = {},
    stances = {},
	toggles = {},
	variables = {},
}

Hekili.Scripts = {
    DB = {},
    Channels = {},
    PackInfo = {},
}

Hekili.State = {}

ns.hotkeys = {}
ns.keys = {}
ns.queue = {}
ns.targets = {}
ns.TTD = {}

ns.UI = {
    Displays = {},
    Buttons = {}
}

ns.debug = {}
ns.snapshots = {}


function Hekili:Query( ... )
	local output = ns

	for i = 1, select( '#', ... ) do
		output = output[ select( i, ... ) ]
    end

    return output
end


function Hekili:Run( ... )
	local n = select( "#", ... )
	local fn = select( n, ... )

	local func = ns

	for i = 1, fn - 1 do
		func = func[ select( i, ... ) ]
    end

    return func( select( fn, ... ) )
end


local debug = ns.debug
local active_debug
local current_display

local lastIndent = 0

function Hekili:SetupDebug( display )
    if not self.ActiveDebug then return end
    if not display then return end

    current_display = display

    debug[ current_display ] = debug[ current_display ] or {
        log = {},
        index = 1
    }
    active_debug = debug[ current_display ]
	active_debug.index = 1

	lastIndent = 0

	local pack = self.State.system.packName

    if not pack then return end

	self:Debug( "New Recommendations for [ %s ] requested at %s ( %.2f ); using %s( %s ) priority.", display, date( "%H:%M:%S"), GetTime(), self.DB.profile.packs[ pack ].builtIn and "built-in " or "", pack )
end


function Hekili:Debug( ... )
    if not self.ActiveDebug then return end
	if not active_debug then return end

	local indent, text = ...
	local start

	if type( indent ) ~= "number" then
		indent = lastIndent
		text = ...
		start = 2
	else
		lastIndent = indent
		start = 3
	end

	local prepend = format( indent > 0 and ( "%" .. ( indent * 4 ) .. "s" ) or "%s", "" )
	text = text:gsub("\n", "\n" .. prepend )

	active_debug.log[ active_debug.index ] = format( "%" .. ( indent > 0 and ( 4 * indent ) or "" ) .. "s" .. text, "", select( start, ... ) )
    active_debug.index = active_debug.index + 1
end


local snapshots = ns.snapshots

function Hekili:SaveDebugSnapshot( dispName )
    local snapped = false
    local formatKey = ns.formatKey
    local state = Hekili.State

	for k, v in pairs( debug ) do
		if not dispName or dispName == k then
			for i = #v.log, v.index, -1 do
				v.log[ i ] = nil
			end

            -- Store aura data.
            local auraString = "\nplayer_buffs:"
            local now = GetTime()

            local class = Hekili.Class

            for i = 1, 40 do
                local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitBuff( "player", i )

                if not name then break end

                local aura = class.auras[ spellId ]
                local key = aura and aura.key
                if key and not state.auras.player.buff[ key ] then key = key .. " [MISSING]" end

                auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
            end

            auraString = auraString .. "\n\nplayer_debuffs:"

            for i = 1, 40 do
                local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitDebuff( "player", i )

                if not name then break end

                local aura = class.auras[ spellId ]
                local key = aura and aura.key
                if key and not state.auras.player.debuff[ key ] then key = key .. " [MISSING]" end

                auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
            end


            if not UnitExists( "target" ) then
                auraString = auraString .. "\n\ntarget_auras:  target does not exist"
            else
                auraString = auraString .. "\n\ntarget_buffs:"

                for i = 1, 40 do
                    local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitBuff( "target", i )

                    if not name then break end

                    local aura = class.auras[ spellId ]
                    local key = aura and aura.key
                    if key and not state.auras.target.buff[ key ] then key = key .. " [MISSING]" end

                    auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
                end

                auraString = auraString .. "\n\ntarget_debuffs:"

                for i = 1, 40 do
                    local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitDebuff( "target", i, "PLAYER" )

                    if not name then break end

                    local aura = class.auras[ spellId ]
                    local key = aura and aura.key
                    if key and not state.auras.target.debuff[ key ] then key = key .. " [MISSING]" end

                    auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
                end
            end

            auraString = auraString .. "\n\n"

            insert( v.log, 1, auraString )
            if Hekili.TargetDebug and Hekili.TargetDebug:len() > 0 then
                insert( v.log, 1, "targets:\n" .. Hekili.TargetDebug )
            end
            insert( v.log, 1, self:GenerateProfile() )

            local custom = ""

            local pack = self.DB.profile.packs[ state.system.packName ]
            if not pack.builtIn then
                custom = format( " |cFFFFA700(Custom: %s[%d])|r", state.spec.name, state.spec.id )
            end

            local overview = format( "%s%s; %s|r", state.system.packName, custom, dispName or "Unknown" )
            local recs = Hekili.DisplayPool[ dispName ].Recommendations

            for i, rec in ipairs( recs ) do
                if not rec.actionName then
                    if i == 1 then
                        overview = format( "%s - |cFF666666N/A|r", overview )
                    end
                    break
                end
                overview = format( "%s%s%s|cFFFFD100(%0.2f)|r", overview, ( i == 1 and " - " or ", " ), class.abilities[ rec.actionName ].name, rec.time )
            end

            insert( v.log, 1, overview )

            local snap = {
                header = "|cFFFFD100[" .. date( "%H:%M:%S" ) .. "]|r " .. overview,
                log = concat( v.log, "\n" ),
                data = ns.tableCopy( v.log ),
                recs = {}
            }

            insert( snapshots, snap )
            snapped = true
		end
    end

    if snapped then
        if Hekili.DB.profile.screenshot then Screenshot() end
        return true
    end

    return false
end

Hekili.Snapshots = ns.snapshots



ns.Tooltip = CreateFrame( "GameTooltip", "HekiliTooltip", UIParent, "GameTooltipTemplate" )
Hekili:ProfileFrame( "HekiliTooltip", ns.Tooltip )


-- Addon initialization
local f = CreateFrame( "Frame" )
f:RegisterEvent( "ADDON_LOADED" )
f:RegisterEvent( "PLAYER_ENTERING_WORLD" )

-- Function to determine whether to load specific expansion modules
function Hekili:DetermineExpansion()
    local toc = select(4, GetBuildInfo())
    
    if toc >= 50000 and toc < 60000 then
        self.Flavor = "Mists"
    elseif toc >= 40000 and toc < 50000 then
        self.Flavor = "Cataclysm"
    elseif toc >= 30000 and toc < 40000 then
        self.Flavor = "Wrath"
    else
        self.Flavor = "Unknown"
    end
    
    return self.Flavor
end
