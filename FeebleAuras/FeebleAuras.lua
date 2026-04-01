local Loaded = 0
local CurrentlyActive = false
local LastInstanceExit
local LoggingState

local colours = {
    ["lightred"] = "ff9999",
    ["lightgreen"] = "90ee90",
    ["lightblue"] = "87cefa",
}

local function AddColour(str, colour)
    str = str or ""
    local rgb = colours[colour]
    if not rgb then
        if colour:match("^[0-9a-fA-F]{6}$") == nil then
            return str
        end
        rgb = colour
    end

    return "|cff" .. rgb .. str .. "|r"
end

local function Set (list)

    if type(list) ~= "table" then
        return {}
    end

    for k, _ in pairs(list) do
        if type(k) ~= "number" then
            -- probably already a set
            return list
        end
    end

    local set = {}

    for _, l in ipairs(list) do
        set[l] = true
    end
    return set
end

local function GetAny(set)
    local longest = nil
    local maxLen = 0

    for k in pairs(set) do
        local len = #k
        if len > maxLen then
            longest = k
            maxLen = len
        end
    end

    return longest
end

local function SplitString(str)
    local result = {}

    for word in str:gmatch("%S+") do
        table.insert(result, word)
    end

    return result
end

local function Prepend(value, list)
    local new = { value }

    for i = 1, #list do
        new[i + 1] = list[i]
    end
    return new
end

