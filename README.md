# AzerothDash

An in-game item delivery and courier service addon for Burning Crusade Anniversary Classic. Request items delivered to you anywhere in Azeroth, or earn gold as a courier — think of it like a delivery app, but for WoW.

## Features

- **Request Items**: Drag items from your bags, set a tip amount, and broadcast your order to dashers in your area
- **Deliver Orders**: Browse available orders in your zone, accept deliveries, and earn gold
- **Courier Availability**: Mark yourself as available for deliveries and get notified of new orders
- **Transaction Verification**: Multi-step confirmation ensures both parties complete the trade
- **Interactive Tutorial**: Step-by-step guide for first-time users (6 slides)
- **Active Orders Tab**: Track your orders in progress with real-time status updates
- **Reputation Tab**: Public log of bad traders with community import/export
- **Reputation System**: Build trust scores based on completed/failed transactions
- **Community Sharing**: Export/import reputation lists to share with guild/friends
- **Block List**: Block players you don't want to trade with
- **Delivery Confirmation**: Requester confirms receipt, dasher marks delivered
- **Dispute Resolution**: Report issues with deliveries for mediation
- **Scalable UI**: Automatically scales based on screen resolution
- **Minimap Button**: Quick access with draggable minimap integration
- **Localization Support**: English, German, French (extensible to more languages)
- **Order Management**: Automatic expiration, duplicate detection, and order history
- **ToS Compliance**: Built-in safeguards against gold laundering and RMT
- **Safety Modes**: Friends-only or guild-only order visibility

## Usage

### Slash Commands
- `/ad` or `/dash` - Toggle the main window
- `/ad available` - Toggle courier availability
- `/ad debug` - Toggle debug mode
- `/ad reset` - Reset all settings and reload UI
- `/ad config` - Open settings
- `/ad limits` - Show your current rate limits
- `/ad report PlayerName reason` - Report a suspicious player
- `/ad tutorial` - Replay the tutorial
- `/ad audit` - View audit log (debug mode only)
- `/ad help` - Show help

### First Time Setup
When you first install AzerothDash, you'll see a **6-step interactive tutorial**:

1. **Welcome** - What is AzerothDash?
2. **How It Works** - Step-by-step instructions
3. **Safety First** - How to avoid scams
4. **Golden Rules** - Be honest, fair, and kind
5. **Terms of Service** - The official rules
6. **Your Pledge** - Type "I AGREE" to confirm you won't scam

You can replay the tutorial anytime with `/ad tutorial`

### Requesting Items
1. Open AzerothDash via `/ad` or the minimap button
2. Click the "Request" tab
3. Drag items from your bags into the slots
4. Set your tip amount in gold
5. Click "Broadcast Order"

### Delivering Orders
1. Open AzerothDash
2. Click the "Deliver" tab
3. Browse available orders
4. Click the "I am available for deliveries" checkbox
5. Click "Dash" on an order to accept it
6. The order moves to your "Active" tab
7. Deliver the items in-game via trade
8. Click "Mark Delivered" in the Active tab
9. Wait for requester to confirm receipt

**Pro Tip:** Enable "Notify me of new orders" to get alerts when someone requests a delivery!

### Transaction Verification Flow
Both parties must confirm for a transaction to complete:

1. **Requester** broadcasts order → Status: `PENDING`
2. **Dasher** clicks "Dash" → Status: `ACCEPTED` (whisper sent)
3. **Dasher** delivers items via trade → Clicks "Mark Delivered" → Status: `DELIVERED`
4. **Requester** receives popup notification
5. **Requester** clicks "Confirm" → Status: `COMPLETED` (gold exchanged)

If there's an issue:
- **Requester** can click "Issue" to report a problem → Status: `DISPUTED`
- Both parties receive notifications
- Reputation scores affected

### Active Orders Tab (Tab 3)
Track all your ongoing transactions:
- **As Requester**: See pending orders, cancel if needed, confirm deliveries
- **As Dasher**: See accepted orders, mark delivered, view confirmation status
- **Statuses**: Pending → Accepted → Delivered → Completed/Disputed

