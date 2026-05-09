--[[
    AzerothDash - Configuration Module
]]

local _, AzerothDash = ...

-- Default configuration
local defaults = {
    global = {
        debugMode = false,
        soundEnabled = true,
        showMinimap = true,
        showNotifications = true,
        orderTimeout = 1800,
        maxDisplayOrders = 50,
        filterOwnFaction = false,
        autoAcceptFriends = false,
        autoAcceptGuild = false,
        friendsOnlyMode = false,      -- ToS safety: only trade with friends
        guildOnlyMode = false,        -- ToS safety: only trade with guild
        tosAgreementVersion = 0,      -- Track ToS agreement
        auditLog = {},                -- Transaction audit trail
        blockedSenders = {},          -- Reported/blocked players
    },
    profile = {
        window = {
            point = "CENTER",
            relPoint = "CENTER",
            x = 0,
            y = 0,
            width = 460,
            height = 500,
            scale = 1.0,
        },
        minimap = {
            hide = false,
            angle = 0,
            radius = 80,
            lock = false,
        },
        ui = {
            fontSize = "medium", -- small, medium, large
            compactMode = false,
            showTooltips = true,
            animateRows = true,
        },
        notifications = {
            sound = true,
            visual = true,
            chat = false,
        },
    },
    char = {
        preferredZone = nil,
        deliveryStats = {
            completed = 0,
            earned = 0,
        },
        requestStats = {
            placed = 0,
            fulfilled = 0,
            spent = 0,
        },
        blockedPlayers = {},
        -- Rate limiting tracking
        rateLimit = {
            ordersThisHour = 0,
            goldThisHour = 0,
            ordersToday = 0,
            lastReset = 0,
            lastGoldReset = 0,
        },
    },
}

function AzerothDash:LoadConfig()
    -- Initialize saved variables
    AzerothDashDB = AzerothDashDB or {}
    AzerothDashCache = AzerothDashCache or {}
    AzerothDashCharDB = AzerothDashCharDB or {}
    
    -- Set up defaults for global DB
    for k, v in pairs(defaults.global) do
        if AzerothDashDB[k] == nil then
            AzerothDashDB[k] = v
        end
    end
    
    -- Set up defaults for profile DB
    if not AzerothDashDB.profiles then
        AzerothDashDB.profiles = {}
    end
    
    local profileKey = UnitName("player") .. " - " .. GetRealmName()
    if not AzerothDashDB.profiles[profileKey] then
        AzerothDashDB.profiles[profileKey] = CopyTable(defaults.profile)
    end
    
    -- Merge with defaults for any new settings
    for k, v in pairs(defaults.profile) do
        if AzerothDashDB.profiles[profileKey][k] == nil then
            AzerothDashDB.profiles[profileKey][k] = v
        elseif type(v) == "table" and type(AzerothDashDB.profiles[profileKey][k]) == "table" then
            -- Deep merge for tables
            for subK, subV in pairs(v) do
                if AzerothDashDB.profiles[profileKey][k][subK] == nil then
                    AzerothDashDB.profiles[profileKey][k][subK] = subV
                end
            end
        end
    end
    
    self.db = {
        global = AzerothDashDB,
        profile = AzerothDashDB.profiles[profileKey],
    }
    
    -- Character DB
    for k, v in pairs(defaults.char) do
        if AzerothDashCharDB[k] == nil then
            AzerothDashCharDB[k] = type(v) == "table" and CopyTable(v) or v
        end
    end
    self.charDB = AzerothDashCharDB
    
    self:Debug("Config loaded for", profileKey)
end

function AzerothDash:SaveConfig()
    -- Config is saved automatically by WoW, but we can do any pre-save cleanup here
    self:Debug("Config saved")
end

function AzerothDash:ResetConfig()
    AzerothDashDB = nil
    AzerothDashCharDB = nil
    self:Print("Configuration reset. Reloading UI...")
end

function AzerothDash:GetProfile()
    return self.db.profile
end

function AzerothDash:GetGlobal()
    return self.db.global
end

function AzerothDash:GetCharDB()
    return self.charDB
end

-- Migration from old DB format
function AzerothDash:MigrateOldDB()
    if AzerothDashDB and AzerothDashDB.minimap and not AzerothDashDB.profiles then
        -- Old format detected, migrate
        self:Debug("Migrating old database format")
        local oldData = CopyTable(AzerothDashDB)
        AzerothDashDB = { profiles = {} }
        
        local profileKey = UnitName("player") .. " - " .. GetRealmName()
        AzerothDashDB.profiles[profileKey] = {
            minimap = oldData.minimap or defaults.profile.minimap,
            window = oldData.window or defaults.profile.window,
            ui = defaults.profile.ui,
            notifications = defaults.profile.notifications,
        }
        AzerothDashDB.soundEnabled = oldData.soundEnabled
    end
end
