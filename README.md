# AzerothDash

The "DoorDash" of Azeroth - a World of Warcraft addon for requesting items or delivering them for gold.

## Features

- **Request Items**: Drag items from your bags, set a tip amount, and broadcast your order to dashers in your area
- **Deliver Orders**: Browse available orders in your zone, accept deliveries, and earn gold
- **Scalable UI**: Automatically scales based on screen resolution
- **Minimap Button**: Quick access with draggable minimap integration
- **Localization Support**: English, German, French (extensible to more languages)
- **Order Management**: Automatic expiration, duplicate detection, and order history
- **ToS Compliance**: Built-in safeguards against gold laundering and RMT
- **Safety Modes**: Friends-only or guild-only order visibility

## Usage

### Slash Commands
- `/ad` or `/dash` - Toggle the main window
- `/ad debug` - Toggle debug mode
- `/ad reset` - Reset all settings and reload UI
- `/ad config` - Open settings
- `/ad limits` - Show your current rate limits
- `/ad report PlayerName reason` - Report a suspicious player
- `/ad audit` - View audit log (debug mode only)
- `/ad help` - Show help

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
4. Click "Dash" on an order to accept it
5. A whisper will be sent to the requester automatically

## Installation

1. Download the addon
2. Extract to `Interface/AddOns/AzerothDash`
3. Restart WoW or reload UI

## Saved Variables

- `AzerothDashDB` - Global settings
- `AzerothDashCharDB` - Per-character stats and preferences

## Compatibility

- **Retail WoW**: Version 11.1.5+
- **Classic**: Not currently supported (different API)

## Development

### File Structure
```
AzerothDash/
├── AzerothDash.toc    - Addon metadata
├── Core.lua           - Core functionality, slash commands
├── Config.lua         - Saved variables and settings
├── Localization.lua   - Translations
├── Utils.lua          - Utility functions
├── ToS.lua            - Terms of Service compliance module
├── Network.lua        - Communication layer
├── UI.lua             - User interface
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
- **Modules**: Network, UI, Minimap register themselves with Core
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
