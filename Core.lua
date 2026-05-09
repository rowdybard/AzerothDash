--[[
    AzerothDash - Core Module
    In-game item delivery and courier service for Azeroth
    Version: 1.0.0
]]

local addonName, AzerothDash = ...
_G.AzerothDash = AzerothDash

-- Version info
AzerothDash.VERSION = "1.0.0"
AzerothDash.DATA_VERSION = 2

-- Constants
AzerothDash.CONSTANTS = {
    COMM_PREFIX = "AzDash",
    CHANNEL_NAME = "AzerothDashGlobal",
    ORDER_TIMEOUT = 1800,  -- 30 minutes
    SPAM_THROTTLE = 5.0,   -- Seconds between broadcasts (increased for ToS safety)
    MAX_ORDER_AGE = 3600,  -- 1 hour max
    MAX_ITEMS_PER_ORDER = 6,
    UI_SCALE_BASE = 768,   -- Reference resolution for scaling
    
    AUDIT_LOG_SIZE = 100,             -- Keep last 100 transactions
    
    -- Transaction timeout (how long courier has to deliver)
    TRANSACTION_TIMEOUT = 1800,       -- 30 minutes to complete delivery
    CONFIRMATION_TIMEOUT = 300,       -- 5 minutes for requester to confirm
}

-- Runtime state
AzerothDash.state = {
    availableOrders = {},
    myOrders = {},
    lastSendTime = 0,
    isLoaded = false,
    debugMode = false,
    tosDeclined = false,
}

-- Transaction status constants
AzerothDash.STATUS = {
    PENDING = "PENDING",           -- Order broadcast, waiting for dasher
    ACCEPTED = "ACCEPTED",       -- Dasher accepted, in progress
    DELIVERED = "DELIVERED",     -- Dasher marked as delivered
    COMPLETED = "COMPLETED",     -- Requester confirmed receipt
    DISPUTED = "DISPUTED",       -- Requester reported issue
    CANCELLED = "CANCELLED",     -- Requester cancelled
    EXPIRED = "EXPIRED",         -- Dasher didn't deliver in time
}

-- Event frame
AzerothDash.eventFrame = CreateFrame("Frame")
AzerothDash.eventFrame:RegisterEvent("ADDON_LOADED")

AzerothDash.eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            AzerothDash:Init()
        end
    else
        local handler = AzerothDash.events[event]
        if handler then
            handler(AzerothDash, ...)
        end
    end
end)

-- Module references
AzerothDash.modules = {}

function AzerothDash:RegisterModule(name, module)
    self.modules[name] = module
    if module.Init then
        module:Init()
    end
end

function AzerothDash:GetModule(name)
    return self.modules[name]
end

-- Debug output
function AzerothDash:Debug(...)
    if self.state.debugMode then
        local msg = string.join(" ", tostringall(...))
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[AD Debug]|r " .. msg)
    end
end

-- Print wrapper
function AzerothDash:Print(msg)
    if self.L and self.L["PRINT_PREFIX"] then
        DEFAULT_CHAT_FRAME:AddMessage(self.L["PRINT_PREFIX"] .. " " .. msg)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[AzerothDash]|r " .. msg)
    end
end

-- Get screen scale factor for responsive UI
function AzerothDash:GetScaleFactor()
    local screenHeight = GetScreenHeight()
    local baseHeight = self.CONSTANTS.UI_SCALE_BASE
    return math.max(0.8, math.min(1.2, screenHeight / baseHeight))
end

-- Apply scale to a frame
function AzerothDash:ApplyScale(frame, baseScale)
    local scale = (baseScale or 1) * self:GetScaleFactor()
    frame:SetScale(scale)
    return scale
end

-- Initialize addon
function AzerothDash:Init()
    if self.state.isLoaded then return end
    
    -- Load Config first
    self:LoadConfig()
    
    -- Load Localization
    self:LoadLocalization()
    
    -- Register remaining events
    self.eventFrame:RegisterEvent("PLAYER_LOGIN")
    self.eventFrame:RegisterEvent("PLAYER_LOGOUT")
    
    self.state.isLoaded = true
    self:Debug("Core initialized")
end

-- Event handlers table
AzerothDash.events = {}

