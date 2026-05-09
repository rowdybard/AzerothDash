--[[
    AzerothDash - Minimap Button Module
]]

local _, AzerothDash = ...

-- Capture the WoW Minimap frame BEFORE the local module shadows it
local WoWMinimap = Minimap

local Minimap = {}
AzerothDash:RegisterModule("Minimap", Minimap)

-- Constants
local BUTTON_SIZE = 32
local ICON_SIZE   = 28
local DEFAULT_RADIUS = 80
local ICON_PATH = "Interface\\AddOns\\AzerothDash\\icon.png"

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

    -- Parent to the WoW Minimap frame so it moves with it
    button = CreateFrame("Button", "AzerothDashMinimapButton", WoWMinimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameLevel(8)
    button:SetFrameStrata("MEDIUM")
    button:EnableMouse(true)

    -- Rounded icon using the addon PNG with a circular mask
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON_PATH)
    icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    button.icon = icon

    -- Thin circular border so it looks like other minimap buttons
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(BUTTON_SIZE + 4, BUTTON_SIZE + 4)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    -- Highlight ring on mouse-over
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(BUTTON_SIZE + 4, BUTTON_SIZE + 4)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    button.highlight = highlight

    -- Left click = open/close UI, Right click = lock/unlock dragging
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            if AzerothDash.modules.UI then
                AzerothDash.modules.UI:ToggleMainFrame()
            end
        else
            db.lock = not db.lock
            GameTooltip:Hide()
            AzerothDash:Print(db.lock and "Minimap button locked." or "Minimap button unlocked.")
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

    -- Dragging around the minimap edge
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
        self:UpdatePosition()
    end)

    button:SetScript("OnUpdate", function(self)
        if self.isDragging and not db.lock then
            local xpos, ypos = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local xmin  = WoWMinimap:GetLeft()
            local ymin  = WoWMinimap:GetBottom()
            local mmScale = WoWMinimap:GetEffectiveScale()

            xpos = (xmin - xpos / scale + 70) / mmScale
            ypos = (ypos / scale - ymin - 70) / mmScale

            db.angle = math.atan2(ypos, xpos)
            self:UpdatePosition()
        end
    end)

    -- Snap button to the minimap edge at the stored angle
    button.UpdatePosition = function(self)
        local angle  = db.angle  or 0
        local radius = db.radius or DEFAULT_RADIUS
        self:ClearAllPoints()
        self:SetPoint("CENTER", WoWMinimap, "CENTER",
            math.cos(angle) * radius,
            math.sin(angle) * radius)
    end

    button:UpdatePosition()

    AzerothDash:Debug("Minimap button created")
end

function Minimap:UpdatePosition()
    if button then button:UpdatePosition() end
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
    if button then button:Hide() end
    db.hide = true
end

function Minimap:IsVisible()
    return button and button:IsShown()
end

function Minimap:GetButton()
    return button
end
