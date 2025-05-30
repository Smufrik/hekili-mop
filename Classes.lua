-- Classes.lua
-- July 2014

local addon, ns = ...
local Hekili = _G[ addon ]

local class = Hekili.Class
local state = Hekili.State


local CommitKey = ns.commitKey
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local GetItemInfo = ns.CachedGetItemInfo
local GetResourceInfo, GetResourceKey = ns.GetResourceInfo, ns.GetResourceKey
local RegisterEvent = ns.RegisterEvent
local RegisterUnitEvent = ns.RegisterUnitEvent

local formatKey = ns.formatKey
local getSpecializationKey = ns.getSpecializationKey
local tableCopy = ns.tableCopy

local strformat = string.format
local insert, wipe = table.insert, table.wipe

local mt_resource = ns.metatables.mt_resource

local GetItemCooldown = _G.C_Container.GetItemCooldown

local GetPlayerAuraBySpellID = _G.GetPlayerAuraBySpellID or function( id ) return FindUnitBuffByID( "player", id ) end

local GetSpellDescription, GetSpellTexture = _G.GetSpellDescription, _G.GetSpellTexture

local GetSpecialization = _G.GetSpecialization or function() return GetActiveTalentGroup() end
local GetSpecializationInfo = _G.GetSpecializationInfo or function()
    local name, baseName, id = UnitClass( "player" )
    return id, baseName, name
end

local Casting = _G.SPELL_CASTING or "Casting"


local specTemplate = {
    enabled = true,

    potion = "prolonged_power",

    aoe = 2,
    cycle = false,
    cycle_min = 6,
    gcdSync = true,
    enhancedRecheck = false,

    buffPadding = 0,
    debuffPadding = 0,

    nameplates = true,
    nameplateRange = 8,

    petbased = false,

    damage = true,
    damageExpiration = 8,
    damageDots = false,
    damageRange = 0,
    damagePets = false,

    throttleRefresh = false,
    regularRefresh = 0.5,
    combatRefresh = 0.1,

    throttleTime = false,
    maxTime = 10,

    -- Toggles
    custom1Name = "Custom 1",
    custom2Name = "Custom 2",
    noFeignedCooldown = false,

    abilities = {
        ['**'] = {
            disabled = false,
            toggle = "default",
            clash = 0,
            targetMin = 0,
            targetMax = 0,
            boss = false
        }
    },
    items = {
        ['**'] = {
            disabled = false,
            toggle = "default",
            clash = 0,
            targetMin = 0,
            targetMax = 0,
            boss = false,
            criteria = nil
        }
    },
    settings = {},
    cooldowns = {},
    utility = {},
    defensives = {},
    custom1 = {},
    custom2 = {},

    autoPacks = {},
}
ns.specTemplate = specTemplate -- for options.


local function Aura_DetectSharedAura( t, type )
    if not t then return end
    local finder = type == "debuff" and FindUnitDebuffByID or FindUnitBuffByID
    local aura = class.auras[ t.key ]

    local name, _, count, _, duration, expirationTime, caster = finder( aura.shared, aura.multi or aura.id )

    if name then
        t.count = count > 0 and count or 1

        if expirationTime > 0 then
            t.applied = expirationTime - duration
            t.expires = expirationTime
        else
            t.applied = state.query_time
            t.expires = state.query_time + t.duration
        end
        t.caster = caster
        return
    end

    t.count = 0
    t.applied = 0
    t.expires = 0
    t.caster = "nobody"
end


local protectedFunctions = {
    -- Channels.
    start = true,
    tick = true,
    finish = true,

    -- Casts
    handler = true, -- Cast finish.
    impact = true,  -- Projectile impact.
}


local HekiliSpecMixin = {
    RegisterResource = function( self, resourceID, regen, model, meta )
        local resource = GetResourceKey( resourceID )

        if not resource then
            Hekili:Error( "Unable to identify resource with PowerType " .. resourceID .. "." )
            return
        end

        local r = self.resources[ resource ] or {}

        r.resource = resource
        r.type = resourceID
        r.state = model or setmetatable( {
            resource = resource,
            type = resourceID,

            forecast = {},
            fcount = 0,
            times = {},
            values = {},

            active_regen = 0,
            inactive_regen = 0,
            last_tick = 0,

            swingGen = false,

            add = function( amt, overcap )
                -- Bypasses forecast, useful in hooks.
                if overcap then r.state.amount = r.state.amount + amt
                else r.state.amount = max( 0, min( r.state.amount + amt, r.state.max ) ) end
            end,

            timeTo = function( x )
                return state:TimeToResource( r.state, x )
            end,
        }, mt_resource )
        r.state.regenModel = regen
        r.state.meta = meta or {}

        for _, func in pairs( r.state.meta ) do
            setfenv( func, state )
        end

        if model and not model.timeTo then
            model.timeTo = function( x )
                return state:TimeToResource( r.state, x )
            end
        end

        if r.state.regenModel then
            for _, v in pairs( r.state.regenModel ) do
                v.resource = v.resource or resource
                self.resourceAuras[ v.resource ] = self.resourceAuras[ v.resource ] or {}

                if v.aura then
                    self.resourceAuras[ v.resource ][ v.aura ] = true
                end

                if v.channel then
                    self.resourceAuras[ v.resource ].casting = true
                end

                if v.swing then
                    r.state.swingGen = true
                end
            end
        end

        self.primaryResource = self.primaryResource or resource
        self.resources[ resource ] = r

        CommitKey( resource )
    end,

    RegisterTalents = function( self, talents )
        for talent, id in pairs( talents ) do
            self.talents[ talent ] = id
            CommitKey( talent )
        end
    end,

    RegisterPvpTalents = function( self, pvp )
        for talent, spell in pairs( pvp ) do
            self.pvptalents[ talent ] = spell
            CommitKey( talent )
        end
    end,

    RegisterAura = function( self, aura, data )
        CommitKey( aura )

        local a = setmetatable( {
            funcs = {}
        }, {
            __index = function( t, k )
                if t.funcs[ k ] then return t.funcs[ k ]() end

                local setup = rawget( t, "onLoad" )
                if setup then
                    t.onLoad = nil
                    setup( t )

                    return t[ k ]
                end
            end
        } )

        a.key = aura

        if not data.id then
            self.pseudoAuras = self.pseudoAuras + 1
            data.id = ( -1000 * self.id ) - self.pseudoAuras
        end

        -- default values.
        data.duration  = data.duration or 30
        data.max_stack = data.max_stack or 1

        -- This is a shared buff that can come from anyone, give it a special generator.
        --[[ if data.shared then
            a.generate = Aura_DetectSharedAura
        end ]]

        for element, value in pairs( data ) do
            if type( value ) == 'function' then
                setfenv( value, state )
                if element ~= 'generate' then a.funcs[ element ] = value
                else a[ element ] = value end
            else
                a[ element ] = value
            end

            class.knownAuraAttributes[ element ] = true
        end

        self.auras[ aura ] = a

        if a.id then
            if a.id > 0 then
                -- Hekili:ContinueOnSpellLoad( a.id, function( success )
                a.onLoad = function( a )
                    a.name = GetSpellInfo( a.id )

                    if not a.name then
                        for k, v in pairs( class.auraList ) do
                            if v == a then class.auraList[ k ] = nil end
                        end

                        Hekili.InvalidSpellIDs = Hekili.InvalidSpellIDs or {}
                        Hekili.InvalidSpellIDs[ a.id ] = a.name or a.key

                        a.id = a.key
                        a.name = a.name or a.key

                        return
                    end

                    a.desc = GetSpellDescription( a.id )

                    local texture = a.texture or GetSpellTexture( a.id )

                    if self.id > 0 then
                        class.auraList[ a.key ] = "|T" .. texture .. ":0|t " .. a.name
                    end

                    self.auras[ a.name ] = a
                    if GetSpecializationInfo( GetSpecialization() or 0 ) == self.id then
                        -- Copy to class table as well.
                        class.auras[ a.name ] = a
                    end

                    if self.pendingItemSpells[ a.name ] then
                        local items = self.pendingItemSpells[ a.name ]

                        if type( items ) == 'table' then
                            for i, item in ipairs( items ) do
                                local ability = self.abilities[ item ]
                                ability.itemSpellKey = a.key .. "_" .. ability.itemSpellID

                                self.abilities[ ability.itemSpellKey ] = a
                                class.abilities[ ability.itemSpellKey ] = a
                            end
                        else
                            local ability = self.abilities[ items ]
                            ability.itemSpellKey = a.key .. "_" .. ability.itemSpellID

                            self.abilities[ ability.itemSpellKey ] = a
                            class.abilities[ ability.itemSpellKey ] = a
                        end

                        self.pendingItemSpells[ a.name ] = nil
                        self.itemPended = nil
                    end
                end
            end
            self.auras[ a.id ] = a
        end

        if data.meta then
            for k, v in pairs( data.meta ) do
                if type( v ) == 'function' then data.meta[ k ] = setfenv( v, state ) end
                class.knownAuraAttributes[ k ] = true
            end
        end

        if type( data.copy ) == 'string' then
            self.auras[ data.copy ] = a
        elseif type( data.copy ) == 'table' then
            a.multi = {}
            if a.id and a.id > 0 then a.multi[ a.id ] = 1 end
            for _, key in ipairs( data.copy ) do
                self.auras[ key ] = a
                if type( key ) == "number" then a.multi[ key ] = 1 end
            end
        end
    end,

    RegisterAuras = function( self, auras )
        for aura, data in pairs( auras ) do
            self:RegisterAura( aura, data )
        end
    end,


    RegisterPower = function( self, power, id, aura )
        self.powers[ power ] = id
        CommitKey( power )

        if aura and type( aura ) == "table" then
            self:RegisterAura( power, aura )
        end
    end,

    RegisterPowers = function( self, powers )
        for k, v in pairs( powers ) do
            self.powers[ k ] = v.id
            self.powers[ v.id ] = k

            for token, ids in pairs( v.triggers ) do
                if not self.auras[ token ] then
                    self:RegisterAura( token, {
                        id = v.id,
                        copy = ids
                    } )
                end
            end
        end
    end,

    RegisterStateExpr = function( self, key, func )
        setfenv( func, state )
        self.stateExprs[ key ] = func
        class.stateExprs[ key ] = func
        CommitKey( key )
    end,

    RegisterStateFunction = function( self, key, func )
        setfenv( func, state )
        self.stateFuncs[ key ] = func
        class.stateFuncs[ key ] = func
        CommitKey( key )
    end,

    RegisterStateTable = function( self, key, data )
        for _, f in pairs( data ) do
            if type( f ) == 'function' then
                setfenv( f, state )
            end
        end

        local meta = getmetatable( data )

        if meta and meta.__index then
            setfenv( meta.__index, state )
        end

        self.stateTables[ key ] = data
        class.stateTables[ key ] = data
        CommitKey( key )
    end,

    RegisterGear = function( self, key, ... )
        local n = select( "#", ... )

        local gear = self.gear[ key ] or {}

        for i = 1, n do
            local item = select( i, ... )
            table.insert( gear, item )
            gear[ item ] = true
        end

        self.gear[ key ] = gear
        CommitKey( key )
    end,

    -- Check for the set bonus based on hidden aura instead of counting the number of equipped items.
    -- This may be useful for tier set items that are crafted so their item ID doesn't match.
    -- The alternative is *probably* to treat sets based on bonusIDs.
    RegisterSetBonus = function( self, key, spellID )
        self.setBonuses[ key ] = spellID
        CommitKey( key )
    end,

    RegisterSetBonuses = function( self, ... )
        local n = select( "#", ... )

        for i = 1, n, 2 do
            self:RegisterSetBonus( select( i, ... ) )
        end
    end,

    RegisterPotion = function( self, potion, data )
        self.potions[ potion ] = data

        data.key = potion

        if data.copy then
            if type( data.copy ) == "table" then
                for _, key in ipairs( data.copy ) do
                    self.potions[ key ] = data
                    CommitKey( key )
                end
            else
                self.potions[ data.copy ] = data
                CommitKey( data.copy )
            end
        end

        local potionItem = Item:CreateFromItemID( data.item )

        if not potionItem:IsItemEmpty() then
            potionItem:ContinueOnItemLoad( function()
                if not data.name then data.name = potionItem:GetItemName() end
                if not data.link then data.link = potionItem:GetItemLink() end
                

                class.potionList[ potion ] = data.link
                return true
            end )

        end

        if data.buff and data.aura then
            self:RegisterAura( data.buff, data.aura )
        end

        CommitKey( potion )
    end,

    RegisterPotions = function( self, potions )
        for k, v in pairs( potions ) do
            self:RegisterPotion( k, v )
        end
    end,

    SetPotion = function( self, potion )
        -- if not class.potions[ potion ] then return end
        self.potion = potion
    end,

    RegisterRecheck = function( self, func )
        self.recheck = func
    end,

    RegisterHook = function( self, hook, func, noState )
        if not ( noState == true or hook == "COMBAT_LOG_EVENT_UNFILTERED" and noState == nil ) then
            func = setfenv( func, state )
        end
        self.hooks[ hook ] = self.hooks[ hook ] or {}
        insert( self.hooks[ hook ], func )
    end,

    RegisterAbility = function( self, ability, data )
        CommitKey( ability )

        local a = setmetatable( {
            funcs = {},
        }, {
            __index = function( t, k )
                local setup = rawget( t, "onLoad" )
                if setup then
                    t.onLoad = nil
                    setup( t )
                    return t[ k ]
                end

                if t.funcs[ k ] then return t.funcs[ k ]() end
                if k == "lastCast" then return state.history.casts[ t.key ] or t.realCast end
                if k == "lastUnit" then return state.history.units[ t.key ] or t.realUnit end
            end,
        } )

        a.key = ability
        a.from = self.id
        
        local item = data.item
        if item and type( item ) == 'function' then
            setfenv( item, state )
            item = item()
        end
        
        if not data.id then
            if data.item or data.isItem then
                self.itemAbilities = self.itemAbilities + 1
                data.id = -100 - self.itemAbilities
            else
                self.pseudoAbilities = self.pseudoAbilities + 1
                data.id = -1000 * self.id - self.pseudoAbilities
            end
        end

        if data.meta then
            for k, v in pairs( data.meta ) do
                if type( v ) == 'function' then data.meta[ k ] = setfenv( v, state ) end
            end
        end

        -- default values.
        if not data.cooldown then data.cooldown = 0 end
        if not data.recharge then data.recharge = data.cooldown end
        if not data.charges  then data.charges = 1 end

        if data.hasteCD then
            if type( data.cooldown ) == "number" and data.cooldown > 0 then data.cooldown = Hekili:Loadstring( "return " .. data.cooldown .. " * haste" ) end
            if type( data.recharge ) == "number" and data.recharge > 0 then data.recharge = Hekili:Loadstring( "return " .. data.recharge .. " * haste" ) end
        end

        if not data.fixedCast and type( data.cast ) == "number" then
            data.cast = Hekili:Loadstring( "return " .. data.cast .. " * haste" )
        end

        if data.toggle == "interrupts" and data.gcd == "off" and data.readyTime == state.timeToInterrupt and data.interrupt == nil then
            data.interrupt = true
        end

        for key, value in pairs( data ) do
            if type( value ) == 'function' then
                setfenv( value, state )

                if not protectedFunctions[ key ] then a.funcs[ key ] = value
                else a[ key ] = value end
                data[ key ] = nil
            else
                a[ key ] = value
            end
        end

        if ( a.velocity or a.flightTime ) and a.impact then
            a.isProjectile = true
        end

        a.realCast = 0

        if a.isItem or item and a.id < 0 then
            --[[ local name, link, _, _, _, _, _, _, _, texture = GetItemInfo( item )

            a.name = name or ability
            a.link = link or ability ]]

            if a.key == "best_mana_potion" then
                if ability then class.abilities[ ability ] = a end
                if a.name  then class.abilities[ a.name ]  = a end
                if a.link  then class.abilities[ a.link ]  = a end
                if a.id    then class.abilities[ a.id ]    = a end

                Hekili.OptionsReady = false

                if not a.unlisted then
                    class.abilityList[ ability ] = "|T" .. ( a.texture or texture ) .. ":0|t " .. a.link
                    class.itemList[ a.id ] = "|T" .. a.texture .. ":0|t " .. a.link

                    class.abilityByName[ a.name ] = a
                end
            else
                class.itemMap[ item ] = ability

                -- Register the item if it doesn't already exist.
                class.specs[0]:RegisterGear( ability, item )

                local actionItem = Item:CreateFromItemID( item )
                if not actionItem:IsItemEmpty() then
                    local itempcall = function()
                        actionItem:ContinueOnItemLoad( function( success )
                            --[[if not success then
                                Hekili:Error( "Unable to load " .. item .. " (" .. ability .. ")." )

                                -- Assume the item is not presently in-game.
                                for key, entry in pairs( class.abilities ) do
                                    if a == entry then
                                        class.abilities[ key ] = nil
                                        class.abilityList[ key ] = nil
                                        class.abilityByName[ key ] = nil
                                        class.itemList[ key ] = nil

                                        self.abilities[ key ] = nil
                                    end
                                end

                                return
                            end]]

                            local name = a.name or actionItem:GetItemName()
                            local link = a.link or actionItem:GetItemLink()
                            local texture = a.texture or actionItem:GetItemIcon()

                            if name then
                                if not a.name or a.name == a.key then a.name = name end
                                if not a.link or a.link == a.key then a.link = link end
                                a.texture = a.texture or texture

                                if a.suffix then
                                    a.actualName = name
                                    a.name = a.name .. " " .. a.suffix
                                end

                                self.abilities[ ability ] = self.abilities[ ability ] or a
                                self.abilities[ a.name ] = self.abilities[ a.name ] or a
                                self.abilities[ a.link ] = self.abilities[ a.link ] or a
                                self.abilities[ data.id ] = self.abilities[ a.link ] or a

                                a.itemLoaded = GetTime()

                                if a.item and a.item ~= 158075 then
                                    a.itemSpellName, a.itemSpellID = GetItemSpell( a.item )

                                    if a.itemSpellID then
                                        a.itemSpellKey = a.key .. "_" .. a.itemSpellID
                                        self.abilities[ a.itemSpellKey ] = a
                                        class.abilities[ a.itemSpellKey ] = a
                                    end

                                    if a.itemSpellName then
                                        local itemAura = self.auras[ a.itemSpellName ]

                                        if itemAura then
                                            a.itemSpellKey = itemAura.key .. "_" .. a.itemSpellID
                                            self.abilities[ a.itemSpellKey ] = a
                                            class.abilities[ a.itemSpellKey ] = a

                                        else
                                            if self.pendingItemSpells[ a.itemSpellName ] then
                                                if type( self.pendingItemSpells[ a.itemSpellName ] ) == 'table' then
                                                    table.insert( self.pendingItemSpells[ a.itemSpellName ], ability )
                                                else
                                                    local first = self.pendingItemSpells[ a.itemSpellName ]
                                                    self.pendingItemSpells[ a.itemSpellName ] = {
                                                        first,
                                                        ability
                                                    }
                                                end
                                            else
                                                self.pendingItemSpells[ a.itemSpellName ] = ability
                                                a.itemPended = GetTime()
                                            end
                                        end
                                    end
                                end

                                if not a.unlisted then
                                    class.abilityList[ ability ] = "|T" .. ( a.texture or texture ) .. ":0|t " .. link
                                    class.itemList[ item ] = "|T" .. a.texture .. ":0|t " .. link

                                    class.abilityByName[ a.name ] = a
                                end

                                if data.copy then
                                    if type( data.copy ) == 'string' or type( data.copy ) == 'number' then
                                        self.abilities[ data.copy ] = a
                                    elseif type( data.copy ) == 'table' then
                                        for _, key in ipairs( data.copy ) do
                                            self.abilities[ key ] = a
                                        end
                                    end
                                end

                                if data.items then
                                    local addedToItemList = false

                                    for _, id in ipairs( data.items ) do
                                        local copyItem = Item:CreateFromItemID( id )

                                        if not copyItem:IsItemEmpty() then
                                            copyItem:ContinueOnItemLoad( function()
                                                local name = copyItem:GetItemName()
                                                local link = copyItem:GetItemLink()
                                                local texture = copyItem:GetItemIcon()

                                                if name then
                                                    class.abilities[ name ] = a
                                                    self.abilities[ name ]  = a

                                                    if not class.itemList[ id ] then
                                                        class.itemList[ id ] = "|T" .. ( a.texture or texture ) .. ":0|t " .. link
                                                        addedToItemList = true
                                                    end
                                                end
                                            end )
                                        end
                                    end

                                    if addedToItemList then
                                        if ns.ReadKeybindings then ns.ReadKeybindings() end
                                    end
                                end

                                if ability then class.abilities[ ability ] = a end
                                if a.name  then class.abilities[ a.name ]  = a end
                                if a.link  then class.abilities[ a.link ]  = a end
                                if a.id    then class.abilities[ a.id ]    = a end

                                Hekili.OptionsReady = false

                                return true
                            end

                            return false
                        end )
                    end
                    local status, message = pcall(itempcall)
                    --[[ if not status then
                        Hekili:Error( "Unable to load " .. item .. " (" .. ability .. ")." )
                    end ]]
                end
            end
            
        end

        if a.id and a.id > 0 then
            -- Hekili:ContinueOnSpellLoad( a.id, function( success )
            a.onLoad = function()
                a.name = GetSpellInfo( a.id )

                if not a.name then
                    for k, v in pairs( class.abilityList ) do
                        if v == a then class.abilityList[ k ] = nil end
                    end
                    Hekili.InvalidSpellIDs = Hekili.InvalidSpellIDs or {}
                    table.insert( Hekili.InvalidSpellIDs, a.id )
                    Hekili:Error( "Name info not available for " .. a.id .. " / " .. a.key .. "." )
                    return
                end

                a.desc = GetSpellDescription( a.id ) -- was returning raw tooltip data.

                if a.suffix then
                    a.actualName = a.name
                    a.name = a.name .. " " .. a.suffix
                end

                local texture = a.texture or GetSpellTexture( a.id )

                self.abilities[ a.name ] = self.abilities[ a.name ] or a
                class.abilities[ a.name ] = class.abilities[ a.name ] or a

                if not a.unlisted then
                    class.abilityList[ ability ] = a.listName or ( "|T" .. texture .. ":0|t " .. a.name )
                    class.abilityByName[ a.name ] = class.abilities[ a.name ] or a
                end

                if a.rangeSpell and type( a.rangeSpell ) == "number" then
                    Hekili:ContinueOnSpellLoad( a.rangeSpell, function( success )
                        if success then
                            a.rangeSpell = GetSpellInfo( a.rangeSpell )
                        else
                            a.rangeSpell = nil
                        end
                    end )
                end

                Hekili.OptionsReady = false
            end
        end

        self.abilities[ ability ] = a
        self.abilities[ a.id ] = a

        if not a.unlisted then class.abilityList[ ability ] = class.abilityList[ ability ] or a.listName or a.name end

        if data.copy then
            if type( data.copy ) == 'string' or type( data.copy ) == 'number' then
                self.abilities[ data.copy ] = a
            elseif type( data.copy ) == 'table' then
                for _, key in ipairs( data.copy ) do
                    self.abilities[ key ] = a
                end
            end
        end

        if data.items then
            for _, itemID in ipairs( data.items ) do
                class.itemMap[ itemID ] = ability
            end
        end

        if a.dual_cast or a.funcs.dual_cast then
            self.can_dual_cast = true
            self.dual_cast[ a.key ] = true
        end

        if a.auras then
            self:RegisterAuras( a.auras )
        end
    end,

    RegisterAbilities = function( self, abilities )
        for ability, data in pairs( abilities ) do
            self:RegisterAbility( ability, data )
        end
    end,

    RegisterPack = function( self, name, version, import )
        self.packs[ name ] = {
            version = tonumber( version ),
            import = import:gsub("([^|])|([^|])", "%1||%2")
        }
    end,

    RegisterOptions = function( self, options )
        self.options = options
    end,

    RegisterEvent = function( self, event, func )
        RegisterEvent( event, function( ... )
            if state.spec.id == self.id then func( ... ) end
        end )
    end,

    RegisterUnitEvent = function( self, event, unit1, unit2, func )
        RegisterUnitEvent( event, unit1, unit2, function( ... )
            if state.spec.id == self.id then func( ... ) end
        end )
    end,

    RegisterCombatLogEvent = function( self, func )
        self:RegisterHook( "COMBAT_LOG_EVENT_UNFILTERED", func )
    end,

    RegisterCycle = function( self, func )
        self.cycle = setfenv( func, state )
    end,

    RegisterPet = function( self, token, id, spell, duration, ... )
        CommitKey( token )

        self.pets[ token ] = {
            id = type( id ) == 'function' and setfenv( id, state ) or id,
            token = token,
            spell = spell,
            duration = type( duration ) == 'function' and setfenv( duration, state ) or duration
        }

        local n = select( "#", ... )

        if n and n > 0 then
            for i = 1, n do
                local copy = select( i, ... )
                self.pets[ copy ] = self.pets[ token ]
            end
        end
    end,

    RegisterTotem = function( self, token, id )
        self.totems[ token ] = id
        self.totems[ id ] = token

        CommitKey( token )
    end,


    GetSetting = function( self, info )
        local setting = info[ #info ]
        return Hekili.DB.profile.specs[ self.id ].settings[ setting ]
    end,

    SetSetting = function( self, info, val )
        local setting = info[ #info ]
        Hekili.DB.profile.specs[ self.id ].settings[ setting ] = val
    end,

    -- option should be an AceOption table.
    RegisterSetting = function( self, key, value, option, isPackSelector )
        CommitKey( key )

        table.insert( self.settings, {
            name = key,
            default = value,
            info = option,
            isPackSelector = isPackSelector
        } )

        option.order = option.order or ( 100 + #self.settings )

        option.get = option.get or function( info )
            local setting = info[ #info ]
            local val = Hekili.DB.profile.specs[ self.id ].settings[ setting ]

            if val ~= nil then return val end
            return value
        end

        option.set = option.set or function( info, val )
            local setting = info[ #info ]
            Hekili.DB.profile.specs[ self.id ].settings[ setting ] = val
        end
    end,

    -- For faster variables.
    RegisterVariable = function( self, key, func )
        CommitKey( key )
        self.variables[ key ] = setfenv( func, state )
    end,

    RegisterPackSelector = function( self, key, package, name, description, condition )
        insert( self.packSelectors, {
            key = key,
            name = name,
            condition = setfenv( condition, state )
        } )

        self:RegisterSetting( key, package, {
            type = "select",
            name = name,
            desc = description .. "\n\nIf set to (inactive), your active priority will not change.",
            order = #self.packSelectors,
            width = "full",
            values = function()
                local values = {
                    none = "(inactive)"
                }

                for pname, pkg in pairs( Hekili.DB.profile.packs ) do
                    local fancyName = pkg.builtIn and "|cFF00B4FF" .. pname .. "|r" or pname
                    if pkg.spec == self.id then
                        values[ pname ] = fancyName
                    end
                end

                return values
            end,
            set = function( info, val )
                Hekili.DB.profile.specs[ self.id ].autoPacks[ key ] = val
            end,
            get = function( info )
                return Hekili.DB.profile.specs[ self.id ].autoPacks[ key ] or "none"
            end
        }, true )
    end,
}
ns.HekiliSpecMixin = HekiliSpecMixin


function Hekili:RestoreDefaults()
    local p = self.DB.profile
    local changed = {}

    for k, v in pairs( class.packs ) do
        local existing = rawget( p.packs, k )

        if not existing or not existing.version or existing.version < v.version then
            local data = self:DeserializeActionPack( v.import )

            if data and type( data ) == 'table' then
                p.packs[ k ] = data.payload
                data.payload.version = v.version
                data.payload.date = v.version
                data.payload.builtIn = true
                insert( changed, k )

                local specID = data.payload.spec

                if specID then
                    local spec = rawget( p.specs, specID )
                    if spec then
                        if spec.package then
                            local currPack = p.packs[ spec.package ]
                            if not currPack or currPack.spec ~= specID then
                                spec.package = k
                            end
                        else
                            spec.package = k
                        end
                    end
                end
            end
        end
    end

    if #changed > 0 then
        self:LoadScripts()
        -- self:RefreshOptions()

        local msg

        if #changed == 1 then
            msg = "The |cFFFFD100" .. changed[1] .. "|r priority was updated."
        elseif #changed == 2 then
            msg = "The |cFFFFD100" .. changed[1] .. "|r and |cFFFFD100" .. changed[2] .. "|r priorities were updated."
        else
            msg = "|cFFFFD100" .. changed[1] .. "|r"

            for i = 2, #changed - 1 do
                msg = msg .. ", |cFFFFD100" .. changed[i] .. "|r"
            end

            msg = "The " .. msg .. ", and |cFFFFD100" .. changed[ #changed ] .. "|r priorities were updated."
        end

        if msg then C_Timer.After( 5, function()
            if Hekili.DB.profile.notifications.enabled then Hekili:Notify( msg, 6 ) end
            Hekili:Print( msg )
        end ) end
    end
end


function Hekili:RestoreDefault( name )
    local p = self.DB.profile

    local default = class.packs[ name ]

    if default then
        local data = self:DeserializeActionPack( default.import )

        if data and type( data ) == 'table' then
            p.packs[ name ] = data.payload
            data.payload.version = default.version
            data.payload.date = default.version
            data.payload.builtIn = true
        end
    end
end


ns.restoreDefaults = function( category, purge )
end


ns.isDefault = function( name, category )
    if not name or not category then
        return false
    end

    for i, default in ipairs( class.defaults ) do
        if default.type == category and default.name == name then
            return true, i
        end
    end

    return false
end


-- Trinket APL
-- ns.storeDefault( [[Usable Items]], 'actionLists', 20180208.181753, [[dq0NnaqijvTjPKpjrrJssPtjr1TufQSljzyk0XqjldPQNHsPAAiLsDnukLTHuk5BOunouk5CQcLMNKk3tQSpjfhucAHivEOefMisPYfvfSrvHmsukQtkbwPu4LOuKBkrj7uv6NQcflvI8uvMkQ0vLOuBfLc9vKsH9s6Vsvdw4WGwScEmctgvDzOnlL6ZOy0iLCAIvJuQ61OuWSv0Tb2Ts)wvnCKILJONlA6uDDKSDuX3vfQA8sOZRkA9iLIMVu0(PSYs5QhTdBdPMUsNEVqaQxzNWHjArbocs9kKWL)Mkx9LLYvVhw4We5v607fcq9ODKqkgA5w8BBX9PMPEfS8cb0)K6T)f1ReoryI6l9JSyN1OELW8trsGPYvD9kCqMI)upEsifdT8(F7(8tnt9ocsHgxV6Tir3LLjR4LeomrElAzH1as4chShxeiyArnDwKO7YYKvazfafWIwwynQ1IeDxwMScalkakGfDDwmArZMwajCHd2JlcemTOUols0DzzYkaSOaOawuU66l9kx9EyHdtKxPtVJGuOX1REls0DzzYkEjHdtK3IwwynGeUWb7XfbcMwutNfj6USmzfqwbqbSOLfwJATir3LLjRaWIcGcyrxNfJw0SPfqcx4G94IabtlQRZIeDxwMScalkakGfLRxjm)uKeyQCvxVchKP4p1RnKA6p7j(uRJKaeMuKOEfS8cb0)K6T)f1ReoryI6l9JSyN1OEVqaQ3JGut)PfLXNADKeGWKIevxFz7kx9EyHdtKxPtVJGuOX1REls0DzzYkEjHdtK3IwwynGeUWb7XfbcMwutNfj6USmzfqwbqbSOLfwJATir3LLjRaWIcGcyrxNfJw0SPfqcx4G94IabtlQRZIeDxwMScalkakGfLR3leG69iC(4EmYe5TOGTnsUWPfLfKGwYI6v4Gmf)PETX5xMiFVSTrYfo7bqcAjlQxjm)uKeyQCvxVs4eHjQV0pYIDwJ6vWYleq)tQ3(xuD9L2w5Q3dlCyI8kD69cbOEp6tYGTfC5lZ0IhbhifcO)j1ReMFkscmvUQRxHdYu8N61(tYGTfC5Z(2WbsHa6Fs9ky5fcO)j1B)lQxjCIWe1x6hzXoRr9ocsHgxV6Tir3LLjR4LeomrElAzH1as4chShxeiyArnDwKO7YYKvazfafWIwwynQ1IeDxwMScalkakGfDDwmArZMwajCHd2JlcemTOUols0DzzYkaSOaOawuU66lBt5Q3dlCyI8kD6DeKcnUE1BrIUlltwXljCyI8w0YcRbKWfoypUiqW0IA6Sir3LLjRaYkakGfTSWAuRfj6USmzfawuaual66Sy0IMnTas4chShxeiyArDDwKO7YYKvayrbqbSOC9EHaup28NCT432c2iC(j1RWbzk(t9O1NC7)T75aNFs9kH5NIKatLR66vcNimr9L(rwSZAuVcwEHa6Fs92)IQRV0wkx9EyHdtKxPtVJGuOX1REls0DzzYkEjHdtK3IwwynGeUWb7XfbcMwutNfj6USmzfqwbqbSOLfwJATir3LLjRaWIcGcyrxNfJw0SPfqcx4G94IabtlQRZIeDxwMScalkakGfLRxjm)uKeyQCvxVchKP4p1JnitApe5Xn7hOixzz6F8ssl9ky5fcO)j1B)lQxjCIWe1x6hzXoRr9EHaup2KmltApe5XTmtlOJICLLXcAdjPL66l7kx9EyHdtKxPtVxia1RSegA5w8BBbBI8NuPELW8trsGPYvD9kCqMI)upGWqlV)3UNnq(tQuVcwEHa6Fs92)I6vcNimr9L(rwSZAuVJGuOX1REls0DzzYkEjHdtK3IwwynGeUWb7XfbcMwutNfj6USmzfqwbqbSOLfwJATir3LLjRaWIcGcyrxNfJw0SPfqcx4G94IabtlQRZIeDxwMScalkakGfLRU(Ywkx9EyHdtKxPtVJGuOX1REls0DzzYkEjHdtK3IwwynGeUWb7XfbcMwutNfj6USmzfqwbqbSOLfwJATir3LLjRaWIcGcyrxNfJw0SPfqcx4G94IabtlQRZIeDxwMScalkakGfLR3leG6vswgl(TTOm(ZjKMuwglEeLtrIPEfoitXFQhPSm9)29e)5estkltFBkNIet9kH5NIKatLR66vcNimr9L(rwSZAuVcwEHa6Fs92)IQRVpwLREpSWHjYR0P3rqk046vVfj6USmzfVKWHjYBrllSgqcx4G94IabtlQPZIeDxwMSciRaOaw0YcRrTwKO7YYKvayrbqbSORZIrlA20ciHlCWECrGGPf11zrIUlltwbGffafWIY1ReMFkscmvUQRxHdYu8N6L0Geos2)B3pGoj8jCQxblVqa9pPE7Fr9kHteMO(s)il2znQ3leG6D0GeosAXVTf0Hoj8jCQU(YAu5Q3dlCyI8kD6DeKcnUE1BrIUlltwXljCyI8w0YcRbKWfoypUiqW0IA6Sir3LLjRaYkakGfTSWAuRfj6USmzfawuaual66Sy0IMnTas4chShxeiyArDDwKO7YYKvayrbqbSOC9ky5fcO)j1B)lQxHdYu8N65Fa2)B3tTKqo4uwM(eUI)uVsy(PijWu5QUELWjctuFPFKf7Sg17fcq94(bOf)2wu2ljKdoLLXIdUI)uD9LflLREpSWHjYR0P3rqk046vVfj6USmzfVKWHjYBrllSgqcx4G94IabtlQPZIeDxwMSciRaOaw0YcRrTwKO7YYKvayrbqbSORZIrlA20ciHlCWECrGGPf11zrIUlltwbGffafWIY1ReMFkscmvUQRxHdYu8N6rbgiHZEW)VmtOWbt9ky5fcO)j1B)lQxjCIWe1x6hzXoRr9EHaup2KmltApe5XTmtlOJICLLXcAdjPL66l7kx9EyHdtKxPtVxia1RSegA5w8BBbBI8NuPELW8trsGPYvD9kCqMI)upGWqlV)3UNnq(tQuVcwEHa6Fs92)I6vcNimr9L(rwSZAuVJGuOX1REls0DzzYkEjHdtK3IwwynGeUWb7XfbcMwutNfj6USmzfqwbqbSOLfwJATir3LLjRaWIcGcyrxNfJw0SPfqcx4G94IabtlQRZIeDxwMScalkakGfLRU(Ywkx9EyHdtKxPtVJGuOX1REls0DzzYkEjHdtK3IwwynGeUWb7XfbcMwutNfj6USmzfqwbqbSOLfwJATir3LLjRaWIcGcyrxNfJw0SPfqcx4G94IabtlQRZIeDxwMScalkakGfLR3leG6vswgl(TTOm(ZjKMuwglEeLtrIPEfoitXFQhPSm9)29e)5estkltFBkNIet9kH5NIKatLR66vcNimr9L(rwSZAuVcwEHa6Fs92)IQRVpwLREpSWHjYR0P3rqk046PhBw45XvPtVJgKqGtH2e6YF13r1vfa]] )


