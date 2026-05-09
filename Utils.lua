--[[
    AzerothDash - Utility Functions
]]

local _, AzerothDash = ...

-- Get player coordinates with fallback
function AzerothDash:GetPlayerCoords()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return GetZoneText() or "Unknown Zone", 0, 0
    end
    
    local mapInfo = C_Map.GetMapInfo(mapID)
    local zoneName = mapInfo and mapInfo.name or GetZoneText() or "Unknown Zone"
    
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        return zoneName, pos.x * 100, pos.y * 100
    else
        return zoneName, 0, 0
    end
end

-- Format gold amount for display
function AzerothDash:FormatGold(amount)
    if not amount or amount == 0 then
        return "0|cffffd100g|r"
    end
    
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    
    if gold > 0 then
        return string.format("%d|cffffd100g|r", gold)
    elseif silver > 0 then
        return string.format("%d|cffc7c7cfs|r", silver)
    else
        return string.format("%d|cffeda55fc|r", copper)
    end
end

-- Format large numbers
function AzerothDash:FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

-- Truncate text with ellipsis
function AzerothDash:TruncateText(text, maxLength)
    if not text or #text <= maxLength then
        return text
    end
    return text:sub(1, maxLength - 3) .. "..."
end

-- Get class color hex
function AzerothDash:GetClassColor(class)
    if not class then return "ffffffff" end
    
    local color = RAID_CLASS_COLORS[class]
    if color then
        return color.colorStr
    end
    return "ffffffff"
end

-- Clean expired orders
function AzerothDash:CleanExpiredOrders()
    local now = GetTime()
    local timeout = self.db.global.orderTimeout or self.CONSTANTS.ORDER_TIMEOUT
    local removed = 0
    
    -- Clean available orders
    for i = #self.state.availableOrders, 1, -1 do
        local order = self.state.availableOrders[i]
        if (now - order.timestamp) > timeout then
            table.remove(self.state.availableOrders, i)
            removed = removed + 1
        end
    end
    
    -- Clean my orders
    for i = #self.state.myOrders, 1, -1 do
        local order = self.state.myOrders[i]
        if (now - order.timestamp) > timeout then
            table.remove(self.state.myOrders, i)
        end
    end
    
    if removed > 0 then
        self:Debug("Cleaned", removed, "expired orders")
        if self.modules.UI then
            self.modules.UI:UpdateOrderList()
        end
    end
    
    return removed
end

-- Throttle check
function AzerothDash:CheckThrottle(action)
    local now = GetTime()
    if action == "send" then
        if (now - self.state.lastSendTime) < self.CONSTANTS.SPAM_THROTTLE then
            return false, self.CONSTANTS.SPAM_THROTTLE - (now - self.state.lastSendTime)
        end
        self.state.lastSendTime = now
    end
    return true
end

-- Copy table helper
function AzerothDash:CopyTable(src)
    local dest = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = self:CopyTable(v)
        else
            dest[k] = v
        end
    end
    return dest
end

-- Safe pcall wrapper for item info
function AzerothDash:SafeGetItemInfo(itemID_or_link)
    local ok, name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = pcall(GetItemInfo, itemID_or_link)
    if ok then
        return name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice
    end
    return nil
end

-- Check if player has item in bags
function AzerothDash:HasItemInBags(itemLink, count)
    count = count or 1
    local total = 0
    
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and itemInfo.hyperlink == itemLink then
                total = total + (itemInfo.stackCount or 1)
                if total >= count then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Generate unique order ID
function AzerothDash:GenerateOrderID()
    return string.format("%s-%d-%d", UnitName("player"), GetTime(), math.random(1000, 9999))
end

-- Table operations
function AzerothDash:TableFind(tbl, predicate)
    for i, v in ipairs(tbl) do
        if predicate(v) then
            return i, v
        end
    end
    return nil
end

function AzerothDash:TableFilter(tbl, predicate)
    local result = {}
    for _, v in ipairs(tbl) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
end
