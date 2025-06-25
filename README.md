# Cosmic Trader - Gamified Perpetual Trading Contract

A comprehensive smart contract system for gamified perpetual trading on Starknet, featuring user management, XP tracking, streak systems, and trading functionality in a single efficient contract.

## 🚀 Architecture

### Combined Contract Approach

This project uses a **single combined contract** (`CosmicTrader`) that merges user management and trading functionality for optimal gas efficiency and simplified deployment.

**Why Combined?**

- ✅ **Gas Efficient**: No inter-contract calls needed
- ✅ **Atomic Operations**: XP updates happen in same transaction as trades
- ✅ **Simple Deployment**: Single contract to deploy and manage
- ✅ **Direct Integration**: Trading automatically updates user stats and streaks

## 📁 Project Structure

```
src/
├── cosmic_trader.cairo          # Main combined contract
├── interfaces/
│   ├── user_interface.cairo     # User management interface
│   ├── trading_interface.cairo  # Trading interface
│   ├── leaderboard_interface.cairo
│   └── achievement_interface.cairo
└── lib.cairo                    # Module exports

tests/
└── test_cosmic_trader.cairo     # Comprehensive test suite
```

## 🎮 Features

### User Management

- User registration and profile management
- XP system with configurable multipliers
- Progressive leveling (exponential XP requirements)
- Daily streak tracking with bonus multipliers
- Trading statistics aggregation

### Trading System

- Mock trading sessions for onboarding
- Real trading integration (ready for Extended API)
- Automatic XP rewards based on trading volume
- P&L calculation and tracking
- Trade history and active trade management

### Gamification

- **XP System**: 10 XP per $1 trading volume (configurable)
- **Levels**: Progressive levels requiring 50% more XP each
- **Streaks**: Daily consecutive trading with up to 100% XP bonus
- **Multipliers**: Global and streak-based XP multipliers

## 🛠️ Contract Deployment

### Building

```bash
scarb build
```

### Testing

```bash
scarb test
```

### Deployment to Sepolia

```bash
sncast --account <your-account> declare --network sepolia --contract-name CosmicTrader
```

**Successfully Deployed:**

- **Class Hash**: `0x026e9f7afcd9810f46f7b6b38aac60307c4de204a7553d55079bc43046572407`
- **View on Starkscan**: [Contract](https://sepolia.starkscan.co/class/0x026e9f7afcd9810f46f7b6b38aac60307c4de204a7553d55079bc43046572407)


## 🎯 Usage Example

```cairo
// Deploy contract
let cosmic_trader = ICosmicTraderDispatcher { contract_address };

// Register user
cosmic_trader.register_user();

// Start trading session
let session_id = cosmic_trader.start_mock_session();

// Place trade
let trade_id = cosmic_trader.place_mock_trade('BTC', 1000, TradeDirection::Long, 50000);

// Close trade (automatically awards XP and updates streak)
cosmic_trader.close_mock_trade(trade_id, 55000);

// Check updated profile
let profile = cosmic_trader.get_user_profile(user_address);
// profile.xp > 0, profile.total_trades = 1, etc.
```

## 🔧 Configuration

### Admin Functions

- `set_xp_multiplier(multiplier: u32)`: Global XP multiplier
- `set_base_xp_rate(rate: u256)`: Base XP per dollar volume
- `set_mock_trade_multiplier(multiplier: u32)`: XP percentage for mock trades

### Default Settings

- Base XP Rate: 10 XP per $1 volume
- Mock Trade Multiplier: 50% (half XP for practice trades)
- Streak Bonus: +3% XP per consecutive day (max 100% bonus)
- Level Progression: Each level requires 50% more XP than previous

## 🚀 Future Enhancements

The modular interface design allows for easy addition of:

- **Leaderboard Contract**: For ranking and competitions
- **Achievement NFTs**: Mint NFTs for milestones
- **Governance**: DAO voting for parameter changes
- **Extended API Integration**: Real perpetual trading

## 📝 License

This project is for educational and demonstration purposes.

----

**Built with ❤️ for the Starknet ecosystem**