function Hekili:NewSpecialization( specID, isRanged, icon )

    if not specID or specID < 0 then return end

    local id, name, _, texture, role, pClass

    if Hekili.IsRetail() and specID > 0 then id, name, _, texture, role, pClass = GetSpecializationInfoByID( specID )
    else
        id = specID
        texture = icon
        name, pClass = UnitClass( "player" )
    end

    if not id then
        Hekili:Error( "Unable to generate specialization DB for spec ID #" .. specID .. "." )
        return nil
    end

    local token = getSpecializationKey( id )

    local spec = class.specs[ id ] or {
        id = id,
        key = token,
        name = name,
        texture = texture,
        role = role,
        class = pClass,
        melee = not isRanged,

        resources = {},
        resourceAuras = {},
        primaryResource = nil,

        talents = {},
        pvptalents = {},
        powers = {},
        glyphs = {},

        auras = {},
        pseudoAuras = 0,

        abilities = {},
        pseudoAbilities = 0,
        itemAbilities = 0,
        pendingItemSpells = {},

        pets = {},
        totems = {},

        potions = {},

        settings = {},

        stateExprs = {}, -- expressions are returned as values and take no args.
        stateFuncs = {}, -- functions can take arguments and can be used as helper functions in handlers.
        stateTables = {}, -- tables are... tables.

        gear = {},
        setBonuses = {},

        hooks = {},
        funcHooks = {},

        dual_cast = {},

        packs = {},
        options = {},
        packSelectors = {},

        variables = {}
    }

    class.num = class.num + 1

    for key, func in pairs( HekiliSpecMixin ) do
        spec[ key ] = func
    end

    class.specs[ id ] = spec
    return spec
end


function Hekili:GetSpecialization( specID )
    if not specID then return class.specs[ 0 ] end
    return class.specs[ specID ]
end


class.file = UnitClassBase( "player" )
local all = Hekili:NewSpecialization( 0, "All", "Interface\\Addons\\Hekili\\Textures\\LOGO-WHITE.blp" )

------------------------------
-- SHARED SPELLS/BUFFS/ETC. --
------------------------------

