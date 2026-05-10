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
    
    -- Support both retail (C_Container) and classic (globals)
    local getNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    local getItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
    
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, getNumSlots(bag) do
            local link = getItemLink(bag, slot)
            if link == itemLink then
                if C_Container and C_Container.GetContainerItemInfo then
                    local info = getItemInfo(bag, slot)
                    total = total + (info and info.stackCount or 1)
                else
                    -- Classic returns: texture, count, locked, quality, readable, lootable, link
                    local _, cnt = getItemInfo(bag, slot)
                    total = total + (cnt or 1)
                end
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

-- Serialize reputation data for export (simple CSV-like format)
function AzerothDash:SerializeReputation(data)
    local parts = {}
    table.insert(parts, "AZDREPv" .. (data.version or 1))
    table.insert(parts, "EXPORTER:" .. (data.exportedBy or "Unknown"))
    table.insert(parts, "TIME:" .. (data.exportedAt or GetTime()))
    
    for playerName, rep in pairs(data.reputation or {}) do
        local line = string.format("%s,%d,%d,%d,%s", 
            playerName, 
            rep.score or 50, 
            rep.completed or 0, 
            rep.disputed or 0,
            rep.reason or ""
        )
        table.insert(parts, line)
    end
    
    return table.concat(parts, ";")
end

-- Deserialize and import reputation data
function AzerothDash:ImportReputation(dataString)
    if not dataString or dataString == "" then
        self:Print("No data to import.")
        return false
    end
    
    -- Parse the data
    local parts = {strsplit(";", dataString)}
    
    -- Check version
    local header = parts[1]
    if not header or not header:match("^AZDREPv%d+") then
        self:Print("Invalid reputation data format.")
        return false
    end
    
    local version = tonumber(header:match("v(%d+)")) or 1
    
    -- Parse exporter info
    local exporter = "Unknown"
    local exportTime = GetTime()
    
    for i = 2, math.min(3, #parts) do
        local part = parts[i]
        if part:match("^EXPORTER:") then
            exporter = part:gsub("^EXPORTER:", "")
        elseif part:match("^TIME:") then
            exportTime = tonumber(part:gsub("^TIME:", "")) or GetTime()
        end
    end
    
    -- Initialize community reputation if needed
    if not self.db.global.communityReputation then
        self.db.global.communityReputation = {}
    end
    
    local imported = 0
    local startIdx = 4
    if version == 1 then
        -- Skip header lines to find data
        for i = 2, #parts do
            local part = parts[i]
            if not part:match("^EXPORTER:") and not part:match("^TIME:") and part:match("," ) then
                startIdx = i
                break
            end
        end
    end
    
    -- Parse player entries
    for i = startIdx, #parts do
        local line = parts[i]
        if line and line ~= "" and line:match(",") then
            local values = {strsplit(",", line)}
            if #values >= 4 then
                local playerName = values[1]
                local score = tonumber(values[2]) or 50
                local completed = tonumber(values[3]) or 0
                local disputed = tonumber(values[4]) or 0
                local reason = values[5] or "Community reported"
                
                -- Only import if score is low or has disputes
                if score < 50 or disputed > 0 then
                    -- Don't overwrite personal experience with community data
                    if not self.db.global.communityReputation[playerName] then
                        self.db.global.communityReputation[playerName] = {
                            score = score,
                            completed = completed,
                            disputed = disputed,
                            reason = reason,
                            importedFrom = exporter,
                            importedAt = GetTime(),
                        }
                        imported = imported + 1
                    end
                end
            end
        end
    end
    
    self:Print(string.format("Imported %d players from %s's reputation list.", imported, exporter))
    
    -- Update UI if visible
    if self.modules.UI and self.modules.UI.UpdateReputationList then
        self.modules.UI:UpdateReputationList()
    end
    
    return true
end
