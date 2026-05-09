--[[
    AzerothDash - Localization Module
    Supports: enUS (default), deDE, frFR, esES, itIT, ptBR, ruRU, koKR, zhCN, zhTW
]]

local _, AzerothDash = ...

local locales = {
    enUS = {
        PRINT_PREFIX = "|cff00ccff[AzerothDash]|r",
        LOADED_MESSAGE = "Loaded! Use |cff00ccff/ad|r or click the minimap button.",
        
        -- Tab labels
        TAB_REQUEST = "Request",
        TAB_DELIVER = "Deliver",
        TAB_ACTIVE = "Active",
        
        -- Active orders
        ACTIVE_EMPTY = "No active orders",
        ACTIVE_STATUS_PENDING = "Pending",
        ACTIVE_STATUS_ACCEPTED = "Accepted",
        ACTIVE_STATUS_DELIVERED = "Delivered",
        ACTIVE_STATUS_COMPLETED = "Completed",
        ACTIVE_STATUS_DISPUTED = "Disputed",
        ACTIVE_STATUS_CANCELLED = "Cancelled",
        ACTIVE_STATUS_EXPIRED = "Expired",
        
        ACTIVE_ACTION_CANCEL = "Cancel",
        ACTIVE_ACTION_CONFIRM = "Confirm",
        ACTIVE_ACTION_ISSUE = "Issue",
        ACTIVE_ACTION_MARK_DELIVERED = "Mark Delivered",
        ACTIVE_WAITING_DELIVERY = "Waiting for delivery...",
        ACTIVE_WAITING_CONFIRM = "Waiting for confirmation...",
        
        -- Delivery notification
        DELIVERY_NOTIFICATION = "%s has delivered your order:\n%s\n\nConfirm receipt?",
        DELIVERY_CONFIRM_BTN = "Confirm",
        DELIVERY_ISSUE_BTN = "Report Issue",
        DELIVERY_LATER_BTN = "Later",
        
        -- Reputation
        REPUTATION_SCORE = "Trust: %d%%",
        TAB_REPUTATION = "Reputation",
        
        -- Tutorial
        TUTORIAL_STEP = "Step %d of %d",
        TUTORIAL_TYPE_I_AGREE = "Type 'I AGREE' to continue:",
        TUTORIAL_NEXT = "Next →",
        TUTORIAL_BACK = "← Back",
        TUTORIAL_I_AGREE_CONTINUE = "I Agree & Continue",
        TUTORIAL_REPLAY = "Replay tutorial with /ad tutorial",
        REPUTATION_TITLE = "Community Reputation",
        REPUTATION_SUBTITLE = "Reported players and trust scores from your transactions",
        REPUTATION_SHOW_BAD = "Bad Only",
        REPUTATION_SHOW_ALL = "All",
        REPUTATION_EMPTY = "No reputation data available",
        REPUTATION_EXPORT = "Export",
        REPUTATION_IMPORT = "Import",
        REPUTATION_EXPORT_TIP = "Copy reputation data to share with others",
        REPUTATION_IMPORT_TIP = "Import reputation data from community",
        REPUTATION_BLOCK = "Block",
        REPUTATION_UNBLOCK = "Unblock",
        REPUTATION_EXPORT_TEXT = "Copy this data to share with your guild/friends:",
        REPUTATION_IMPORT_TEXT = "Paste reputation data from community:",
        
        -- Request tab
        REQUEST_HEADER = "New Delivery Request",
        REQUEST_SUBHEADER = "Drag items from your bags into the slots below.",
        REQUEST_TIP_LABEL = "Tip Amount:",
        REQUEST_BROADCAST = "Broadcast Order",
        REQUEST_RESET = "Reset",
        REQUEST_HELP = "Dashers in your area will be notified immediately.",
        REQUEST_ADD_SLOT = "Add another item slot",
        
        -- Deliver tab
        DELIVER_EMPTY = "No active orders in your area",
        DELIVER_REFRESH = "Refresh",
        DELIVER_BUTTON = "Dash",
        DELIVER_DISMISS = "Dismiss",
        
        -- Order display
        ORDER_REWARD_FORMAT = "%dg",
        ORDER_EXPIRES_FORMAT = "Expires in %dm",
        ORDER_FROM_FORMAT = "From: %s",
        ORDER_LOCATION_FORMAT = "Location: %s (%.1f, %.1f)",
        ORDER_ITEMS_LABEL = "Items:",
        ORDER_PLUS_MORE = "(+%d more)",
        ORDER_NOTE_LABEL = "Note:",
        
        -- Courier status
        COURIER_STATUS = "Courier Status:",
        COURIER_AVAILABLE = "I am available for deliveries",
        COURIER_NOW_AVAILABLE = "You are now marked as available for deliveries!",
        COURIER_OFFLINE = "You are now offline for deliveries.",
        COURIER_NOTIFY = "Notify me of new orders",
        
        -- Note to courier
        REQUEST_NOTE_LABEL = "Note to Courier:",
        REQUEST_NOTE_HINT = "E.g., 'At Stormwind Inn' or 'Whisper me when ready'",
        
        -- Tooltips
        TOOLTIP_MINIMAP = "AzerothDash",
        TOOLTIP_MINIMAP_CLICK = "Click to open dashboard",
        TOOLTIP_MINIMAP_RIGHT = "Right-click for options",
        
        -- Errors and messages
        ERROR_WAIT = "Please wait %d seconds before sending another order.",
        ERROR_NO_ITEMS = "Please add at least one item.",
        ERROR_NO_GOLD = "Please enter a valid gold reward.",
        ERROR_SELF_DELIVER = "You cannot dash for yourself!",
        ERROR_CONNECTION = "Connection lost. Reconnecting...",
        ERROR_ORDER_NOT_FOUND = "Order no longer available.",
        
        SUCCESS_BROADCAST = "Order broadcasted successfully!",
        SUCCESS_ACCEPTED = "Accepted order! Location: %s",
        SUCCESS_ORDER_RECEIVED = "New order from %s!",
        
        -- ToS/Rate limiting
        TOS_MAX_GOLD = "Order value exceeds maximum of %dg per order (ToS compliance).",
        TOS_MIN_GOLD = "Minimum order value is %dg.",
        TOS_HOUR_LIMIT = "Hourly order limit reached. Please wait before creating more orders.",
        TOS_GOLD_LIMIT = "Hourly gold movement limit approaching. Please wait before creating high-value orders.",
        TOS_DAILY_LIMIT = "Daily order limit reached. Please try again tomorrow.",
        TOS_DECLINED = "You must accept the Terms of Use to create orders.",
        TOS_TITLE = "AzerothDash - Terms of Use",
        TOS_AGREE = "I Agree",
        TOS_DECLINE = "Decline",
        TOS_THANKS = "Thank you for agreeing to the Terms of Use.",
        TOS_MUST_AGREE = "You must agree to the Terms of Use to use AzerothDash.",
        
        -- Safety
        SAFETY_TIP_WARNING = "|cffff0000Warning:|r Large gold transfers may be flagged by Blizzard. Ensure this is a legitimate trade.",
        SAFETY_FRIENDS_ONLY = "Friends Only mode enabled. Only friends can see your orders.",
        SAFETY_GUILD_ONLY = "Guild Only mode enabled. Only guild members can see your orders.",
        
        -- Settings
        SETTING_SOUND = "Enable sounds",
        SETTING_NOTIFICATIONS = "Enable notifications",
        SETTING_COMPACT = "Compact mode",
        SETTING_SCALE = "UI Scale",
        SETTING_FRIENDS_ONLY = "Friends only",
        SETTING_GUILD_ONLY = "Guild only",
        
        -- Stats
        STAT_DELIVERIES_COMPLETED = "Deliveries: %d",
        STAT_GOLD_EARNED = "Gold earned: %s",
        STAT_REQUESTS_PLACED = "Requests: %d",
        STAT_GOLD_SPENT = "Gold spent: %s",
    },
    
    deDE = {
        PRINT_PREFIX = "|cff00ccff[AzerothDash]|r",
        LOADED_MESSAGE = "Geladen! Benutze |cff00ccff/ad|r oder klicke den Minikarten-Button.",
        TAB_REQUEST = "Anfragen",
        TAB_DELIVER = "Liefern",
        REQUEST_HEADER = "Neue Lieferanfrage",
        REQUEST_SUBHEADER = "Ziehe Gegenstände aus deinen Taschen in die Slots.",
        REQUEST_TIP_LABEL = "Trinkgeld:",
        REQUEST_BROADCAST = "Auftrag senden",
        REQUEST_RESET = "Zurücksetzen",
        DELIVER_EMPTY = "Keine aktiven Aufträge",
        DELIVER_BUTTON = "Liefern",
    },
    
    frFR = {
        PRINT_PREFIX = "|cff00ccff[AzerothDash]|r",
        LOADED_MESSAGE = "Chargé! Utilisez |cff00ccff/ad|r ou cliquez sur le bouton de la minicarte.",
        TAB_REQUEST = "Demande",
        TAB_DELIVER = "Livrer",
        REQUEST_HEADER = "Nouvelle demande de livraison",
        REQUEST_SUBHEADER = "Glissez les objets de vos sacs dans les emplacements.",
        REQUEST_TIP_LABEL = "Pourboire:",
        REQUEST_BROADCAST = "Diffuser la commande",
        REQUEST_RESET = "Réinitialiser",
        DELIVER_EMPTY = "Aucune commande active",
        DELIVER_BUTTON = "Livrer",
    },
}

-- Fallback to enUS for missing strings
setmetatable(locales.deDE, { __index = locales.enUS })
setmetatable(locales.frFR, { __index = locales.enUS })

function AzerothDash:LoadLocalization()
    local locale = GetLocale()
    
    -- Default to enUS if locale not supported
    if not locales[locale] then
        locale = "enUS"
    end
    
    self.strings = locales[locale]
    
    -- Make L available globally for modules
    _G.ADL = self.strings
end

-- Get localized string with formatting
function AzerothDash:L(key, ...)
    local str = self.strings and self.strings[key] or key
    if ... then
        return string.format(str, ...)
    end
    return str
end
