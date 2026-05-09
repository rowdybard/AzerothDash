--[[
    AzerothDash - User Interface Module
    Scalable, responsive UI with proper frame management
]]

local _, AzerothDash = ...
local UI = {}
AzerothDash:RegisterModule("UI", UI)

-- Local references
local L = AzerothDash.L
local db
local CONSTANTS = AzerothDash.CONSTANTS

-- UI Elements
local mainFrame, reqFrame, dashFrame
local tabButtons = {}
local itemSlots = {}
local currentTab = 1

-- Scaling
local scaleFactor = 1

-- Initialize module
function UI:Init()
    -- Delayed until login
end

function UI:OnLogin()
    db = AzerothDash.db.profile
    scaleFactor = AzerothDash:GetScaleFactor()
    
    self:CreateMainFrame()
    self:CreateRequestFrame()
    self:CreateDeliveryFrame()
    self:CreateTabButtons()
    self:SetTab(1)
    
    -- Restore position
    self:RestorePosition()
    
    AzerothDash:Debug("UI module initialized, scale:", scaleFactor)
end

-- Main Frame
function UI:CreateMainFrame()
    mainFrame = CreateFrame("Frame", "AzerothDashMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(db.window.width, db.window.height)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:Hide()
    
    -- Apply scale
    mainFrame:SetScale(db.window.scale * scaleFactor)
    
    -- Title
    mainFrame.TitleBg:SetHeight(24)
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", mainFrame.TitleBg, "CENTER", 0, 2)
    title:SetText("AzerothDash")
    mainFrame.titleText = title
    
    -- Portrait
    local portrait = mainFrame:CreateTexture(nil, "OVERLAY")
    portrait:SetSize(60, 60)
    portrait:SetPoint("TOPLEFT", -5, 5)
    portrait:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Green")
    mainFrame.portrait = portrait
    
    local portraitBorder = mainFrame:CreateTexture(nil, "OVERLAY")
    portraitBorder:SetSize(60, 60)
    portraitBorder:SetPoint("TOPLEFT", -5, 5)
    portraitBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mainFrame.portraitBorder = portraitBorder
    
    -- Close button is part of the template, but we can hook it
    mainFrame.CloseButton:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    
    -- Dragging
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SavePosition()
    end)
    
    -- Settings button
    local settingsBtn = CreateFrame("Button", nil, mainFrame)
    settingsBtn:SetSize(20, 20)
    settingsBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -35, -11)
    settingsBtn:SetNormalTexture("Interface\\WorldMap\\GearIcon")
    settingsBtn:SetHighlightTexture("Interface\\WorldMap\\GearIcon")
    settingsBtn:GetHighlightTexture():SetBlendMode("ADD")
    settingsBtn:SetScript("OnClick", function()
        self:OpenConfig()
    end)
    settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    mainFrame.settingsBtn = settingsBtn
    
    UI.mainFrame = mainFrame
end

