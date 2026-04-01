local LastInstanceExit
local LoggingState

local validDifficulties = {
    [23] = "Mythic",
    [8]  = "Mythic+",
    [14] = "Normal Raid",
    [15] = "Heroic Raid",
    [16] = "Mythic Raid",
    -- testing
    [208] = "Delve 5",
}

local eventListenerFrame = CreateFrame("Frame", "SlightBoredAddonEventListener", UIParent)

eventListenerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventListenerFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

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

local function EventHandler(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local _, instanceType = IsInInstance()
        if instanceType == "scenario" or instanceType == "party" or instanceType == "raid" then
            local _, _, difficultyID, difficultyName = GetInstanceInfo()
            print ("Entering", instanceType, ", difficulty =", difficultyName .. " (" .. tostring(difficultyID) .. ")")
            if validDifficulties[difficultyID] then
                ToggleMeter(not InCombatLockdown())
            else
                ToggleMeter(false)
            end
        else
            ToggleMeter(false)
        end
    end
end

eventListenerFrame:SetScript("OnEvent", EventHandler)