function AzerothDash.events:PLAYER_LOGIN()
    self:Debug("Player login")
    
    -- Initialize all modules
    if self.modules.ToS then
        self.modules.ToS:OnLogin()
    end
    if self.modules.Transactions then
        self.modules.Transactions:OnLogin()
    end
    if self.modules.Network then
        self.modules.Network:OnLogin()
    end
    if self.modules.UI then
        self.modules.UI:OnLogin()
    end
    if self.modules.Minimap then
        self.modules.Minimap:OnLogin()
    end
    
    self:Print(self.L["LOADED_MESSAGE"] or "AzerothDash loaded! Use /ad or click the minimap button.")
end

function AzerothDash.events:PLAYER_LOGOUT()
    self:SaveConfig()
end

-- Slash commands
SLASH_AZEROTHDASH1 = "/ad"
SLASH_AZEROTHDASH2 = "/azerothdash"
SLASH_AZEROTHDASH3 = "/dash"

SlashCmdList["AZEROTHDASH"] = function(msg)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()
    
    if command == "debug" then
        AzerothDash.state.debugMode = not AzerothDash.state.debugMode
        AzerothDash:Print("Debug mode " .. (AzerothDash.state.debugMode and "enabled" or "disabled"))
    elseif command == "reset" then
        AzerothDash:ResetConfig()
        ReloadUI()
    elseif command == "config" or command == "options" then
        if AzerothDash.modules.UI then
            AzerothDash.modules.UI:OpenConfig()
        end
    elseif command == "report" then
        if rest and rest ~= "" then
            local playerName, reason = rest:match("^(%S+)%s*(.*)$")
            if AzerothDash.modules.ToS then
                AzerothDash.modules.ToS:ReportPlayer(playerName, reason)
            end
        else
            AzerothDash:Print("Usage: /ad report PlayerName-Realm reason")
        end
    elseif command == "tutorial" then
        if AzerothDash.modules.ToS then
            AzerothDash.modules.ToS:ShowTutorial()
        end
    elseif command == "limits" or command == "rate" then
        if AzerothDash.modules.ToS then
            AzerothDash.modules.ToS:ShowRateLimits()
        end
    elseif command == "available" or command == "avail" then
        -- Toggle courier availability
        local db = AzerothDash.db.profile.courier
        db.available = not db.available
        if db.available then
            AzerothDash:Print("|cff00ff00You are now AVAILABLE for deliveries!|r")
            if AzerothDash.modules.UI then
                AzerothDash.modules.UI:SetupCourierNotifications()
            end
        else
            AzerothDash:Print("|cffff0000You are now OFFLINE for deliveries.|r")
        end
        -- Update checkbox if visible
        if AzerothDash.modules.UI and AzerothDash.modules.UI.UpdateCourierIndicator then
            AzerothDash.modules.UI:UpdateCourierIndicator()
        end
    elseif command == "audit" then
        if AzerothDash.state.debugMode then
            local audit = AzerothDash.modules.ToS and AzerothDash.modules.ToS:GetAuditLog()
            if audit then
                AzerothDash:Print("|cffffd100Recent Audit Log:|r")
                for i = 1, math.min(10, #audit) do
                    local entry = audit[i]
                    local timeStr = date("%H:%M:%S", entry.timestamp)
                    AzerothDash:Print(string.format("%s - %s: %s", timeStr, entry.action, entry.details or ""))
                end
            end
        else
            AzerothDash:Print("Audit log only available in debug mode (/ad debug)")
        end
    elseif command == "help" then
        AzerothDash:Print("|cffffd100AzerothDash Commands:|r")
        AzerothDash:Print("/ad - Toggle main window")
        AzerothDash:Print("/ad config - Open settings")
        AzerothDash:Print("/ad available - Toggle courier availability")
        AzerothDash:Print("/ad limits - Show rate limits")
        AzerothDash:Print("/ad report PlayerName reason - Report a suspicious player")
        AzerothDash:Print("/ad tutorial - Replay the tutorial")
        AzerothDash:Print("/ad debug - Toggle debug mode")
        AzerothDash:Print("/ad reset - Reset all settings")
    else
        -- Toggle main window
        if AzerothDash.modules.UI then
            AzerothDash.modules.UI:ToggleMainFrame()
        end
    end
end