-- Request Frame (Tab 1)
function UI:CreateRequestFrame()
    reqFrame = CreateFrame("Frame", nil, mainFrame)
    reqFrame:SetSize(db.window.width - 40, db.window.height - 80)
    reqFrame:SetPoint("TOP", 0, -40)
    
    -- Header background
    local headerBg = CreateFrame("Frame", nil, reqFrame, "BackdropTemplate")
    headerBg:SetPoint("TOPLEFT", 10, -10)
    headerBg:SetPoint("TOPRIGHT", -10, -10)
    headerBg:SetHeight(100)
    headerBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    headerBg:SetBackdropColor(0, 0, 0, 0.6)
    headerBg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    reqFrame.headerBg = headerBg
    
    -- Header text
    local header = reqFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", headerBg, "TOPLEFT", 15, -15)
    header:SetText(L["REQUEST_HEADER"])
    reqFrame.header = header
    
    local subHeader = reqFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    subHeader:SetText(L["REQUEST_SUBHEADER"])
    subHeader:SetTextColor(0.7, 0.7, 0.7)
    reqFrame.subHeader = subHeader
    
    -- Item slots
    reqFrame.items = {}
    reqFrame.slots = {}
    
    local slotSize = 40
    local slotSpacing = 10
    local startX = 15
    local startY = -55
    
    for i = 1, CONSTANTS.MAX_ITEMS_PER_ORDER do
        local slot = self:CreateItemSlot(reqFrame, i)
        slot:SetSize(slotSize, slotSize)
        
        if i == 1 then
            slot:SetPoint("BOTTOMLEFT", headerBg, "BOTTOMLEFT", startX, startY)
        else
            slot:SetPoint("LEFT", reqFrame.slots[i-1], "RIGHT", slotSpacing, 0)
        end
        
        if i > 1 then
            slot:Hide()
        end
        
        reqFrame.slots[i] = slot
    end
    
    -- Plus button to add more slots
    local plusBtn = CreateFrame("Button", nil, reqFrame)
    plusBtn:SetSize(25, 25)
    plusBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    plusBtn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
    plusBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    plusBtn:SetPoint("LEFT", reqFrame.slots[1], "RIGHT", -20, 0) -- Hidden initially
    plusBtn:Hide()
    plusBtn:SetScript("OnClick", function()
        for i = 1, CONSTANTS.MAX_ITEMS_PER_ORDER do
            if not reqFrame.slots[i]:IsShown() then
                reqFrame.slots[i]:Show()
                break
            end
        end
        self:UpdatePlusButton()
    end)
    plusBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["REQUEST_ADD_SLOT"])
        GameTooltip:Show()
    end)
    plusBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    reqFrame.plusBtn = plusBtn
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, headerBg, "UIPanelButtonTemplate")
    resetBtn:SetSize(60, 22)
    resetBtn:SetPoint("TOPRIGHT", -10, -10)
    resetBtn:SetText(L["REQUEST_RESET"])
    resetBtn:SetScript("OnClick", function()
        self:ResetRequestForm()
    end)
    reqFrame.resetBtn = resetBtn
    
    -- Gold input section
    local goldLabel = reqFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldLabel:SetPoint("TOPLEFT", headerBg, "BOTTOMLEFT", 0, -25)
    goldLabel:SetText(L["REQUEST_TIP_LABEL"])
    reqFrame.goldLabel = goldLabel
    
    local goldInput = CreateFrame("EditBox", nil, reqFrame, "InputBoxTemplate")
    goldInput:SetSize(80, 22)
    goldInput:SetPoint("LEFT", goldLabel, "RIGHT", 10, 0)
    goldInput:SetNumeric(true)
    goldInput:SetAutoFocus(false)
    goldInput:SetJustifyH("RIGHT")
    goldInput:SetMaxLetters(6)
    reqFrame.goldInput = goldInput
    
    local goldIcon = reqFrame:CreateTexture(nil, "OVERLAY")
    goldIcon:SetSize(16, 16)
    goldIcon:SetPoint("LEFT", goldInput, "RIGHT", 5, 0)
    goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    reqFrame.goldIcon = goldIcon
    
    -- High gold warning
    local warningText = reqFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warningText:SetPoint("TOPLEFT", goldLabel, "BOTTOMLEFT", 0, -8)
    warningText:SetWidth(350)
    warningText:SetJustifyH("LEFT")
    warningText:SetText(L["SAFETY_TIP_WARNING"])
    warningText:SetTextColor(1, 0.5, 0.5)
    warningText:Hide()
    reqFrame.warningText = warningText
    
    -- Safety mode checkboxes
    local friendsCheck = CreateFrame("CheckButton", nil, reqFrame, "ChatConfigCheckButtonTemplate")
    friendsCheck:SetPoint("TOPLEFT", goldLabel, "BOTTOMLEFT", 0, -30)
    friendsCheck.Text:SetText(L["SETTING_FRIENDS_ONLY"] or "Friends only")
    friendsCheck:SetScript("OnClick", function(self)
        AzerothDash.db.global.friendsOnlyMode = self:GetChecked()
        if self:GetChecked() then
            reqFrame.guildCheck:SetChecked(false)
            AzerothDash.db.global.guildOnlyMode = false
        end
    end)
    friendsCheck:SetChecked(AzerothDash.db.global.friendsOnlyMode)
    reqFrame.friendsCheck = friendsCheck
    
    local guildCheck = CreateFrame("CheckButton", nil, reqFrame, "ChatConfigCheckButtonTemplate")
    guildCheck:SetPoint("LEFT", friendsCheck, "RIGHT", 120, 0)
    guildCheck.Text:SetText(L["SETTING_GUILD_ONLY"] or "Guild only")
    guildCheck:SetScript("OnClick", function(self)
        AzerothDash.db.global.guildOnlyMode = self:GetChecked()
        if self:GetChecked() then
            reqFrame.friendsCheck:SetChecked(false)
            AzerothDash.db.global.friendsOnlyMode = false
        end
    end)
    guildCheck:SetChecked(AzerothDash.db.global.guildOnlyMode)
    reqFrame.guildCheck = guildCheck
    
    -- Note to courier
    local noteLabel = reqFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT", friendsCheck, "BOTTOMLEFT", 0, -15)
    noteLabel:SetText(L["REQUEST_NOTE_LABEL"] or "Note to Courier:")
    reqFrame.noteLabel = noteLabel
    
    local noteInput = CreateFrame("EditBox", nil, reqFrame, "InputBoxTemplate")
    noteInput:SetSize(380, 30)
    noteInput:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 0, -5)
    noteInput:SetAutoFocus(false)
    noteInput:SetMaxLetters(100)
    noteInput:SetText("")
    noteInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    noteInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    reqFrame.noteInput = noteInput
    
    -- Note hint text
    local noteHint = reqFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteHint:SetPoint("TOPLEFT", noteInput, "BOTTOMLEFT", 0, -2)
    noteHint:SetText(L["REQUEST_NOTE_HINT"] or "E.g., 'At Stormwind Inn' or 'Whisper me when ready'")
    noteHint:SetTextColor(0.5, 0.5, 0.5)
    reqFrame.noteHint = noteHint
    
    -- Warning text update script
    goldInput:SetScript("OnTextChanged", function(self)
        local gold = tonumber(self:GetText()) or 0
        if gold >= 1000 then
            warningText:Show()
        else
            warningText:Hide()
        end
    end)
    
    -- Broadcast button
    local broadcastBtn = CreateFrame("Button", nil, reqFrame, "UIPanelButtonTemplate")
    broadcastBtn:SetPoint("BOTTOM", 0, 40)
    broadcastBtn:SetSize(180, 40)
    broadcastBtn:SetText(L["REQUEST_BROADCAST"])
    broadcastBtn:SetNormalFontObject("GameFontNormalLarge")
    broadcastBtn:SetHighlightFontObject("GameFontHighlightLarge")
    broadcastBtn:SetScript("OnClick", function()
        self:OnBroadcastClick()
    end)
    reqFrame.broadcastBtn = broadcastBtn
    
    -- Help text
    local helpText = reqFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("TOP", broadcastBtn, "BOTTOM", 0, -10)
    helpText:SetWidth(350)
    helpText:SetText(L["REQUEST_HELP"])
    helpText:SetTextColor(0.6, 0.6, 0.6)
    reqFrame.helpText = helpText
    
    self:UpdatePlusButton()
    reqFrame:Hide()
end

-- Create a single item slot
function UI:CreateItemSlot(parent, index)
    local slot = CreateFrame("Button", nil, parent)
    slot:SetFrameLevel(parent:GetFrameLevel() + 2)
    
    -- Background
    slot:SetNormalTexture("Interface\\Buttons\\UI-Slot-Background")
    slot:GetNormalTexture():SetAllPoints()
    
    -- Highlight
    slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    slot:GetHighlightTexture():SetAllPoints()
    slot:GetHighlightTexture():SetBlendMode("ADD")
    
    -- Pushed
    slot:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    slot:GetPushedTexture():SetAllPoints()
    
    -- Icon
    local icon = slot:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:Hide()
    slot.icon = icon
    
    -- Count editbox
    local countBox = CreateFrame("EditBox", nil, slot)
    countBox:SetSize(28, 14)
    countBox:SetPoint("BOTTOMRIGHT", -2, 2)
    countBox:SetFontObject("NumberFontNormal")
    countBox:SetNumeric(true)
    countBox:SetAutoFocus(false)
    countBox:SetMaxLetters(3)
    countBox:SetJustifyH("RIGHT")
    countBox:SetText("1")
    countBox:Hide()
    countBox:SetFrameLevel(slot:GetFrameLevel() + 3)
    
    -- Background for count
    local countBg = countBox:CreateTexture(nil, "BACKGROUND")
    countBg:SetAllPoints()
    countBg:SetColorTexture(0, 0, 0, 0.6)
    countBox.bg = countBg
    
    countBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    countBox:SetScript("OnEditFocusLost", function(self)
        local num = tonumber(self:GetText())
        if not num or num < 1 then
            self:SetText("1")
        end
        self:HighlightText(0, 0)
    end)
    countBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    
    slot.countBox = countBox
    
    -- Drag and click handlers
    slot:SetScript("OnReceiveDrag", function(self)
        self:OnItemDropped()
    end)
    
    slot:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            self:ClearItem()
        else
            self:OnItemDropped()
        end
    end)
    
    slot:SetScript("OnEnter", function(self)
        if reqFrame.items[index] then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(reqFrame.items[index])
            GameTooltip:Show()
        end
    end)
    
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Methods
    slot.OnItemDropped = function(self)
        local infoType, info1, info2 = GetCursorInfo()
        if infoType == "item" then
            local itemLink = info2  -- info2 is the link for item type
            if not itemLink then
                local _, link = GetItemInfo(info1)
                itemLink = link
            end
            
            if itemLink then
                local _, _, _, _, _, _, _, maxStack, _, texture = GetItemInfo(itemLink)
                
                reqFrame.items[index] = itemLink
                self.icon:SetTexture(texture)
                self.icon:Show()
                self:GetNormalTexture():Hide()
                
                if maxStack and maxStack > 1 then
                    self.countBox:Show()
                    self.countBox:SetText("1")
                else
                    self.countBox:Hide()
                end
                
                ClearCursor()
                UI:UpdatePlusButton()
            end
        end
    end
    
    slot.ClearItem = function(self)
        reqFrame.items[index] = nil
        self.icon:Hide()
        self:GetNormalTexture():Show()
        self.countBox:Hide()
        UI:UpdatePlusButton()
    end
    
    return slot
