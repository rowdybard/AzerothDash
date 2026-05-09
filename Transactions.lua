--[[
    AzerothDash - Transaction Tracking Module
    Verifies trades happen on both ends and manages order lifecycle
]]

local _, AzerothDash = ...
local Transactions = {}
AzerothDash:RegisterModule("Transactions", Transactions)

-- Local references
local CONSTANTS = AzerothDash.CONSTANTS
local STATUS = AzerothDash.STATUS
local charDB

-- Message types for transaction protocol
local MSG_TYPES = {
    ACCEPT = "ACC",      -- Courier accepts order
    DELIVERED = "DLV",   -- Courier marked as delivered
    CONFIRM = "CNF",     -- Requester confirms receipt
    DISPUTE = "DSP",     -- Requester reports issue
    CANCEL = "CAN",      -- Requester cancels
    STATUS_QUERY = "QRY", -- Query order status
}

function Transactions:Init()
    -- Delayed until config loaded
end

function Transactions:OnLogin()
    charDB = AzerothDash.charDB
    
    -- Set up transaction monitoring
    C_Timer.NewTicker(60, function()
        self:CheckTimeouts()
    end)
    
    -- Register for addon messages
    AzerothDash.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    local oldHandler = AzerothDash.events["CHAT_MSG_ADDON"]
    AzerothDash.events["CHAT_MSG_ADDON"] = function(self, prefix, msg, channel, sender)
        -- Call original handler
        if oldHandler then
            oldHandler(self, prefix, msg, channel, sender)
        end
        -- Also process transaction messages
        Transactions:OnTransactionMessage(prefix, msg, channel, sender)
    end
    
    AzerothDash:Debug("Transactions module initialized")
end

-- Send transaction state update
function Transactions:SendTransactionUpdate(orderID, msgType, data)
    local msg = string.format("%s^%s^%s^%s", AzerothDash.DATA_VERSION, msgType, orderID, data or "")
    local index = GetChannelName(CONSTANTS.CHANNEL_NAME)
    if index and index > 0 then
        C_ChatInfo.SendAddonMessage(CONSTANTS.COMM_PREFIX .. "_TX", msg, "CHANNEL", index)
    end
end

-- Send whisper notification
function Transactions:SendWhisper(playerName, message)
    SendChatMessage("[AzerothDash] " .. message, "WHISPER", nil, playerName)
end

-- Handle incoming transaction messages
function Transactions:OnTransactionMessage(prefix, msg, channel, sender)
    if prefix ~= CONSTANTS.COMM_PREFIX .. "_TX" then
        return
    end
    
    if sender == UnitName("player") then
        return
    end
    
    local parts = {strsplit("^", msg)}
    local ver = tonumber(parts[1])
    if not ver or ver > AzerothDash.DATA_VERSION then
        return
    end
    
    local msgType = parts[2]
    local orderID = parts[3]
    local data = parts[4]
    
    -- Find the transaction
    local transaction = self:FindTransaction(orderID)
    if not transaction then
        -- Maybe it's a new accept for our order
        if msgType == MSG_TYPES.ACCEPT then
            self:HandleAcceptNotification(orderID, sender, data)
        end
        return
    end
    
    -- Process based on message type and our role
    -- SECURITY: Always verify sender matches the known partner to prevent spoofing
    if msgType == MSG_TYPES.ACCEPT then
        if transaction.isRequester and transaction.status == STATUS.PENDING then
            self:ProcessAccept(transaction, sender, data)
        end
    elseif msgType == MSG_TYPES.DELIVERED then
        -- Verify sender is our courier
        if transaction.isRequester
            and transaction.status == STATUS.ACCEPTED
            and transaction.partner == sender then
            self:ProcessDelivered(transaction, sender)
        end
    elseif msgType == MSG_TYPES.CONFIRM then
        -- Verify sender is our requester
        if not transaction.isRequester
            and transaction.status == STATUS.DELIVERED
            and transaction.partner == sender then
            self:ProcessConfirm(transaction, sender)
        end
    elseif msgType == MSG_TYPES.DISPUTE then
        -- Verify sender is our requester
        if not transaction.isRequester
            and transaction.partner == sender then
            self:ProcessDispute(transaction, sender, data)
        end
    elseif msgType == MSG_TYPES.CANCEL then
        -- Verify sender is our requester
        if not transaction.isRequester
            and transaction.partner == sender then
            self:ProcessCancel(transaction, sender)
        end
    end
end

-- Find transaction by ID
function Transactions:FindTransaction(orderID)
    for _, tx in ipairs(charDB.activeTransactions) do
        if tx.orderID == orderID then
            return tx
        end
    end
    return nil
end

