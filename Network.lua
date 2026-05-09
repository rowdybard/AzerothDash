--[[
    AzerothDash - Network Communication Module
    Handles addon messages and channel management
]]

local _, AzerothDash = ...
local Network = {}
AzerothDash:RegisterModule("Network", Network)

-- Local references for performance
local CONSTANTS = AzerothDash.CONSTANTS

-- Serialization
local function SerializeOrder(order)
    local items = {}
    for _, item in ipairs(order.items) do
        table.insert(items, item.link .. "~" .. item.count)
    end
    
    -- Escape special characters in zone name, sender, and note
    local zone = order.zone:gsub("\\", "\\\\"):gsub("%^", "\\^")
    local sender = order.sender:gsub("\\", "\\\\"):gsub("%^", "\\^")
    local note = (order.note or ""):gsub("\\", "\\\\"):gsub("%^", "\\^"):gsub("~", "\\~")
    
    local parts = {
        AzerothDash.DATA_VERSION,
        "REQ",
        order.reward,
        zone,
        string.format("%.1f", order.x),
        string.format("%.1f", order.y),
        sender,
        order.class or "PRIEST",
        order.orderID or AzerothDash:GenerateOrderID(),
        table.concat(items, "^"),
        note
    }
    
    return table.concat(parts, "^")
end

