--[[
    AzerothDash - Minimap Button Module
]]

local _, AzerothDash = ...
local Minimap = {}
AzerothDash:RegisterModule("Minimap", Minimap)

-- Constants
local BUTTON_SIZE = 31
local ICON_SIZE = 20
local BORDER_SIZE = 53
local DEFAULT_RADIUS = 80

-- Local references
local db
local button

function Minimap:Init()
    -- Will be populated after login when db is available
end

function Minimap:OnLogin()
    db = AzerothDash.db.profile.minimap
    
    if not db.hide then
        self:CreateButton()
    end
end

function Minimap:CreateButton()
    if button then
        button:Show()
        return
    end
    
    -- Create button frame
    button = CreateFrame("Button", "AzerothDashMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameLevel(8)
    button:SetFrameStrata("MEDIUM")
    button:EnableMouse(true)
    
    -- Border texture
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(BORDER_SIZE, BORDER_SIZE)
    border:SetPoint("TOPLEFT", -11, 10)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border
    
    -- Icon texture
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Green")
    icon:SetMask("Interface\\Minimap\\UI-Minimap-Background")
    button.icon = icon
    
    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(BORDER_SIZE, BORDER_SIZE)
    highlight:SetPoint("TOPLEFT", -11, 10)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    button.highlight = highlight
    
    -- Scripts
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            if AzerothDash.modules.UI then
                AzerothDash.modules.UI:ToggleMainFrame()
            end
        else
            -- Right click - toggle minimap lock
            db.lock = not db.lock
            GameTooltip:Hide()
            AzerothDash:Print(db.lock and "Minimap button locked" or "Minimap button unlocked")
        end
    end)
    
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(AzerothDash:L("TOOLTIP_MINIMAP"), 1, 0.82, 0)
        GameTooltip:AddLine(AzerothDash:L("TOOLTIP_MINIMAP_CLICK"), 1, 1, 1)
        GameTooltip:AddLine(AzerothDash:L("TOOLTIP_MINIMAP_RIGHT"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Dragging
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    
    button:SetScript("OnDragStart", function(self)
        if not db.lock then
            self.isDragging = true
            self:LockHighlight()
        end
    end)
    
    button:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:UnlockHighlight()
    end)
    
    button:SetScript("OnUpdate", function(self)
        if self.isDragging and not db.lock then
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
            local scale = UIParent:GetEffectiveScale()
            
            xpos = (xmin - xpos / scale + 70) / Minimap:GetEffectiveScale()
            ypos = (ypos / scale - ymin - 70) / Minimap:GetEffectiveScale()
            
            local angle = math.atan2(ypos, xpos)
            db.angle = angle
            
            self:UpdatePosition()
        end
    end)
    
    -- Position update function
    button.UpdatePosition = function(self)
        local angle = db.angle or 0
        local radius = db.radius or DEFAULT_RADIUS
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        self:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    -- Initial position
    button:UpdatePosition()
    
    AzerothDash:Debug("Minimap button created")
end

function Minimap:UpdatePosition()
    if button then
        button:UpdatePosition()
    end
end

function Minimap:Show()
    if not button then
        self:CreateButton()
    else
        button:Show()
    end
    db.hide = false
end

function Minimap:Hide()
    if button then
        button:Hide()
    end
    db.hide = true
end

function Minimap:IsVisible()
    return button and button:IsShown()
end

function Minimap:GetButton()
    return button
end
