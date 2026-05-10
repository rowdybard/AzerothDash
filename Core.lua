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
    if self.strings and self.strings["PRINT_PREFIX"] then
        DEFAULT_CHAT_FRAME:AddMessage(self.strings["PRINT_PREFIX"] .. " " .. msg)
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
    
    -- Only register events here; config/locale need PLAYER_LOGIN (UnitName is nil at ADDON_LOADED)
    self.eventFrame:RegisterEvent("PLAYER_LOGIN")
    self.eventFrame:RegisterEvent("PLAYER_LOGOUT")
    
    self.state.isLoaded = true
    self:Debug("Core initialized")
end

-- Event handlers table
AzerothDash.events = {}

function AzerothDash.events:PLAYER_LOGIN()
    self:Debug("Player login")
    
    -- Load config and locale now that UnitName("player") is available
    local ok, err = pcall(function() self:LoadConfig() end)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000AzerothDash [LoadConfig] error:|r " .. tostring(err))
        return
    end
    
    ok, err = pcall(function() self:LoadLocalization() end)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000AzerothDash [LoadLocalization] error:|r " .. tostring(err))
        return
    end
    
    -- Initialize all modules (pcall so one crash doesn't block the rest)
    local function SafeInit(name, mod)
        if not mod then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000AzerothDash [" .. name .. "] SKIP: module nil|r")
            return
        end
        if not mod.OnLogin then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000AzerothDash [" .. name .. "] SKIP: OnLogin nil|r")
            return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888AzerothDash [" .. name .. "] calling OnLogin...|r")
        local ok, err = pcall(function() mod:OnLogin() end)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000AzerothDash [" .. name .. "] FAIL:|r " .. tostring(err))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AzerothDash [" .. name .. "] OK|r")
        end
    end
    SafeInit("ToS",          self.modules.ToS)
    SafeInit("Transactions", self.modules.Transactions)
    SafeInit("Network",      self.modules.Network)
    SafeInit("UI",           self.modules.UI)
    SafeInit("Minimap",      self.modules.Minimap)
    
    self:Print(self.strings["LOADED_MESSAGE"] or "AzerothDash loaded! Use /ad or click the minimap button.")
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
    
    if command == "nuclear" then
        local p = DEFAULT_CHAT_FRAME
        p:AddMessage("|cffff0000NUCLEAR TEST|r")
        
        -- Create the simplest possible frame WITH BackdropTemplate
        local testFrame = CreateFrame("Frame", "AzerothDashTest", UIParent, "BackdropTemplate")
        testFrame:SetSize(200, 200)
        testFrame:SetPoint("CENTER")
        testFrame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, edgeSize = 16})
        testFrame:SetBackdropColor(0, 0, 0, 0.8)
        testFrame:EnableMouse(true)
        testFrame:SetMovable(true)
        testFrame:RegisterForDrag("LeftButton")
        testFrame:SetScript("OnDragStart", testFrame.StartMoving)
        testFrame:SetScript("OnDragStop", testFrame.StopMovingOrSizing)
        
        -- Close button
        local close = CreateFrame("Button", nil, testFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        close:SetScript("OnClick", function() testFrame:Hide() end)
        
        -- Show button
        local showBtn = CreateFrame("Button", nil, testFrame, "UIPanelButtonTemplate")
        showBtn:SetSize(100, 30)
        showBtn:SetPoint("CENTER")
        showBtn:SetText("Show Main UI")
        showBtn:SetScript("OnClick", function()
            local UI = AzerothDash.modules.UI
            if UI then
                if not UI:GetMainFrame() then
                    pcall(function() UI:OnLogin() end)
                end
                if UI:GetMainFrame() then
                    UI:ToggleMainFrame()
                    p:AddMessage("Main UI toggled!")
                else
                    p:AddMessage("|cffff0000Main UI still nil|r")
                end
            end
        end)
        
        testFrame:Show()
        p:AddMessage("Test frame shown. Click 'Show Main UI' to trigger the real UI.")
        
    elseif command == "trace" then
        local p = DEFAULT_CHAT_FRAME
        p:AddMessage("|cffffd100AzerothDash Trace:|r")
        local UI = AzerothDash.modules.UI
        if not UI then p:AddMessage("|cffff0000UI module nil|r") return end
        
        -- Step 1: Check what UI module has
        p:AddMessage("Step 1 - UI methods:")
        for k, v in pairs(UI) do
            if type(v) == "function" then
                p:AddMessage("  fn: " .. k)
            end
        end
        
        -- Step 2: Try CreateMainFrame directly
        p:AddMessage("Step 2 - calling CreateMainFrame...")
        UI.L = AzerothDash.strings
        UI.db = AzerothDash.db.profile
        local ok, err = pcall(function()
            -- Set UI's locals via OnLogin's first part
            UI:OnLogin()
        end)
        p:AddMessage("  OnLogin: " .. tostring(ok) .. " err=" .. tostring(err))
        
        -- Step 3: Check global frame
        local globalFrame = _G["AzerothDashMainFrame"]
        p:AddMessage("Step 3 - _G.AzerothDashMainFrame: " .. tostring(globalFrame))
        if globalFrame then
            p:AddMessage("  IsShown: " .. tostring(globalFrame:IsShown()))
            p:AddMessage("  IsVisible: " .. tostring(globalFrame:IsVisible()))
            p:AddMessage("  GetWidth: " .. tostring(globalFrame:GetWidth()))
            p:AddMessage("  Trying Show()...")
            globalFrame:Show()
            p:AddMessage("  After Show, IsShown: " .. tostring(globalFrame:IsShown()))
        end
        
        -- Step 4: GetMainFrame
        p:AddMessage("Step 4 - UI:GetMainFrame(): " .. tostring(UI:GetMainFrame()))
        p:AddMessage("Step 4 - UI.mainFrame: " .. tostring(UI.mainFrame))
    elseif command == "status" then
        local p = DEFAULT_CHAT_FRAME
        p:AddMessage("|cffffd100AzerothDash Status Report:|r")
        p:AddMessage("  db: " .. tostring(AzerothDash.db and "OK" or "NIL"))
        p:AddMessage("  db.profile: " .. tostring(AzerothDash.db and AzerothDash.db.profile and "OK" or "NIL"))
        p:AddMessage("  strings: " .. tostring(AzerothDash.strings and "OK" or "NIL"))
        for name, mod in pairs(AzerothDash.modules) do
            local hasOnLogin = mod.OnLogin and "yes" or "NO"
            p:AddMessage("  module [" .. name .. "] OnLogin=" .. hasOnLogin)
        end
        local UI = AzerothDash.modules.UI
        p:AddMessage("  UI module: " .. tostring(UI and "OK" or "NIL"))
        p:AddMessage("  UI.mainFrame: " .. tostring(UI and UI.mainFrame and "OK" or "NIL"))
        p:AddMessage("  UI:GetMainFrame(): " .. tostring(UI and UI.GetMainFrame and tostring(UI:GetMainFrame()) or "NIL"))
        -- Try calling OnLogin manually with full error
        if UI then
            local ok, err = pcall(function() UI:OnLogin() end)
            p:AddMessage("  UI:OnLogin() test: " .. (ok and "|cff00ff00OK|r" or "|cffff0000FAIL: " .. tostring(err) .. "|r"))
        end
    elseif command == "debug" then
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
        local p = DEFAULT_CHAT_FRAME
        local UI = AzerothDash.modules.UI
        p:AddMessage("UI=" .. tostring(UI))
        if not UI then p:AddMessage("UI MODULE NIL") return end
        p:AddMessage("GetMainFrame=" .. tostring(UI:GetMainFrame()))
        if not UI:GetMainFrame() then
            local ok, err = pcall(function() UI:OnLogin() end)
            p:AddMessage("OnLogin ok=" .. tostring(ok) .. " err=" .. tostring(err))
            p:AddMessage("GetMainFrame after=" .. tostring(UI:GetMainFrame()))
        end
        if UI:GetMainFrame() then
            UI:ToggleMainFrame()
            p:AddMessage("ToggleMainFrame called")
        else
            p:AddMessage("STILL NIL")
        end
    end
end
