# Cosmic Trader Contract - Gamified Perpetual Trading on Starknet

A comprehensive smart contract system for gamified perpetual trading that makes trading accessible, fun, and rewarding for everyone. Built on Starknet with Cairo.

## 🌟 Overview

Cosmic Trader transforms traditional perpetual trading into an engaging, gamified experience that combines:

- **Pokémon GO/Duolingo-style mechanics** with XP, levels, and streaks
- **Achievement NFTs** for milestones and accomplishments
- **Leaderboards** and competitive features
- **Free-to-play mode** with mock trading
- **Gas-free transactions** via Starknet paymaster integration

## 🏗️ Architecture

The system consists of modular smart contracts:

### Core Contracts

1. **UserManagement** - User profiles, XP tracking, levels, and streaks
2. **Trading** - Mock and real trading with Extended API integration
3. **Leaderboard** - Rankings and competitive features (planned)
4. **AchievementNFT** - NFT rewards for milestones (planned)

### Key Features

- **XP System**: Earn experience points for trades, streaks, and achievements
- **Level Progression**: Exponential leveling system with visual rewards
- **Streak Mechanics**: Daily trading streaks with XP multipliers
- **Mock Trading**: Free-to-play mode for onboarding and practice
- **Real Trading**: Integration with Extended API for actual perpetual trades
- **Achievement System**: NFT collectibles for reaching milestones

## 📋 Requirements for v0/POC

✅ **Completed:**

- User registration and profile management
- XP tracking for trades and streaks
- Mock trading system for free-to-play mode
- Comprehensive test suite
- Modular contract architecture

🔄 **In Progress:**

- Basic leaderboard system
- Achievement NFT contract
- Extended API integration

📋 **Planned:**

- Frontend design proposal
- Mobile-first frontend with Starknet.dart
- Paymaster integration for gas-free transactions

## 🚀 Quick Start

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) - Cairo package manager
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) - Testing framework

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd cosmic_trader_contract
```

2. Build the project:

```bash
scarb build
```

3. Run tests:

```bash
snforge test
```

## 📚 Smart Contract Documentation

### UserManagement Contract

Manages user profiles, XP, levels, and streaks.

**Key Functions:**

- `register_user()` - Register a new user
- `add_xp(user, amount)` - Add XP to user (called by trading contract)
- `update_streak(user)` - Update daily trading streak
- `get_user_profile(user)` - Get complete user profile
- `calculate_level_from_xp(xp)` - Calculate level from XP amount

**Level System:**

- Level 1: 0 XP
- Level 2: 1,000 XP
- Level 3: 1,500 XP
- Each subsequent level requires 50% more XP

**Streak System:**

- Daily trading increases streak
- Streak multiplier: 100% + (streak_days \* 3%), capped at 200%
- Missing a day resets streak to 0

### Trading Contract

Handles both mock and real trading with XP rewards.

**Key Functions:**

- `start_mock_session()` - Begin free-to-play trading session
- `place_mock_trade(asset, amount, direction, price)` - Place mock trade
- `close_mock_trade(trade_id, exit_price)` - Close mock trade
- `place_real_trade(...)` - Place real trade (Extended API integration)
- `get_user_trades(user)` - Get all user trades
- `calculate_trade_xp(volume, profitable, is_mock)` - Calculate XP rewards

**XP Calculation:**

- Base: 10 XP per $1 trading volume
- Profitable trade bonus: +20% XP
- Mock trade penalty: -50% XP (configurable)
- Streak multiplier applied from UserManagement contract

## 🧪 Testing

The project includes comprehensive tests for all major functionality:

```bash
# Run all tests
snforge test

# Run specific test file
snforge test tests/test_user_management.cairo
snforge test tests/test_trading.cairo
```

**Test Coverage:**

- User registration and profile management
- XP addition and level calculation
- Streak tracking and multipliers
- Mock trading lifecycle
- Trade placement and closure
- P&L calculation
- Daily volume tracking
- Admin functions and access control

## 🎮 Gamification Features

### XP and Levels

- **XP Sources**: Trading volume, profitable trades, daily streaks, achievements
- **Level Benefits**: Visual progression, unlock new features, increased multipliers
- **Level Display**: Traditional RPG-style level progression

### Streak System

- **Daily Streaks**: Trade at least once per day to maintain streak
- **Streak Rewards**: Up to 100% XP bonus for 30+ day streaks
- **Streak Recovery**: Missing a day resets to 0 (but max streak is preserved)

### Achievement System (Planned)

- **Categories**: Trading, Streak, Volume, Social, Milestone, Seasonal
- **Rarities**: Common, Rare, Epic, Legendary
- **NFT Rewards**: Each achievement mints a unique NFT
- **Ecosystem Integration**: NFTs can be displayed in user's castle/garden

### Social Features (Planned)

- **Leaderboards**: XP, Volume, Streaks, Seasonal rankings
- **Clans/Alliances**: Team-based challenges and competitions
- **Social Sharing**: Share achievements and performance

## 🔧 Configuration

### Contract Parameters

**UserManagement:**

- `xp_multiplier`: Global XP multiplier (default: 100%)
- `level_requirements`: XP required for each level

**Trading:**

- `base_xp_rate`: XP per unit volume (default: 10 XP per $1)
- `mock_trade_multiplier`: XP reduction for mock trades (default: 50%)

### Admin Functions

- `set_xp_multiplier(multiplier)` - Adjust global XP rates
- `set_base_xp_rate(rate)` - Adjust trading XP rates
- `set_mock_trade_multiplier(multiplier)` - Adjust mock trade XP

## 🚀 Deployment

### Local Development

1. Start local Starknet devnet:

```bash
starknet-devnet
```

2. Deploy contracts:

```bash
sncast deploy --url http://localhost:5050 --contract UserManagement
sncast deploy --url http://localhost:5050 --contract Trading
```

### Testnet Deployment

1. Configure network in `snfoundry.toml`
2. Deploy with proper constructor arguments
3. Verify contract addresses and functionality

## 🔮 Future Enhancements

### v1 Features

- **Extended API Integration**: Real perpetual trading
- **Leaderboard Contract**: Rankings and seasons
- **Achievement NFTs**: Milestone rewards
- **Ecosystem Contract**: User's virtual castle/garden

### v2 Features

- **Clan System**: Team-based trading competitions
- **Advanced Analytics**: Trading performance insights
- **Social Features**: Friend systems and challenges
- **Mobile Widgets**: Real-time portfolio on lock screen

### v3 Features

- **Cross-chain Trading**: Multi-chain perpetual support
- **AI Trading Assistant**: Personalized trading tips
- **Marketplace**: Trade achievement NFTs
- **Tournament System**: Scheduled trading competitions

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Write tests for your changes
4. Ensure all tests pass (`snforge test`)
5. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
6. Push to the branch (`git push origin feature/AmazingFeature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Starknet** - L2 scaling solution for Ethereum
- **Cairo** - Smart contract programming language
- **Extended** - Perpetual trading infrastructure
- **OpenZeppelin** - Security-focused contract libraries
- **Starknet Foundry** - Testing and development tools

---

**Built with ❤️ for the Starknet ecosystem**