all:RegisterAuras( {

    enlisted_a = {
        id = 282559,
        duration = 3600,
    },

    enlisted_b = {
        id = 289954,
        duration = 3600,
    },

    enlisted_c = {
        id = 269083,
        duration = 3600,
    },

    enlisted = {
        alias = { "enlisted_c", "enlisted_b", "enlisted_a" },
        aliasMode = "first",
        aliasType = "buff",
        duration = 3600,
    },

    -- Can be used in GCD calculation.
    shadowform = {
        id = 232698,
        duration = 3600,
        max_stack = 1,
    },

    voidform = {
        id = 194249,
        duration = 15,
        max_stack = 1,
    },

    adrenaline_rush = {
        id = 13750,
        duration = 20,
        max_stack = 1,
    },

    -- Bloodlusts
    ancient_hysteria = {
        id = 90355,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    heroism = {
        id = 32182,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    time_warp = {
        id = 80353,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    netherwinds = {
        id = 160452,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    primal_rage = {
        id = 264667,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    drums_of_deathly_ferocity = {
        id = 309658,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    bloodlust = {
        id = 2825,
        duration = 40,
        generate = function ( t )
            local bloodlusts = {
                [90355] = 'ancient_hysteria',
                [32182] = 'heroism',
                [80353] = 'time_warp',
                [160452] = 'netherwinds',
                [264667] = 'primal_rage',
                [309658] = 'drums_of_deathly_ferocity',
            }

            if Hekili.IsDragonflight() then
                bloodlusts[390386] = "fury_of_the_aspects"
            end

            for id, key in pairs( bloodlusts ) do
                local aura = buff[ key ]
                if aura.up then
                    t.count = aura.count
                    t.expires = aura.expires
                    t.applied = aura.applied
                    t.caster = aura.caster
                    return
                end
            end

            local name, _, count, _, duration, expires, caster, _, _, spellID = GetPlayerAuraBySpellID( 2825 )

            if name then
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = 'nobody'
        end,
    },

    exhaustion = {
        id = 57723,
        shared = "player",
        duration = 600,
        max_stack = 1,
        copy = 390435
    },

    insanity = {
        id = 95809,
        shared = "player",
        duration = 600,
        max_stack = 1
    },

    temporal_displacement = {
        id = 80354,
        shared = "player",
        duration = 600,
        max_stack = 1
    },

    fatigued = {
        id = 264689,
        shared = "player",
        duration = 600,
        max_stack = 1
    },

    sated = {
        id = 57724,
        duration = 600,
        max_stack = 1,
        generate = function ( t )
            local sateds = {
                [57723] = 'exhaustion',
                [95809] = 'insanity',
                [80354] = 'temporal_displacement',
                [264689] = 'fatigued',
            }

            if Hekili.IsDragonflight() then
                sateds[390435] = "exhaustion"
            end

            for id, key in pairs( sateds ) do
                local aura = debuff[ key ]
                if aura.up then
                    t.count = aura.count
                    t.expires = aura.expires
                    t.applied = aura.applied
                    t.caster = aura.caster
                    return
                end
            end

            local name, _, count, _, duration, expires, caster, _, _, spellID = GetPlayerAuraBySpellID( 57724 )

            if name then
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = 'nobody'
        end,
    },

    -- Increases Stamina by $w1.
    prayer_of_fortitude = {
        id = 21562,
        duration = 3600,
        max_stack = 1,
        copy = { 21562, 21564, 25392, 39231, 43939, 48162 },
        shared = "player"
    },

    -- Increases Stamina by $w1.
    power_word_fortitude = {
        id = 1243,
        duration = 1800,
        max_stack = 1,
        copy = { 1243, 1244, 1245, 2791, 10937, 10938, 23947, 23948, 25389, 48161 },
        shared = "player"
    },

    -- Increases Spirit by $s1.
    divine_spirit = {
        id = 14752,
        duration = 1800,
        max_stack = 1,
        copy = { 14752, 14818, 14819, 16875, 25312, 27841, 39234, 48073 },
        shared = "player"
    },
    
    -- Increases Spirit by $s1.
    prayer_of_spirit = {
        id = 27681,
        duration = 3600,
        max_stack = 1,
        copy = { 27681, 32999, 48074 },
        shared = "player"
    },

    demonic_pact = {
        id = 48090,
        duration = 34,
        max_stack = 1,
        shared = "player"
    },

    abominations_might = {
        id = 53138,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = 53137
    },

    -- Increases melee haste by $s1%.
    icy_talons = {
        id = 58578,
        duration = 20,
        max_stack = 1,
        shared = "player",
        copy = { 58578, 58577, 58576, 58575, 50882 },
    },

    -- Increases your attack power by $s1.
    battle_shout = {
        id = 47436,
        duration = function() return ( glyph.battle.enabled and 240 or 120 ) * ( 1 + talent.booming_voice.rank * 0.1 ) end,
        max_stack = 1,
        shared = "player",
        copy = { 2048, 5242, 6192, 6673, 11549, 11550, 11551, 25289, 27578, 47436 },
    },

    commanding_shout = {
        id = 469,
        duration = function() return glyph.command.enabled and 240 or 120 end,
        max_stack = 1,
        shared = "player",
        copy = { 469, 45517, 47439, 47440 },
    },

    -- Armor reduced by $s2%.
    shattering_throw = {
        id = 64382,
        duration = 10,
        max_stack = 1,
        shared = "target",
    },

    corrosive_spit = {
        id = 35387,
        duration = 30,
        max_stack = 3,
        shared = "target",
    },

    -- Armor decreased by $s1%.
    sunder_armor = {
        id = 58567,
        duration = 30,
        max_stack = 5,
        shared = "target",
    },

    -- Decreases armor by $s1%.  Cannot stealth or turn invisible.
    faerie_fire = {
        id = 91565,
        duration = 300,
        max_stack = 3,
        shared = "target",
        copy = { 770, 16857 },
    },

    major_armor_reduction = {
        alias = { "faerie_fire", "sunder_armor", "corrosive_spit", "expose_armor", "shattering_throw" },
        aliasType = "debuff",
        aliasMode = "longest"
    },

    -- Reduces physical damage caused by 10%.
    demoralizing_shout = {
        id = 1160,
        duration = 30,
        max_stack = 1,
        shared = "target",
    },

    -- Reduces physical damage caused by 10%.
    demoralizing_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
        shared = "target",
    },
    -- Physical damage reduced by 10%.
    demoralizing_roar_pet = {
        id = 50256,
        duration = 15,
        max_stack = 1,
        shared = "target",
    },

    -- Physical damage reduced by 10%.
    demoralizing_screech_pet = {
        id = 24423,
        duration = 10,
        max_stack = 1,
        shared = "target",
    },

     -- Physical damage dealt reduced by 10%.
    scarlet_fever = {
        id = 81130,
        duration = 21,
        max_stack = 1,
        shared = "target",
    },

    -- Physical damage done reduced by 10%
    vindication = {
        id = 26017,
        duration = 30,
        max_stack = 1,
        shared = "target",
    },

    -- Decreases armor by $s1%.  Cannot stealth or turn invisible.
    curse_of_weakness = {
        id = 702,
        duration = 120,
        max_stack = 1,
        shared = "target",
    },

    ap_reduction = {
        alias = { "demoralizing_shout", "curse_of_weakness", "demoralizing_roar", "scarlet_fever", "vindication", "demoralizing_roar_pet", "demoralizing_screech_pet" },
        aliasType = "debuff",
        aliasMode = "longest"
    },

    -- Time between attacks increased by 20%.
    earth_shock = {
        id = 8042,
        duration = 8,
        max_stack = 1,
        shared = "target",
    },

    -- Deals Frost damage over $d.  Reduces melee and ranged attack speed.
    frost_fever = {
        id = 55095,
        duration = function () return 21 + ( 4 * talent.epidemic.rank ) end,
        tick_time = 3,
        max_stack = 1,
    },

    -- Deals Frost damage over $d.  Reduces melee and ranged attack speed.
    frost_fever_shared = {
        --id = 55095,
        duration = function () return 21 + ( 4 * talent.epidemic.rank ) end,
        tick_time = 3,
        max_stack = 1,
        generate = function ( t )
            local name, _, count, _, duration, expires, caster = FindUnitDebuffByID( "target", 55095 )

            if name then
                t.name = name
                t.count = 1
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

    -- Movement speed slowed by $s1% and attack speed slowed by $s2%.
    infected_wounds = {
        id = 48484,
        duration = 12,
        max_stack = 1,
        shared = "target",
        copy = { 48484, 48483 },
    },

    -- Reduces melee attack speed.
    judgements_of_the_just = {
        id = 53696,
        duration = 20,
        max_stack = 1,
        shared = "target",
    },

    -- Attack speed reduced by $s2%.
    thunder_clap = {
        id = 6343,
        duration = 30,
        max_stack = 1,
        shared = "target",
    },

    attack_speed_reduction = {
        alias = { "earth_shock", "frost_fever_shared", "infected_wounds", "judgements_of_the_just", "thunder_clap" },
        aliasType = "debuff",
        aliasMode = "longest"
    },

    rampage = {
        id = 29801,
        duration = 3600,
        max_stack = 1,
        shared = "player",
    },

    -- Increases your total Strength and Agility by $s1.
    horn_of_winter = {
        id = 57623,
        duration = function () return glyph.horn_of_winter.enabled and 180 or 120 end,
        max_stack = 1,
        shared = "player",
        copy = { 57330, 57623 },
    },

    -- All bleed effects cause $s2% additional damage.
    mangle_bear = {
        id = 33878,
        duration = 60,
        max_stack = 1,
        shared = "target",
        copy = { 33878, 33986, 33987, 48563, 48564 },
    },

    -- All bleed effects cause $s2% additional damage.
    mangle_cat = {
        id = 33876,
        duration = 60,
        max_stack = 1,
        shared = "target",
        copy = { 33876, 33982, 33983, 48565, 48566 },
    },

    -- All bleed effects cause $s2% additional damage.
    trauma = {
        id = 46857,
        duration = 60,
        max_stack = 1,
        shared = "target",
    },

    -- All bleed effects cause $s2% additional damage.
    stampede = {
        id = 57386,
        duration = 30,
        max_stack = 1,
        shared = "target",
    },
    
    -- Increases damage taken from Bleed effects by 30%.
	hemorrhage_debuff = {
        id = 16511,
        duration = 60,
        max_stack = 1,
        shared = "target",
    },
	
    -- Alias for all bleed vulnerability effects
    bleed_vulnerability = {
        alias = { "mangle_bear", "mangle_cat", "trauma", "stampede", "hemorrhage_debuff" },
        aliasType = "debuff",
        aliasMode = "longest"
    },

-- Keeping the old aliases for compatibility, but they now reference bleed_vulnerability
   hemorrhage = {
       alias = { "bleed_vulnerability" },
       aliasType = "debuff",
       aliasMode = "longest"
    },
	
    mangle = {
        alias = { "bleed_vulnerability" },
        aliasType = "debuff",
        aliasMode = "longest"
    },

    -- Increases physical damage taken by $s1%.
    acid_spit = {
        id = 55749,
        duration = 30,
        max_stack = 2,
        shared = "target",
        copy = { 55749, 55750, 55751, 55752, 55753, 55754 }
    },

    blood_frenzy = {
        id = 29859,
        duration = 3600,
        max_stack = 1,
    },

    brittle_bones = {
        id = 81328,
        duration = 3600,
        max_stack = 1,
    },

    savage_combat = {
        id = 58684,
        duration = 3600,
        max_stack = 1,
        copy = { 58683, 58684 },
    },

    -- Alias-Aura collecting all physical-vulnerability debuffs
    phys_vuln = {
        alias = { "acid_spit", "blood_frenzy", "brittle_bones", "savage_combat"},
        aliasType = "debuff",
        aliasMode = "longest"
    },

    -- Increases armor by $s1.
    mark_of_the_wild = {
        id = 79061,
        duration = 1800,
        max_stack = 1,
        shared = "player",
        copy = { 1126, 5232, 5234, 6756, 8907, 9884, 9885, 16878, 24752, 26990, 39233, 48469 },
    },

    -- Increases armor by $s1, all attributes by $s2 and all resistances by $s3.
    gift_of_the_wild = {
        id = 21849,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = { 21849, 21850, 26991, 48470 },
    },

    -- Expose Armor.
    expose_armor = {
        id = 8647,
        duration = function() return UnitClassBase( 'player' ) ~= 'ROGUE' and 10 or 10 * combo_points.current + ( glyph.expose_armor.enabled and 12 or 0 ) end,
        max_stack = 1,
        shared = "target",
    },

    -- The threat caused by your next damaging attack and all actions taken for $57933d afterwards will be transferred to the target.  In addition, all damage caused by the target is increased by $57933s1% during this time.
    tricks_of_the_trade = {
        id = 57934,
        duration = 30,
        max_stack = 1,
        shared = "player",
    },

    tricks_of_the_trade_buff = {
        id = 57933,
        duration = function() return glyph.tricks_of_the_trade.enabled and 10 or 6 end,
        max_stack = 1,
        shared = "player"
    },

    -- Chance to be critically hit with spells increased by $s1%.
    shadow_mastery = {
        id = 17800,
        duration = 30,
        max_stack = 1,
        shared = "target"
    },

    power_infusion = {
        id = 10060,
        duration = 20,
        max_stack = 1
    },

    replenishment = {
        id = 57669,
        duration = 15,
        max_stack = 1,
        shared = "player"
    },

    ferocious_inspiration = {
        id = 75447,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = { 75593, 75446, 75447 }
    },

    -- Increases attack power by $s1%.
    trueshot_aura = {
        id = 19506,
        duration = 3600,
        max_stack = 1,
        shared = "player"
    },

    -- Places a Blessing on the friendly target, increasing Strength, Agility, Stamina, and Intellect by 5%, and all magical resistances by 97, for 1 hour.  
    -- If target is in your party or raid, all party and raid members will be affected. Players may only have one Blessing on them per Paladin at any one time.
    blessing_of_kings = {
        id = 79063,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = { 20217, 79063 }
    },

    -- Places a Blessing on the friendly target, increasing melee attack power by 20%, increasing ranged attack power by 10%, and restoring 0 mana every 5 seconds for 1 hour.  
    -- If target is in your party or raid, all party and raid members will be affected. Players may only have one Blessing on them per Paladin at any one time.
    blessing_of_might = {
        id = 79102,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = { 19740, 79102 }
    },

    -- Reduces casting or channeling time lost when damaged by $s1%.
    concentration_aura = {
        id = 19746,
        duration = 3600,
        max_stack = 1,
        shared = "player"
    },

    -- Mounted speed increased by $s1%.  This does not stack with other movement speed increasing effects.
    crusader_aura = {
        id = 32223,
        duration = 3600,
        max_stack = 1,
        shared = "player"
    },

    -- Increases Fire resistance by $s1.
    fire_resistance_aura = {
        id = 48947,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = { 19891, 19899, 19900, 27153, 48947 },
    },

    -- Increases Frost resistance by $s1.
    frost_resistance_aura = {
        id = 48945,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = { 19888, 19897, 19898, 27152, 48945 },
    },

    stat_buff = {
        alias = { "blessing_of_kings", "mark_of_the_wild" },
        aliasMode = "longest",
        aliasType = "buff"
    },

    -- Does $s1 Holy damage to anyone who strikes you.
    retribution_aura = {
        id = 54043,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = { 7294, 8990, 10298, 10299, 10300, 10301, 27150, 54043 },
    },

    -- Increases Shadow resistance by $s1.
    shadow_resistance_aura = {
        id = 48943,
        duration = 3600,
        max_stack = 1,
        copy = { 19876, 19895, 19896, 27151, 48943 },
    },

    -- SL Season 3
    decrypted_urh_cypher = {
        id = 368239,
        duration = 10,
        max_stack = 1,
    },

    old_war = {
        id = 188028,
        duration = 25,
    },

    deadly_grace = {
        id = 188027,
        duration = 25,
    },

    prolonged_power = {
        id = 229206,
        duration = 60,
    },

    dextrous = {
        id = 146308,
        duration = 20,
    },

    vicious = {
        id = 148903,
        duration = 10,
    },

    -- WoD Legendaries
    archmages_incandescence_agi = {
        id = 177161,
        duration = 10,
    },

    archmages_incandescence_int = {
        id = 177159,
        duration = 10,
    },

    archmages_incandescence_str = {
        id = 177160,
        duration = 10,
    },

    archmages_greater_incandescence_agi = {
        id = 177172,
        duration = 10,
    },

    archmages_greater_incandescence_int = {
        id = 177176,
        duration = 10,
    },

    archmages_greater_incandescence_str = {
        id = 177175,
        duration = 10,
    },

    maalus = {
        id = 187620,
        duration = 15,
    },

    thorasus = {
        id = 187619,
        duration = 15,
    },

    sephuzs_secret = {
        id = 208052,
        duration = 10,
        max_stack = 1,
    },

    str_agi_int = {
        duration = 3600,
    },

    stamina = {
        duration = 3600,
    },

    attack_power_multiplier = {
        duration = 3600,
    },

    haste = {
        duration = 3600,
    },

    spell_power_multiplier = {
        duration = 3600,
    },

    critical_strike = {
        duration = 3600,
    },

    mastery = {
        duration = 3600,
    },

    versatility = {
        duration = 3600,
    },

    casting = {
        name = "Casting",
        generate = function( t, auraType )
            local unit = auraType == "debuff" and "target" or "player"

            if unit == "player" or UnitCanAttack( "player", "target" ) then
                local spell, _, _, startCast, endCast, _, _, notInterruptible, spellID = UnitCastingInfo( unit )

                if spell then
                    startCast = startCast / 1000
                    endCast = endCast / 1000

                    t.name = spell
                    t.count = 1
                    t.expires = endCast
                    t.applied = startCast
                    t.duration = endCast - startCast
                    t.v1 = spellID
                    t.v2 = notInterruptible and 1 or 0
                    t.v3 = 0
                    t.caster = unit

                    return
                end

                spell, _, _, startCast, endCast, _, notInterruptible, spellID = UnitChannelInfo( unit )

                if spell then
                    startCast = startCast / 1000
                    endCast = endCast / 1000

                    t.name = spell
                    t.count = 1
                    t.expires = endCast
                    t.applied = startCast
                    t.duration = endCast - startCast
                    t.v1 = spellID
                    t.v2 = notInterruptible and 1 or 0
                    t.v3 = 1 -- channeled.
                    t.caster = unit

                    return
                end
            end

            t.name = "Casting"
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.v1 = 0
            t.v2 = 0
            t.v3 = 0
            t.caster = unit
        end,
    },

    --[[ player_casting = {
        name = "Casting",
        generate = function ()
            local aura = buff.player_casting

            local name, _, _, startCast, endCast, _, _, notInterruptible, spell = UnitCastingInfo( "player" )

            if name then
                aura.name = name
                aura.count = 1
                aura.expires = endCast / 1000
                aura.applied = startCast / 1000
                aura.v1 = spell
                aura.caster = 'player'
                return
            end

            name, _, _, startCast, endCast, _, _, notInterruptible, spell = UnitChannelInfo( "player" )

            if notInterruptible == false then
                aura.name = name
                aura.count = 1
                aura.expires = endCast / 1000
                aura.applied = startCast / 1000
                aura.v1 = spell
                aura.caster = 'player'
                return
            end

            aura.name = "Casting"
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.v1 = 0
            aura.caster = 'target'
        end,
    }, ]]

    movement = {
        duration = 5,
        max_stack = 1,
        generate = function ()
            local m = buff.movement

            if moving then
                m.count = 1
                m.expires = query_time + 5
                m.applied = query_time
                m.caster = "player"
                return
            end

            m.count = 0
            m.expires = 0
            m.applied = 0
            m.caster = "nobody"
        end,
    },

    repeat_performance = {
        id = 304409,
        duration = 30,
        max_stack = 1,
    },

    -- Why do we have this, again?
    unknown_buff = {},

    berserking = {
        id = 26297,
        duration = 10,
    },

    hyper_organic_light_originator = {
        id = 312924,
        duration = 6,
    },

    blood_fury = {
        id = 20572,
        duration = 15,
    },

    shadowmeld = {
        id = 58984,
        duration = 3600,
    },

    ferocity_of_the_frostwolf = {
        id = 274741,
        duration = 15,
    },

    might_of_the_blackrock = {
        id = 274742,
        duration = 15,
    },

    zeal_of_the_burning_blade = {
        id = 274740,
        duration = 15,
    },

    rictus_of_the_laughing_skull = {
        id = 274739,
        duration = 15,
    },

    ancestral_call = {
        duration = 15,
        alias = { "ferocity_of_the_frostwolf", "might_of_the_blackrock", "zeal_of_the_burning_blade", "rictus_of_the_laughing_skull" },
        aliasMode = "first",
    },

    arcane_pulse = {
        id = 260369,
        duration = 12,
    },

    fireblood = {
        id = 273104,
        duration = 8,
    },

    out_of_range = {
        generate = function ()
            local oor = buff.out_of_range

            if target.distance > 8 then
                oor.count = 1
                oor.applied = query_time
                oor.expires = 3600
                oor.caster = "player"
                return
            end

            oor.count = 0
            oor.applied = 0
            oor.expires = 0
            oor.caster = "nobody"
        end,
    },

    loss_of_control = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = "none", 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )

                    if event.lockoutSchool == 0 and event.startTime and event.startTime > 0 and event.timeRemaining and event.timeRemaining > 0 and event.startTime > start and event.timeRemaining > remains then
                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    dispellable_curse = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Curse" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_poison = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Poison" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_disease = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Disease" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_magic = {
        generate = function( t, auraType )
            if auraType == "buff" then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "Magic" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end

            else
                local i = 1
                local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

                while( name ) do
                    if debuffType == "Magic" then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
                end

                if name then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end

            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    stealable_magic = {
        generate = function( t )
            if UnitCanAttack( "player", "target" ) then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "Magic" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    reversible_magic = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Magic" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_enrage = {
        generate = function( t )
            if UnitCanAttack( "player", "target" ) then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    banner_of_the_horde = {
        id = 61574,
        max_stack = 1,
        shared = "target"
    },

    banner_of_the_alliance = {
        id = 61573,
        max_stack = 1,
        shared = "target"
    },

    training_dummy = {
        alias = { "banner_of_the_horde", "banner_of_the_alliance" },
        aliasType = "buff",
        aliasMode = "longest"
    }
} )

-- TODO: Needs MoP potions
-- TODO: Something about potions is not currently working, needs investigation.
all:RegisterPotions( {
    volcanic = {
        item = 58091,
        buff = "volcanic_power",
        aura = {
            id = 79476,
            duration = 25,
            max_stack = 1,
        }
    },
    
    speed = {
        item = 40211,
        buff = "speed",
        aura = {
            id = 53908,
            duration = 15,
            max_stack = 1
        }
    },
    golemblood = {
        item = 58146,
        buff = "golems_strength",
        aura = {
            id = 79634,
            duration = 25,
            max_stack = 1
        }
    },
    tolvir = {
        item = 58145,
        buff = "tolvir_agility",
        aura = {
            id = 79633,
            duration = 25,
            max_stack = 1
        }
    },
    runic_mana_injector = {
        item = 42545
    },
    wild_magic = {
        item = 40212,
        buff = "wild_magic",
        aura = {
            id = 53908,
            duration = 15,
            max_stack = 1
        }
    },
    runic_mana_potion = {
        item = 33448
    },
    indestructible_potion = {
        item = 40093,
        buff = "indestructible",
        aura = {
            id = 53762,
            duration = 120,
            max_stack = 1
        }
    },
    endless_mana_potion = {
        item = 43570
    },
    runic_healing_potion = {
        item = 33447
    },
    runic_healing_injector = {
        item = 41166
    },
    crazy_alchemists_potion = {
        item = 40077
    },
    nightmares = {
        item = 40081,
        buff = "nightmare_slumber",
        aura = {
            id = 53753,
            duration = 6,
            max_stack = 1
        },
    },
    endless_healing_potion = {
        item = 43569
    },
    powerful_rejuvenation_potion = {
        item = 40087
    },
    mighty_fire_protection_potion = {
        item = 40214,
        buff = "fire_protection",
        aura = {
            id = 53911,
            duration = 120,
            max_stack = 1
        },
    },
    mighty_frost_protection_potion = {
        item = 40215,
        buff = "frost_protection",
        aura = {
            id = 53913,
            duration = 120,
            max_stack = 1
        }
    },
    mighty_nature_protection_potion = {
        item = 40216,
        buff = "nature_protection",
        aura = {
            id = 53914,
            duration = 120,
            max_stack = 1,
        },
    },
    mighty_shadow_protection_potion = {
        item = 40217,
        buff = "shadow_protection",
        aura = {
            id = 53915,
            duration = 120,
            max_stack = 1,
        }
    },
    mighty_arcane_protection_potion = {
        item = 40213,
        buff = "arcane_protection",
        aura = {
            id = 53910,
            duration = 120,
            max_stack = 1,
        }
    },
    
    -- MoP Potions
    master_healing_potion = {
        item = 76097
    },
    master_mana_potion = {
        item = 76098
    },
    mogu_power = {
        item = 76095,
        buff = "mogu_power",
        aura = {
            id = 105706,
            duration = 25,
            max_stack = 1
        }
    },
    jade_serpent = {
        item = 76094,
        buff = "jade_serpent",
        aura = {
            id = 105702,
            duration = 25,
            max_stack = 1
        }
    },
    virmens_bite = {
        item = 76089,
        buff = "virmens_bite",
        aura = {
            id = 105697,
            duration = 25,
            max_stack = 1
        }
    },
    focus = {
        item = 76092,
        buff = "focus",
        aura = {
            id = 105701,
            duration = 25,
            max_stack = 1
        }
    },
    mountains = {
        item = 76090,
        buff = "mountains",
        aura = {
            id = 105698,
            duration = 25,
            max_stack = 1
        }
    },
    luck = {
        item = 76093,
        buff = "luck",
        aura = {
            id = 135855,
            duration = 60,
            max_stack = 1
        }
    }
} )


all:RegisterAuras( {
    -- 9.0
    potion_of_spectral_strength = {
        id = 307164,
        duration = 25,
        max_stack = 1,
        copy = "spectral_strength"
    },
    potion_of_spectral_agility = {
        id = 307159,
        duration = 25,
        max_stack = 1,
        copy = "spectral_agility"
    },
    potion_of_spiritual_clarity = {
        id = 307161,
        duration = 10,
        max_stack = 1,
        copy = "spiritual_clarity"
    },
    potion_of_phantom_fire = {
        id = 307495,
        duration = 25,
        max_stack = 1,
        copy = "phantom_fire",
    },
    potion_of_spectral_intellect = {
        id = 307162,
        duration = 25,
        max_stack = 1,
        copy = "spectral_intellect"
    },
    potion_of_deathly_fixation = {
        id = 307497,
        duration = 25,
        max_stack = 1,
        copy = "deathly_fixation"
    },
    strength_of_blood = {
        id = 338385,
        duration = 60,
        max_stack = 1
    },
    potion_of_empowered_exorcisms = {
        id = 307494,
        duration = 25,
        max_stack = 1,
        copy = "empowered_exorcisms"
    },
    potion_of_unusual_strength = {
        id = 334436,
        duration = 25,
        max_stack = 1,
        copy = "unusual_strength"
    },
    potion_of_spectral_stamina = {
        id = 307163,
        duration = 25,
        max_stack = 1,
        copy = "spectral_stamina"
    },

    -- 8.2
    potion_of_empowered_proximity = {
        id = 298225,
        duration = 25,
        max_stack = 1
    },
    potion_of_focused_resolve = {
        id = 298317,
        duration = 25,
        max_stack = 1
    },
    potion_of_unbridled_fury = {
        id = 300714,
        duration = 60,
        max_stack = 1
    },
    superior_battle_potion_of_agility = {
        id = 298146,
        duration = 25,
        max_stack = 1
    },
    superior_battle_potion_of_intellect = {
        id = 298152,
        duration = 25,
        max_stack = 1
    },
    superior_battle_potion_of_stamina = {
        id = 298153,
        duration = 25,
        max_stack = 1
    },
    superior_battle_potion_of_strength = {
        id = 298154,
        duration = 25,
        max_stack = 1
    },
    superior_steelskin_potion = {
        id = 298155,
        duration = 25,
        max_stack = 1
    },

    -- 8.0
    battle_potion_of_agility = {
        id = 279152,
        duration = 25,
        max_stack = 1,
    },
    battle_potion_of_intellect = {
        id = 279151,
        duration = 25,
        max_stack = 1,
    },
    battle_potion_of_stamina = {
        id = 279154,
        duration = 25,
        max_stack = 1,
    },
    battle_potion_of_strength = {
        id = 279153,
        duration = 25,
        max_stack = 1,
    },
    potion_of_bursting_blood = {
        id = 251316,
        duration = 25,
        max_stack = 1,
    },
    potion_of_rising_death = {
        id = 269853,
        duration = 25,
        max_stack = 1,
    },
    steelskin_potion = {
        id = 251231,
        duration = 25,
        max_stack = 1,
    },
    
    -- MoP Potions
    mogu_power = {
        id = 105706,
        duration = 25,
        max_stack = 1,
    },
    jade_serpent = {
        id = 105702,
        duration = 25,
        max_stack = 1,
    },
    virmens_bite = {
        id = 105697,
        duration = 25,
        max_stack = 1,
    },
    focus = {
        id = 105701,
        duration = 25,
        max_stack = 1,
    },
    mountains = {
        id = 105698,
        duration = 25,
        max_stack = 1,
    },
    luck = {
        id = 135855,
        duration = 60,
        max_stack = 1,
    },

} )


all:SetPotion( "prolonged_power" )


local gotn_classes = {
    WARRIOR = 28880,
    MONK = 121093,
    DEATHKNIGHT = 59545,
    SHAMAN = 59547,
    HUNTER = 59543,
    PRIEST = 59544,
    MAGE = 59548,
    PALADIN = 59542
}

all:RegisterAura( "gift_of_the_naaru", {
    id = gotn_classes[ UnitClassBase( "player" ) or "WARRIOR" ],
    duration = 5,
    max_stack = 1,
    copy = { 28800, 121093, 59545, 59547, 59543, 59544, 59548, 59542 }
} )

all:RegisterAbility( "gift_of_the_naaru", {
    id = 59544,
    cast = 0,
    cooldown = 180,
    gcd = "off",

    handler = function ()
        applyBuff( "gift_of_the_naaru" )
    end,
} )


all:RegisterAbilities( {
    global_cooldown = {
        id = 61304,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        unlisted = true,
        known = function () return true end,

        copy = 61304
    },

    -- Troll racial was present in MoP
    berserking = {
        id = 26297,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",

        -- usable = function () return race.troll end,
        handler = function ()
            applyBuff( 'berserking' )
        end,
    },

    -- Blood Fury (Orc racial) was present in MoP
    blood_fury = {
        id = 20572,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "blood_fury" )
        end,
    },

    -- Will of the Forsaken (Undead racial) was present in MoP
    will_of_the_forsaken = {
        id = 7744,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "defensives",

        handler = function ()
            applyBuff( "will_of_the_forsaken" )
            -- In MoP this shared cooldown with other similar effects
            setCooldown( "arcane_torrent", 30 )
        end,
    },

    -- Stoneform (Dwarf racial) was present in MoP
    stoneform = {
        id = 20594,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "defensives",

        handler = function ()
            removeBuff( "dispellable_poison" )
            removeBuff( "dispellable_disease" )
            removeBuff( "dispellable_curse" )
            removeBuff( "dispellable_magic" )
            removeBuff( "dispellable_bleed" )
            applyBuff( "stoneform" )
        end,
    },

    -- Every Man for Himself (Human racial) was present in MoP
    every_man_for_himself = {
        id = 59752,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "defensives",

        handler = function()
            -- Removes movement impairing effects and loss of control effects
        end,
    },

    -- Remove non-MoP abilities (these were from later expansions)
    -- ancestral_call (Mag'har Orc - BfA)
    -- arcane_pulse (Nightborne - Legion)
    -- hyper_organic_light_originator (Mechagnome - BfA)
    -- bag_of_tricks (Vulpera - BfA)
    -- haymaker (Kul Tiran - BfA)
} )


-- Blood Fury spell IDs vary by class (whether you need AP/Int/both).
local bf_classes = {
    DEATHKNIGHT = 20572,
    HUNTER = 20572,
    MAGE = 33702,
    MONK = 33697,
    ROGUE = 20572,
    SHAMAN = 33697,
    WARLOCK = 33702,
    WARRIOR = 20572,
}

all:RegisterAbilities( {
    blood_fury = {
        id = function () return bf_classes[ class.file ] or 20572 end,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "cooldowns",

        -- usable = function () return race.orc end,
        handler = function ()
            applyBuff( "blood_fury", 15 )
        end,

        copy = { 33702, 20572, 33697 },
    },

    --[[ arcane_torrent = {
        id = function ()
            if class.file == "PALADIN"      then return 155145 end
            if class.file == "MONK"         then return 129597 end
            if class.file == "DEATHKNIGHT"  then return  50613 end
            -- if class.file == "WARRIOR"      then return  69179 end
            if class.file == "ROGUE"        then return  25046 end
            if class.file == "HUNTER"       then return  80483 end
            if class.file == "DEMONHUNTER"  then return 202719 end
            if class.file == "PRIEST"       then return 232633 end
            return 28730
        end,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        startsCombat = true,

        -- usable = function () return race.blood_elf end,
        toggle = "cooldowns",

        handler = function ()
            if class.file == "DEATHKNIGHT" then gain( 20, "runic_power" )
            elseif class.file == "HUNTER" then gain( 15, "focus" )
            elseif class.file == "MONK" then gain( 1, "chi" )
            elseif class.file == "PALADIN" then gain( 1, "holy_power" )
            elseif class.file == "ROGUE" then gain( 15, "energy" )
            elseif class.file == "DEMONHUNTER" then gain( 15, "fury" )
            elseif class.file == "PRIEST" and state.spec.shadow then gain( 15, "insanity" ) end

            removeBuff( "dispellable_magic" )
        end,
    }, ]]

    -- Removes all movement impairing effects and all effects which cause loss of control of your character.  This effect shares a cooldown with other similar effects.
    will_to_survive = {
        id = 59752,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        startsCombat = false,
        texture = 136129,

        toggle = "defensives",

        -- TODO: Detect loss of control effects.
        handler = function ()
        end,
    },

    shadowmeld = {
        id = 58984,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        usable = function ()
            if not boss or solo then return false, "requires boss fight or group (to avoid resetting)" end
            if moving then return false, "can't shadowmeld while moving" end
            return true
        end,

        handler = function ()
            applyBuff( "shadowmeld" )
        end,
    },


    lights_judgment = not Hekili.IsClassic() and {
        id = 255647,
        cast = 0,
        cooldown = 150,
        gcd = "spell",

        -- usable = function () return race.lightforged_draenei end,

        toggle = 'cooldowns',
    } or nil,


    stoneform = {
        id = 20594,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        handler = function ()
            removeBuff( "dispellable_poison" )
            removeBuff( "dispellable_disease" )
            removeBuff( "dispellable_curse" )
            removeBuff( "dispellable_magic" )
            removeBuff( "dispellable_bleed" )

            applyBuff( "stoneform" )
        end,

        auras = {
            stoneform = {
                id = 65116,
                duration = 8,
                max_stack = 1
            }
        }
    },


    fireblood = not Hekili.IsClassic() and {
        id = 265221,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "cooldowns",

        -- usable = function () return race.dark_iron_dwarf end,
        handler = function () applyBuff( "fireblood" ) end,
    } or nil,


    -- INTERNAL HANDLERS
    call_action_list = {
        name = '|cff00ccff[Call Action List]|r',
        cast = 0,
        cooldown = 0,
        gcd = 'off',
        essential = true,
    },

    run_action_list = {
        name = '|cff00ccff[Run Action List]|r',
        cast = 0,
        cooldown = 0,
        gcd = 'off',
        essential = true,
    },

    wait = {
        name = '|cff00ccff[Wait]|r',
        cast = 0,
        cooldown = 0,
        gcd = 'off',
        essential = true,
    },

    pool_resource = {
        name = '|cff00ccff[Pool Resource]|r',
        cast = 0,
        cooldown = 0,
        gcd = 'off',
    },

    cancel_action = {
        name = "|cff00ccff[Cancel Action]|r",
        cast = 0,
        cooldown = 0,
        gcd = "off",
    },

    variable = {
        name = '|cff00ccff[Variable]|r',
        cast = 0,
        cooldown = 0,
        gcd = 'off',
        essential = true,
    },

    potion = {
        name = '|cff00ccff[Potion]|r',
        cast = 0,
        cooldown = function () return time > 0 and 3600 or 60 end,
        gcd = 'off',

        startsCombat = false,
        toggle = "potions",

        item = function ()
            local potion = args.potion or args.name
            if not potion or potion == default then potion = class.potion end
            potion = class.potions[ potion ]

            if potion then return potion.item end
        end,
        bagItem = true,

        timeToReady = function ()
            local potion = args.potion or args.name
            if not potion or potion == "default" then potion = class.potion end
            potion = class.potions[ potion ]

            if potion then
                local start, dur = GetItemCooldown( potion.item )
                return max( 0, start + dur - query_time )
            end

            return 3600
        end,

        handler = function ()
            local potion = args.potion or args.name
            if not potion or potion == "default" then potion = class.potion end
            potion = class.potions[ potion ]

            if potion then
                applyBuff( potion.buff, potion.duration or 25 )
            end
        end,

        usable = function ()
            local pName = args.potion or args.name
            if not pName or pName == "default" then pName = class.potion end
            local potion = class.potions[ pName ]

            if not potion or GetItemCount( potion.item ) == 0 then return false, "no potion found/" .. tostring(potion) .. "/" .. ( potion and potion.item or 0 ) end

            return true
        end,
    },

    runic_mana_injector = {
        name = function() return GetItemInfo( 42545 ) end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 42545,
        bagItem = true,

        usable = function ()
            return GetItemCount( 67490 ) > 0, "requires runic_mana_injector in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 67490 )
            return max( 0, start + duration - query_time )
        end,

        mana_restored = 4200,

        handler = function()
            gain( 4200, "mana" )
        end,
    },

    runic_mana_potion = {
        name = function() return GetItemInfo( 33448 ) end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 33448,
        bagItem = true,

        usable = function ()
            return GetItemCount( 33448 ) > 0, "requires runic_mana_potion in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 33448 )
            return max( 0, start + duration - query_time )
        end,

        mana_restored = 4200,

        handler = function()
            gain( 4200, "mana" )
        end,
    },

    potion_of_nightmares = {
        id = 53753,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 40081,
        bagItem = true,

        usable = function ()
            return GetItemCount( 40081 ) > 0, "requires potion_of_nightmares in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 40081 )
            return max( 0, start + duration - query_time )
        end,

        handler = function()
            applyBuff( "nightmare_slumber" )
            setCooldown( "global_cooldown", 6 )
        end,

        auras = {
            nightmare_slumber = {
                id = 53753,
                duration = 6,
                max_stack = 1
            }
        }
    },

    crazy_alchemists_potion = {
        id = 53750,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 40077,
        bagItem = true,

        usable = function ()
            return GetItemCount( 40077 ) > 0, "requires crazy_alchemists_potion in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 40077 )
            return max( 0, start + duration - query_time )
        end,

        mana_restored = 4200,

        handler = function()
            gain( 3100, "health" )
            gain( 4200, "mana" )
        end,
    },
    volcanic_potion = {
        name = function() return GetItemInfo( 58091 ) end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 58091,
        bagItem = true,

        usable = function ()
            return GetItemCount( 58091 ) > 0, "requires volcanic_potion in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 58091 )
            return max( 0, start + duration - query_time )
        end,

        handler = function()
            applyBuff( "volcanic_power" )
        end,
    },

    tol_vir_potion = {
        name = function() return GetItemInfo( 58145 ) end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 58145,
        bagItem = true,

        usable = function ()
            return GetItemCount( 58145 ) > 0, "requires tol_vir_potion in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 58145 )
            return max( 0, start + duration - query_time )
        end,

        handler = function()
            applyBuff( "tol_vir_potion" )
        end,
    },
    
    endless_mana_potion = {
        name = function() return GetItemInfo( 43570 ) end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 43570,
        bagItem = true,

        usable = function ()
            return GetItemCount( 43570 ) > 0, "requires endless_mana_potion in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 43570 )
            return max( 0, start + duration - query_time )
        end,

        mana_restored = 1800,

        handler = function()
            gain( 1800, "mana" )
        end,
    },

    icy_mana_potion = {
        name = function() return GetItemInfo( 40067 ) end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 40067,
        bagItem = true,

        usable = function ()
            return GetItemCount( 40067 ) > 0, "requires icy_mana_potion in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 40067 )
            return max( 0, start + duration - query_time )
        end,

        mana_restored = 1800,

        handler = function()
            gain( 1800, "mana" )
        end,
    },

    best_mana_potion = {
        name = strformat( '|cff00ccff[%s %s]|r', BEST, GetSpellInfo( 3452 ) ),
        link = strformat( '|cff00ccff[%s %s]|r', BEST, GetSpellInfo( 3452 ) ),
        cast = 0,
        cooldown = 60,
        gcd = 'off',

        startsCombat = false,
        toggle = "potions",
        texture = function()
            local item = action.best_mana_potion.item
            return GetItemIcon( item )
        end,

        isItem = true,
        item = function()
            if not Hekili.PLAYER_ENTERING_WORLD or not rawget( state, "mana" ) then return 45276 end

            local deficit = mana.deficit

            if deficit > 4200 then
                if GetItemCount( 45276 ) > 0 then return 45276 end
                if GetItemCount( 42545 ) > 0 then return 42545 end
                if GetItemCount( 33448 ) > 0 then return 33448 end
                if GetItemCount( 40077 ) > 0 then return 40077 end
            end

            if deficit > 1800 then
                if GetItemCount( 40067 ) > 0 then return 40067 end
                if GetItemCount( 43530 ) > 0 then return 43530 end
                if GetItemCount( 43570 ) > 0 then return 43570 end
            end

            return 45276
        end,
        bagItem = true,

        usable = function ()
            local item = action.best_mana_potion.item
            return GetItemCount( action.best_mana_potion.item ) > 0, "requires a mana deficit and mana_potion in bags"
        end,

        readyTime = function ()
            local item = action.best_mana_potion.item
            if item == 0 then return 3600 end
            local start, dur = GetItemCooldown( item )
            return max( 0, start + dur - query_time )
        end,

        handler = function ()
            class.abilities[ class.itemMap[ action.best_mana_potion.item ] ].handler()
        end,

    },

    argent_mana_potion = {
        name = function() return GetItemInfo( 43530 ) end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 43530,
        bagItem = true,

        usable = function ()
            return GetItemCount( 43530 ) > 0, "requires argent_mana_potion in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 43530 )
            return max( 0, start + duration - query_time )
        end,

        mana_restored = 1800,

        handler = function()
            gain( 1800, "mana" )
        end,
    },

    jillians_genius_juice = {
        name = function() return GetItemInfo( 45276 ) end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,

        item = 45276,
        bagItem = true,

        usable = function ()
            return GetItemCount( 45276 ) > 0, "requires jillians_genius_juice in bags"
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 45276 )
            return max( 0, start + duration - query_time )
        end,

        mana_restored = 4200,

        handler = function()
            gain( 4200, "mana" )
        end,
    },

    flame_cap = {
        id = 28714,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        item = 22788,
        bagItem = true,

        startsCombat = false,
        texture = 134209,
        toggle = "cooldowns",

        usable = function ()
            if GetItemCount( 22788 ) == 0 then return false, "requires flame cap in bags"
            elseif not IsUsableItem( 22788 ) then return false, "on cooldown or unusable" end
            return true
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 22788 )
            return max( 0, start + duration - query_time )
        end,

        handler = function ()
            applyBuff( "flame_cap" )
        end,

        auras = {
            flame_cap = {
                id = 28714,
                duration = 60,
                max_stack = 1
            }
        }
    },

    global_thermal_sapper_charge = {
        id = 56488,
        cast = 0,
        cooldown = 300,
        gcd = "off",

        item = 56488,
        bagItem = true,

        startsCombat = true,
        texture = 135826,
        toggle = "cooldowns",

        usable = function ()
            if GetItemCount( 56488 ) == 0 then return false, "requires charge in bag"
            elseif not IsUsableItem( 56488 ) then return false, "on cooldown or unusable" end
            return true
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 56488 )
            return max( 0, start + duration - query_time )
        end,

        handler = function ()
            if class.file == "MAGE" then
                -- Assume we're proccing Incanter's Absorption.
                if talent.incanters_absorption.enabled and buff.fire_ward.up then applyBuff( "incanters_absorption" ) end
            end
        end,
    },

    healthstone = {
        name = "|cff00ccff[Healthstone]|r",
        cast = 0,
        cooldown = function () return time > 0 and 3600 or 60 end,
        gcd = "off",

        item = 5512,
        bagItem = true,

        startsCombat = false,
        texture = 538745,

        usable = function ()
            if GetItemCount( 5512 ) == 0 then return false, "requires healthstone in bags"
            elseif not IsUsableItem( 5512 ) then return false, "healthstone on CD"
            elseif health.current >= health.max then return false, "must be damaged" end
            return true
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 5512 )
            return max( 0, start + duration - query_time )
        end,

        handler = function ()
            gain( 0.25 * health.max, "health" )
        end,
    },

    cancel_buff = {
        name = '|cff00ccff[Cancel Buff]|r',
        cast = 0,
        gcd = 'off',

        startsCombat = false,

        buff = function () return args.buff_name or nil end,

        indicator = "cancel",
        texture = function ()
            if not args.buff_name then return 134400 end

            local a = class.auras[ args.buff_name ]
            -- if not a then return 134400 end
            if a.texture then return a.texture end

            a = a and a.id
            a = a and GetSpellTexture( a )

            return a or 134400
        end,

        usable = function () return args.buff_name ~= nil, "no buff name detected" end,
        timeToReady = function () return gcd.remains end,
        handler = function ()
            local cancel = args.buff_name and buff[ args.buff_name ]
            cancel = cancel and rawget( cancel, "onCancel" )

            if cancel then
                cancel()
                return
            end

            removeBuff( args.buff_name )
        end,
    },

    null_cooldown = {
        name = "|cff00ccff[Null Cooldown]|r",
        cast = 0,
        gcd = "off",

        startsCombat = false,

        unlisted = true
    },

    trinket1 = {
        name = "|cff00ccff[Trinket #1]",
        cast = 0,
        gcd = "off",
    },

    trinket2 = {
        name = "|cff00ccff[Trinket #2]",
        cast = 0,
        gcd = "off",
    },
} )


-- Use Items
do
    -- Should handle trinkets/items internally.
    -- 1.  Check APLs and don't try to recommend items that have their own APL entries.
    -- 2.  Respect item preferences registered in spec options.

    all:RegisterAbility( "use_items", {
        name = "|cff00ccff[Use Items]|r",
        cast = 0,
        cooldown = 120,
        gcd = 'off',
    } )

    all:RegisterAbility( "heart_essence", {
        name = "|cff00ccff[Heart Essence]|r",
        cast = 0,
        cooldown = 0,
        gcd = 'off',

        item = 158075,
        essence = true,

        toggle = "essences",

        usable = function () return false, "your equipped major essence is supported elsewhere in the priority or is not an active ability" end
    } )
end

all:RegisterAbility( "grim_toll", {
    cast = 0,
    cooldown = 45,
    gcd = "off",
    unlisted = true,

    item = 40256,
    aura = 60437
})
all:RegisterAura( "grim_toll", {
    id = 60437,
    duration = 15,
    max_stack = 1
})

all:RegisterAbility( "mjolnir_runestone", {
    cast = 0,
    cooldown = 45,
    gcd = "off",
    unlisted = true,

    item = 45931,
    aura = 65019
})
all:RegisterAura( "mjolnir_runestone", {
    id = 65019,
    duration = 15,
    max_stack = 1
})

all:RegisterAbility( "dark_matter", {
    cast = 0,
    cooldown = 45,
    gcd = "off",
    unlisted = true,

    item = 46038,
    aura = 65024
})
all:RegisterAura("enigma", {
    id = 92123,
    duration = 15,
    max_stack = 1
})
all:RegisterAbility("unsolvable_riddle", {
    cast = 0,
    cooldown = 45,
    gcd = "off",
    unlisted = false,

    item = 68709,
    aura = 92123
})
all:RegisterAura( "dark_matter", {
    id = 65024,
    duration = 10,
    max_stack = 1
})

all:RegisterAbility( "whispering_fanged_skull", {
    cast = 0,
    cooldown = 45,
    gcd = "off",
    unlisted = true,

    item = 50342,
    aura = 71401
})
all:RegisterAbility( "whispering_fanged_skull_heroic", {
    suffix = strformat( "(%s)", ITEM_HEROIC ),
    cast = 0,
    cooldown = 45,
    gcd = "off",
    unlisted = true,

    item = 50343,
    aura = 71541
})
all:RegisterAura( "icy_rage", {
    id = 71401,
    duration = 15,
    max_stack = 1,
    copy = { 71401, 71541 }
})



-- x.x - Heirloom Trinket(s)
all:RegisterAbility( "touch_of_the_void", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 128318,
    toggle = "cooldowns",
} )


-- 8.3 - WORLD
-- Corruption Curse that impacts resource costs.

all:RegisterAura( "hysteria", {
    id = 312677,
    duration = 30,
    max_stack = 99
} )


-- BFA TRINKETS
-- EQUIPPED EFFECTS
all:RegisterAuras( {
    -- Darkmoon Deck: Squalls
    suffocating_squall = { id = 276132, duration = 26, max_stack = 1 }, -- I made up max duration (assume 13 card types and 2s per card).

    -- Construct Overcharger
    titanic_overcharge = { id = 278070, duration = 10, max_stack = 8 },

    -- Xalzaix's Veiled Eye
    xalzaixs_gaze = { id = 278158, duration = 20, max_stack = 1 },

    -- Syringe of Bloodborne Infirmity
    wasting_infection = { id = 278110, duration = 12, max_stack = 1 },
    critical_prowess = { id = 278109, duration = 6, max_stack = 5 },

    -- Frenetic Corpuscle
    frothing_rage = { id = 278140, duration = 45, max_stack = 4 },

    -- Tear of the Void
    voidspark = { id = 278831, duration = 14, max_stack = 1 },

    -- Prism of Dark Intensity
    dark_intensity = { id = 278378, duration = 18, max_stack = 6,
        meta = {
            -- Stacks every 3 seconds until expiration; should generalize this kind of thing...
            stacks = function ( aura )
                if aura.up then return 1 + floor( ( query_time - aura.applied ) / 3 ) end
                return 0
            end
        }
    },

    -- Plume of the Seaborne Avian
    seaborne_tempest = { id = 278382, duration = 10, max_stack = 1 },

    -- Drust-Runed Icicle
    chill_of_the_runes = { id = 278862, duration = 12, max_stack = 1 },

    -- Permafrost-Encrusted Heart
    coldhearted_instincts = { id = 278388, duration = 15, max_stack = 5, copy = "cold_hearted_instincts",
        meta = {
            -- Stacks every 3 seconds until expiration; should generalize this kind of thing...
            stacks = function ( aura )
                if aura.up then return 1 + floor( ( query_time - aura.applied ) / 3 ) end
                return 0
            end
        }
    },

    -- Spiritbound Voodoo Burl
    coalesced_essence = { id = 278224, duration = 12, max_stack = 1 },

    -- Wing Bone of the Budding Tempest
    avian_tempest = { id = 278253, duration = 10, max_stack = 5 },

    -- Razorcrest of the Enraged Matriarch
    winged_tempest = { id = 278248, duration = 16, max_stack = 1 },

    -- Hurricane Heart
    hurricane_within = { id = 161416, duration = 12, max_stack = 6,
        meta = {
            -- Stacks every 2 seconds until expiration; should generalize this kind of thing...
            stacks = function ( aura )
                if aura.up then return 1 + floor( ( query_time - aura.applied ) / 2 ) end
                return 0
            end
        }
    },

    -- Kraulok's Claw
    krauloks_strength = { id = 278287, duration = 10, max_stack = 1 },

    -- Doom's Hatred
    blood_hatred = { id = 278356, duration = 10, max_stack = 1 },

    -- Lion's Grace
    lions_grace = { id = 278815, duration = 10, max_stack = 1 },

    -- Landoi's Scrutiny
    landois_scrutiny = { id = 281544, duration = 15, max_stack = 1 },

    -- Leyshock's Grand Compilation
    precision_module = { id = 281791, duration = 15, max_stack = 3 }, -- Crit.
    iteration_capacitor = { id = 281792, duration = 15, max_stack = 3 }, -- Haste.
    efficiency_widget = { id = 281794, duration = 15, max_stack = 3 }, -- Mastery.
    adaptive_circuit = { id = 281795, duration = 15, max_stack = 3 }, -- Versatility.
    leyshocks_grand_compilation = {
        alias = { "precision_module", "iteration_capacitor", "efficiency_widget", "adaptive_circuit" },
        aliasMode = "longest",
        aliasType = "buff",
        duration = 15,
    },

    -- Twitching Tentacle of Xalzaix
    lingering_power_of_xalzaix = { id = 278155, duration = 30, max_stack = 5 },
    uncontained_power = { id = 278156, duration = 12, max_stack = 1 },

    -- Surging Alchemist Stone
    -- I believe these buffs are recycled a lot...
    agility = { id = 60233, duration = 15, max_stack = 1 },
    intellect = { id = 60234, duration = 15, max_stack = 1 },
    strength = { id = 60229, duration = 15, max_stack = 1 },

    -- Harlan's Loaded Dice
    loaded_die_mastery = { id = 267325, duration = 15, max_stack = 1 },
    loaded_die_haste = { id = 267327, duration = 15, max_stack = 1 },
    loaded_die_critical_strike = { id = 267330, duration = 15, max_stack = 1 },
    loaded_die = {
        alias = { "loaded_die_mastery", "loaded_die_haste", "loaded_die_critical_strike" },
        aliasMode = "longest",
        aliasType = "buff",
        duration = 15,
    },

    -- Tiny Electromental in a Jar
    phenomenal_power = { id = 267179, duration = 30, max_stack = 12 },

    -- Rezan's Gleaming Eye
    rezans_gleaming_eye = { id = 271103, duration = 15, max_stack = 1 },

    -- Azerokk's Resonating Heart
    resonating_elemental_heart = { id = 268441, duration = 15, max_stack = 1 },

    -- Gore-Crusted Butcher's Block
    butchers_eye = { id = 271104, duration = 15, max_stack = 1 },

    -- Briny Barnacle
    choking_brine = { id = 268194, duration = 6, max_stack = 1 },

    -- Conch of Dark Whispers
    conch_of_dark_whispers = { id = 271071, duration = 15, max_stack = 1 },

    -- Dead Eye Spyglass
    dead_ahead = { id = 268756, duration = 10, max_stack = 1 },
    dead_ahead_crit = { id = 268769, duration = 10, max_stack = 5 },

    -- Lingering Sporepods
    lingering_spore_pods = { id = 268062, duration = 4, max_stack = 1 },

} )


-- BFA TRINKETS/ITEMS
-- Ny'alotha

all:RegisterAbility( "manifesto_of_madness", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 174103,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "manifesto_of_madness_chapter_one" )
    end,
} )