end

function UI:UpdatePlusButton()
    local lastVisible = 0
    for i = 1, CONSTANTS.MAX_ITEMS_PER_ORDER do
        if reqFrame.slots[i]:IsShown() then
            lastVisible = i
        end
    end
    
    if reqFrame.items[lastVisible] and lastVisible < CONSTANTS.MAX_ITEMS_PER_ORDER then
        reqFrame.plusBtn:Show()
        reqFrame.plusBtn:ClearAllPoints()
        reqFrame.plusBtn:SetPoint("LEFT", reqFrame.slots[lastVisible], "RIGHT", 5, 0)
    else
        reqFrame.plusBtn:Hide()
    end
end

function UI:ResetRequestForm()
    for i = 1, CONSTANTS.MAX_ITEMS_PER_ORDER do
        reqFrame.items[i] = nil
        reqFrame.slots[i].icon:Hide()
        reqFrame.slots[i]:GetNormalTexture():Show()
        reqFrame.slots[i].countBox:Hide()
        if i > 1 then
            reqFrame.slots[i]:Hide()
        end
    end
    reqFrame.goldInput:SetText("")
    reqFrame.noteInput:SetText("")
    self:UpdatePlusButton()
end

function UI:OnBroadcastClick()
    -- Gather items
    local items = {}
    for i = 1, CONSTANTS.MAX_ITEMS_PER_ORDER do
        if reqFrame.items[i] then
            local count = tonumber(reqFrame.slots[i].countBox:GetText()) or 1
            table.insert(items, {
                link = reqFrame.items[i],
                count = math.max(1, count)
            })
        end
    end
    
    -- Validate
    if #items == 0 then
        AzerothDash:Print(L["ERROR_NO_ITEMS"])
        return
    end
    
    local gold = tonumber(reqFrame.goldInput:GetText())
    if not gold or gold <= 0 then
        AzerothDash:Print(L["ERROR_NO_GOLD"])
        return
    end
    
    -- ToS Compliance Check
    if AzerothDash.modules.ToS then
        if not AzerothDash.modules.ToS:CanCreateOrder(gold) then
            return -- Error message already printed by ToS module
        end
    end
    
    -- Get note
    local note = reqFrame.noteInput:GetText()
    if note and #note > 0 then
        note = note:gsub("\^", ""):gsub("~", "") -- Remove special characters used in serialization
    end
    
    -- Send order
    if AzerothDash.modules.Network then
        local success = AzerothDash.modules.Network:BroadcastOrder(items, gold, note)
        if success then
            -- Record for rate limiting
            if AzerothDash.modules.ToS then
                AzerothDash.modules.ToS:RecordOrder(gold)
            end
            self:ResetRequestForm()
        end
    end
end

-- Delivery Frame (Tab 2)
function UI:CreateDeliveryFrame()
    dashFrame = CreateFrame("Frame", nil, mainFrame)
    dashFrame:SetSize(db.window.width - 40, db.window.height - 80)
    dashFrame:SetPoint("TOP", 0, -40)
    
    -- Empty state text
    local emptyText = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    emptyText:SetPoint("CENTER", 0, 0)
    emptyText:SetText(L["DELIVER_EMPTY"])
    emptyText:Hide()
    dashFrame.emptyText = emptyText
    
    -- Courier Availability Header
    local courierHeader = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    courierHeader:SetPoint("TOPLEFT", 10, -10)
    courierHeader:SetText(L["COURIER_STATUS"] or "Courier Status")
    dashFrame.courierHeader = courierHeader
    
    -- Available checkbox
    local availableCheck = CreateFrame("CheckButton", nil, dashFrame, "ChatConfigCheckButtonTemplate")
    availableCheck:SetPoint("LEFT", courierHeader, "RIGHT", 10, 0)
    availableCheck.Text:SetText(L["COURIER_AVAILABLE"] or "I am available for deliveries")
    availableCheck:SetChecked(db.courier.available)
    availableCheck:SetScript("OnClick", function(btn)
        db.courier.available = btn:GetChecked()
        if btn:GetChecked() then
            AzerothDash:Print(L["COURIER_NOW_AVAILABLE"] or "You are now marked as available for deliveries!")
            UI:SetupCourierNotifications()
        else
            AzerothDash:Print(L["COURIER_OFFLINE"] or "You are now offline for deliveries.")
        end
        UI:UpdateCourierIndicator()
    end)
    dashFrame.availableCheck = availableCheck
    
    -- Courier indicator (glowing orb)
    local indicator = dashFrame:CreateTexture(nil, "OVERLAY")
    indicator:SetSize(16, 16)
    indicator:SetPoint("LEFT", availableCheck, "RIGHT", 10, 0)
    indicator:SetTexture("Interface\\TargetingFrame\\UI-PhasingIcon")
    indicator:Hide()
    dashFrame.courierIndicator = indicator
    
    -- Notify on new orders checkbox
    local notifyCheck = CreateFrame("CheckButton", nil, dashFrame, "ChatConfigCheckButtonTemplate")
    notifyCheck:SetPoint("TOPLEFT", courierHeader, "BOTTOMLEFT", 0, -5)
    notifyCheck.Text:SetText(L["COURIER_NOTIFY"] or "Notify me of new orders")
    notifyCheck:SetChecked(db.courier.notifyOnNewOrder)
    notifyCheck:SetScript("OnClick", function(self)
        db.courier.notifyOnNewOrder = self:GetChecked()
    end)
    dashFrame.notifyCheck = notifyCheck
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, dashFrame)
    refreshBtn:SetSize(24, 24)
    refreshBtn:SetPoint("TOPRIGHT", dashFrame, "TOPRIGHT", 0, 5)
    refreshBtn:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    refreshBtn:SetHighlightTexture("Interface\\Buttons\\UI-RefreshButton")
    refreshBtn:GetHighlightTexture():SetBlendMode("ADD")
    refreshBtn:SetScript("OnClick", function()
        AzerothDash:CleanExpiredOrders()
        self:UpdateOrderList()
    end)
    refreshBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["DELIVER_REFRESH"])
        GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    dashFrame.refreshBtn = refreshBtn
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "AzerothDashScroll", dashFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    
    dashFrame.scroll = scrollFrame
    dashFrame.content = content
    dashFrame.rows = {}
    
    dashFrame:Hide()
