--[[
    AzerothDash - Terms of Service Compliance Module
    Ensures addon usage complies with WoW ToS and prevents gold laundering
]]

local _, AzerothDash = ...
local ToS = {}
AzerothDash:RegisterModule("ToS", ToS)

-- Current ToS agreement version (bump when terms change)
local TOS_VERSION = 1

-- Local references
local CONSTANTS = AzerothDash.CONSTANTS
local db
local charDB

function ToS:Init()
    -- Delayed until config is loaded
end

function ToS:OnLogin()
    db = AzerothDash.db.global
    charDB = AzerothDash.charDB
    
    -- Check if user has agreed to current ToS
    if db.tosAgreementVersion < TOS_VERSION then
        self:ShowToSDialog()
    end
    
    -- Reset rate limits if needed
    self:ResetRateLimitsIfNeeded()
    
    AzerothDash:Debug("ToS module initialized")
end

-- Show ToS agreement dialog
function ToS:ShowToSDialog()
    local dialog = CreateFrame("Frame", "AzerothDashToSDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(500, 450)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    
    local L = AzerothDash.L
    
    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", dialog.TitleBg, "CENTER", 0, 0)
    title:SetText(L["TOS_TITLE"] or "AzerothDash - Terms of Use")
    
    -- Scroll frame for ToS text
    local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 15, -35)
    scroll:SetPoint("BOTTOMRIGHT", -35, 70)
    
    local content = CreateFrame("Frame")
    content:SetSize(420, 1)
    scroll:SetScrollChild(content)
    
    -- ToS text (hardcoded for legal clarity, but could be localized)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetPoint("TOPRIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetSpacing(4)
    text:SetText([[
|cffffd100Terms of Use & Compliance|r

AzerothDash is designed to facilitate legitimate in-game item trading between players. By using this addon, you agree to the following:

|cffffd1001. Prohibited Uses|r
• This addon may NOT be used for Real Money Trading (RMT)
• This addon may NOT be used for gold selling or buying
• This addon may NOT be used to transfer gold between your own accounts
• This addon may NOT be used for any commercial purposes

|cffffd1002. Safety Limits|r
• Maximum gold per order: 5,000g
• Maximum orders per hour: 10
• Maximum gold movement per hour: 20,000g
• Orders must be for legitimate item trades only

|cffffd1003. Fair Use|r
• All trades should represent fair market value
• The addon includes rate limiting to prevent abuse
• Blizzard's Terms of Service apply to all transactions

|cffffd1004. Privacy|r
• Order data is broadcast to other addon users
• No personal data is collected or transmitted
• Transaction logs are stored locally only

|cffffd1005. Violations|r
• Users who violate these terms may be blocked
• Abuse may result in addon restrictions
• Report suspicious activity using /ad report

By clicking "I Agree", you confirm that you will use this addon responsibly and in accordance with WoW's Terms of Service.
]])
    
    content:SetHeight(text:GetStringHeight() + 20)
    
    -- Agreement buttons
    local agreeBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    agreeBtn:SetSize(120, 30)
    agreeBtn:SetPoint("BOTTOM", -70, 20)
    agreeBtn:SetText(L["TOS_AGREE"] or "I Agree")
    agreeBtn:SetScript("OnClick", function()
        db.tosAgreementVersion = TOS_VERSION
        dialog:Hide()
        AzerothDash:Print(L["TOS_THANKS"] or "Thank you for agreeing to the Terms of Use.")
    end)
    
    local disagreeBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    disagreeBtn:SetSize(120, 30)
    disagreeBtn:SetPoint("BOTTOM", 70, 20)
    disagreeBtn:SetText(L["TOS_DECLINE"] or "Decline")
    disagreeBtn:SetScript("OnClick", function()
        dialog:Hide()
        AzerothDash:Print(L["TOS_MUST_AGREE"] or "You must agree to the Terms of Use to use AzerothDash.")
        -- Disable functionality
        AzerothDash.state.tosDeclined = true
    end)
    
    dialog:Show()
end

-- Rate limiting
function ToS:ResetRateLimitsIfNeeded()
    local now = GetTime()
    local hourAgo = now - 3600
    local dayAgo = now - 86400
    
    -- Reset hourly counters
    if charDB.rateLimit.lastReset < hourAgo then
        charDB.rateLimit.ordersThisHour = 0
        charDB.rateLimit.lastReset = now
    end
    
    -- Reset gold tracking
    if charDB.rateLimit.lastGoldReset < hourAgo then
        charDB.rateLimit.goldThisHour = 0
        charDB.rateLimit.lastGoldReset = now
    end
    
    -- Reset daily counter at midnight (approximate)
    if charDB.rateLimit.ordersToday > 0 and charDB.rateLimit.lastDailyReset and charDB.rateLimit.lastDailyReset < dayAgo then
        charDB.rateLimit.ordersToday = 0
        charDB.rateLimit.lastDailyReset = now
    end
end

-- Check if order is allowed
function ToS:CanCreateOrder(goldAmount)
    local L = AzerothDash.L
    
    -- Check if ToS was declined
    if AzerothDash.state.tosDeclined then
        AzerothDash:Print(L["TOS_DECLINED"] or "You must accept the Terms of Use to create orders.")
        return false
    end
    
    -- Check gold limits
    if goldAmount > CONSTANTS.MAX_GOLD_PER_ORDER then
        AzerothDash:Print(string.format(L["TOS_MAX_GOLD"] or "Order value exceeds maximum of %dg per order (ToS compliance).", CONSTANTS.MAX_GOLD_PER_ORDER))
        return false
    end
    
    if goldAmount < CONSTANTS.MIN_ORDER_VALUE then
        AzerothDash:Print(string.format(L["TOS_MIN_GOLD"] or "Minimum order value is %dg.", CONSTANTS.MIN_ORDER_VALUE))
        return false
    end
    
    -- Reset counters if needed
    self:ResetRateLimitsIfNeeded()
    
    -- Check hourly order limit
    if charDB.rateLimit.ordersThisHour >= CONSTANTS.MAX_ORDERS_PER_HOUR then
        AzerothDash:Print(L["TOS_HOUR_LIMIT"] or "Hourly order limit reached. Please wait before creating more orders.")
        return false
    end
    
    -- Check hourly gold limit
    if (charDB.rateLimit.goldThisHour + goldAmount) > CONSTANTS.MAX_GOLD_PER_HOUR then
        AzerothDash:Print(L["TOS_GOLD_LIMIT"] or "Hourly gold movement limit approaching. Please wait before creating high-value orders.")
        return false
    end
    
    -- Check daily order limit
    if charDB.rateLimit.ordersToday >= CONSTANTS.MAX_ORDERS_PER_DAY then
        AzerothDash:Print(L["TOS_DAILY_LIMIT"] or "Daily order limit reached. Please try again tomorrow.")
        return false
    end
    
    return true
end

-- Record order creation for rate limiting
function ToS:RecordOrder(goldAmount)
    charDB.rateLimit.ordersThisHour = charDB.rateLimit.ordersThisHour + 1
    charDB.rateLimit.goldThisHour = charDB.rateLimit.goldThisHour + goldAmount
    charDB.rateLimit.ordersToday = charDB.rateLimit.ordersToday + 1
    
    -- Set first reset time if not set
    if charDB.rateLimit.lastReset == 0 then
        charDB.rateLimit.lastReset = GetTime()
    end
    if charDB.rateLimit.lastGoldReset == 0 then
        charDB.rateLimit.lastGoldReset = GetTime()
    end
    if not charDB.rateLimit.lastDailyReset then
        charDB.rateLimit.lastDailyReset = GetTime()
    end
    
    -- Add to audit log
    self:AddAuditEntry("CREATE_ORDER", goldAmount)
end

-- Audit logging
function ToS:AddAuditEntry(action, details)
    local entry = {
        timestamp = GetTime(),
        action = action,
        details = details,
        player = UnitName("player"),
        zone = GetZoneText(),
    }
    
    table.insert(db.auditLog, 1, entry)
    
    -- Trim log if too large
    while #db.auditLog > CONSTANTS.AUDIT_LOG_SIZE do
        table.remove(db.auditLog)
    end
end

-- Get audit log
function ToS:GetAuditLog()
    return db.auditLog
end

-- Report player
function ToS:ReportPlayer(playerName, reason)
    if not playerName or playerName == "" then
        AzerothDash:Print("Usage: /ad report PlayerName-Realm reason")
        return
    end
    
    db.blockedSenders[playerName] = {
        reportedAt = GetTime(),
        reason = reason or "Suspected ToS violation",
        reportedBy = UnitName("player"),
    }
    
    -- Add to audit log
    self:AddAuditEntry("REPORT_PLAYER", playerName .. ": " .. (reason or "No reason given"))
    
    AzerothDash:Print("Player " .. playerName .. " has been reported and blocked.")
end

-- Check if sender is blocked
function ToS:IsPlayerBlocked(playerName)
    return db.blockedSenders[playerName] ~= nil
end

-- Filter orders based on safety settings
function ToS:ShouldShowOrder(order)
    -- Check if globally blocked
    if db.blockedSenders[order.sender] then
        return false
    end
    
    -- Check friends only mode
    if db.friendsOnlyMode then
        if not C_FriendList.IsFriend(order.sender) then
            return false
        end
    end
    
    -- Check guild only mode
    if db.guildOnlyMode then
        if not IsInGuild() or not IsGuildMember(order.sender) then
            return false
        end
    end
    
    -- Check gold limits
    if order.reward > CONSTANTS.MAX_GOLD_PER_ORDER then
        AzerothDash:Debug("Filtered order exceeding gold limit from", order.sender)
        return false
    end
    
    return true
end

-- Show rate limit status
function ToS:ShowRateLimits()
    self:ResetRateLimitsIfNeeded()
    
    AzerothDash:Print("|cffffd100Rate Limits (per character):|r")
    AzerothDash:Print(string.format("Orders this hour: %d/%d", charDB.rateLimit.ordersThisHour, CONSTANTS.MAX_ORDERS_PER_HOUR))
    AzerothDash:Print(string.format("Gold this hour: %s/%s", AzerothDash:FormatGold(charDB.rateLimit.goldThisHour * 10000), AzerothDash:FormatGold(CONSTANTS.MAX_GOLD_PER_HOUR * 10000)))
    AzerothDash:Print(string.format("Orders today: %d/%d", charDB.rateLimit.ordersToday, CONSTANTS.MAX_ORDERS_PER_DAY))
end