all:RegisterAuras( {
    manifesto_of_madness_chapter_one = {
        id = 313948,
        duration = 10,
        max_stack = 1
    },

    manifesto_of_madness_chapter_two = {
        id = 314040,
        duration = 10,
        max_stack = 1
    }
} )


all:RegisterAbility( "forbidden_obsidian_claw", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 173944,
    toggle = "cooldowns",

    handler = function ()
        applyDebuff( "target", "obsidian_claw" )
    end,
} )

all:RegisterAura( "obsidian_claw", {
    id = 313148,
    duration = 8.5,
    max_stack = 1
} )


all:RegisterAbility( "sigil_of_warding", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 173940,
    toggle = "defensives",

    handler = function ()
        applyBuff( "stoneskin", 8 )
    end,
} )

all:RegisterAura( "stoneskin", {
    id = 313060,
    duration = 16,
    max_stack = 1,
} )


all:RegisterAbility( "writhing_segment_of_drestagath", {
    cast = 0,
    cooldown = 80,
    gcd = "off",

    item = 173946,
    toggle = "cooldowns",
} )


all:RegisterAbility( "lingering_psychic_shell", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 174277,
    toggle = "defensives",

    handler = function ()
        applyBuff( "" )
    end,
} )

all:RegisterAura( "psychic_shell", {
    id = 314585,
    duration = 8,
    max_stack = 1
} )