local function ConcatKeys(set, sep, prefix)
    local t = {}
    for k in pairs(set) do
        if prefix then
            t[#t + 1] = prefix .. k
        else
            t[#t + 1] = k
        end
    end
    return table.concat(t, sep or ", ")
end

local function AppendList(set1, set2)
    local new = {}

    for k in pairs(set1) do
        new[k] = true
    end

    for k in pairs(set2) do
        new[k] = true
    end

    return new
end

local validDifficulties = {
    [23] = "Mythic",
    [8]  = "Mythic+",
    [14] = "Normal Raid",
    [15] = "Heroic Raid",
    [16] = "Mythic Raid",
    [208] = "Delve 5",
}

local DamageMeter

function ToggleMeter(show)
    local ok, err = pcall(function()
        if not DamageMeter then
            DamageMeter = _G["DamageMeter"]
        end

        if not DamageMeter then
            error("Cannot find Damage Meter")
        end

        if DamageMeter then
            if show == nil then
                DamageMeter:SetShown(not DamageMeter:IsShown())
            elseif show ~= DamageMeter:IsShown() then
                DamageMeter:SetShown(show)
            end
        end
    end)

    if not ok then
        print("ToggleMeter Error:", err)
    end
end

local eventListenerFrame = CreateFrame("Frame", "SlightBoredAddonEventListener", UIParent)

eventListenerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventListenerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventListenerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventListenerFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventListenerFrame:RegisterEvent("ADDON_LOADED")

function Activate(active)
    local ok, err = pcall(function()
        if active == nil then
            active = not CurrentlyActive
        end

        if active then
            eventListenerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            eventListenerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
            if CurrentlyActive ~= nil and Loaded >= 2 then
                print ("Damage Meter Auto-Toggle Enabled")
            end
            CurrentlyActive = true
        else
            eventListenerFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            eventListenerFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
            if CurrentlyActive ~= nil and Loaded >= 2 then
                print ("Damage Meter Auto-Toggle Disabled")
            end
            CurrentlyActive = false
        end
    end)

    if not ok and Loaded >= 2 then
        print("Activation Error:", err)
    end
end

function ToggleLogging(active)
    if LoggingState == nil or LoggingState ~= active then
        local now = GetTime()
        if active == false and now - LastInstanceExit > 5 then
            LastInstanceExit = now
        end

        local result = LoggingCombat(active)
        if result == nil then
            print ("Combat Logging rate limited, last seen", LoggingState and "on" or "off")
        else
            print ("Combat Logging", result and "enabled" or "disabled" )
            LoggingState = result
        end
    end
end

function AutoActivate(active)
    ToggleLogging(active)
    if FeebleAurasGlobalData.UserEnabled == true then
        Activate(active)
    else
        if Loaded >= 2 then
            print ("Auto activation currently disabled, run", AddColour("/sb on", "lightblue"))
        end
    end
end

function UserActivate(active)
    if active ~= nil then
        FeebleAurasGlobalData.UserEnabled = active
    else
        FeebleAurasGlobalData.UserEnabled = not FeebleAurasGlobalData.UserEnabled
    end

    Activate(FeebleAurasGlobalData.UserEnabled == true)
end

local function EventHandler(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        local inCombat = InCombatLockdown()
        ToggleMeter(not inCombat)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local _, instanceType = IsInInstance()
        if instanceType == "scenario" or instanceType == "party" or instanceType == "raid" then
            local _, _, difficultyID, difficultyName = GetInstanceInfo()
            print ("Entering", instanceType, ", difficulty =", difficultyName .. " (" .. tostring(difficultyID) .. ")")
            if validDifficulties[difficultyID] then
                -- enable auto
                AutoActivate(true)
                ToggleMeter(not InCombatLockdown())
            else
                -- disable auto
                AutoActivate(false)
                ToggleMeter(false)
            end
        else
            -- disable auto
            AutoActivate(false)
            ToggleMeter(false)
        end

        if Loaded < 2 then
            Loaded = Loaded + 1
        end
    elseif event == "ADDON_LOADED" then
        if (...) == "FeebleAuras" then
            FeebleAurasGlobalData = FeebleAurasGlobalData or {}

            if FeebleAurasGlobalData.UserEnabled == nil then
                FeebleAurasGlobalData.UserEnabled = true
            end
            FeebleAurasCharacterData = FeebleAurasCharacterData or {}
            Loaded = Loaded + 1
        end
    end
end

eventListenerFrame:SetScript("OnEvent", EventHandler)

local positiveSynonyms = Set { "on", "enable", "activate", "yes", "y" }
local negativeSynonyms = Set { "off", "disable", "deactivate", "no", "n" }
local helpSynonyms = Set { "help", "h", "/?" }

local function InjectHelp(root)
    root.commands = root.commands or {}
    local rootCmds = root.commands or {}

    local hasHelp = false
    for _, cmd in pairs(rootCmds) do
        for alias in pairs(cmd.aliases) do
            if helpSynonyms[alias] then
                hasHelp = true
                break
            end
        end
    end

    if not hasHelp then
        table.insert(rootCmds, {
            aliases = helpSynonyms,
            description = "Show detailed info for this command",
            handler = function(opts)
                local commandsOnly = false
                if opts then
                    for _, v in pairs(opts) do
                        if v == "c" then
                            commandsOnly = true
                        end
                    end
                end

                print("--------------------")
                if not commandsOnly then
                    print(AddColour("Synonyms", "lightgreen") .. ":", ConcatKeys(root.aliases, ", ", "/"))
                end

                if #rootCmds > 0 then
                    print(AddColour("Options", "lightgreen") .. ":")
                    for _, c in ipairs(rootCmds) do
                        local mainOption = GetAny(c.aliases) or "none"
                        print("  " .. AddColour(mainOption, "lightblue") ..":", c.description or "No description")
                    end
                end
                print("--------------------")

            end
        })
    end

    -- recurse into subcommands
    for _, cmd in ipairs(rootCmds) do
        if cmd.aliases ~= helpSynonyms then
            InjectHelp(cmd)
        end
    end
end

local SlashCommands = {
    {
        aliases = Set {"sb", "slightlybored"},
        description = "Main commands",
        commands = {
            {
                aliases = positiveSynonyms,
                description = "Enable auto-show",
                handler = function()
                    UserActivate(true)
                end,
            },
            {
                aliases = negativeSynonyms,
                description = "Disable auto-show",
                handler = function()
                    UserActivate(false)
                end,
            },
            {
                aliases = Set { "toggle", "t" },
                description = "Toggle auto-show",
                handler = function()
                    UserActivate()
                end,
            },
            {
                aliases = Set { "meter", "meters" },
                description = "Meter functions",
                commands = {
                    {
                        aliases = Set(AppendList(Set {"show", "s"}, positiveSynonyms)),
                        description = "Show meter",
                        handler = function()
                            ToggleMeter(true)
                        end,
                    },
                    {
                        aliases = Set(AppendList(Set {"hide", "h"}, positiveSynonyms)),
                        description = "Hide meter",
                        handler = function()
                            ToggleMeter(false)
                        end,
                    },
                    {
                        aliases = Set { "toggle", "t" },
                        description = "Toggle meter",
                        handler = function()
                            ToggleMeter()
                        end,
                    }
                }
            },
        },
    },
    {
        aliases = Set {"tome"},
        description = "Turns auto-show on",
        handler = function()
            UserActivate(true)
        end,
    },
    {
        aliases = Set {"toyou"},
        description = "Turns auto-show off",
        handler = function()
            UserActivate(false)
        end,
    }
}

for _, root in ipairs(SlashCommands) do
    InjectHelp(root)
end

local function FindByAlias(list, input)
    if not input then
        return nil
    end

    for _, item in ipairs(list) do
        if item.aliases[input] then
            return item
        end
    end

end

local function CallHandler(cmd, args)
    if type(cmd.handler) == "function" then
        cmd.handler(args)
        return true
    end
    return false
end

local function HandleCommand(alias, root, msg)
    local args
    if type(msg) == "table" then
        args = msg
    else
        args = SplitString(string.lower(msg or ""))
    end
    local arg = table.remove(args, 1)

    local rootCmds = root.commands or {}
    local rootDesc = root.description or "Unknown Command"

    if not arg or arg == "" then
        if not CallHandler(root) then
            print("Invalid command \"".. AddColour(arg, "lightred") .. "\"")
            HandleCommand(alias, root, "help c")
        end
        return
    end

    if #rootCmds > 0 then
        local cmd = FindByAlias(rootCmds, arg)

        if not cmd then
            print("Invalid option \"".. AddColour(arg, "lightred") .. "\"")
            HandleCommand(alias, root, "help c") --recursive
        else
            HandleCommand(alias, cmd, args) --recursive
        end
    else
        if not CallHandler(root, Prepend(arg, args)) then
            print(rootDesc, "no more options, something has gone wrong")
        end
    end
end

function RegisterSlashCommands ()
    for i, root in ipairs(SlashCommands) do
        local baseName = "SBCMD" .. i
        local j = 1
        for alias in pairs(root.aliases) do
            local key =  baseName .. "X" .. j

            _G["SLASH_" .. key .. "1"] = "/" .. alias
            j = j + 1

            SlashCmdList[key] = function(msg)
                HandleCommand(alias, root, msg)
            end
        end
    end
end

RegisterSlashCommands()