end

-- Order row creation
function UI:GetOrderRow(index)
    if dashFrame.rows[index] then
        return dashFrame.rows[index]
    end
    
    local row = CreateFrame("Frame", nil, dashFrame.content, "BackdropTemplate")
    row:SetSize(dashFrame.content:GetWidth(), 60)
    
    row:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    row:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Item text
    local itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    itemText:SetPoint("TOPLEFT", 10, -10)
    itemText:SetWidth(220)
    itemText:SetJustifyH("LEFT")
    itemText:SetHeight(20)
    row.itemText = itemText
    
    -- Reward text
    local rewardText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rewardText:SetPoint("TOPRIGHT", -10, -10)
    rewardText:SetJustifyH("RIGHT")
    row.rewardText = rewardText
    
    -- Note text (for dasher to see requester notes)
    local noteText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteText:SetPoint("TOPLEFT", itemText, "BOTTOMLEFT", 0, -2)
    noteText:SetWidth(350)
    noteText:SetJustifyH("LEFT")
    noteText:SetTextColor(0.7, 0.7, 1) -- Light blue to distinguish
    row.noteText = noteText
    
    -- Location/sender text
    local locText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    locText:SetPoint("BOTTOMLEFT", 10, 10)
    locText:SetWidth(200)
    locText:SetJustifyH("LEFT")
    row.locText = locText
    
    -- Dash button
    local dashBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    dashBtn:SetSize(60, 26)
    dashBtn:SetPoint("BOTTOMRIGHT", -10, 8)
    dashBtn:SetText(L["DELIVER_BUTTON"])
    row.dashBtn = dashBtn
    
    -- Dismiss button
    local dismissBtn = CreateFrame("Button", nil, row)
    dismissBtn:SetSize(16, 16)
    dismissBtn:SetPoint("TOPRIGHT", -6, -6)
    dismissBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    dismissBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
    dismissBtn:SetScript("OnClick", function()
        table.remove(AzerothDash.state.availableOrders, index)
        self:UpdateOrderList()
    end)
    row.dismissBtn = dismissBtn
    
    -- Tooltip
    row:SetScript("OnEnter", function(self)
        local order = AzerothDash.state.availableOrders[index]
        if not order then return end
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(string.format(L["ORDER_FROM_FORMAT"], order.sender))
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["ORDER_ITEMS_LABEL"], 1, 0.82, 0)
        
        for _, item in ipairs(order.items) do
            GameTooltip:AddLine((item.count > 1 and (item.count .. "x ") or "") .. item.link)
        end
        
        -- Add note to tooltip if present
        if order.note and order.note ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["ORDER_NOTE_LABEL"] or "Note:", 0.7, 0.7, 1)
            GameTooltip:AddLine(order.note, 1, 1, 1)
        end
        
        GameTooltip:AddLine(" ")
        local remaining = math.floor((CONSTANTS.ORDER_TIMEOUT - (GetTime() - order.timestamp)) / 60)
        GameTooltip:AddLine(string.format(L["ORDER_EXPIRES_FORMAT"], math.max(0, remaining)), 0.6, 0.6, 0.6)
        GameTooltip:AddDoubleLine(L["ORDER_REWARD_FORMAT"]:gsub("%%d", order.reward), 
            string.format("%.1f, %.1f", order.x, order.y), 1, 0.82, 0, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    dashFrame.rows[index] = row
    return row
end

-- Update order list
function UI:UpdateOrderList()
    local orders = AzerothDash.state.availableOrders
    
    -- Hide all rows first
    for _, row in pairs(dashFrame.rows) do
        row:Hide()
    end
    
    -- Show empty state if needed
    if #orders == 0 then
        dashFrame.emptyText:Show()
        dashFrame.content:SetHeight(1)
        return
    end
    
    dashFrame.emptyText:Hide()
    
    -- Update/create rows
    local yOffset = -5
    local rowHeight = 65
    
    for i, order in ipairs(orders) do
        local row = self:GetOrderRow(i)
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", dashFrame.content, "TOPLEFT", 0, yOffset)
        
        -- Format item display
        local firstItem = order.items[1]
        local displayStr = (firstItem.count > 1 and (firstItem.count .. "x ") or "") .. firstItem.link
        if #order.items > 1 then
            displayStr = displayStr .. " |cff888888(+" .. (#order.items - 1) .. ")|r"
        end
        
        row.itemText:SetText(displayStr)
        row.rewardText:SetText(string.format(L["ORDER_REWARD_FORMAT"], order.reward))
        
        -- Show note if present
        if order.note and order.note ~= "" then
            row.noteText:SetText("|cffaaaaaaNote: |r" .. order.note)
            row.noteText:Show()
        else
            row.noteText:SetText("")
            row.noteText:Hide()
        end
        
        -- Colored sender name
        local colorHex = AzerothDash:GetClassColor(order.class)
        local senderText = "|c" .. colorHex .. order.sender .. "|r"
        if order.sender == UnitName("player") then
            senderText = senderText .. " |cff00ff00(You)|r"
        end
        row.locText:SetText(senderText .. " - " .. order.zone)
        
        -- Adjust row height based on note
        if order.note and order.note ~= "" then
            row:SetHeight(75)
            rowHeight = 80
        else
            row:SetHeight(60)
            rowHeight = 65
        end
        
        -- Dash button action
        row.dashBtn:SetScript("OnClick", function()
            if AzerothDash.modules.Network then
                AzerothDash.modules.Network:AcceptOrder(i)
            end
        end)
        
        yOffset = yOffset - rowHeight
    end
    
    dashFrame.content:SetHeight(math.abs(yOffset) + 10)
end

-- Update courier availability indicator
function UI:UpdateCourierIndicator()
    if dashFrame and dashFrame.courierIndicator then
        if db.courier.available then
            dashFrame.courierIndicator:Show()
            -- Add pulsing animation
            C_Timer.NewTicker(1, function()
                if dashFrame and dashFrame.courierIndicator and dashFrame.courierIndicator:IsShown() then
                    local alpha = dashFrame.courierIndicator:GetAlpha()
                    if alpha > 0.5 then
                        dashFrame.courierIndicator:SetAlpha(0.3)
                    else
                        dashFrame.courierIndicator:SetAlpha(1.0)
                    end
                end
            end)
        else
            dashFrame.courierIndicator:Hide()
        end
    end
end

-- Setup courier notifications
function UI:SetupCourierNotifications()
    if not db.courier.available or not db.courier.notifyOnNewOrder then
        return
    end
    
    -- Track previous order count
    self.lastOrderCount = self.lastOrderCount or #AzerothDash.state.availableOrders
    
    -- Check periodically for new orders
    if not self.courierTicker then
        self.courierTicker = C_Timer.NewTicker(2, function()
            if not db.courier.available then
                return
            end
            
            local currentCount = #AzerothDash.state.availableOrders
            if currentCount > self.lastOrderCount then
                -- New orders appeared!
                local newOrders = currentCount - self.lastOrderCount
                
                -- Play sound
                if db.notifications.sound then
                    PlaySound(SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION, "Master")
                end
                
                -- Visual notification
                if db.notifications.visual then
                    AzerothDash:Print(string.format("|cff00ff00NEW ORDER ALERT:|r %d new delivery request(s) available!", newOrders))
                end
                
                -- Auto-refresh the list if on Deliver tab
                if currentTab == 2 and dashFrame:IsShown() then
                    self:UpdateOrderList()
                end
            end
            
            self.lastOrderCount = currentCount
        end)
    end
end

-- Notify couriers about specific order (called when order is received)
function UI:NotifyCouriersOfOrder(order)
    -- Only notify if we're available
    if not db.courier.available or not db.courier.notifyOnNewOrder then
        return
    end
    
    -- Check if in same zone (or nearby)
    local currentZone = GetZoneText()
    if order.zone == currentZone or order.zone:find(currentZone) or currentZone:find(order.zone) then
        -- Enhanced notification for nearby orders
        AzerothDash:Print(string.format("|cff00ff00NEARBY ORDER:|r %d delivery request in %s!", order.reward, order.zone))
    end
end

-- Active orders frame (Tab 3)
local activeFrame

-- Bad Traders/Reputation frame (Tab 4)
local reputationFrame

-- Tab buttons
function UI:CreateTabButtons()
    for i = 1, 4 do
        local tab = CreateFrame("Button", "$parentTab" .. i, mainFrame, "CharacterFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetScript("OnClick", function()
            self:SetTab(i)
        end)
        
        if i == 1 then
            tab:SetPoint("CENTER", mainFrame, "BOTTOMLEFT", 60, -14)
            tab:SetText(L["TAB_REQUEST"])
        elseif i == 2 then
            tab:SetPoint("LEFT", tabButtons[i-1], "RIGHT", -16, 0)
            tab:SetText(L["TAB_DELIVER"])
        elseif i == 3 then
            tab:SetPoint("LEFT", tabButtons[i-1], "RIGHT", -16, 0)
            tab:SetText(L["TAB_ACTIVE"] or "Active")
        else
            tab:SetPoint("LEFT", tabButtons[i-1], "RIGHT", -16, 0)
            tab:SetText(L["TAB_REPUTATION"] or "Reputation")
        end
        
        tabButtons[i] = tab
    end
    
    PanelTemplates_SetNumTabs(mainFrame, 4)
    
    -- Create frames
    self:CreateActiveOrdersFrame()
    self:CreateReputationFrame()
end

function UI:CreateActiveOrdersFrame()
    activeFrame = CreateFrame("Frame", nil, mainFrame)
    activeFrame:SetSize(db.window.width - 40, db.window.height - 80)
    activeFrame:SetPoint("TOP", 0, -40)
    
    -- Empty state text
    local emptyText = activeFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    emptyText:SetPoint("CENTER", 0, 0)
    emptyText:SetText(L["ACTIVE_EMPTY"] or "No active orders")
    emptyText:Hide()
    activeFrame.emptyText = emptyText
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "AzerothDashActiveScroll", activeFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    
    activeFrame.scroll = scrollFrame
    activeFrame.content = content
    activeFrame.rows = {}
    
    activeFrame:Hide()
end

-- Get or create row for active transaction
function UI:GetActiveRow(index)
    if activeFrame.rows[index] then
        return activeFrame.rows[index]
    end
    
    local row = CreateFrame("Frame", nil, activeFrame.content, "BackdropTemplate")
    row:SetSize(activeFrame.content:GetWidth(), 80)
    
    row:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    row:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    -- Item text
    local itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    itemText:SetPoint("TOPLEFT", 10, -10)
    itemText:SetWidth(200)
    itemText:SetJustifyH("LEFT")
    row.itemText = itemText
    
    -- Status text
    local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPRIGHT", -10, -10)
    statusText:SetJustifyH("RIGHT")
    row.statusText = statusText
    
    -- Partner text
    local partnerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    partnerText:SetPoint("TOPLEFT", itemText, "BOTTOMLEFT", 0, -5)
    partnerText:SetWidth(200)
    partnerText:SetJustifyH("LEFT")
    row.partnerText = partnerText
    
    -- Reward text
    local rewardText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rewardText:SetPoint("TOPLEFT", partnerText, "BOTTOMLEFT", 0, -5)
    row.rewardText = rewardText
    
    -- Action buttons container
    local btnContainer = CreateFrame("Frame", nil, row)
    btnContainer:SetPoint("BOTTOMRIGHT", -10, 10)
    btnContainer:SetSize(180, 30)
    row.btnContainer = btnContainer
    
    activeFrame.rows[index] = row
    return row
end

-- Update active transactions display
function UI:UpdateActiveTransactions()
    if not AzerothDash.modules.Transactions then
        return
    end
    
    local transactions = AzerothDash.modules.Transactions:GetActiveTransactions()
    local STATUS = AzerothDash.STATUS
    
    -- Hide all rows
    for _, row in pairs(activeFrame.rows) do
        row:Hide()
    end
    
    -- Show empty state
    if #transactions == 0 then
        activeFrame.emptyText:Show()
        activeFrame.content:SetHeight(1)
        return
    end
    
    activeFrame.emptyText:Hide()
    
    -- Update rows
    local yOffset = -5
    local rowHeight = 85
    
    for i, tx in ipairs(transactions) do
        local row = self:GetActiveRow(i)
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", activeFrame.content, "TOPLEFT", 0, yOffset)
        
        -- Format item display
        local firstItem = tx.items[1]
        local displayStr = (firstItem.count > 1 and (firstItem.count .. "x ") or "") .. firstItem.link
        if #tx.items > 1 then
            displayStr = displayStr .. " |cff888888(+" .. (#tx.items - 1) .. ")|r"
        end
        row.itemText:SetText(displayStr)
        
        -- Status with color
        local statusColor = "ffffff"
        local statusText = tx.status
        if tx.status == STATUS.ACCEPTED then
            statusColor = "ffff00"
        elseif tx.status == STATUS.DELIVERED then
            statusColor = "ff8800"
        elseif tx.status == STATUS.COMPLETED then
            statusColor = "00ff00"
        elseif tx.status == STATUS.DISPUTED then
            statusColor = "ff0000"
        elseif tx.status == STATUS.EXPIRED or tx.status == STATUS.CANCELLED then
            statusColor = "888888"
        end
        row.statusText:SetText("|cff" .. statusColor .. statusText .. "|r")
        
        -- Partner
        local role = tx.isRequester and "Dasher: " or "Requester: "
        local partnerName = tx.partner or "Unknown"
        row.partnerText:SetText(role .. partnerName)
        
        -- Reward
        row.rewardText:SetText(string.format(L["ORDER_REWARD_FORMAT"], tx.reward))
        
        -- Clear old buttons
        for _, child in ipairs({row.btnContainer:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end
        
        -- Add action buttons based on role and status
        self:AddActionButtons(row.btnContainer, tx)
        
        yOffset = yOffset - rowHeight
    end
    
    activeFrame.content:SetHeight(math.abs(yOffset) + 10)
end

-- Add action buttons based on transaction state
function UI:AddActionButtons(container, tx)
    local STATUS = AzerothDash.STATUS
    local buttons = {}
    
    if tx.isRequester then
        -- Requester actions
        if tx.status == STATUS.PENDING then
            -- Can cancel
            local btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
            btn:SetSize(80, 22)
            btn:SetPoint("LEFT", 0, 0)
            btn:SetText("Cancel")
            btn:SetScript("OnClick", function()
                if AzerothDash.modules.Transactions then
                    AzerothDash.modules.Transactions:CancelOrder(tx.orderID)
                end
            end)
            table.insert(buttons, btn)
            
        elseif tx.status == STATUS.ACCEPTED then
            -- Waiting for delivery - no action needed yet
            local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", 0, 0)
            text:SetText("Waiting for delivery...")
            text:SetTextColor(0.8, 0.8, 0.2)
            
        elseif tx.status == STATUS.DELIVERED then
            -- Can confirm or dispute
            local confirmBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
            confirmBtn:SetSize(70, 22)
            confirmBtn:SetPoint("LEFT", 0, 0)
            confirmBtn:SetText("Confirm")
            confirmBtn:SetScript("OnClick", function()
                if AzerothDash.modules.Transactions then
                    AzerothDash.modules.Transactions:ConfirmReceipt(tx.orderID)
                end
            end)
            table.insert(buttons, confirmBtn)
            
            local disputeBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
            disputeBtn:SetSize(70, 22)
            disputeBtn:SetPoint("LEFT", confirmBtn, "RIGHT", 5, 0)
            disputeBtn:SetText("Issue")
            disputeBtn:SetScript("OnClick", function()
                StaticPopup_Show("AZEROTHDASH_REPORT_ISSUE", tx.partner, nil, { orderID = tx.orderID })
            end)
            table.insert(buttons, disputeBtn)
        end
    else
        -- Dasher actions
        if tx.status == STATUS.ACCEPTED then
            -- Can mark delivered
            local btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
            btn:SetSize(100, 22)
            btn:SetPoint("LEFT", 0, 0)
            btn:SetText("Mark Delivered")
            btn:SetScript("OnClick", function()
                if AzerothDash.modules.Transactions then
                    AzerothDash.modules.Transactions:MarkDelivered(tx.orderID)
                end
            end)
            table.insert(buttons, btn)
        elseif tx.status == STATUS.DELIVERED then
            -- Waiting for confirmation
            local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", 0, 0)
            text:SetText("Waiting for confirmation...")
            text:SetTextColor(0.8, 0.8, 0.2)
        end
    end
end

-- Show delivery notification popup
function UI:ShowDeliveryNotification(tx)
    local firstItem = tx.items[1]
    local itemSummary = (firstItem.count > 1 and (firstItem.count .. "x ") or "") .. firstItem.link
    
    StaticPopupDialogs["AZEROTHDASH_DELIVERY"] = {
        text = tx.partner .. " has delivered your order:\n" .. itemSummary .. "\n\nConfirm receipt?",
        button1 = "Confirm",
        button2 = "Report Issue",
        button3 = "Later",
        OnAccept = function(self, data)
            if AzerothDash.modules.Transactions then
                AzerothDash.modules.Transactions:ConfirmReceipt(data.orderID)
            end
        end,
        OnCancel = function(self, data)
            if AzerothDash.modules.Transactions then
                AzerothDash.modules.Transactions:ReportIssue(data.orderID, "Delivery issue reported via popup")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    StaticPopup_Show("AZEROTHDASH_DELIVERY", nil, nil, { orderID = tx.orderID })
end

-- Report issue popup
StaticPopupDialogs["AZEROTHDASH_REPORT_ISSUE"] = {
    text = "Report issue with delivery from %s:\n(They will be notified)",
    button1 = "Report",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        self.editBox:SetText("Items not received / wrong items")
    end,
    OnAccept = function(self, data)
        local reason = self.editBox:GetText()
        if AzerothDash.modules.Transactions then
            AzerothDash.modules.Transactions:ReportIssue(data.orderID, reason)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function UI:SetTab(id)
    currentTab = id
    PanelTemplates_SetTab(mainFrame, id)
    
    if id == 1 then
        reqFrame:Show()
        dashFrame:Hide()
        activeFrame:Hide()
        reputationFrame:Hide()
    elseif id == 2 then
        reqFrame:Hide()
        dashFrame:Show()
        activeFrame:Hide()
        reputationFrame:Hide()
        AzerothDash:CleanExpiredOrders()
        self:UpdateOrderList()
    elseif id == 3 then
        reqFrame:Hide()
        dashFrame:Hide()
        activeFrame:Show()
        reputationFrame:Hide()
        self:UpdateActiveTransactions()
    else
        reqFrame:Hide()
        dashFrame:Hide()
        activeFrame:Hide()
        reputationFrame:Show()
        self:UpdateReputationList()
    end
end

-- Create Reputation / Bad Traders frame
function UI:CreateReputationFrame()
    reputationFrame = CreateFrame("Frame", nil, mainFrame)
    reputationFrame:SetSize(db.window.width - 40, db.window.height - 80)
    reputationFrame:SetPoint("TOP", 0, -40)
    
    -- Header
    local header = reputationFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 10, -10)
    header:SetText(L["REPUTATION_TITLE"] or "Community Reputation")
    reputationFrame.header = header
    
    local subHeader = reputationFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    subHeader:SetText(L["REPUTATION_SUBTITLE"] or "Reported players and trust scores from your transactions")
    subHeader:SetTextColor(0.7, 0.7, 0.7)
    reputationFrame.subHeader = subHeader
    
    -- Filter buttons
    local showBadBtn = CreateFrame("Button", nil, reputationFrame, "UIPanelButtonTemplate")
    showBadBtn:SetSize(80, 22)
    showBadBtn:SetPoint("TOPRIGHT", -10, -10)
    showBadBtn:SetText(L["REPUTATION_SHOW_BAD"] or "Bad Only")
    showBadBtn:SetScript("OnClick", function()
        reputationFrame.filter = "bad"
        self:UpdateReputationList()
    end)
    reputationFrame.showBadBtn = showBadBtn
    
    local showAllBtn = CreateFrame("Button", nil, reputationFrame, "UIPanelButtonTemplate")
    showAllBtn:SetSize(60, 22)
    showAllBtn:SetPoint("RIGHT", showBadBtn, "LEFT", -5, 0)
    showAllBtn:SetText(L["REPUTATION_SHOW_ALL"] or "All")
    showAllBtn:SetScript("OnClick", function()
        reputationFrame.filter = nil
        self:UpdateReputationList()
    end)
    reputationFrame.showAllBtn = showAllBtn
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "AzerothDashRepScroll", reputationFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    
    reputationFrame.scroll = scrollFrame
    reputationFrame.content = content
    reputationFrame.rows = {}
    
    -- Empty state text
    local emptyText = reputationFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    emptyText:SetPoint("CENTER", 0, 0)
    emptyText:SetText(L["REPUTATION_EMPTY"] or "No reputation data available")
    emptyText:Hide()
    reputationFrame.emptyText = emptyText
    
    -- Import/Export buttons
    local exportBtn = CreateFrame("Button", nil, reputationFrame, "UIPanelButtonTemplate")
    exportBtn:SetSize(70, 22)
    exportBtn:SetPoint("BOTTOMLEFT", 10, 10)
    exportBtn:SetText(L["REPUTATION_EXPORT"] or "Export")
    exportBtn:SetScript("OnClick", function()
        self:ExportReputation()
    end)
    exportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["REPUTATION_EXPORT_TIP"] or "Copy reputation data to share with others")
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    reputationFrame.exportBtn = exportBtn
    
    local importBtn = CreateFrame("Button", nil, reputationFrame, "UIPanelButtonTemplate")
    importBtn:SetSize(70, 22)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 5, 0)
    importBtn:SetText(L["REPUTATION_IMPORT"] or "Import")
    importBtn:SetScript("OnClick", function()
        StaticPopup_Show("AZEROTHDASH_IMPORT_REP")
    end)
    importBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["REPUTATION_IMPORT_TIP"] or "Import reputation data from community")
        GameTooltip:Show()
    end)
    importBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    reputationFrame.importBtn = importBtn
    
    reputationFrame:Hide()
end

-- Get or create reputation row
function UI:GetReputationRow(index)
    if reputationFrame.rows[index] then
        return reputationFrame.rows[index]
    end
    
    local row = CreateFrame("Frame", nil, reputationFrame.content, "BackdropTemplate")
    row:SetSize(reputationFrame.content:GetWidth(), 50)
    
    row:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    -- Player name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", 10, -8)
    nameText:SetWidth(150)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText
    
    -- Trust score
    local scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scoreText:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
    scoreText:SetWidth(80)
    scoreText:SetJustifyH("CENTER")
    row.scoreText = scoreText
    
    -- Stats
    local statsText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -5)
    statsText:SetWidth(200)
    row.statsText = statsText
    
    -- Reason/Status
    local reasonText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reasonText:SetPoint("LEFT", scoreText, "RIGHT", 10, 0)
    reasonText:SetWidth(180)
    reasonText:SetJustifyH("LEFT")
    row.reasonText = reasonText
    
    -- Block button
    local blockBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    blockBtn:SetSize(60, 20)
    blockBtn:SetPoint("RIGHT", -10, 0)
    blockBtn:SetText(L["REPUTATION_BLOCK"] or "Block")
    row.blockBtn = blockBtn
    
    reputationFrame.rows[index] = row
    return row
end

-- Update reputation list
function UI:UpdateReputationList()
    local charDB = AzerothDash.charDB
    local globalDB = AzerothDash.db.global
    local filter = reputationFrame.filter
    
    -- Collect all reputation data
    local entries = {}
    
    -- Add from playerReputation (my experience)
    for playerName, rep in pairs(charDB.playerReputation or {}) do
        table.insert(entries, {
            name = playerName,
            score = rep.score or 100,
            completed = rep.completed or 0,
            disputed = rep.disputed or 0,
            source = "personal",
            reason = nil,
        })
    end
    
    -- Add from blockedSenders (reported globally)
    for playerName, data in pairs(globalDB.blockedSenders or {}) do
        local existing = nil
        for i, entry in ipairs(entries) do
            if entry.name == playerName then
                existing = entry
                break
            end
        end
        
        if existing then
            existing.reportedAt = data.reportedAt
            existing.reportReason = data.reason
            if existing.score > 50 then
                existing.score = 25 -- Force low score for reported players
            end
        else
            table.insert(entries, {
                name = playerName,
                score = 25,
                completed = 0,
                disputed = 1,
                source = "reported",
                reportedAt = data.reportedAt,
                reportReason = data.reason,
            })
        end
    end
    
    -- Add from community reputation (imported)
    for playerName, rep in pairs(globalDB.communityReputation or {}) do
        local existing = nil
        for i, entry in ipairs(entries) do
            if entry.name == playerName then
                existing = entry
                break
            end
        end
        
        if not existing then
            table.insert(entries, {
                name = playerName,
                score = rep.score or 50,
                completed = rep.completed or 0,
                disputed = rep.disputed or 0,
                source = "community",
                reason = rep.reason,
            })
        end
    end
    
    -- Filter if needed
    if filter == "bad" then
        entries = AzerothDash:TableFilter(entries, function(e)
            return e.score < 50 or e.disputed > 0
        end)
    end
    
    -- Sort by score (lowest first - worst actors at top)
    table.sort(entries, function(a, b)
        return a.score < b.score
    end)
    
    -- Hide all rows
    for _, row in pairs(reputationFrame.rows) do
        row:Hide()
    end
    
    -- Show empty state
    if #entries == 0 then
        reputationFrame.emptyText:Show()
        reputationFrame.content:SetHeight(1)
        return
    end
    
    reputationFrame.emptyText:Hide()
    
    -- Update rows
    local yOffset = -5
    local rowHeight = 55
    
    for i, entry in ipairs(entries) do
        local row = self:GetReputationRow(i)
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", reputationFrame.content, "TOPLEFT", 0, yOffset)
        
        -- Name
        row.nameText:SetText(entry.name)
        
        -- Score with color
        local scoreColor = "00ff00"
        if entry.score < 70 then
            scoreColor = "ffff00"
        end
        if entry.score < 50 then
            scoreColor = "ff8800"
        end
        if entry.score < 30 then
            scoreColor = "ff0000"
        end
        row.scoreText:SetText("|cff" .. scoreColor .. entry.score .. "%|r")
        
        -- Stats
        row.statsText:SetText(string.format("Completed: %d | Disputed: %d", entry.completed, entry.disputed))
        
        -- Reason
        local reason = entry.reportReason or entry.reason
        if entry.source == "reported" then
            reason = "|cffff0000Reported|r"
        elseif entry.source == "community" then
            reason = reason or "|cff00ccffCommunity Flag|r"
        end
        row.reasonText:SetText(reason or "")
        
        -- Block button
        local isBlocked = charDB.blockedPlayers and charDB.blockedPlayers[entry.name]
        row.blockBtn:SetText(isBlocked and (L["REPUTATION_UNBLOCK"] or "Unblock") or (L["REPUTATION_BLOCK"] or "Block"))
        row.blockBtn:SetScript("OnClick", function()
            if isBlocked then
                charDB.blockedPlayers[entry.name] = nil
                AzerothDash:Print("Unblocked " .. entry.name)
            else
                charDB.blockedPlayers[entry.name] = true
                AzerothDash:Print("Blocked " .. entry.name)
            end
            self:UpdateReputationList()
        end)
        
        -- Color row background based on score
        if entry.score < 30 then
            row:SetBackdropColor(0.3, 0.1, 0.1, 0.8) -- Dark red
        elseif entry.score < 50 then
            row:SetBackdropColor(0.3, 0.2, 0.1, 0.8) -- Dark orange
        else
            row:SetBackdropColor(0.1, 0.1, 0.1, 0.8) -- Normal
        end
        
        yOffset = yOffset - rowHeight
    end
    
    reputationFrame.content:SetHeight(math.abs(yOffset) + 10)
end

-- Export reputation data
function UI:ExportReputation()
    local charDB = AzerothDash.charDB
    local exportData = {
        version = 1,
        exportedAt = GetTime(),
        exportedBy = UnitName("player"),
        reputation = {},
    }
    
    for playerName, rep in pairs(charDB.playerReputation or {}) do
        if rep.disputed > 0 or rep.score < 50 then
            exportData.reputation[playerName] = {
                score = rep.score,
                completed = rep.completed,
                disputed = rep.disputed,
                reason = rep.lastDisputeReason,
            }
        end
    end
    
    -- Serialize to string
    local serialized = AzerothDash:SerializeReputation(exportData)
    
    -- Show in popup for copying
    StaticPopupDialogs["AZEROTHDASH_EXPORT"] = {
        text = L["REPUTATION_EXPORT_TEXT"] or "Copy this data to share with your guild/friends:",
        hasEditBox = true,
        button1 = "Done",
        OnShow = function(self)
            self.editBox:SetText(serialized)
            self.editBox:HighlightText()
            self.editBox:SetFocus()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    StaticPopup_Show("AZEROTHDASH_EXPORT")
end

-- Import reputation popup
StaticPopupDialogs["AZEROTHDASH_IMPORT_REP"] = {
    text = L["REPUTATION_IMPORT_TEXT"] or "Paste reputation data from community:",
    hasEditBox = true,
    button1 = "Import",
    button2 = "Cancel",
    OnShow = function(self)
        self.editBox:SetText("")
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)
        local data = self.editBox:GetText()
        if data and data ~= "" then
            AzerothDash:ImportReputation(data)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Position management
function UI:SavePosition()
    local point, _, relPoint, x, y = mainFrame:GetPoint(1)
    if point then
        db.window.point = point
        db.window.relPoint = relPoint
        db.window.x = x
        db.window.y = y
        db.window.scale = mainFrame:GetScale() / scaleFactor
    end
end

function UI:RestorePosition()
    if db.window.point then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(db.window.point, UIParent, db.window.relPoint or db.window.point, db.window.x, db.window.y)
    end
end

-- Public methods
function UI:ToggleMainFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        if currentTab == 2 then
            self:UpdateOrderList()
        elseif currentTab == 3 then
            self:UpdateActiveTransactions()
        elseif currentTab == 4 then
            self:UpdateReputationList()
        end
    end
end

function UI:OpenConfig()
    -- For now, just toggle - can expand to a config panel
    AzerothDash:Print("Settings panel coming soon! Use the checkboxes in the main window.")
end

function UI:GetMainFrame()
    return mainFrame
end