-- Azshara's EP
all:RegisterAbility( "orgozoas_paralytic_barb", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 168899,
    toggle = "defensives",

    handler = function ()
        applyBuff( "paralytic_spines" )
    end,
} )

all:RegisterAura( "paralytic_spines", {
    id = 303350,
    duration = 15,
    max_stack = 1
} )

all:RegisterAbility( "azsharas_font_of_power", {
    cast = 4,
    channeled = true,
    cooldown = 120,
    gcd = "spell",

    item = 169314,
    toggle = "cooldowns",

    start = function ()
        applyBuff( "latent_arcana_channel" )
    end,

    breakchannel = function ()
        removeBuff( "latent_arcana_channel" )
        applyBuff( "latent_arcana" )
    end,

    finish = function ()
        removeBuff( "latent_arcana_channel" )
        applyBuff( "latent_arcana" )
    end,

    copy = { "latent_arcana" }
} )

all:RegisterAuras( {
    latent_arcana = {
        id = 296962,
        duration = 30,
        max_stack = 5
    },

    latent_arcana_channel = {
        id = 296971,
        duration = 4,
        max_stack = 1
    }
} )


all:RegisterAbility( "shiver_venom_relic", {
    cast = 0,
    cooldown = 60,
    gcd = "spell",

    item = 168905,
    toggle = "cooldowns",

    usable = function ()
        if debuff.shiver_venom.stack < 5 then return false, "shiver_venom is not at max stacks" end
        return true
    end,

    aura = "shiver_venom",
    cycle = "shiver_venom",

    handler = function()
        removeDebuff( "target", "shiver_venom" )
    end,
} )

all:RegisterAura( "shiver_venom", {
    id = 301624,
    duration = 20,
    max_stack = 5
} )


do
    -- local coralGUID, coralApplied, coralStacks = "none", 0, 0

    -- Ashvane's Razor Coral, 169311
    all:RegisterAbility( "ashvanes_razor_coral", {
        cast = 0,
        cooldown = 20,
        gcd = "off",

        item = 169311,
        toggle = "cooldowns",

        --[[ usable = function ()
            if active_dot.razor_coral > 0 and target.unit ~= coralGUID then
                return false, "current target does not have razor_coral applied"
            end
            return true
        end, ]]

        handler = function ()
            if active_dot.razor_coral > 0 then
                removeDebuff( "target", "razor_coral" )
                active_dot.razor_coral = 0

                applyBuff( "razor_coral_crit" )
                setCooldown( "ashvanes_razor_coral", 20 )
            else
                applyDebuff( "target", "razor_coral" )
            end
        end
    } )


    --[[
    local HandleRazorCoral = function( event )
        if not state.equipped.ashvanes_razor_coral then return end

        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            local _, subtype, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName = CombatLogGetCurrentEventInfo()

            if sourceGUID == state.GUID and ( subtype == "SPELL_AURA_APPLIED" or subtype == "SPELL_AURA_REFRESH" or subtype == "SPELL_AURA_APPLIED_DOSE" ) then
                if spellID == 303568 and destGUID then
                    coralGUID = destGUID
                    coralApplied = GetTime()
                    coralStacks = ( subtype == "SPELL_AURA_APPLIED_DOSE" ) and ( coralStacks + 1 ) or 1
                elseif spellID == 303570 then
                    -- Coral was removed.
                    coralGUID = "none"
                    coralApplied = 0
                    coralStacks = 0
                end
            end
        else
            coralGUID = "none"
            coralApplied = 0
            coralStacks = 0
        end
    end

    RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED", HandleRazorCoral )
    RegisterEvent( "PLAYER_REGEN_ENABLED", HandleRazorCoral )

    all:RegisterStateExpr( "coral_time_to_30", function()
        if coralGUID == 0 then return 3600 end
        return Hekili:GetTimeToPctByGUID( coralGUID, 30 ) - ( offset + delay )
    end ) ]]

    all:RegisterAuras( {
        razor_coral = {
            id = 303568,
            duration = 120,
            max_stack = 100, -- ???
            copy = "razor_coral_debuff",
            generate = function( t, auraType )
                local name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = FindUnitDebuffByID( "target", 303568, "PLAYER" )

                if name then
                    -- It's on our actual target, trust it.
                    t.name = name
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime
                    t.applied = expirationTime - duration
                    t.caster = "player"
                    return

                --[[ elseif coralGUID ~= "none" then
                    t.name = class.auras.razor_coral.name
                    t.count = coralStacks > 0 and coralStacks or 1
                    t.applied = coralApplied > 0 and coralApplied or state.query_time
                    t.expires = coralApplied > 0 and ( coralApplied + 120 ) or ( state.query_time + Hekili:GetDeathClockByGUID( coralGUID ) )
                    t.caster = "player"

                    return ]]
                end

                t.name = class.auras.razor_coral.name
                t.count = 0
                t.applied = 0
                t.expires = 0

                t.caster = "nobody"
            end,
        },

        razor_coral_crit = {
            id = 303570,
            duration = 20,
            max_stack = 1,
        }
    } )
end

    all:RegisterAura( "swordguard_embroidery", {
        id = 75176,
        duration = 15,
        max_stack = 1
} )
   

    all:RegisterAbility( "swordguard_embroidery", {
        id = 75176,
        cast = 0,
        cooldown = 45,
        gcd = "off",

        toggle = "cooldowns",
        item = 0,
        itemKey = "swordguard_embroidery",
        texture = 236282,

        handler = function ()
            applyBuff( "swordguard_embroidery" )
        end
    } )
-- Dribbling Inkpod
all:RegisterAura( "conductive_ink", {
    id = 302565,
    duration = 60,
    max_stack = 999, -- ???
    copy = "conductive_ink_debuff"
} )


-- Edicts of the Faithless, 169315

-- Vision of Demise, 169307
all:RegisterAbility( "vision_of_demise", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 169307,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "vision_of_demise" )
    end
} )

all:RegisterAura( "vision_of_demise", {
    id = 303431,
    duration = 10,
    max_stack = 1
} )


-- Aquipotent Nautilus, 169305
all:RegisterAbility( "aquipotent_nautilus", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 169305,
    toggle = "cooldowns",

    handler = function ()
        applyDebuff( "target", "surging_flood" )
    end
} )

all:RegisterAura( "surging_flood", {
    id = 302580,
    duration = 4,
    max_stack = 1
} )


-- Chain of Suffering, 169308
all:RegisterAbility( "chain_of_suffering", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 169308,
    toggle = "defensives",

    handler = function ()
        applyBuff( "chain_of_suffering" )
    end,
} )

all:RegisterAura( "chain_of_suffering", {
    id = 297036,
    duration = 25,
    max_stack = 1
} )

-- Tinkers
if Hekili.IsClassic() then
    all:RegisterAura( "hyperspeed_acceleration", {
        id = 54758,
        duration = 15,
        max_stack = 1
    })
    all:RegisterAbility( "hyperspeed_acceleration", {
        id = 54758,
        known = function () return tinker.hand.spell == 54758 end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        item = function() return tinker.hand.spell == 54758 and tinker.hand.item or 0 end,
        itemKey = "hyperspeed_acceleration",

        texture = function() return tinker.hand.spell == 54758 and tinker.hand.texture or 0 end,
        startsCombat = true,

        toggle = "cooldowns",

        usable = function ()
            return tinker.hand.spell == 54758
        end,

        handler = function()
            applyBuff("hyperspeed_acceleration")
        end
    } )
    -- Increases your primary_stat by 480 for 10 sec.
    all:RegisterAura( "synapse_springs", {
        id = 96228,
        duration = 15,
        max_stack = 1,
        copy = {96228, 96229, 96230}
    })
    -- Increases your Intellect, Agility, or Strength by 480 for 10 sec.  Your highest stat is always chosen.
    all:RegisterAbility( "synapse_springs", {
        id = 82174,
        known = function () return tinker.hand.spell == 82174 end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        item = function() return tinker.hand.spell == 82174 and tinker.hand.item or 0 end,
        itemKey = "synapse_springs",

        texture = function() return tinker.hand.spell == 82174 and tinker.hand.texture or 0 end,
        startsCombat = true,

        toggle = "cooldowns",

        usable = function ()
            return tinker.hand.spell == 82174
        end,

        handler = function()
            applyBuff("synapse_springs")
        end
    } )
end

if Hekili.IsClassic( "synapse_springs" ) then
    all:RegisterAura( "synapse_springs", {
        id = 82174,
        duration = 10,
        max_stack = 1
    })
    all:RegisterAbility( "synapse_springs", {
        id = 82174,
        known = function () return tinker.hand.spell == 82174 end,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        item = function() return tinker.hand.spell == 82174 and tinker.hand.item or 0 end,
        itemKey = "synapse_springs",

        texture = function() return tinker.hand.spell == 82174 and tinker.hand.texture or 0 end,
        startsCombat = true,

        toggle = "cooldowns",

        usable = function ()
            return tinker.hand.spell == 82174
        end,

        handler = function()
            applyBuff("synapse_springs")
        end
    } )
end