### Reputation / Bad Traders Tab (Tab 4)
View and manage player reputation:
- **Your Experience**: Shows players you've traded with and their trust scores
- **Reported Players**: Shows players reported by the community
- **Community Import**: Import reputation lists shared by guildmates/friends
- **Export**: Share your bad trader list with others
- **Block**: Block specific players from seeing your orders
- **Filter**: View "Bad Only" (score < 50%) or all players
- **Trust Score**: Color-coded (Green 70-100%, Yellow 50-70%, Orange 30-50%, Red 0-30%)

**How to share reputation data:**
1. Click "Export" to copy your reputation data
2. Paste in guild chat, Discord, or PM to friends
3. They click "Import" and paste the data
4. Community-protected from known bad traders!

## Installation

1. Download the addon
2. Extract to `Interface/AddOns/AzerothDash`
3. Restart WoW or reload UI

## Saved Variables

- `AzerothDashDB` - Global settings
- `AzerothDashCharDB` - Per-character stats and preferences

## Compatibility

- **Burning Crusade Anniversary Classic**: 2.5.4 (Interface 20504) ✅
- **TBC Classic (original)**: 2.5.4 ✅
- **Classic Era / Vanilla**: Untested — may work but not officially supported
- **Retail WoW**: Not supported (different interface version)

## Development

### File Structure
```
AzerothDash/
├── AzerothDash.toc    - Addon metadata
├── Core.lua           - Core functionality, slash commands, constants
├── Config.lua         - Saved variables, defaults, profile management
├── Localization.lua   - Translations (enUS, deDE, frFR)
├── Utils.lua          - Utility functions, reputation import/export
├── ToS.lua            - Terms of Service compliance, rate limiting
├── Transactions.lua   - Transaction tracking, verification, lifecycle
├── Network.lua        - Communication layer, addon messages
├── UI.lua             - User interface (4 tabs)
├── Minimap.lua        - Minimap button
└── README.md          - This file
```

### ToS Compliance & Safety Features

This addon includes multiple safeguards to comply with WoW's Terms of Service:

**Rate Limiting:**
- Maximum 5,000g per order
- Maximum 10 orders per hour
- Maximum 20,000g movement per hour
- Maximum 50 orders per day
- Minimum 1g order value

**Safety Features:**
- First-run Terms of Use agreement
- Friends-only mode (only friends see your orders)
- Guild-only mode (only guild members see your orders)
- Player reporting system (`/ad report`)
- Audit logging for transaction tracking
- High-value trade warnings

**Anti-Laundering Measures:**
- All orders must include actual items (no pure gold transfers)
- Rate limiting prevents rapid-fire gold movement
- Order values capped to prevent large transfers
- Automatic duplicate detection

**Privacy:**
- Order data is only shared with other addon users
- No personal data is collected
- No external servers or APIs are contacted
- All transaction logs are stored locally only

### Architecture
The addon uses a modular architecture:
- **Core**: Main entry point, event handling, slash commands
- **ToS**: Terms of Service compliance, rate limiting, audit logging
- **Transactions**: Order lifecycle management, verification, reputation system
- **Network**: Communication layer (delegates transaction handling to Transactions)
- **UI**: User interface with 3 tabs (Request, Deliver, Active)
- **Utils**: Shared utility functions
- **Config**: Database management with defaults and migrations

### Safety Guidelines for Users

To ensure you stay within WoW's Terms of Service:

1. **Only trade for legitimate items** - Never use this addon for pure gold transfers
2. **Keep orders reasonable** - Tip amounts should reflect actual service value
3. **Don't circumvent limits** - The rate limits exist for your protection
4. **Report abuse** - Use `/ad report` if you see suspicious activity
5. **Use safety modes** - Enable friends-only or guild-only for safer trading

## License

MIT License

## Credits

Created for the AzerothDash community.