-- Create a new transaction when we accept an order
function Transactions:CreateTransaction(order, isRequester)
    local tx = {
        orderID = order.orderID,
        status = isRequester and STATUS.PENDING or STATUS.ACCEPTED,
        isRequester = isRequester,
        partner = isRequester and nil or order.sender, -- Will be set when someone accepts
        items = order.items,
        reward = order.reward,
        zone = order.zone,
        note = order.note, -- Store the note for reference
        createdAt = GetTime(),
        updatedAt = GetTime(),
        acceptedAt = isRequester and nil or GetTime(),
        deliveredAt = nil,
        completedAt = nil,
    }
    
    table.insert(charDB.activeTransactions, 1, tx)
    
    -- Limit active transactions list
    while #charDB.activeTransactions > 20 do
        table.remove(charDB.activeTransactions)
    end
    
    return tx
end

-- Courier accepts an order
function Transactions:AcceptOrder(orderIndex)
    local order = AzerothDash.state.availableOrders[orderIndex]
    if not order then
        AzerothDash:Print("Order no longer available.")
        return false
    end
    
    if order.sender == UnitName("player") then
        AzerothDash:Print("You cannot courier your own order!")
        return false
    end
    
    -- Create transaction record
    local tx = self:CreateTransaction(order, false)
    tx.partner = order.sender
    
    -- Send accept notification
    self:SendTransactionUpdate(order.orderID, MSG_TYPES.ACCEPT, UnitName("player"))
    
    -- Send whisper
    local firstItem = order.items[1]
    local itemSummary = (firstItem.count > 1 and (firstItem.count .. "x ") or "") .. firstItem.link
    if #order.items > 1 then
        itemSummary = itemSummary .. " (and " .. (#order.items - 1) .. " other items)"
    end
    
    local whisperMsg = string.format("I've accepted your delivery request for %s. I'm on my way to %s!", itemSummary, order.zone)
    if order.note and order.note ~= "" then
        whisperMsg = whisperMsg .. " Note: " .. order.note
    end
    
    self:SendWhisper(order.sender, whisperMsg)
    
    -- Remove from available orders
    table.remove(AzerothDash.state.availableOrders, orderIndex)
    
    -- Update UI - switch to Active tab so courier can see progress
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateOrderList()
        AzerothDash.modules.UI:UpdateActiveTransactions()
        AzerothDash.modules.UI:SetTab(3)
    end
    
    AzerothDash:Print("Order accepted! Deliver the items and click 'Mark Delivered' when ready.")
    return true
end

-- Courier marks order as delivered
function Transactions:MarkDelivered(orderID)
    local tx = self:FindTransaction(orderID)
    if not tx or tx.isRequester then
        AzerothDash:Print("Transaction not found.")
        return false
    end
    
    if tx.status ~= STATUS.ACCEPTED then
        AzerothDash:Print("Order is not in accepted state.")
        return false
    end
    
    tx.status = STATUS.DELIVERED
    tx.deliveredAt = GetTime()
    tx.updatedAt = GetTime()
    
    -- Notify requester
    self:SendTransactionUpdate(orderID, MSG_TYPES.DELIVERED, "")
    self:SendWhisper(tx.partner, "I've delivered your items! Please confirm receipt in AzerothDash.")
    
    AzerothDash:Print("Marked as delivered. Waiting for requester confirmation...")
    
    -- Update UI
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
    end
    
    return true
end

-- Requester confirms receipt
function Transactions:ConfirmReceipt(orderID)
    local tx = self:FindTransaction(orderID)
    if not tx or not tx.isRequester then
        AzerothDash:Print("Transaction not found.")
        return false
    end
    
    -- SECURITY: Only allow confirm after courier has marked delivered
    -- Prevents requester from prematurely closing a transaction
    if tx.status ~= STATUS.DELIVERED then
        AzerothDash:Print("Cannot confirm - please wait for the courier to mark the order delivered first.")
        return false
    end
    
    tx.status = STATUS.COMPLETED
    tx.completedAt = GetTime()
    tx.updatedAt = GetTime()
    
    -- Update stats (Requester side: track requests fulfilled and gold spent)
    charDB.requestStats.fulfilled = (charDB.requestStats.fulfilled or 0) + 1
    charDB.requestStats.spent = (charDB.requestStats.spent or 0) + tx.reward
    
    -- Update reputation for the courier
    self:UpdateReputation(tx.partner, true)
    
    -- Notify courier
    self:SendTransactionUpdate(orderID, MSG_TYPES.CONFIRM, "")
    if tx.partner then
        self:SendWhisper(tx.partner, "Thank you for the delivery! Payment sent. Transaction completed.")
    end
    
    AzerothDash:Print("Transaction completed! Thank you for using AzerothDash.")
    
    -- Archive after delay
    C_Timer.After(300, function()
        self:ArchiveTransaction(orderID)
    end)
    
    -- Update UI
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
    end
    
    return true
end

-- Requester reports issue (dispute)
function Transactions:ReportIssue(orderID, reason)
    local tx = self:FindTransaction(orderID)
    if not tx or not tx.isRequester then
        AzerothDash:Print("Transaction not found.")
        return false
    end
    
    tx.status = STATUS.DISPUTED
    tx.updatedAt = GetTime()
    tx.disputeReason = reason
    
    -- Update reputation negatively
    self:UpdateReputation(tx.partner, false)
    
    -- Notify courier
    self:SendTransactionUpdate(orderID, MSG_TYPES.DISPUTE, reason or "Issue reported")
    if tx.partner then
        self:SendWhisper(tx.partner, "The requester has reported an issue with the delivery. Reason: " .. (reason or "Not specified"))
    end
    
    AzerothDash:Print("Issue reported. The transaction has been marked as disputed.")
    
    -- Update UI
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
    end
    
    return true
end

-- Requester cancels order
function Transactions:CancelOrder(orderID)
    local tx = self:FindTransaction(orderID)
    if not tx or not tx.isRequester then
        AzerothDash:Print("Transaction not found.")
        return false
    end
    
    if tx.status == STATUS.COMPLETED or tx.status == STATUS.DISPUTED then
        AzerothDash:Print("Cannot cancel a completed or disputed order.")
        return false
    end
    
    tx.status = STATUS.CANCELLED
    tx.updatedAt = GetTime()
    
    -- Notify courier if accepted
    if tx.partner then
        self:SendTransactionUpdate(orderID, MSG_TYPES.CANCEL, "")
        self:SendWhisper(tx.partner, "The requester has cancelled the order. No payment needed.")
    end
    
    AzerothDash:Print("Order cancelled.")
    
    -- Archive after delay
    C_Timer.After(60, function()
        self:ArchiveTransaction(orderID)
    end)
    
    -- Update UI
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
    end
    
    return true
end

-- Process incoming accept notification
function Transactions:ProcessAccept(tx, courier, data)
    tx.partner = courier
    tx.status = STATUS.ACCEPTED
    tx.acceptedAt = GetTime()
    tx.updatedAt = GetTime()
    
    AzerothDash:Print(courier .. " has accepted your order and is on their way!")
    
    if AzerothDash.db.global.soundEnabled then
        PlaySound(SOUNDKIT.READY_CHECK, "Master") -- READY_CHECK exists since TBC (patch 2.0)
    end
    
    -- Update UI - switch requester to Active tab
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
        AzerothDash.modules.UI:SetTab(3)
    end
end

-- Process delivered notification
function Transactions:ProcessDelivered(tx, courier)
    tx.status = STATUS.DELIVERED
    tx.deliveredAt = GetTime()
    tx.updatedAt = GetTime()
    
    AzerothDash:Print(courier .. " has marked the order as delivered!")
    AzerothDash:Print("Please confirm receipt after checking the items, or report an issue if there's a problem.")
    
    if AzerothDash.db.global.soundEnabled then
        PlaySound(SOUNDKIT.TELL_MESSAGE, "Master") -- Tell sound exists since vanilla
    end
    
    -- Update UI - switch to Active tab and show popup
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
        AzerothDash.modules.UI:SetTab(3)
        AzerothDash.modules.UI:ShowDeliveryNotification(tx)
    end
end

-- Process confirm notification
function Transactions:ProcessConfirm(tx, requester)
    tx.status = STATUS.COMPLETED
    tx.completedAt = GetTime()
    tx.updatedAt = GetTime()
    
    -- Update stats (Courier side: track deliveries completed and gold earned)
    charDB.deliveryStats.completed = (charDB.deliveryStats.completed or 0) + 1
    charDB.deliveryStats.earned = (charDB.deliveryStats.earned or 0) + tx.reward
    
    -- Update reputation for the requester
    self:UpdateReputation(requester, true)
    
    AzerothDash:Print(requester .. " has confirmed receipt! Transaction completed.")
    AzerothDash:Print("You earned " .. tx.reward .. "g for this delivery.")
    
    -- Archive after delay
    C_Timer.After(300, function()
        self:ArchiveTransaction(tx.orderID)
    end)
    
    -- Update UI
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
    end
end

-- Process dispute notification
function Transactions:ProcessDispute(tx, requester, reason)
    tx.status = STATUS.DISPUTED
    tx.updatedAt = GetTime()
    tx.disputeReason = reason
    
    AzerothDash:Print("|cffff0000ALERT:|r " .. requester .. " has reported an issue with your delivery!")
    AzerothDash:Print("Reason: " .. (reason or "Not specified"))
    AzerothDash:Print("Please contact them to resolve this.")
    
    -- Update UI
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
    end
end

-- Process cancel notification
function Transactions:ProcessCancel(tx, requester)
    tx.status = STATUS.CANCELLED
    tx.updatedAt = GetTime()
    
    AzerothDash:Print(requester .. " has cancelled the order.")
    
    -- Archive after delay
    C_Timer.After(60, function()
        self:ArchiveTransaction(tx.orderID)
    end)
    
    -- Update UI
    if AzerothDash.modules.UI then
        AzerothDash.modules.UI:UpdateActiveTransactions()
    end
end

-- Handle accept notification for our pending orders
function Transactions:HandleAcceptNotification(orderID, courier, data)
    -- Find in myOrders
    for _, order in ipairs(AzerothDash.state.myOrders) do
        if order.orderID == orderID then
            -- Create transaction record
            local tx = self:CreateTransaction(order, true)
            tx.partner = courier
            tx.status = STATUS.ACCEPTED
            tx.acceptedAt = GetTime()
            
            AzerothDash:Print(courier .. " has accepted your order and is on their way!")
            
            if AzerothDash.db.global.soundEnabled then
                PlaySound(SOUNDKIT.READY_CHECK, "Master")
            end
            
            if AzerothDash.modules.UI then
                AzerothDash.modules.UI:UpdateActiveTransactions()
                AzerothDash.modules.UI:SetTab(3)
            end
            return
        end
    end
end

-- Check for timed out transactions
function Transactions:CheckTimeouts()
    local now = GetTime()
    
    for i = #charDB.activeTransactions, 1, -1 do
        local tx = charDB.activeTransactions[i]
        
        -- Check delivery timeout
        if tx.status == STATUS.ACCEPTED and tx.acceptedAt then
            if (now - tx.acceptedAt) > CONSTANTS.TRANSACTION_TIMEOUT then
                tx.status = STATUS.EXPIRED
                tx.updatedAt = now
                
                if tx.isRequester then
                    AzerothDash:Print("Your order to " .. (tx.partner or "Unknown") .. " has expired (no delivery within 30 minutes).")
                    -- Re-list order?
                else
                    AzerothDash:Print("Order delivery timed out. You were unable to deliver within 30 minutes.")
                    -- Penalize reputation slightly?
                    self:UpdateReputation(tx.partner, false, true) -- soft fail
                end
                
                -- Archive expired
                C_Timer.After(300, function()
                    self:ArchiveTransaction(tx.orderID)
                end)
            end
        end
        
        -- Check confirmation timeout (optional - auto-complete after 5 min?)
        -- For now, we don't auto-complete - we let it sit in DELIVERED state
    end
end

-- Update player reputation
function Transactions:UpdateReputation(playerName, success, soft)
    if not playerName then return end
    
    if not charDB.playerReputation[playerName] then
        charDB.playerReputation[playerName] = {
            completed = 0,
            disputed = 0,
            score = 100, -- Start at 100
        }
    end
    
    local rep = charDB.playerReputation[playerName]
    
    if success then
        rep.completed = rep.completed + 1
        rep.score = math.min(100, rep.score + 5)
    else
        rep.disputed = rep.disputed + 1
        if soft then
            rep.score = math.max(0, rep.score - 10)
        else
            rep.score = math.max(0, rep.score - 25)
        end
    end
    
    AzerothDash:Debug("Updated reputation for", playerName, "Score:", rep.score)
end

-- Get player reputation
function Transactions:GetReputation(playerName)
    if not charDB.playerReputation[playerName] then
        return { score = 100, completed = 0, disputed = 0 }
    end
    return charDB.playerReputation[playerName]
end

-- Archive completed/cancelled/expired transaction
function Transactions:ArchiveTransaction(orderID)
    for i, tx in ipairs(charDB.activeTransactions) do
        if tx.orderID == orderID then
            -- Could save to a history table here
            -- For now, just remove from active
            table.remove(charDB.activeTransactions, i)
            AzerothDash:Debug("Archived transaction", orderID)
            break
        end
    end
end

-- Get active transactions for display
function Transactions:GetActiveTransactions()
    return charDB.activeTransactions
end

-- Get reputation color
function Transactions:GetReputationColor(score)
    if score >= 90 then
        return "00ff00" -- Green
    elseif score >= 70 then
        return "ffff00" -- Yellow
    elseif score >= 50 then
        return "ff8800" -- Orange
    else
        return "ff0000" -- Red
    end
end