-- Mechagon
do
    if not Hekili.IsClassic() then
        all:RegisterGear( "pocketsized_computation_device", 167555 )
        all:RegisterGear( "cyclotronic_blast", 167672 )
        all:RegisterGear( "harmonic_dematerializer", 167677 )

        all:RegisterAura( "cyclotronic_blast", {
            id = 293491,
            duration = function () return 2.5 * haste end,
            max_stack = 1
        } )

        --[[ all:RegisterAbility( "pocketsized_computation_device", {
            -- key = "pocketsized_computation_device",
            cast = 0,
            cooldown = 120,
            gcd = "spell",

            -- item = 167555,
            texture = 2115322,
            bind = { "cyclotronic_blast", "harmonic_dematerializer", "inactive_red_punchcard" },
            startsCombat = true,

            unlisted = true,

            usable = function() return false, "no supported red punchcard installed" end,
            copy = "inactive_red_punchcard"
        } ) ]]

        all:RegisterAbility( "cyclotronic_blast", {
            id = 293491,
            known = function () return equipped.cyclotronic_blast end,
            cast = function () return 1.5 * haste end,
            channeled = function () return cooldown.cyclotronic_blast.remains > 0 end,
            cooldown = function () return equipped.cyclotronic_blast and 120 or 0 end,
            gcd = "spell",

            item = 167672,
            itemCd = 167555,
            itemKey = "cyclotronic_blast",

            texture = 2115322,
            bind = { "pocketsized_computation_device", "inactive_red_punchcard", "harmonic_dematerializer" },
            startsCombat = true,

            toggle = "cooldowns",

            usable = function ()
                return equipped.cyclotronic_blast, "punchcard not equipped"
            end,

            handler = function()
                setCooldown( "global_cooldown", 2.5 * haste )
                applyBuff( "casting", 2.5 * haste )
            end,

            copy = "pocketsized_computation_device"
        } )

        all:RegisterAura( "harmonic_dematerializer", {
            id = 293512,
            duration = 300,
            max_stack = 99
        } )

        all:RegisterAbility( "harmonic_dematerializer", {
            id = 293512,
            known = function () return equipped.harmonic_dematerializer end,
            cast = 0,
            cooldown = 15,
            gcd = "spell",

            item = 167677,
            itemCd = 167555,
            itemKey = "harmonic_dematerializer",

            texture = 2115322,

            bind = { "pocketsized_computation_device", "cyclotronic_blast", "inactive_red_punchcard" },

            startsCombat = true,

            usable = function ()
                return equipped.harmonic_dematerializer, "punchcard not equipped"
            end,

            handler = function ()
                addStack( "harmonic_dematerializer", nil, 1 )
            end
        } )
    end


    -- Hyperthread Wristwraps
    all:RegisterAbility( "hyperthread_wristwraps", {
        cast = 0,
        cooldown = 120,
        gcd = "off",

        item = 168989,

        handler = function ()
            -- Gain 5 seconds of CD for the last 3 spells.
            for i = 1, 3 do
                local ability = prev[i].spell

                if ability and ability ~= "no_action" then
                    gainChargeTime( ability, 5 )
                end
            end
        end,

        copy = "hyperthread_wristwraps_300142"
    } )


    all:RegisterAbility( "neural_synapse_enhancer", {
        cast = 0,
        cooldown = 45,
        gcd = "off",

        item = 168973,

        handler = function ()
            applyBuff( "enhance_synapses" )
        end,

        copy = "enhance_synapses_300612"
    } )

    all:RegisterAura( "enhance_synapses", {
        id = 300612,
        duration = 15,
        max_stack = 1
    } )

    all:RegisterAbility( "wraps_of_electrostatic_potential", {
        cast = 0,
        cooldown = 60,
        gcd = "off",

        item = 169069,

        handler = function()
            applyDebuff( "target", "electrostatic_induction" )
        end,

        auras = {
            electrostatic_induction = {
                id = 300145,
                duration = 8,
                max_stack = 1
            }
        }
    } )
end


-- Shockbiter's Fang
all:RegisterAbility( "shockbiters_fang", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 169318,
    toggle = "cooldowns",

    handler = function () applyBuff( "shockbitten" ) end
} )

all:RegisterAura( "shockbitten", {
    id = 303953,
    duration = 12,
    max_stack = 1
} )


all:RegisterAbility( "living_oil_canister", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 158216,

    copy = "living_oil_cannister"
} )


-- Remote Guidance Device, 169769
all:RegisterAbility( "remote_guidance_device", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 169769,
    toggle = "cooldowns",
} )


-- Modular Platinum Plating, 168965
all:RegisterAbility( "modular_platinum_plating", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 168965,
    toggle = "defensives",

    handler = function ()
        applyBuff( "platinum_plating", nil, 4 )
    end
} )

all:RegisterAura( "platinum_plating", {
    id = 299869,
    duration = 30,
    max_stack = 4
} )


-- Crucible
all:RegisterAbility( "pillar_of_the_drowned_cabal", {
    cast = 0,
    cooldown = 30,
    gcd = "spell", -- ???

    item = 167863,
    toggle = "defensives", -- ???

    handler = function () applyBuff( "mariners_ward" ) end
} )

all:RegisterAura( "mariners_ward", {
    id = 295411,
    duration = 90,
    max_stack = 1,
} )


-- Abyssal Speaker's Guantlets (PROC)
all:RegisterAura( "ephemeral_vigor", {
    id = 295431,
    duration = 60,
    max_stack = 1
} )


-- Fathom Dredgers (PROC)
all:RegisterAura( "dredged_vitality", {
    id = 295134,
    duration = 8,
    max_stack = 1
} )


-- Gloves of the Undying Pact
all:RegisterAbility( "gloves_of_the_undying_pact", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 167219,
    toggle = "defensives", -- ???

    handler = function() applyBuff( "undying_pact" ) end
} )

all:RegisterAura( "undying_pact", {
    id = 295193,
    duration = 6,
    max_stack = 1
} )


-- Insurgent's Scouring Chain (PROC)
all:RegisterAura( "scouring_wake", {
    id = 295141,
    duration = 20,
    max_stack = 1
} )


-- Mindthief's Eldritch Clasp (PROC)
all:RegisterAura( "phantom_pain", {
    id = 295527,
    duration = 180,
    max_stack = 1,
} )


-- Leggings of the Aberrant Tidesage
-- HoT spell ID not found.

-- Zaxasj's Deepstriders (EFFECT)
all:RegisterAura( "deepstrider", {
    id = 295167,
    duration = 3600,
    max_stack = 1
} )


-- Trident of Deep Ocean
-- Custody of the Deep (shield proc)
all:RegisterAura( "custody_of_the_deep_shield", {
    id = 292675,
    duration = 40,
    max_stack = 1
} )
-- Custody of the Deep (mainstat proc)
all:RegisterAura( "custody_of_the_deep_buff", {
    id = 292653,
    duration = 60,
    max_stack = 3
} )


-- Malformed Herald's Legwraps
all:RegisterAbility( "malformed_heralds_legwraps", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 167835,
    toggle = "cooldowns",

    usable = function () return buff.movement.down end,
    handler = function () applyBuff( "void_embrace" ) end,
} )

all:RegisterAura( "void_embrace", {
    id = 295174,
    duration = 12,
    max_stack = 1,
} )


-- Idol of Indiscriminate Consumption
all:RegisterAbility( "idol_of_indiscriminate_consumption", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 167868,
    toggle = "cooldowns",

    handler = function() gain( 2.5 * 7000 * active_enemies, "health" ) end,
} )


-- Lurker's Insidious Gift
all:RegisterAbility( "lurkers_insidious_gift", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 167866,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "insidious_gift" )
        applyDebuff( "suffering" )
    end
} )

all:RegisterAura( "insidious_gift", {
    id = 295408,
    duration = 30,
    max_stack = 1
} )
all:RegisterAura( "suffering", {
    id = 295413,
    duration = 30,
    max_stack = 30,
    meta = {
        stack = function ()
            return buff.insidious_gift.up and floor( 30 - buff.insidious_gift.remains ) or 0
        end
    }
} )


-- Void Stone
all:RegisterAbility( "void_stone", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 167865,
    toggle = "defensives",

    handler = function ()
        applyBuff( "umbral_shell" )
    end,
} )

all:RegisterAura( "umbral_shell", {
    id = 295271,
    duration = 12,
    max_stack = 1
} )


-- ON USE
-- Kezan Stamped Bijou
all:RegisterAbility( "kezan_stamped_bijou", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 165662,
    toggle = "cooldowns",

    handler = function () applyBuff( "kajamite_surge" ) end
} )

all:RegisterAura( "kajamite_surge", {
    id = 285475,
    duration = 12,
    max_stack = 1,
} )


-- Sea Giant's Tidestone
all:RegisterAbility( "sea_giants_tidestone", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 165664,
    toggle = "cooldowns",

    handler = function () applyBuff( "ferocity_of_the_skrog" ) end
} )

all:RegisterAura( "ferocity_of_the_skrog", {
    id = 285482,
    duration = 12,
    max_stack = 1
} )


-- Ritual Feather
all:RegisterAbility( "ritual_feather_of_unng_ak", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 165665,
    toggle = "cooldowns",

    handler = function () applyBuff( "might_of_the_blackpaw" ) end
} )

all:RegisterAura( "might_of_the_blackpaw", {
    id = 285489,
    duration = 16,
    max_stack = 1
} )


-- Battle of Dazar'alor
all:RegisterAbility( "invocation_of_yulon", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 165568,
    toggle = "cooldowns",
} )


all:RegisterAbility( "ward_of_envelopment", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 165569,
    toggle = "defensives",

    handler = function() applyBuff( "enveloping_protection" ) end
} )

all:RegisterAura( "enveloping_protection", {
    id = 287568,
    duration = 10,
    max_stack = 1
} )


-- Everchill Anchor debuff.
all:RegisterAura( "everchill", {
    id = 289525,
    duration = 12,
    max_stack = 10
} )


-- Incandescent Sliver
all:RegisterAura( "incandescent_luster", {
    id = 289523,
    duration = 20,
    max_stack = 10
} )

all:RegisterAura( "incandescent_mastery", {
    id = 289524,
    duration = 20,
    max_stack = 1
} )



all:RegisterAbility( "variable_intensity_gigavolt_oscillating_reactor", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 165572,
    toggle = "cooldowns",

    buff = "vigor_engaged",
    usable = function ()
        if buff.vigor_engaged.stack < 6 then return false, "has fewer than 6 stacks" end
        return true
    end,
    handler = function() applyBuff( "oscillating_overload" ) end
} )

all:RegisterAura( "vigor_engaged", {
    id = 287916,
    duration = 3600,
    max_stack = 6
    -- May need to emulate the stacking portion.
} )

all:RegisterAura( "vigor_cooldown", {
    id = 287967,
    duration = 6,
    max_stack = 1
} )

all:RegisterAura( "oscillating_overload", {
    id = 287917,
    duration = 6,
    max_stack = 1
} )


-- Diamond-Laced Refracting Prism
all:RegisterAura( "diamond_barrier", {
    id = 288034,
    duration = 10,
    max_stack = 1
} )


all:RegisterAbility( "grongs_primal_rage", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 165574,
    toggle = "cooldowns",

    handler = function()
        applyBuff( "primal_rage" )
        setCooldown( "global_cooldown", 4 )
    end
} )

all:RegisterAura( "primal_rage", {
    id = 288267,
    duration = 4,
    max_stack = 1
} )


all:RegisterAbility( "tidestorm_codex", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 165576,
    toggle = "cooldowns",
} )


-- Bwonsamdi's Bargain
all:RegisterAura( "bwonsamdis_due", {
    id = 288193,
    duration = 300,
    max_stack = 1
} )

all:RegisterAura( "bwonsamdis_bargain_fulfilled", {
    id = 288194,
    duration = 360,
    max_stack = 1
} )


all:RegisterAbility( "mirror_of_entwined_fate", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 165578,
    toggle = "defensives",

    handler = function() applyDebuff( "player", "mirror_of_entwined_fate" ) end
} )

all:RegisterAura( "mirror_of_entwined_fate", {
    id = 287999,
    duration = 30,
    max_stack = 1
} )


-- Kimbul's Razor Claw
all:RegisterAura( "kimbuls_razor_claw", {
    id = 288330,
    duration = 6,
    tick_time = 2,
    max_stack = 1
} )


all:RegisterAbility( "ramping_amplitude_gigavolt_engine", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 165580,
    toggle = "cooldowns",

    handler = function() applyBuff( "r_a_g_e" ) end
} )

all:RegisterAura( "rage", {
    id = 288156,
    duration = 18,
    max_stack = 15,
    copy = "r_a_g_e"
} )


-- Crest of Pa'ku
all:RegisterAura( "gift_of_wind", {
    id = 288304,
    duration = 15,
    max_stack = 1
} )


all:RegisterAbility( "endless_tincture_of_fractional_power", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 152636,

    toggle = "cooldowns",

    handler = function ()
        -- I don't know the auras it applies...
    end
} )


all:RegisterAbility( "mercys_psalter", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 155564,

    toggle = "cooldowns",

    handler = function ()
        applyBuff( "potency" )
    end,
} )

all:RegisterAura( "potency", {
    id = 268523,
    duration = 15,
    max_stack = 1,
} )


all:RegisterAbility( "clockwork_resharpener", {
    cast = 0,
    cooldown = 60, -- no CD reported in-game yet.
    gcd = "off",

    item = 161375,

    toggle = "cooldowns",

    handler = function ()
        applyBuff( "resharpened" )
    end,
} )

all:RegisterAura( "resharpened", {
    id = 278376,
    duration = 14,
    max_stack = 7,
    meta = {
        -- Stacks every 2 seconds until expiration; should generalize this kind of thing...
        stacks = function ( aura )
            if aura.up then return 1 + floor( ( query_time - aura.applied ) / 2 ) end
            return 0
        end
    }
} )


all:RegisterAbility( "azurethos_singed_plumage", {
    cast = 0,
    cooldown = 88,
    gcd = "off",

    item = 161377,

    toggle = "cooldowns",

    handler = function ()
        applyBuff( "ruffling_tempest" )
    end,
} )

all:RegisterAura( "ruffling_tempest", {
    id = 278383,
    duration = 15,
    max_stack = 1,
    -- Actually decrements but doesn't appear to use stacks to implement itself.
} )


all:RegisterAbility( "galecallers_beak", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 161379,

    toggle = "cooldowns",

    handler = function ()
        applyBuff( "gale_call" )
    end,
} )

all:RegisterAura( "gale_call", {
    id = 278385,
    duration = 15,
    max_stack = 1,
} )


all:RegisterAbility( "sublimating_iceshard", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 161382,

    toggle = "cooldowns",

    handler = function ()
        applyBuff( "sublimating_power" )
    end,
} )

all:RegisterAura( "sublimating_power", {
    id = 278869,
    duration = 14,
    max_stack = 1,
    -- Decrements after 6 sec but doesn't appear to use stacks to convey this...
} )


all:RegisterAbility( "tzanes_barkspines", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 161411,

    toggle = "cooldowns",

    handler = function ()
        applyBuff( "barkspines" )
    end,
} )

all:RegisterAura( "barkspines", {
    id = 278227,
    duration = 10,
    max_stack = 1,
} )


--[[ Redundant Ancient Knot of Wisdom???
all:RegisterAbility( "sandscoured_idol", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 161417,

    toggle = "cooldowns",

    handler = function ()
        applyBuff( "secrets_of_the_sands" )
    end,
} )

all:RegisterAura( "secrets_of_the_sands", {
    id = 278267,
    duration = 20,
    max_stack = 1,
} ) ]]


all:RegisterAbility( "deployable_vibro_enhancer", {
    cast = 0,
    cooldown = 105,
    gcd = "off",

    item = 161418,

    toggle = "cooldowns",

    handler = function ()
        applyBuff( "vibro_enhanced" )
    end,
} )

all:RegisterAura( "vibro_enhanced", {
    id = 278260,
    duration = 12,
    max_stack = 4,
    meta = {
        -- Stacks every 2 seconds until expiration; should generalize this kind of thing...
        stacks = function ( aura )
            if aura.up then return 1 + floor( ( query_time - aura.applied ) / 3 ) end
            return 0
        end
    }
} )


all:RegisterAbility( "dooms_wake", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 161462,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "dooms_wake" )
    end,
} )

all:RegisterAura( "dooms_wake", {
    id = 278317,
    duration = 16,
    max_stack = 1
} )


all:RegisterAbility( "dooms_fury", {
    cast = 0,
    cooldown = 105,
    gcd = "off",

    item = 161463,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "bristling_fury" )
    end,
} )

all:RegisterAura( "bristling_fury", {
    id = 278364,
    duration = 18,
    max_stack = 1,
} )


all:RegisterAbility( "lions_guile", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 161473,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "lions_guile" )
    end,
} )

all:RegisterAura( "lions_guile", {
    id = 278806,
    duration = 16,
    max_stack = 10,
    meta = {
        stack = function( t ) return t.down and 0 or min( 6, 1 + ( ( query_time - t.app ) / 2 ) ) end,
    }
} )


all:RegisterAbility( "lions_strength", {
    cast = 0,
    cooldown = 105,
    gcd = "off",

    item = 161474,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "lions_strength" )
    end,
} )

all:RegisterAura( "lions_strength", {
    id = 278819,
    duration = 18,
    max_stack = 1,
} )

all:RegisterAbility( "mr_munchykins", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 155567,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "tea_time" )
    end,
} )

all:RegisterAura( "tea_time", {
    id = 268504,
    duration = 15,
    max_stack = 1,
} )

all:RegisterAbility( "bygone_bee_almanac", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 163936,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "process_improvement" )
    end,
} )

all:RegisterAura( "process_improvement", {
    id = 281543,
    duration = 12,
    max_stack = 1,
} ) -- extends on spending resources, could hook here...


all:RegisterAbility( "mydas_talisman", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 158319,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "touch_of_gold" )
    end,
} )

all:RegisterAura( "touch_of_gold", {
    id = 265954,
    duration = 20,
    max_stack = 1,
} )


all:RegisterAbility( "merekthas_fang", {
    cast = 3,
    channeled = true,
    cooldown = 120,
    gcd = "off",

    item = 158367,
    toggle = "cooldowns",

    -- not sure if this debuffs during the channel...
} )


all:RegisterAbility( "razdunks_big_red_button", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 159611,
    toggle = "cooldowns",

    velocity = 10,
} )


all:RegisterAbility( "galecallers_boon", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 159614,
    toggle = "cooldowns",

    usable = function () return buff.movement.down end,
    handler = function ()
        applyBuff( "galecallers_boon" )
    end,
} )

all:RegisterAura( "galecallers_boon", {
    id = 268311,
    duration = 10,
    max_stack = 1,
    meta = {
        expires = function( t ) return max( 0, action.galecallers_boon.lastCast + 10 ) end
    }
} )


all:RegisterAbility( "ignition_mages_fuse", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 159615,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "ignition_mages_fuse" )
    end,
} )

all:RegisterAura( "ignition_mages_fuse", {
    id = 271115,
    duration = 20,
    max_stack = 1,
} )


all:RegisterAbility( "lustrous_golden_plumage", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 159617,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "golden_luster" )
    end,
} )

all:RegisterAura( "golden_luster", {
    id = 271107,
    duration = 20,
    max_stack = 1,
} )


all:RegisterAbility( "mchimbas_ritual_bandages", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 159618,
    toggle = "defensives",

    handler = function ()
        applyBuff( "ritual_wraps" )
    end,
} )

all:RegisterAura( "ritual_wraps", {
    id = 265946,
    duration = 6,
    max_stack = 1,
} )


all:RegisterAbility( "rotcrusted_voodoo_doll", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 159624,
    toggle = "cooldowns",

    handler = function ()
        applyDebuff( "target", "rotcrusted_voodoo_doll" )
    end,
} )

all:RegisterAura( "rotcrusted_voodoo_doll", {
    id = 271465,
    duration = 6,
    max_stack = 1,
} )


all:RegisterAbility( "vial_of_animated_blood", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 159625,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "blood_of_my_enemies" )
    end,
} )

all:RegisterAura( "blood_of_my_enemies", {
    id = 268836,
    duration = 18,
    max_stack = 1,
} )


all:RegisterAbility( "jes_howler", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 159627,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "motivating_howl" )
    end,
} )

all:RegisterAura( "motivating_howl", {
    id = 266047,
    duration = 12,
    max_stack = 1,
} )


all:RegisterAbility( "balefire_branch", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 159630,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "kindled_soul" )
    end,
} )

all:RegisterAura( "kindled_soul", {
    id = 268998,
    duration = 20,
    max_stack = 1,
} )


all:RegisterAbility( "sanguinating_totem", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 160753,
    toggle = "defensives",
} )


all:RegisterAbility( "fetish_of_the_tormented_mind", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 160833,
    toggle = "defensives",

    handler = function ()
        applyDebuff( "target", "doubting_mind" )
    end,
} )

all:RegisterAura( "doubting_mind", {
    id = 273559,
    duration = 5,
    max_stack = 1
} )


all:RegisterAbility( "whirlwings_plumage", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 158215,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "gryphons_pride" )
    end,
} )

all:RegisterAura( "gryphons_pride", {
    id = 268550,
    duration = 20,
    max_stack = 1,
} )



