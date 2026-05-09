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
    
    -- Send order
    if AzerothDash.modules.Network then
        local success = AzerothDash.modules.Network:BroadcastOrder(items, gold)
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
        
        -- Colored sender name
        local colorHex = AzerothDash:GetClassColor(order.class)
        local senderText = "|c" .. colorHex .. order.sender .. "|r"
        if order.sender == UnitName("player") then
            senderText = senderText .. " |cff00ff00(You)|r"
        end
        row.locText:SetText(senderText .. " - " .. order.zone)
        
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

-- Tab buttons
function UI:CreateTabButtons()
    for i = 1, 2 do
        local tab = CreateFrame("Button", "$parentTab" .. i, mainFrame, "CharacterFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetScript("OnClick", function()
            self:SetTab(i)
        end)
        
        if i == 1 then
            tab:SetPoint("CENTER", mainFrame, "BOTTOMLEFT", 60, -14)
            tab:SetText(L["TAB_REQUEST"])
        else
            tab:SetPoint("LEFT", tabButtons[i-1], "RIGHT", -16, 0)
            tab:SetText(L["TAB_DELIVER"])
        end
        
        tabButtons[i] = tab
    end
    
    PanelTemplates_SetNumTabs(mainFrame, 2)
end

function UI:SetTab(id)
    currentTab = id
    PanelTemplates_SetTab(mainFrame, id)
    
    if id == 1 then
        reqFrame:Show()
        dashFrame:Hide()
    else
        reqFrame:Hide()
        dashFrame:Show()
        AzerothDash:CleanExpiredOrders()
        self:UpdateOrderList()
    end
end

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
