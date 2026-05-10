--[[
    AzerothDash - Terms of Service Compliance Module
    Ensures addon usage complies with WoW ToS and prevents gold laundering
]]

local _, AzerothDash = ...
local ToS = {}
AzerothDash:RegisterModule("ToS", ToS)

-- Current ToS agreement version (bump when terms change)
local TOS_VERSION = 1
local TUTORIAL_VERSION = 1  -- Bump when tutorial content changes

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
    
    -- Initialize tutorial tracking
    if not db.tutorialCompleted then
        db.tutorialCompleted = 0
    end
    
    -- Show tutorial for first-time users
    if db.tutorialCompleted < TUTORIAL_VERSION then
        self:ShowTutorial()
    elseif db.tosAgreementVersion < TOS_VERSION then
        -- Tutorial done but need ToS agreement
        self:ShowToSDialog()
    end
    
    -- Reset rate limits if needed
    self:ResetRateLimitsIfNeeded()
    
    AzerothDash:Debug("ToS module initialized")
end

-- Tutorial slides content
local tutorialSlides = {
    {
        title = "Welcome to AzerothDash!",
        icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
        content = [[
|cffffd100Hi there! Welcome to AzerothDash!|r

This addon helps you get items delivered anywhere in Azeroth!

|cff00ff00Here's the simple version:|r
• You need an item but don't want to travel? Ask for delivery!
• You want to make gold by helping others? Be a courier!
• Everyone wins!

Think of it like this: You're at home and want pizza. Instead of going to the pizza place, you pay someone to bring it to you. Same idea, but with WoW items!

Click "Next" to learn how it works!
        ]],
    },
    {
        title = "How It Works (Super Simple!)",
        icon = "Interface\\Icons\\inv_misc_note_01",
        content = [[
|cffffd100How to Request an Item:|r

1. Open AzerothDash (click the bag icon on your minimap)
2. Drag the item you want from your bags
3. Type how much gold you'll pay (the "tip")
4. Click "Broadcast Order"
5. Wait for someone to accept!

|cffffd100How to Deliver (Make Gold!):|r

1. Open AzerothDash
2. Click "Deliver" tab
3. See what people need
4. Click "Dash" on an order you can fill
5. Buy/trade for the item
6. Meet them and trade!
7. Get paid!

|cff888888It's like being a delivery driver, but in Azeroth!|r
        ]],
    },
    {
        title = "Safety First! 🛡️",
        icon = "Interface\\Icons\\inv_shield_04",
        content = [[
|cffffd100Staying Safe (Read This!)|r

|cff00ff00For Requesters (People Ordering):|r
• Only pay AFTER you get the item (in the trade window)
• The courier will mark "Delivered" - you click "Confirm" when you have the item
• If something goes wrong, click "Issue" to report it

|cff00ff00For Couriers (People Delivering):|r
• Only give the item AFTER they put gold in the trade window
• Mark "Delivered" only after you've actually traded
• The requester must confirm - that's your proof!

|cff00ccffThe addon tracks everything, so if someone scams, everyone will know!|r

|cff888888Golden Rule: Never trade outside the game. Always use the trade window!|r
        ]],
    },
    {
        title = "The Golden Rules 📜",
        icon = "Interface\\Icons\\inv_misc_book_09",
        content = [[
|cffffd100Promise to Be a Good Citizen|r

By using this addon, you agree to:

✓ |cff00ff00BE HONEST|r - Don't scam people. It's a game, but real people are behind the characters.

✓ |cff00ff00BE FAIR|r - Pay what you promised. Deliver what you promised.

✓ |cff00ff00BE KIND|r - Mistakes happen. Communicate if there's a problem.

✓ |cff00ff00NO RMT|r - This is NOT for buying/selling gold with real money.

✓ |cff00ff00NO EXPLOITS|r - Don't use this to move gold between your own accounts.

|cff888888Scammers get reported and their reputation score goes down. Bad actors get blocked by the community.|r

Click "Next" to read the official Terms of Service.
        ]],
    },
    {
        title = "Terms of Service (The Serious Stuff)",
        icon = "Interface\\Icons\\inv_scroll_01",
        content = [[
|cffffd100Official Rules You Must Follow:|r

1. |cffff0000NO Real Money Trading|r - This addon is for in-game gold only.

2. |cffff0000NO Commercial Use|r - Don't use this to run a business or sell services.

3. |cffff0000NO Gold Laundering|r - Don't use this to move gold between your alts.

4. |cffff0000Respect the Limits|r - Max 5000g per order, max 10 orders per hour.

5. |cffff0000Blizzard's Rules Apply|r - This addon follows WoW's Terms of Service.

6. |cffff0000You Can Be Reported|r - Bad actors can be reported and blocked.

|cff888888Breaking these rules can get you banned from WoW. Don't risk it!|r
        ]],
    },
    {
        title = "Your Pledge 🤝",
        icon = "Interface\\Icons\\spell_holy_heal",
        content = [[
|cffffd100Final Step: Your Promise|r

Type the following in the box below to continue:

|cff00ccff"I promise to use AzerothDash honestly and fairly. I will not scam others, and I understand that scammers get reported and blocked. I will follow WoW's Terms of Service."|r

(You don't have to type the whole thing - just type: |cff00ff00I AGREE|r)

This is your digital handshake. Be a good person, and everyone benefits!

|cff888888Communities thrive when people help each other. Let's make Azeroth a better place, one delivery at a time!|r
        ]],
        requireText = "I AGREE",
    },
}

-- Tutorial wizard
function ToS:ShowTutorial()
    local currentSlide = 1
    local tutorialFrame = nil
    local L = AzerothDash.strings
    
    local function ShowSlide(index)
        local slide = tutorialSlides[index]
        if not slide then
            -- Tutorial complete
            db.tutorialCompleted = TUTORIAL_VERSION
            tutorialFrame:Hide()
            -- Now show ToS dialog
            self:ShowToSDialog()
            return
        end
        
        -- Update frame content
        tutorialFrame.titleText:SetText(slide.title)
        tutorialFrame.icon:SetTexture(slide.icon)
        tutorialFrame.contentText:SetText(slide.content)
        
        -- Update page counter
        tutorialFrame.pageText:SetText(string.format("Step %d of %d", index, #tutorialSlides))
        
        -- Show/hide text input for pledge slide
        if slide.requireText then
            tutorialFrame.editBox:Show()
            tutorialFrame.editBox:SetText("")
            tutorialFrame.editBox:SetFocus()
            tutorialFrame.nextBtn:Disable()
        else
            tutorialFrame.editBox:Hide()
            tutorialFrame.nextBtn:Enable()
        end
        
        -- Update button text
        if index == #tutorialSlides then
            tutorialFrame.nextBtn:SetText("I Agree & Continue")
        else
            tutorialFrame.nextBtn:SetText("Next →")
        end
        
        -- Enable/disable back button
        if index == 1 then
            tutorialFrame.backBtn:Disable()
        else
            tutorialFrame.backBtn:Enable()
        end
    end
    
    -- Create tutorial frame
    tutorialFrame = CreateFrame("Frame", "AzerothDashTutorial", UIParent, "BasicFrameTemplateWithInset")
    tutorialFrame:SetSize(600, 500)
    tutorialFrame:SetPoint("CENTER")
    tutorialFrame:SetFrameStrata("DIALOG")
    tutorialFrame:SetMovable(true)
    tutorialFrame:EnableMouse(true)
    tutorialFrame:RegisterForDrag("LeftButton")
    tutorialFrame:SetScript("OnDragStart", tutorialFrame.StartMoving)
    tutorialFrame:SetScript("OnDragStop", tutorialFrame.StopMovingOrSizing)
    tutorialFrame:SetScript("OnHide", function()
        -- Ensure tutorial completion is tracked
        if currentSlide <= #tutorialSlides then
            -- User closed early, mark as completed anyway to not annoy
            db.tutorialCompleted = TUTORIAL_VERSION
        end
    end)
    
    -- Block interaction with rest of game
    tutorialFrame:EnableKeyboard(true)
    tutorialFrame:SetPropagateKeyboardInput(false)
    
    -- Title
    local titleBg = tutorialFrame.TitleBg or tutorialFrame:CreateTexture(nil, "BACKGROUND")
    titleBg:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-Highlight")
    titleBg:SetPoint("TOP", 0, -8)
    titleBg:SetSize(580, 30)
    
    local titleText = tutorialFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("TOP", 0, -15)
    titleText:SetText("Welcome!")
    tutorialFrame.titleText = titleText
    
    -- Icon
    local icon = tutorialFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(64, 64)
    icon:SetPoint("TOPLEFT", 20, -50)
    tutorialFrame.icon = icon
    
    -- Content text
    local contentText = tutorialFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    contentText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 15, 0)
    contentText:SetPoint("TOPRIGHT", -20, -50)
    contentText:SetWidth(480)
    contentText:SetJustifyH("LEFT")
    contentText:SetSpacing(3)
    contentText:SetText("")
    tutorialFrame.contentText = contentText
    
    -- Text input for pledge
    local editBox = CreateFrame("EditBox", nil, tutorialFrame, "InputBoxTemplate")
    editBox:SetSize(550, 30)
    editBox:SetPoint("BOTTOM", 0, 80)
    editBox:SetAutoFocus(false)
    editBox:Hide()
    editBox:SetScript("OnTextChanged", function(self)
        local slide = tutorialSlides[currentSlide]
        if slide and slide.requireText then
            if self:GetText():upper() == slide.requireText:upper() then
                tutorialFrame.nextBtn:Enable()
            else
                tutorialFrame.nextBtn:Disable()
            end
        end
    end)
    editBox:SetScript("OnEnterPressed", function()
        if tutorialFrame.nextBtn:IsEnabled() then
            tutorialFrame.nextBtn:Click()
        end
    end)
    tutorialFrame.editBox = editBox
    
    local editLabel = tutorialFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editLabel:SetPoint("BOTTOM", editBox, "TOP", 0, 5)
    editLabel:SetText("Type 'I AGREE' to continue:")
    editLabel:SetTextColor(1, 0.82, 0)
    editLabel:Hide()
    tutorialFrame.editLabel = editLabel
    
    editBox:SetScript("OnShow", function()
        editLabel:Show()
    end)
    editBox:SetScript("OnHide", function()
        editLabel:Hide()
    end)
    
    -- Page counter
    local pageText = tutorialFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pageText:SetPoint("BOTTOM", 0, 50)
    pageText:SetTextColor(0.7, 0.7, 0.7)
    tutorialFrame.pageText = pageText
    
    -- Back button
    local backBtn = CreateFrame("Button", nil, tutorialFrame, "UIPanelButtonTemplate")
    backBtn:SetSize(100, 30)
    backBtn:SetPoint("BOTTOMLEFT", 20, 15)
    backBtn:SetText("← Back")
    backBtn:SetScript("OnClick", function()
        if currentSlide > 1 then
            currentSlide = currentSlide - 1
            ShowSlide(currentSlide)
        end
    end)
    tutorialFrame.backBtn = backBtn
    
    -- Next button
    local nextBtn = CreateFrame("Button", nil, tutorialFrame, "UIPanelButtonTemplate")
    nextBtn:SetSize(150, 30)
    nextBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    nextBtn:SetText("Next →")
    nextBtn:SetScript("OnClick", function()
        currentSlide = currentSlide + 1
        ShowSlide(currentSlide)
    end)
    tutorialFrame.nextBtn = nextBtn
    
    -- Progress bar
    local progress = CreateFrame("StatusBar", nil, tutorialFrame)
    progress:SetSize(560, 4)
    progress:SetPoint("BOTTOM", 0, 55)
    progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progress:SetStatusBarColor(0, 0.8, 0)
    progress:SetMinMaxValues(0, #tutorialSlides)
    progress:SetValue(1)
    tutorialFrame.progress = progress
    
    -- Hook slide change to update progress
    local originalShowSlide = ShowSlide
    ShowSlide = function(index)
        originalShowSlide(index)
        progress:SetValue(index)
    end
    
    -- Close button (hidden by default, only on last slide)
    tutorialFrame.CloseButton:SetScript("OnClick", function()
        db.tutorialCompleted = TUTORIAL_VERSION
        tutorialFrame:Hide()
        self:ShowToSDialog()
    end)
    
    -- Show first slide
    ShowSlide(1)
    
    tutorialFrame:Show()
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
    
    local L = AzerothDash.strings
    
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
    local L = AzerothDash.strings
    
    -- Check if ToS was declined
    if AzerothDash.state.tosDeclined then
        AzerothDash:Print(L["TOS_DECLINED"] or "You must accept the Terms of Use to create orders.")
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

-- Classic-compatible friend check (C_FriendList.IsFriend doesn't exist in TBC Classic)
local function IsFriendCompat(name)
    -- Try modern API first (Retail)
    if C_FriendList and C_FriendList.GetFriendInfoByName then
        local info = C_FriendList.GetFriendInfoByName(name)
        return info ~= nil
    end
    -- TBC Classic fallback: iterate friend list
    local numFriends = GetNumFriends and GetNumFriends() or 0
    for i = 1, numFriends do
        local friendName = GetFriendInfo(i)
        if friendName and friendName:lower() == name:lower() then
            return true
        end
    end
    return false
end

-- Classic-compatible guild member check (IsGuildMember global doesn't exist)
local function IsGuildMemberCompat(name)
    if not IsInGuild() then return false end
    local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, numMembers do
        local memberName = GetGuildRosterInfo(i)
        if memberName and memberName:lower() == name:lower() then
            return true
        end
    end
    return false
end

-- Filter orders based on safety settings
function ToS:ShouldShowOrder(order)
    -- Check if globally blocked
    if db.blockedSenders[order.sender] then
        return false
    end
    
    -- Check friends only mode
    if db.friendsOnlyMode then
        if not IsFriendCompat(order.sender) then
            return false
        end
    end
    
    -- Check guild only mode
    if db.guildOnlyMode then
        if not IsInGuild() or not IsGuildMemberCompat(order.sender) then
            return false
        end
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