-- PvP Trinkets
-- Medallions
do
    local pvp_medallions = {
        { "dread_aspirants_medallion", 162897 },
        { "dread_gladiators_medallion", 161674 },
        { "sinister_aspirants_medallion", 165220 },
        { "sinister_gladiators_medallion", 165055 },
        { "notorious_aspirants_medallion", 167525 },
        { "notorious_gladiators_medallion", 167377 },
        { "old_corrupted_gladiators_medallion", 172666 },
        { "corrupted_aspirants_medallion", 184058 },
        { "corrupted_gladiators_medallion", 184055 },
        { "sinful_aspirants_medallion", 184052 },
        { "sinful_gladiators_medallion", 181333 },
        { "unchained_aspirants_medallion", 185309 },
        { "unchained_gladiators_medallion", 185304 },
        { "cosmic_aspirants_medallion", 186966 },
        { "cosmic_gladiators_medallion", 186869 },
        { "eternal_aspirants_medallion", 192412 },
        { "eternal_gladiators_medallion", 192298 },
    }

    local pvp_medallions_copy = {}

    for _, v in ipairs( pvp_medallions ) do
        insert( pvp_medallions_copy, v[1] )
        all:RegisterGear( v[1], v[2] )
        all:RegisterGear( "gladiators_medallion", v[2] )
    end

    all:RegisterAbility( "gladiators_medallion", {
        name = function () return "|cff00ccff[" .. ( ( GetSpellInfo( 277179 ) ) or "Gladiator's Medallion" ) .. "]|r" end,
        link = function () return "|cff00ccff[" .. ( ( GetSpellInfo( 277179 ) ) or "Gladiator's Medallion" ) .. "]|r" end,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        item = function ()
            local m
            for _, medallion in ipairs( pvp_medallions ) do
                m = medallion[ 2 ]
                if equipped[ m ] then return m end
            end
            return m
        end,
        items = { 161674, 162897, 165055, 165220, 167377, 167525, 181333, 184052, 184055, 172666, 184058, 185309, 185304, 186966, 186869, 192412, 192298 },
        toggle = "defensives",

        usable = function () return debuff.loss_of_control.up, "requires loss of control effect" end,

        handler = function ()
            applyBuff( "gladiators_medallion" )
        end,

        copy = pvp_medallions_copy
    } )

    all:RegisterAura( "gladiators_medallion", {
        id = 277179,
        duration = 20,
        max_stack = 1
    } )
end

-- Badges
do
    local pvp_badges = {
        { "dread_aspirants_badge", 162966 },
        { "dread_gladiators_badge", 161902 },
        { "sinister_aspirants_badge", 165223 },
        { "sinister_gladiators_badge", 165058 },
        { "notorious_aspirants_badge", 167528 },
        { "notorious_gladiators_badge", 167380 },
        { "corrupted_aspirants_badge", 172849 },
        { "corrupted_gladiators_badge", 172669 },
        { "sinful_aspirants_badge_of_ferocity", 175884 },
        { "sinful_gladiators_badge_of_ferocity", 175921 },
        { "unchained_aspirants_badge_of_ferocity", 185161 },
        { "unchained_gladiators_badge_of_ferocity", 185197 },
        { "cosmic_aspirants_badge_of_ferocity", 186906 },
        { "cosmic_gladiators_badge_of_ferocity", 186866 },
        { "eternal_aspirants_badge_of_ferocity", 192352 },
        { "eternal_gladiators_badge_of_ferocity", 192295 },
    }

    local pvp_badges_copy = {}

    for _, v in ipairs( pvp_badges ) do
        insert( pvp_badges_copy, v[1] )
        all:RegisterGear( v[1], v[2] )
        all:RegisterGear( "gladiators_badge", v[2] )
    end

    all:RegisterAbility( "gladiators_badge", {
        name = function () return "|cff00ccff[" .. ( ( GetSpellInfo( 277185 ) ) or "Gladiator's Badge" ) .. "]|r" end,
        link = function () return "|cff00ccff[" .. ( ( GetSpellInfo( 277185 ) ) or "Gladiator's Badge" ) .. "]|r" end,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        items = { 162966, 161902, 165223, 165058, 167528, 167380, 172849, 172669, 175884, 175921, 185161, 185197, 186906, 186866, 192352, 192295 },
        texture = 135884,

        toggle = "cooldowns",
        item = function ()
            local b

            for i = #pvp_badges, 1, -1 do
                b = pvp_badges[ i ][ 2 ]
                if equipped[ b ] then
                    break
                end
            end
            return b
        end,

        usable = function () return set_bonus.gladiators_badge > 0, "requires Gladiator's Badge" end,
        handler = function ()
            applyBuff( "gladiators_badge" )
        end,

        copy = pvp_badges_copy
    } )

    all:RegisterAura( "gladiators_badge", {
        id = 277185,
        duration = 15,
        max_stack = 1
    } )
end


-- Insignias -- N/A, not on-use.
all:RegisterAura( "gladiators_insignia", {
    id = 277181,
    duration = 20,
    max_stack = 1,
    copy = 345230
} )


-- Safeguard (equipped, not on-use)
all:RegisterAura( "gladiators_safeguard", {
    id = 286342,
    duration = 10,
    max_stack = 1
} )


-- Emblems
do
    local pvp_emblems = {
        -- dread_combatants_emblem = 161812,
        dread_aspirants_emblem = 162898,
        dread_gladiators_emblem = 161675,
        sinister_aspirants_emblem = 165221,
        sinister_gladiators_emblem = 165056,
        notorious_gladiators_emblem = 167378,
        notorious_aspirants_emblem = 167526,
        corrupted_gladiators_emblem = 172667,
        corrupted_aspirants_emblem = 172847,
        sinful_aspirants_emblem = 178334,
        sinful_gladiators_emblem = 178447,
        unchained_aspirants_emblem = 185242,
        unchained_gladiators_emblem = 185282,
        cosmic_aspirants_emblem = 186946,
        cosmic_gladiators_emblem = 186868,
        eternal_aspirants_emblem = 192392,
        eternal_gladiators_emblem = 192297,
    }

    local pvp_emblems_copy = {}

    for k, v in pairs( pvp_emblems ) do
        insert( pvp_emblems_copy, k )
        all:RegisterGear( k, v )
        all:RegisterGear( "gladiators_emblem", v )
    end


    all:RegisterAbility( "gladiators_emblem", {
        name = function () return "|cff00ccff[" .. ( ( GetSpellInfo( 277187 ) ) or "Gladiator's Emblem" ) .. "]|r" end,
        link = function () return "|cff00ccff[" .. ( ( GetSpellInfo( 277187 ) ) or "Gladiator's Emblem" ) .. "]|r" end,
        cast = 0,
        cooldown = 90,
        gcd = "off",

        item = function ()
            local e
            for _, emblem in pairs( pvp_emblems ) do
                e = emblem
                if equipped[ e ] then return e end
            end
            return e
        end,
        items = { 162898, 161675, 165221, 165056, 167378, 167526, 172667, 172847, 178334, 178447, 185242, 185282, 186946, 186868, 192392, 192297 },
        toggle = "cooldowns",

        handler = function ()
            applyBuff( "gladiators_emblem" )
        end,

        copy = pvp_emblems_copy
    } )

    all:RegisterAura( "gladiators_emblem", {
        id = 277187,
        duration = 15,
        max_stack = 1,
    } )
end


-- 8.3 Corrupted On-Use

-- DNI, because potentially you have no enemies w/ Corruption w/in range.
--[[
    all:RegisterAbility( "corrupted_gladiators_breach", {
        cast = 0,
        cooldown = 120,
        gcd = "off",

        item = 174276,
        toggle = "defensives",

        handler = function ()
            applyBuff( "void_jaunt" )
            -- +Debuff?
        end,

        auras = {
            void_jaunt = {
                id = 314517,
                duration = 6,
                max_stack = 1,
            }
        }
} )
]]


all:RegisterAbility( "corrupted_gladiators_spite", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 174472,
    toggle = "cooldowns",

    handler = function ()
        applyDebuff( "target", "gladiators_spite" )
        applyDebuff( "target", "lingering_spite" )
    end,

    auras = {
        gladiators_spite = {
            id = 315391,
            duration = 15,
            max_stack = 1,
        },

        lingering_spite = {
            id = 320297,
            duration = 3600,
            max_stack = 1,
        }
    }
} )


all:RegisterAbility( "corrupted_gladiators_maledict", {
    cast = 0,
    cooldown = 120,
    gcd = "off", -- ???

    item = 172672,
    toggle = "cooldowns",

    handler = function ()
        applyDebuff( "target", "gladiators_maledict" )
    end,

    auras = {
        gladiators_maledict = {
            id = 305252,
            duration = 6,
            max_stack = 1
        }
    }
} )


--[[ WiP: Timewarped Trinkets
do
    local timewarped_trinkets = {
        { "runed_fungalcap",                127184, "shell_of_deterrence",              31771,  20,     1 },
        { "icon_of_the_silver_crescent",    129850, "blessing_of_the_silver_crescent",  194645, 20,     1 },
        { "essence_of_the_martyr",          129851, "essence_of_the_martyr",            194637, 20,     1 },
        { "gnomeregan_autoblocker_601",     129849, "gnome_ingenuity",                  194543, 40,     1 },
        { "emblem_of_fury",                 129937, "lust_for_battle_str",              194638, 20,     1 },
        { "bloodlust_brooch",               129848, "lust_for_battle_agi",              194632, 20,     1 },
        {}

    }

    { "vial_of_the_sunwell",            133462, "vessel_of_the_naaru",              45059,  3600,   1 }, -- vessel_of_the_naaru on-use 45064, 120 sec CD.
end ]]


-- Galewind Chimes
all:RegisterAura( "galewind_chimes", {
    id = 268518,
    duration = 8,
    max_stack = 1,
} )

-- Gilded Loa Figurine
all:RegisterAura( "will_of_the_loa", {
    id = 273974,
    duration = 10,
    max_stack = 1,
} )

-- Emblem of Zandalar
all:RegisterAura( "speed_of_the_spirits", {
    id = 273992,
    duration = 8,
    max_stack = 1,
} )

-- Dinobone Charm
all:RegisterAura( "primal_instinct", {
    id = 273988,
    duration = 7,
    max_stack = 1
} )


all:RegisterAbility( "pearl_divers_compass", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 158162,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "true_north" )
    end,
} )

all:RegisterAura( "true_north", {
    id = 273935,
    duration = 12,
    max_stack = 1,
} )


all:RegisterAbility( "first_mates_spyglass", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 158163,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "spyglass_sight" )
    end,
} )

all:RegisterAura( "spyglass_sight", {
    id = 273955,
    duration = 15,
    max_stack = 1
} )


all:RegisterAbility( "plunderbeards_flask", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 158164,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "bolstered_spirits" )
    end,
} )

all:RegisterAura( "bolstered_spirits", {
    id = 273942,
    duration = 10,
    max_stack = 10,
} )


all:RegisterAura( "sound_barrier", {
    id = 268531,
    duration = 8,
    max_stack = 1,
} )


all:RegisterAbility( "vial_of_storms", {
    cast = 0,
    cooldown = 90,
    gcd = "off",

    item = 158224,
    toggle = "cooldowns",
} )


all:RegisterAura( "sirens_melody", {
    id = 268512,
    duration = 6,
    max_stack = 1,
} )


all:RegisterAura( "tick", {
    id = 274430,
    duration = 6,
    max_stack = 1,
} )

all:RegisterAura( "tock", {
    id = 274431,
    duration = 6,
    max_stack = 1,
} )

all:RegisterAura( "soulguard", {
    id = 274459,
    duration = 12,
    max_stack = 1,
} )


all:RegisterAbility( "berserkers_juju", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 161117,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "berserkers_frenzy" )
    end,
} )

all:RegisterAura( "berserkers_frenzy", {
    id = 274472,
    duration = 10,
    max_stack = 1,
} )


all:RegisterGear( "ancient_knot_of_wisdom", 161417, 166793 )

all:RegisterAbility( "ancient_knot_of_wisdom", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = function ()
        if equipped[161417] then return 161417 end
        return 166793
    end,
    items = { 167417, 166793 },
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "wisdom_of_the_forest_lord" )
    end,
} )

all:RegisterAura( "wisdom_of_the_forest_lord", {
    id = 278267,
    duration = 20,
    max_stack = 5
} )


all:RegisterAbility( "knot_of_ancient_fury", {
    cast = 0,
    cooldown = 60,
    gcd = "off",

    item = 166795,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "fury_of_the_forest_lord" )
    end,
} )

all:RegisterAura( "fury_of_the_forest_lord", {
    id = 278231,
    duration = 12,
    max_stack = 1
} )


-- BREWFEST
all:RegisterAbility( "brawlers_statue", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 117357,
    toggle = "defensives",

    handler = function ()
        applyBuff( "drunken_evasiveness" )
    end
} )

all:RegisterAura( "drunken_evasiveness", {
    id = 127967,
    duration = 20,
    max_stack = 1
} )


-- Various Timewalking Trinkets
all:RegisterAbility( "wrathstone", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 45263,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "wrathstone" )
    end,

    auras = {
        wrathstone = {
            id = 64800,
            duration = 20,
            max_stack = 1
        }
    }
} )


all:RegisterAbility( "skardyns_grace", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 133282,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "speed_of_thought" )
    end,

    auras = {
        speed_of_thought = {
            id = 92099,
            duration = 35,
            max_stack = 1
        }
    }
} )


-- HALLOW'S END
all:RegisterAbility( "the_horsemans_sinister_slicer", {
    cast = 0,
    cooldown = 600,
    gcd = "off",

    item = 117356,
    toggle = "cooldowns",
} )



-- LEGION LEGENDARIES
all:RegisterGear( 'rethus_incessant_courage', 146667 )
    all:RegisterAura( 'rethus_incessant_courage', { id = 241330 } )

all:RegisterGear( 'vigilance_perch', 146668 )
    all:RegisterAura( 'vigilance_perch', { id = 241332, duration =  60, max_stack = 5 } )

all:RegisterGear( 'the_sentinels_eternal_refuge', 146669 )
    all:RegisterAura( 'the_sentinels_eternal_refuge', { id = 241331, duration = 60, max_stack = 5 } )

all:RegisterGear( 'prydaz_xavarics_magnum_opus', 132444 )
    all:RegisterAura( 'xavarics_magnum_opus', { id = 207428, duration = 30 } )



all:RegisterAbility( "draught_of_souls", {
    cast = 0,
    cooldown = 80,
    gcd = 'off',

    item = 140808,

    toggle = 'cooldowns',

    handler = function ()
        applyBuff( "fel_crazed_rage", 3 )
        setCooldown( "global_cooldown", 3 )
    end,
} )

all:RegisterAura( "fel_crazed_rage", {
    id = 225141,
    duration = 3,
})


all:RegisterAbility( "faulty_countermeasure", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 137539,

    toggle = 'cooldowns',

    handler = function ()
        applyBuff( "sheathed_in_frost" )
    end
} )

all:RegisterAura( "sheathed_in_frost", {
    id = 214962,
    duration = 30
} )


all:RegisterAbility( "feloiled_infernal_machine", {
    cast = 0,
    cooldown = 80,
    gcd = 'off',

    item = 144482,

    toggle = 'cooldowns',

    handler = function ()
        applyBuff( "grease_the_gears" )
    end,
} )

all:RegisterAura( "grease_the_gears", {
    id = 238534,
    duration = 20
} )


all:RegisterAbility( "ring_of_collapsing_futures", {
    item = 142173,
    spend = 0,
    cast = 0,
    cooldown = 15,
    gcd = 'off',

    readyTime = function () return debuff.temptation.remains end,
    handler = function ()
        applyDebuff( "player", "temptation", 30, debuff.temptation.stack + 1 )
    end
} )

all:RegisterAura( "temptation", {
    id = 234143,
    duration = 30,
    max_stack = 20
} )


all:RegisterAbility( "forgefiends_fabricator", {
    item = 151963,
    spend = 0,
    cast = 0,
    cooldown = 30,
    gcd = 'off',
} )


all:RegisterAbility( "horn_of_valor", {
    item = 133642,
    spend = 0,
    cast = 0,
    cooldown = 120,
    gcd = 'off',
    toggle = 'cooldowns',
    handler = function () applyBuff( "valarjars_path" ) end
} )

all:RegisterAura( "valarjars_path", {
    id = 215956,
    duration = 30
} )


all:RegisterAbility( "kiljaedens_burning_wish", {
    item = 144259,

    cast = 0,
    cooldown = 75,
    gcd = 'off',

    texture = 1357805,

    toggle = 'cooldowns',
} )


all:RegisterAbility( "might_of_krosus", {
    item = 140799,
    spend = 0,
    cast = 0,
    cooldown = 30,
    gcd = 'off',
    handler = function () if active_enemies > 3 then setCooldown( "might_of_krosus", 15 ) end end
} )


all:RegisterAbility( "ring_of_collapsing_futures", {
    item = 142173,
    spend = 0,
    cast = 0,
    cooldown = 15,
    gcd = 'off',
    readyTime = function () return debuff.temptation.remains end,
    handler = function () applyDebuff( "player", "temptation", 30, debuff.temptation.stack + 1 ) end
} )

all:RegisterAura( 'temptation', {
    id = 234143,
    duration = 30,
    max_stack = 20
} )


all:RegisterAbility( "specter_of_betrayal", {
    item = 151190,
    spend = 0,
    cast = 0,
    cooldown = 45,
    gcd = 'off',
} )


all:RegisterAbility( "tiny_oozeling_in_a_jar", {
    item = 137439,
    spend = 0,
    cast = 0,
    cooldown = 20,
    gcd = "off",
    usable = function () return buff.congealing_goo.stack == 6 end,
    handler = function () removeBuff( "congealing_goo" ) end
} )

all:RegisterAura( "congealing_goo", {
    id = 215126,
    duration = 60,
    max_stack = 6
} )


all:RegisterAbility( "umbral_moonglaives", {
    item = 147012,
    spend = 0,
    cast = 0,
    cooldown = 90,
    gcd = 'off',
    toggle = 'cooldowns',
} )


all:RegisterAbility( "unbridled_fury", {
    item = 139327,
    spend = 0,
    cast = 0,
    cooldown = 120,
    gcd = 'off',
    toggle = 'cooldowns',
    handler = function () applyBuff( "wild_gods_fury" ) end
} )

all:RegisterAura( "wild_gods_fury", {
    id = 221695,
    duration = 30
} )


all:RegisterAbility( "vial_of_ceaseless_toxins", {
    item = 147011,
    spend = 0,
    cast = 0,
    cooldown = 60,
    gcd = 'off',
    toggle = 'cooldowns',
    handler = function () applyDebuff( "target", "ceaseless_toxin", 20 ) end
} )

all:RegisterAura( "ceaseless_toxin", {
    id = 242497,
    duration = 20
} )


all:RegisterAbility( "tome_of_unraveling_sanity", {
    item = 147019,
    spend = 0,
    cast = 0,
    cooldown = 60,
    gcd = "off",
    toggle = "cooldowns",
    handler = function () applyDebuff( "target", "insidious_corruption", 12 ) end
} )

all:RegisterAura( "insidious_corruption", {
    id = 243941,
    duration = 12
} )
all:RegisterAura( "extracted_sanity", {
    id = 243942,
    duration =  24
} )

all:RegisterGear( 'aggramars_stride', 132443 )
all:RegisterAura( 'aggramars_stride', {
    id = 207438,
    duration = 3600
} )

all:RegisterGear( 'sephuzs_secret', 132452 )
all:RegisterAura( 'sephuzs_secret', {
    id = 208051,
    duration = 10
} )
all:RegisterAbility( "buff_sephuzs_secret", {
    name = "Sephuz's Secret (ICD)",
    cast = 0,
    cooldown = 30,
    gcd = "off",

    unlisted = true,
    usable = function () return false end,
} )

all:RegisterGear( 'archimondes_hatred_reborn', 144249 )
all:RegisterAura( 'archimondes_hatred_reborn', {
    id = 235169,
    duration = 10,
    max_stack = 1
} )

all:RegisterGear( 'amanthuls_vision', 154172 )
all:RegisterAura( 'glimpse_of_enlightenment', {
    id = 256818,
    duration = 12
} )
all:RegisterAura( 'amanthuls_grandeur', {
    id = 256832,
    duration = 15
} )

all:RegisterGear( 'insignia_of_the_grand_army', 152626 )

all:RegisterGear( 'eonars_compassion', 154172 )
all:RegisterAura( 'mark_of_eonar', {
    id = 256824,
    duration = 12
} )
all:RegisterAura( 'eonars_verdant_embrace', {
    id = function ()
        if class.file == "SHAMAN" then return 257475 end
        if class.file == "DRUID" then return 257470 end
        if class.file == "MONK" then return 257471 end
        if class.file == "PALADIN" then return 257472 end
        if class.file == "PRIEST" then
            if spec.discipline then return 257473 end
            if spec.holy then return 257474 end
        end
        return 257475
    end,
    duration = 20,
    copy = { 257470, 257471, 257472, 257473, 257474, 257475 }
} )
all:RegisterAura( 'verdant_embrace', {
    id = 257444,
    duration = 30
} )