-- Deserialization
local function DeserializeOrder(msg)
    local parts = {strsplit("^", msg)}
    
    -- Check version
    local ver = tonumber(parts[1])
    if not ver or ver > AzerothDash.DATA_VERSION then
        return nil
    end
    
    -- Check type
    if parts[2] ~= "REQ" then
        return nil
    end
    
    -- Parse basic fields
    local reward = tonumber(parts[3])
    if not reward or reward <= 0 then
        return nil
    end
    
    local zone = parts[4]:gsub("\\", "\"):gsub("\^", "^")
    local x = tonumber(parts[5]) or 0
    local y = tonumber(parts[6]) or 0
    local sender = parts[7]:gsub("\\", "\"):gsub("\^", "^")
    local class = parts[8]
    local orderID = parts[9]
    local note = (parts[11] or ""):gsub("\\", "\"):gsub("\^", "^"):gsub("\~", "~")
    
    -- Parse items (everything between position 10 and the note)
    local items = {}
    for i = 10, #parts do
        -- Stop when we hit the note field (no ~ in note field, so if it has ~ it's an item)
        if parts[i] and parts[i] ~= "" and parts[i]:match("~") then
            local link, count = strsplit("~", parts[i])
            count = tonumber(count) or 1
            if link and link ~= "" then
                table.insert(items, { link = link, count = count })
            end
        end
    end
    
    if #items == 0 then
        return nil
    end
    
    return {
        orderID = orderID,
        items = items,
        reward = reward,
        zone = zone,
        x = x,
        y = y,
        sender = sender,
        class = class,
        timestamp = GetTime(),
        note = note,
    }
end

-- Channel management
function Network:JoinChannel()
    local index = GetChannelName(CONSTANTS.CHANNEL_NAME)
    if not index or index == 0 then
        JoinTemporaryChannel(CONSTANTS.CHANNEL_NAME)
        
        -- Hide from chat frames
        C_Timer.After(1, function()
            local i = 1
            while _G["ChatFrame"..i] do
                ChatFrame_RemoveChannel(_G["ChatFrame"..i], CONSTANTS.CHANNEL_NAME)
                i = i + 1
            end
        end)
        
        AzerothDash:Debug("Joined channel", CONSTANTS.CHANNEL_NAME)
    end
end

-- Send order to network
function Network:BroadcastOrder(items, reward, note)
    -- Check throttle
    local ok, remaining = AzerothDash:CheckThrottle("send")
    if not ok then
        AzerothDash:Print(string.format(AzerothDash:L("ERROR_WAIT"), math.ceil(remaining)))
        return false
    end
    
    -- Get player info
    local zone, x, y = AzerothDash:GetPlayerCoords()
    local sender = UnitName("player")
    local _, class = UnitClass("player")
    
    -- Create order object
    local order = {
        orderID = AzerothDash:GenerateOrderID(),
        items = items,
        reward = reward,
        zone = zone,
        x = x,
        y = y,
        sender = sender,
        class = class,
        note = note,
    }
    
    -- Serialize and send
    local msg = SerializeOrder(order)
    local index = GetChannelName(CONSTANTS.CHANNEL_NAME)
    
    if index and index > 0 then
        C_ChatInfo.SendAddonMessage(CONSTANTS.COMM_PREFIX, msg, "CHANNEL", index)
        AzerothDash:Print(AzerothDash:L("SUCCESS_BROADCAST"))
        
        -- Add to my orders
        order.timestamp = GetTime()
        table.insert(AzerothDash.state.myOrders, order)
        
        -- Also add to available (for testing/self-view)
        table.insert(AzerothDash.state.availableOrders, order)
        
        -- Update UI
        if AzerothDash.modules.UI then
            AzerothDash.modules.UI:UpdateOrderList()
        end
        
        return true
    else
        AzerothDash:Print(AzerothDash:L("ERROR_CONNECTION"))
        self:JoinChannel()
        return false
    end
end

-- Accept an order (delegate to Transactions module)
function Network:AcceptOrder(orderIndex)
    if AzerothDash.modules.Transactions then
        return AzerothDash.modules.Transactions:AcceptOrder(orderIndex)
    end
    return false
end

-- Mark order as delivered (delegate to Transactions)
function Network:MarkDelivered(orderID)
    if AzerothDash.modules.Transactions then
        return AzerothDash.modules.Transactions:MarkDelivered(orderID)
    end
    return false
end

-- Confirm receipt (delegate to Transactions)
function Network:ConfirmReceipt(orderID)
    if AzerothDash.modules.Transactions then
        return AzerothDash.modules.Transactions:ConfirmReceipt(orderID)
    end
    return false
end

-- Report issue (delegate to Transactions)
function Network:ReportIssue(orderID, reason)
    if AzerothDash.modules.Transactions then
        return AzerothDash.modules.Transactions:ReportIssue(orderID, reason)
    end
    return false
end

-- Handle incoming addon messages
function Network:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= CONSTANTS.COMM_PREFIX then
        return
    end
    
    -- Ignore own messages
    if sender == UnitName("player") then
        return
    end
    
    -- Deserialize
    local order = DeserializeOrder(message)
    if not order then
        AzerothDash:Debug("Failed to deserialize message from", sender)
        return
    end
    
    -- Check for duplicates
    local isDuplicate = false
    for _, existing in ipairs(AzerothDash.state.availableOrders) do
        if existing.orderID == order.orderID then
            isDuplicate = true
            break
        end
        -- Also check by sender + reward + time
        if existing.sender == order.sender and 
           existing.reward == order.reward and 
           (order.timestamp - existing.timestamp) < 5 then
            isDuplicate = true
            break
        end
    end
    
    if isDuplicate then
        return
    end
    
    -- Check if blocked
    if AzerothDash.charDB.blockedPlayers[order.sender] then
        AzerothDash:Debug("Blocked order from", order.sender)
        return
    end
    
    -- ToS compliance checks
    if AzerothDash.modules.ToS then
        if not AzerothDash.modules.ToS:ShouldShowOrder(order) then
            AzerothDash:Debug("Order filtered by ToS rules from", order.sender)
            return
        end
    end
    
    -- Add to available orders
    table.insert(AzerothDash.state.availableOrders, order)
    
    -- Limit max orders
    local maxOrders = AzerothDash.db.global.maxDisplayOrders or 50
    while #AzerothDash.state.availableOrders > maxOrders do
        table.remove(AzerothDash.state.availableOrders, 1)
    end
    
    -- Notify
    AzerothDash:Print(string.format(AzerothDash:L("SUCCESS_ORDER_RECEIVED"), order.sender))
    
    -- Play sound
    if AzerothDash.db.global.soundEnabled then
        PlaySound(SOUNDKIT.READY_CHECK, "Master") -- READY_CHECK exists since TBC (patch 2.0)
    end
    
    -- Notify available couriers (enhanced notification)
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:NotifyCouriersOfOrder(order)
    end
    
    -- Update UI
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateOrderList()
    end
end

-- Event handlers
function Network:OnLogin()
    -- Register for addon messages (both prefixes must be registered)
    C_ChatInfo.RegisterAddonMessagePrefix(CONSTANTS.COMM_PREFIX)
    C_ChatInfo.RegisterAddonMessagePrefix(CONSTANTS.COMM_PREFIX .. "_TX")
    
    -- Join channel
    self:JoinChannel()
    
    -- Set up periodic rejoin
    C_Timer.NewTicker(60, function()
        self:JoinChannel()
    end)
    
    -- Set up periodic cleanup
    C_Timer.NewTicker(60, function()
        AzerothDash:CleanExpiredOrders()
    end)
    
    -- Register for addon message events
    AzerothDash.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    AzerothDash.events["CHAT_MSG_ADDON"] = function(self, ...)
        Network:OnAddonMessage(...)
    end
    
    AzerothDash:Debug("Network module initialized")
end