all:RegisterGear( 'aggramars_conviction', 154173 )
all:RegisterAura( 'celestial_bulwark', {
    id = 256816,
    duration = 14
} )
all:RegisterAura( 'aggramars_fortitude', {
    id = 256831,
    duration = 15
 } )

all:RegisterGear( 'golganneths_vitality', 154174 )
all:RegisterAura( 'golganneths_thunderous_wrath', {
    id = 256833,
    duration = 15
} )

all:RegisterGear( 'khazgoroths_courage', 154176 )
all:RegisterAura( 'worldforgers_flame', {
    id = 256826,
    duration = 12
} )
all:RegisterAura( 'khazgoroths_shaping', {
    id = 256835,
    duration = 15
} )

all:RegisterGear( 'norgannons_prowess', 154177 )
all:RegisterAura( 'rush_of_knowledge', {
    id = 256828,
    duration = 12
} )
all:RegisterAura( 'norgannons_command', {
    id = 256836,
    duration = 15,
    max_stack = 6
} )


-- Legion TW
all:RegisterAbilities( {
    windscar_whetstone = {
        cast = 0,
        cooldown = 120,
        gcd = "off",

        item = 137486,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "slicing_maelstrom" )
        end,

        auras = {
            slicing_maelstrom = {
                id = 214980,
                duration = 6,
                max_stack = 1
            }
        }
    },

    giant_ornamental_pearl = {
        cast = 0,
        cooldown = 60,
        gcd = "off",

        item = 137369,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "gaseous_bubble" )
        end,

        auras = {
            gaseous_bubble = {
                id = 214971,
                duration = 8,
                max_stack = 1
            }
        }
    },

    bottled_hurricane = {
        cast = 0,
        gcd = "off",

        item = 137369,

        toggle = "cooldowns",

        buff = "gathering_clouds",

        handler = function ()
            removeBuff( "gathering_clouds" )
        end,

        auras = {
            gathering_clouds = {
                id = 215294,
                duration = 60,
                max_stack = 10
            }
        }
    },

    shard_of_rokmora = {
        cast = 0,
        cooldown = 120,
        gcd = "off",

        item = 137338,

        toggle = "defensives",

        handler = function ()
            applyBuff( "crystalline_body" )
        end,

        auras = {
            crystalline_body = {
                id = 214366,
                duration = 30,
                max_stack = 1
            }
        }
    },

    talisman_of_the_cragshaper = {
        cast = 0,
        cooldown = 60,
        gcd = "off",

        item = 137344,

        toggle = "defensives",

        handler = function ()
            applyBuff( "stance_of_the_mountain" )
        end,

        auras = {
            stance_of_the_mountain = {
                id = 214423,
                duration = 15,
                max_stack = 1
            }
        }
    },

    tirathons_betrayal = {
        cast = 0,
        cooldown = 75,
        gcd = "off",

        item = 137537,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "darkstrikes" )
        end,

        auras = {
            darkstrikes = {
                id = 215658,
                duration = 15,
                max_stack = 1
            }
        }
    },

    orb_of_torment = {
        cast = 0,
        cooldown = 120,
        gcd = "off",

        item = 137538,

        toggle = "defensives",

        handler = function ()
            applyDebuff( "target", "soul_sap" )
        end,

        auras = {
            soul_sap = {
                id = 215936,
                duration = 20,
                max_stack = 1
            }
        }
    },

    moonlit_prism = {
        cast = 0,
        cooldown = 90,
        gcd = "off",

        item = 137541,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "elunes_light" )
        end,

        auras = {
            elunes_light = {
                id = 215648,
                duration = 20,
                max_stack = 20
            }
        }
    },
} )


ns.addToggle = function( name, default, optionName, optionDesc )

    table.insert( class.toggles, {
        name = name,
        state = default,
        option = optionName,
        oDesc = optionDesc
    } )

    if Hekili.DB.profile[ 'Toggle State: ' .. name ] == nil then
        Hekili.DB.profile[ 'Toggle State: ' .. name ] = default
    end

end


ns.addSetting = function( name, default, options )

    table.insert( class.settings, {
        name = name,
        state = default,
        option = options
    } )

    if Hekili.DB.profile[ 'Class Option: ' .. name ] == nil then
        Hekili.DB.profile[ 'Class Option: ' ..name ] = default
    end

end


ns.addWhitespace = function( name, size )

    table.insert( class.settings, {
        name = name,
        option = {
            name = " ",
            type = "description",
            desc = " ",
            width = size
        }
    } )

end


ns.addHook = function( hook, func )
    class.hooks[ hook ] = func
end


do
    local inProgress = {}

    ns.callHook = function( hook, ... )
        if class.hooks[ hook ] and not inProgress[ hook ] then
            local a1, a2, a3, a4, a5

            inProgress[ hook ] = true
            for _, hook in ipairs( class.hooks[ hook ] ) do
                a1, a2, a3, a4, a5 = hook ( ... )
            end
            inProgress[ hook ] = nil

            if a1 ~= nil then
                return a1, a2, a3, a4, a5
            else
                return ...
            end
        end

        return ...
    end
end


ns.registerCustomVariable = function( var, default )
    state[ var ] = default
end




ns.setClass = function( name )
    -- deprecated.
    --class.file = name
end


function ns.setRange( value )
    class.range = value
end


local function storeAbilityElements( key, values )

    local ability = class.abilities[ key ]

    if not ability then
        ns.Error( "storeAbilityElements( " .. key .. " ) - no such ability in abilities table." )
        return
    end

    for k, v in pairs( values ) do
        ability.elem[ k ] = type( v ) == 'function' and setfenv( v, state ) or v
    end

end
ns.storeAbilityElements = storeAbilityElements


local function modifyElement( t, k, elem, value )

    local entry = class[ t ][ k ]

    if not entry then
        ns.Error( "modifyElement() - no such key '" .. k .. "' in '" .. t .. "' table." )
        return
    end

    if type( value ) == 'function' then
        entry.mods[ elem ] = setfenv( value, Hekili.State )
    else
        entry.elem[ elem ] = value
    end

end
ns.modifyElement = modifyElement



local function setUsableItemCooldown( cd )
    state.setCooldown( "usable_items", cd or 10 )
end


-- For Trinket Settings.
class.itemSettings = {}

local function addItemSettings( key, itemID, options )

    options = options or {}

    --[[ options.icon = {
        type = "description",
        name = function () return select( 2, GetItemInfo( itemID ) ) or format( "[%d]", itemID )  end,
        order = 1,
        image = function ()
            local tex = select( 10, GetItemInfo( itemID ) )
            if tex then
                return tex, 50, 50
            end
            return nil
        end,
        imageCoords = { 0.1, 0.9, 0.1, 0.9 },
        width = "full",
        fontSize = "large"
    } ]]

    options.disabled = {
        type = "toggle",
        name = function () return format( "Disable %s via |cff00ccff[Use Items]|r", select( 2, GetItemInfo( itemID ) ) or ( "[" .. itemID .. "]" ) ) end,
        desc = function( info )
            local output = "If disabled, the addon will not recommend this item via the |cff00ccff[Use Items]|r action.  " ..
                "You can still manually include the item in your action lists with your own tailored criteria."
            return output
        end,
        order = 25,
        width = "full"
    }

    options.minimum = {
        type = "range",
        name = "Minimum Targets",
        desc = "The addon will only recommend this trinket (via |cff00ccff[Use Items]|r) when there are at least this many targets available to hit.",
        order = 26,
        width = "full",
        min = 1,
        max = 10,
        step = 1
    }

    options.maximum = {
        type = "range",
        name = "Maximum Targets",
        desc = "The addon will only recommend this trinket (via |cff00ccff[Use Items]|r) when there are no more than this many targets detected.\n\n" ..
            "This setting is ignored if set to 0.",
        order = 27,
        width = "full",
        min = 0,
        max = 10,
        step = 1
    }

    class.itemSettings[ itemID ] = {
        key = key,
        name = function () return select( 2, GetItemInfo( itemID ) ) or ( "[" .. itemID .. "]" ) end,
        item = itemID,
        options = options,
    }

end


--[[ local function addUsableItem( key, id )
    class.items = class.items or {}
    class.items[ key ] = id

    addGearSet( key, id )
    addItemSettings( key, id )
end
ns.addUsableItem = addUsableItem ]]


function Hekili:GetAbilityInfo( index )

    local ability = class.abilities[ index ]

    if not ability then return end

    -- Decide if more details are needed later.
    return ability.id, ability.name, ability.key, ability.item
end

class.interrupts = {}


local function addPet( key, permanent )
    state.pet[ key ] = rawget( state.pet, key ) or {}
    state.pet[ key ].name = key
    state.pet[ key ].expires = 0

    ns.commitKey( key )
end
ns.addPet = addPet


local function addStance( key, spellID )
    class.stances[ key ] = spellID
    ns.commitKey( key )
end
ns.addStance = addStance


local function setRole( key )

    for k,v in pairs( state.role ) do
        state.role[ k ] = nil
    end

    state.role[ key ] = true

end
ns.setRole = setRole


function Hekili:GetActiveSpecOption( opt )
    if not self.currentSpecOpts then return end
    return self.currentSpecOpts[ opt ]
end


function Hekili:GetActivePack()
    return self:GetActiveSpecOption( "package" )
end


local seen = {}

Hekili.SpecChangeHistory = {}

function Hekili:SpecializationChanged()
    local currentSpec, currentID, _, currentClass

    if Hekili.IsClassic() then
        currentSpec = 1
        _, currentClass, currentID = UnitClass( "player" )
    else
        currentSpec = GetSpecialization()
        currentID = GetSpecializationInfo( currentSpec )

        if currentID == nil then
            C_Timer.After( 0.5, function () Hekili:SpecializationChanged() end )
            return
        end
    end

    HekiliEngine.activeThread = nil
    HekiliEngine.criticalUpdate = true
    HekiliEngine.pendingSpecChange = nil

    insert( self.SpecChangeHistory, {
        spec = currentID,
        time = GetTime(),
        bt = debugstack()
    } )

    for k, _ in pairs( state.spec ) do
        state.spec[ k ] = nil
    end

    for key in pairs( GetResourceInfo() ) do
        state[ key ] = nil
        class[ key ] = nil
    end

    class.primaryResource = nil

    wipe( state.buff )
    wipe( state.debuff )

    wipe( class.auras )
    wipe( class.abilities )
    wipe( class.talents )
    wipe( class.pvptalents )
    wipe( class.powers )
    wipe( class.glyphs )
    wipe( class.gear )
    wipe( class.setBonuses )
    wipe( class.packs )
    wipe( class.resources )
    wipe( class.resourceAuras )

    wipe( class.pets )

    class.potion = nil

    local specs = { 0 }

    if Hekili.IsClassic() then
        specs[ 2 ] = currentID
        state.spec.id = currentID
        state.spec.name = currentClass
        state.spec.key = currentClass:lower()
        state.role.attack = true
        state.spec[ state.spec.key ] = true
    else
        for i = 1, 4 do
            local id, name, _, _, role = GetSpecializationInfo( i )

            if not id then break end

            if i == currentSpec then
                table.insert( specs, 1, id )

                state.spec.id = id
                state.spec.name = name
                state.spec.key = getSpecializationKey( id )

                for k in pairs( state.role ) do
                    state.role[ k ] = false
                end

                if role == "DAMAGER" then
                    state.role.attack = true
                elseif role == "TANK" then
                    state.role.tank = true
                else
                    state.role.healer = true
                end

                state.spec[ state.spec.key ] = true
            else
                table.insert( specs, id )
            end
        end
    end


    for key in pairs( GetResourceInfo() ) do
        state[ key ] = nil
        class[ key ] = nil
    end
    if rawget( state, "rune" ) then state.rune = nil; class.rune = nil; end

    for k in pairs( class.resourceAuras ) do
        class.resourceAuras[ k ] = nil
    end

    class.primaryResource = nil

    for k in pairs( class.stateTables ) do
        rawset( state, k, nil )
        class.stateTables[ k ] = nil
    end

    for k in pairs( class.stateFuncs ) do
        rawset( state, k, nil )
        class.stateFuncs[ k ] = nil
    end

    for k in pairs( class.stateExprs ) do
        class.stateExprs[ k ] = nil
    end

    self.currentSpec = nil
    self.currentSpecOpts = nil

    for i, specID in ipairs( specs ) do
        local spec = class.specs[ specID ]

        if spec then
            if specID == currentID then
                self.currentSpec = spec
                self.currentSpecOpts = rawget( self.DB.profile.specs, specID )
                state.settings.spec = self.currentSpecOpts

                state.spec.can_dual_cast = spec.can_dual_cast
                state.spec.dual_cast = spec.dual_cast

                for res, model in pairs( spec.resources ) do
                    class.resources[ res ] = model
                    state[ res ] = model.state
                end
                if rawget( state, "runes" ) then state.rune = state.runes end

                for k,v in pairs( spec.resourceAuras ) do
                    class.resourceAuras[ k ] = v
                end

                class.primaryResource = spec.primaryResource

                for talent, id in pairs( spec.talents ) do
                    class.talents[ talent ] = id
                end

                for talent, id in pairs( spec.pvptalents ) do
                    class.pvptalents[ talent ] = id
                end

                class.hooks = spec.hooks or {}
                --[[ for name, func in pairs( spec.hooks ) do
                    class.hooks[ name ] = func
                end ]]

                class.variables = spec.variables

                class.potionList.default = "|cFFFFD100Default|r"
            end

            if self.currentSpecOpts and self.currentSpecOpts.potion then
                class.potion = self.currentSpecOpts.potion
            end

            if not class.potion and spec.potion then
                class.potion = spec.potion
            end

            for res, model in pairs( spec.resources ) do
                if not class.resources[ res ] then
                    class.resources[ res ] = model
                    state[ res ] = model.state
                end
            end
            if rawget( state, "runes" ) then state.rune = state.runes end

            for k, v in pairs( spec.auras ) do
                if not class.auras[ k ] then class.auras[ k ] = v end
            end

            for k, v in pairs( spec.powers ) do
                if not class.powers[ k ] then class.powers[ k ] = v end
            end

            for k, v in pairs( spec.glyphs ) do
                if not class.glyphs[ k ] then class.glyphs[ k ] = v end
            end

            for k, v in pairs( spec.abilities ) do
                if not class.abilities[ k ] then class.abilities[ k ] = v end
            end

            for k, v in pairs( spec.gear ) do
                if not class.gear[ k ] then class.gear[ k ] = v end
            end

            for k, v in pairs( spec.setBonuses ) do
                if not class.setBonuses[ k ] then class.setBonuses[ k ] = v end
            end

            for k, v in pairs( spec.pets ) do
                if not class.pets[ k ] then class.pets[ k ] = v end
            end

            for k, v in pairs( spec.totems ) do
                if not class.totems[ k ] then class.totems[ k ] = v end
            end

            for k, v in pairs( spec.potions ) do
                if not class.potions[ k ] then
                    class.potions[ k ] = v
                end
                if class.potion == k and class.auras[ k ] then class.auras.potion = class.auras[ k ] end
            end

            for k, v in pairs( spec.packs ) do
                if not class.packs[ k ] then class.packs[ k ] = v end
            end

            for name, func in pairs( spec.stateExprs ) do
                if not class.stateExprs[ name ] then
                    if rawget( state, name ) then state[ name ] = nil end
                    class.stateExprs[ name ] = func
                end
            end

            for name, func in pairs( spec.stateFuncs ) do
                if not class.stateFuncs[ name ] then
                    if rawget( state, name ) then
                        Hekili:Error( "Cannot RegisterStateFunc for an existing expression ( " .. spec.name .. " - " .. name .. " )." )
                    else
                        class.stateFuncs[ name ] = func
                        rawset( state, name, func )
                        -- Hekili:Error( "Not real error, registered " .. name .. " for " .. spec.name .. " (RSF)." )
                    end
                end
            end

            for name, t in pairs( spec.stateTables ) do
                if not class.stateTables[ name ] then
                    if rawget( state, name ) then
                        Hekili:Error( "Cannot RegisterStateTable for an existing expression ( " .. spec.name .. " - " .. name .. " )." )
                    else
                        class.stateTables[ name ] = t
                        rawset( state, name, t )
                        -- Hekili:Error( "Not real error, registered " .. name .. " for " .. spec.name .. " (RST)." )
                    end
                end
            end

            if spec.id > 0 then
                local s = rawget( Hekili.DB.profile.specs, spec.id )

                if s then
                    for k, v in pairs( spec.settings ) do
                        if s.settings[ v.name ] == nil then s.settings[ v.name ] = v.default end
                    end
                end
            end
        end
    end

    for k in pairs( class.abilityList ) do
        local ability = class.abilities[ k ]

        if ability and ability.id > 0 then
            if not ability.texture or not ability.name then
                local name, _, tex = GetSpellInfo( ability.id )

                if name and tex then
                    ability.name = ability.name or name
                    class.abilityList[ k ] = "|T" .. tex .. ":0|t " .. ability.name
                end
            else
                class.abilityList[ k ] = "|T" .. ability.texture .. ":0|t " .. ability.name
            end
        end
    end

    state.GUID = UnitGUID( 'player' )
    state.player.unit = UnitGUID( 'player' )

    ns.callHook( 'specializationChanged' )

    ns.updateTalents()
    -- ns.updateGear()

    state.swings.mh_speed, state.swings.oh_speed = UnitAttackSpeed( "player" )

    self:UpdateDisplayVisibility()

    -- if not self:ScriptsLoaded() then self:LoadScripts() end

    Hekili:UpdateDamageDetectionForCLEU()

    -- Use tooltip to detect Mage Tower.
    local tooltip = ns.Tooltip
    tooltip:SetOwner( UIParent, "ANCHOR_NONE" )

    wipe( seen )

    for k, v in pairs( class.abilities ) do
        if not seen[ v ] then
            if v.id > 0 then
                local disable
                tooltip:SetSpellByID( v.id )

                for i = tooltip:NumLines(), 5, -1 do
                    local label = tooltip:GetName() .. "TextLeft" .. i
                    local line = _G[ label ]
                    if line then
                        local text = line:GetText()
                        if text == _G.TOOLTIP_NOT_IN_MAGE_TOWER then
                            disable = true
                            break
                        end
                    end
                end

                v.disabled = disable
            end

            seen[ v ] = true
        end
    end

    tooltip:Hide()
end


do
    RegisterEvent( "PLAYER_ENTERING_WORLD", function( event, login, reload )
        if login or reload then
            if Hekili.IsClassic() then
                if state.spec.id ~= select( 3, UnitClass( "player" ) ) then Hekili:SpecializationChanged() end
            else
                local currentSpec = GetSpecialization()
                local currentID = GetSpecializationInfo( currentSpec )

                if currentID ~= state.spec.id then
                    Hekili:SpecializationChanged()
                end
            end
        end
    end )
end


class.trinkets = {
    [0] = { -- for when nothing is equipped.
    },
}


setmetatable( class.trinkets, {
    __index = function( t, k )
    return t[0]
end
} )


-- LibItemBuffs is out of date.
-- Initialize trinket stuff.
do
    local LIB = LibStub( "LibItemBuffs-1.0", true )
    if LIB then
        for k, v in pairs( class.trinkets ) do
            local item = k
            local buffs = LIB:GetItemBuffs( k )

            if type( buffs ) == 'table' then
                for i, buff in ipairs( buffs ) do
                    buff = GetSpellInfo( buff )
                    if buff then
                        all:RegisterAura( ns.formatKey( buff ), {
                            id = i,
                            stat = v.stat,
                            duration = v.duration
                        } )
                        class.trinkets[ k ].buff = ns.formatKey( buff )
                    end
                end
            elseif type( buffs ) == 'number' then
                local buff = GetSpellInfo( buffs )
                if buff then
                    all:RegisterAura( ns.formatKey( buff ), {
                        id = buff,
                        stat = v.stat,
                        duration = v.duration
                    } )
                    class.trinkets[ k ].buff = ns.formatKey( buff )
                end
            end
        end
    end
end

-- Enhancing the existing Class system for MoP compatibility
if Hekili.IsMists then
    -- Set Monk icon and load Monk class resources
    Hekili.ClassIcons = Hekili.ClassIcons or {}
    Hekili.ClassIcons["MONK"] = "Interface\\ICONS\\monk_windwalkerstance"
    
    -- Register Monk specs that were added in MoP
    local classIDs = {
        ["MONK"] = 10,
    }
    
    local specIDs = {
        ["MONK"] = {
            [1] = 268, -- Brewmaster
            [2] = 270, -- Mistweaver
            [3] = 269, -- Windwalker
        }
    }
    
    -- Hook into existing class lookup functions
    if Hekili.GetClassID then
        local originalGetClassID = Hekili.GetClassID
        Hekili.GetClassID = function(class)
            if class == "MONK" and Hekili.IsMists() then
                return classIDs["MONK"]
            else
                return originalGetClassID(class)
            end
        end
    end
    
    if Hekili.GetSpecializationID then
        local originalGetSpecID = Hekili.GetSpecializationID
        Hekili.GetSpecializationID = function(class, spec)
            if class == "MONK" and Hekili.IsMists() then
                return specIDs["MONK"][spec]
            else
                return originalGetSpecID(class, spec)
            end
        end
    end
end
