/// Cosmic Trader Contract - Gamified Perpetual Trading on Starknet
/// A comprehensive smart contract system for gamified perpetual trading
/// including user management, XP tracking, leaderboards, and achievement NFTs

#[starknet::contract]
pub mod CosmicTrader {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::{get_caller_address, get_block_timestamp};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;

    // Import interfaces and types
    use cosmic_trader_contract::interfaces::user_interface::{UserProfile, StreakInfo, IUserManagement};
    use cosmic_trader_contract::interfaces::trading_interface::{Trade, TradeDirection, TradingSession, ITrading};

    /// Error constants for better error handling
    mod Errors {
        pub const USER_ALREADY_REGISTERED: felt252 = 'User already registered';
        pub const USER_NOT_REGISTERED: felt252 = 'User not registered';
        pub const NOT_TRADE_OWNER: felt252 = 'Not trade owner';
        pub const TRADE_NOT_FOUND: felt252 = 'Trade not found';
        pub const TRADE_ALREADY_CLOSED: felt252 = 'Trade already closed';
        pub const NOT_SESSION_OWNER: felt252 = 'Not session owner';
        pub const SESSION_ALREADY_ENDED: felt252 = 'Session already ended';
        pub const ONLY_OWNER: felt252 = 'Only owner allowed';
        pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
        pub const INVALID_PRICE: felt252 = 'Invalid price';
    }

    #[storage]
    pub struct Storage {
        // User Management Storage
        users: Map<ContractAddress, UserProfile>,
        user_streaks: Map<ContractAddress, StreakInfo>,
        total_users: u64,
        xp_multiplier: u32,
        owner: ContractAddress,
        
        // Trading Storage
        trades: Map<u64, Trade>,
        user_trades: Map<ContractAddress, Vec<u64>>,
        active_trades: Map<ContractAddress, Vec<u64>>,
        trading_sessions: Map<u64, TradingSession>,
        user_sessions: Map<ContractAddress, Vec<u64>>,
        trade_counter: u64,
        session_counter: u64,
        base_xp_rate: u256,
        mock_trade_multiplier: u32,
        daily_volumes: Map<(ContractAddress, u64), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        // User Management Events
        UserRegistered: UserRegistered,
        XPAdded: XPAdded,
        LevelUp: LevelUp,
        StreakUpdated: StreakUpdated,
        TradingStatsUpdated: TradingStatsUpdated,
        
        // Trading Events
        MockSessionStarted: MockSessionStarted,
        TradeOpened: TradeOpened,
        TradeClosed: TradeClosed,
        SessionEnded: SessionEnded,
        XPEarned: XPEarned,
    }

    // User Management Events
    #[derive(Drop, starknet::Event)]
    pub struct UserRegistered {
        pub user: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct XPAdded {
        pub user: ContractAddress,
        pub amount: u256,
        pub new_total: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LevelUp {
        pub user: ContractAddress,
        pub old_level: u32,
        pub new_level: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreakUpdated {
        pub user: ContractAddress,
        pub old_streak: u32,
        pub new_streak: u32,
        pub multiplier: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TradingStatsUpdated {
        pub user: ContractAddress,
        pub total_trades: u64,
        pub total_volume: u256,
    }

    // Trading Events
    #[derive(Drop, starknet::Event)]
    pub struct MockSessionStarted {
        pub user: ContractAddress,
        pub session_id: u64,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TradeOpened {
        pub user: ContractAddress,
        pub trade_id: u64,
        pub asset: felt252,
        pub amount: u256,
        pub direction: TradeDirection,
        pub price: u256,
        pub is_mock: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TradeClosed {
        pub user: ContractAddress,
        pub trade_id: u64,
        pub exit_price: u256,
        pub profit_loss: felt252,
        pub xp_earned: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SessionEnded {
        pub user: ContractAddress,
        pub session_id: u64,
        pub total_xp: u256,
        pub total_trades: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct XPEarned {
        pub user: ContractAddress,
        pub amount: u256,
        pub source: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.xp_multiplier.write(100); // 100% = no multiplier
        self.base_xp_rate.write(10); // 10 XP per $1 volume
        self.mock_trade_multiplier.write(50); // 50% XP for mock trades
        self.trade_counter.write(1);
        self.session_counter.write(1);
        self.total_users.write(0);
    }

    // User Management Interface Implementation
    #[abi(embed_v0)]
    pub impl UserManagementImpl of IUserManagement<ContractState> {
        /// Registers a new user in the cosmic trading system
        /// 
        /// # Panics
        /// 
        /// * If the user is already registered
        fn register_user(ref self: ContractState) {
            let caller = get_caller_address();
            let existing_user = self.users.entry(caller).read();
            
            assert(existing_user.address.is_zero(), Errors::USER_ALREADY_REGISTERED);
            
            let current_time = get_block_timestamp();
            let user = UserProfile {
                address: caller,
                xp: 0,
                level: 1,
                total_trades: 0,
                total_volume: 0,
                current_streak: 0,
                max_streak: 0,
                join_timestamp: current_time,
                last_activity: current_time,
                is_active: true,
            };
            
            let streak = StreakInfo {
                current_streak: 0,
                max_streak: 0,
                last_activity_day: current_time / 86400,
                streak_multiplier: 100, // 100% base
            };
            
            self.users.entry(caller).write(user);
            self.user_streaks.entry(caller).write(streak);
            
            let new_total = self.total_users.read() + 1;
            self.total_users.write(new_total);
            
            self.emit(Event::UserRegistered(UserRegistered {
                user: caller,
                timestamp: current_time,
            }));
        }

        fn is_user_registered(self: @ContractState, user: ContractAddress) -> bool {
            !self.users.entry(user).read().address.is_zero()
        }

        fn get_user_profile(self: @ContractState, user: ContractAddress) -> UserProfile {
            self.users.entry(user).read()
        }

        fn add_xp(ref self: ContractState, user: ContractAddress, amount: u256) {
            let mut user_profile = self.users.entry(user).read();
            assert(!user_profile.address.is_zero(), 'User not registered');
            
            let multiplier = self.xp_multiplier.read();
            let adjusted_amount = amount * multiplier.into() / 100;
            
            let old_level = user_profile.level;
            user_profile.xp += adjusted_amount;
            user_profile.level = self.calculate_level_from_xp(user_profile.xp);
            user_profile.last_activity = get_block_timestamp();
            
            self.users.entry(user).write(user_profile);
            
            self.emit(Event::XPAdded(XPAdded {
                user,
                amount: adjusted_amount,
                new_total: user_profile.xp,
            }));
            
            if user_profile.level > old_level {
                self.emit(Event::LevelUp(LevelUp {
                    user,
                    old_level,
                    new_level: user_profile.level,
                }));
            }
        }

        fn calculate_level_from_xp(self: @ContractState, xp: u256) -> u32 {
            if xp < 1000 {
                return 1;
            }
            
            let mut level = 2_u32;
            let mut required_xp = 1000_u256;
            
            while xp >= required_xp {
                level += 1;
                required_xp = required_xp * 150 / 100; // Each level requires 50% more XP
            }
            
            level - 1
        }

        fn get_streak_info(self: @ContractState, user: ContractAddress) -> StreakInfo {
            self.user_streaks.entry(user).read()
        }

        fn update_streak(ref self: ContractState, user: ContractAddress) {
            let mut user_profile = self.users.entry(user).read();
            let mut streak_info = self.user_streaks.entry(user).read();
            
            assert(!user_profile.address.is_zero(), 'User not registered');
            
            let current_day = get_block_timestamp() / 86400;
            let last_day = streak_info.last_activity_day;
            
            let old_streak = streak_info.current_streak;
            
            if current_day == last_day {
                // Same day, no change
                return;
            } else if current_day == last_day + 1 {
                // Consecutive day
                streak_info.current_streak += 1;
            } else {
                // Streak broken
                streak_info.current_streak = 1;
            }
            
            // Update max streak
            if streak_info.current_streak > streak_info.max_streak {
                streak_info.max_streak = streak_info.current_streak;
            }
            
            // Calculate streak multiplier (100% base + 3% per day, max 200%)
            let bonus_percentage = streak_info.current_streak * 3;
            let capped_bonus = if bonus_percentage > 100 { 100 } else { bonus_percentage };
            streak_info.streak_multiplier = 100 + capped_bonus;
            
            streak_info.last_activity_day = current_day;
            
            // Update user profile
            user_profile.current_streak = streak_info.current_streak;
            user_profile.max_streak = streak_info.max_streak;
            user_profile.last_activity = get_block_timestamp();
            
            self.user_streaks.entry(user).write(streak_info);
            self.users.entry(user).write(user_profile);
            
            self.emit(Event::StreakUpdated(StreakUpdated {
                user,
                old_streak,
                new_streak: streak_info.current_streak,
                multiplier: streak_info.streak_multiplier,
            }));
        }

        fn update_trading_stats(ref self: ContractState, user: ContractAddress, volume: u256) {
            let mut user_profile = self.users.entry(user).read();
            assert(!user_profile.address.is_zero(), 'User not registered');
            
            user_profile.total_trades += 1;
            user_profile.total_volume += volume;
            user_profile.last_activity = get_block_timestamp();
            
            self.users.entry(user).write(user_profile);
            
            self.emit(Event::TradingStatsUpdated(TradingStatsUpdated {
                user,
                total_trades: user_profile.total_trades,
                total_volume: user_profile.total_volume,
            }));
        }

        fn set_xp_multiplier(ref self: ContractState, multiplier: u32) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            self.xp_multiplier.write(multiplier);
        }

        fn get_total_users(self: @ContractState) -> u64 {
            self.total_users.read()
        }
    }

    // Trading Interface Implementation
    #[abi(embed_v0)]
    pub impl TradingImpl of ITrading<ContractState> {
        fn start_mock_session(ref self: ContractState) -> u64 {
            let caller = get_caller_address();
            assert(UserManagementImpl::is_user_registered(@self, caller), 'User not registered');
            
            let current_time = get_block_timestamp();
            let session_id = self.session_counter.read();

            let session = TradingSession {
                user: caller,
                session_id,
                start_time: current_time,
                end_time: 0,
                total_trades: 0,
                total_volume: 0,
                session_xp: 0,
                is_mock_session: true,
            };

            self.trading_sessions.entry(session_id).write(session);
            self.user_sessions.entry(caller).push(session_id);
            self.session_counter.write(session_id + 1);

            self.emit(Event::MockSessionStarted(MockSessionStarted {
                user: caller,
                session_id,
                timestamp: current_time,
            }));

            session_id
        }

        fn place_mock_trade(
            ref self: ContractState, 
            asset: felt252, 
            amount: u256, 
            direction: TradeDirection, 
            price: u256
        ) -> u64 {
            self._place_trade(asset, amount, direction, price, true)
        }

        fn close_mock_trade(ref self: ContractState, trade_id: u64, exit_price: u256) {
            self._close_trade(trade_id, exit_price);
        }

        fn end_mock_session(ref self: ContractState, session_id: u64) {
            let caller = get_caller_address();
            let mut session = self.trading_sessions.entry(session_id).read();
            
            assert(session.user == caller, 'Not session owner');
            assert(session.end_time == 0, 'Session already ended');
            
            session.end_time = get_block_timestamp();
            self.trading_sessions.entry(session_id).write(session);

            self.emit(Event::SessionEnded(SessionEnded {
                user: caller,
                session_id,
                total_xp: session.session_xp,
                total_trades: session.total_trades,
            }));
        }

        fn place_real_trade(
            ref self: ContractState, 
            asset: felt252, 
            amount: u256, 
            direction: TradeDirection, 
            price: u256
        ) -> u64 {
            self._place_trade(asset, amount, direction, price, false)
        }

        fn close_real_trade(ref self: ContractState, trade_id: u64, exit_price: u256) {
            self._close_trade(trade_id, exit_price);
        }

        fn get_trade(self: @ContractState, trade_id: u64) -> Trade {
            self.trades.entry(trade_id).read()
        }

        fn get_user_trades(self: @ContractState, user: ContractAddress) -> Array<Trade> {
            let trade_ids = self.user_trades.entry(user);
            let mut trades = array![];
            
            let mut i = 0;
            while i < trade_ids.len() {
                let trade_id = trade_ids.at(i).read();
                let trade = self.trades.entry(trade_id).read();
                trades.append(trade);
                i += 1;
            };
            
            trades
        }

        fn get_active_trades(self: @ContractState, user: ContractAddress) -> Array<Trade> {
            let active_trade_ids = self.active_trades.entry(user);
            let mut trades = array![];
            
            let mut i = 0;
            while i < active_trade_ids.len() {
                let trade_id = active_trade_ids.at(i).read();
                let trade = self.trades.entry(trade_id).read();
                if trade.exit_price == 0 {
                    trades.append(trade);
                }
                i += 1;
            };
            
            trades
        }

        fn get_trading_session(self: @ContractState, session_id: u64) -> TradingSession {
            self.trading_sessions.entry(session_id).read()
        }

        fn calculate_trade_xp(self: @ContractState, volume: u256, is_profitable: bool, is_mock: bool) -> u256 {
            let base_rate = self.base_xp_rate.read();
            let mut xp = volume * base_rate / 1000;

            if is_profitable {
                xp = xp * 120 / 100; // 20% bonus
            }

            if is_mock {
                let mock_multiplier = self.mock_trade_multiplier.read();
                xp = xp * mock_multiplier.into() / 100;
            }

            xp
        }

        fn get_daily_trading_volume(self: @ContractState, user: ContractAddress) -> u256 {
            let current_day = get_block_timestamp() / 86400;
            self.daily_volumes.entry((user, current_day)).read()
        }

        fn get_user_trading_stats(self: @ContractState, user: ContractAddress) -> (u64, u256, felt252) {
            let trade_ids = self.user_trades.entry(user);
            let mut total_trades = 0;
            let mut total_volume = 0;
            let mut total_pnl: felt252 = 0;
            
            let mut i = 0;
            while i < trade_ids.len() {
                let trade_id = trade_ids.at(i).read();
                let trade = self.trades.entry(trade_id).read();
                total_trades += 1;
                total_volume += trade.amount;
                total_pnl += trade.profit_loss;
                i += 1;
            };
            
            (total_trades, total_volume, total_pnl)
        }

        fn set_base_xp_rate(ref self: ContractState, rate: u256) {
            assert(get_caller_address() == self.owner.read(), 'Only owner');
            self.base_xp_rate.write(rate);
        }

        fn set_mock_trade_multiplier(ref self: ContractState, multiplier: u32) {
            assert(get_caller_address() == self.owner.read(), 'Only owner');
            assert(multiplier <= 100, 'Invalid multiplier');
            self.mock_trade_multiplier.write(multiplier);
        }

        fn get_total_trades(self: @ContractState) -> u64 {
            self.trade_counter.read() - 1
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn _place_trade(
            ref self: ContractState,
            asset: felt252,
            amount: u256,
            direction: TradeDirection,
            price: u256,
            is_mock: bool
        ) -> u64 {
            let caller = get_caller_address();
            assert(UserManagementImpl::is_user_registered(@self, caller), 'User not registered');
            
            let current_time = get_block_timestamp();
            let trade_id = self.trade_counter.read();

            let trade = Trade {
                id: trade_id,
                trader: caller,
                asset,
                amount,
                direction,
                entry_price: price,
                exit_price: 0,
                timestamp: current_time,
                is_mock,
                profit_loss: 0,
                xp_earned: 0,
            };

            self.trades.entry(trade_id).write(trade);
            self.user_trades.entry(caller).push(trade_id);
            self.active_trades.entry(caller).push(trade_id);
            self.trade_counter.write(trade_id + 1);

            // Update daily volume
            let current_day = current_time / 86400;
            let daily_key = (caller, current_day);
            let current_daily_volume = self.daily_volumes.entry(daily_key).read();
            self.daily_volumes.entry(daily_key).write(current_daily_volume + amount);

            // Update trading stats in user profile (direct internal call)
            UserManagementImpl::update_trading_stats(ref self, caller, amount);

            self.emit(Event::TradeOpened(TradeOpened {
                user: caller,
                trade_id,
                asset,
                amount,
                direction,
                price,
                is_mock,
            }));

            trade_id
        }

        fn _close_trade(ref self: ContractState, trade_id: u64, exit_price: u256) {
            let caller = get_caller_address();
            let mut trade = self.trades.entry(trade_id).read();
            
            assert(trade.trader == caller, 'Not trade owner');
            assert(trade.exit_price == 0, 'Trade already closed');

            trade.exit_price = exit_price;
            
            // Calculate P&L
            let price_diff = if exit_price > trade.entry_price {
                exit_price - trade.entry_price
            } else {
                trade.entry_price - exit_price
            };

            let is_long = match trade.direction {
                TradeDirection::Long => true,
                TradeDirection::Short => false,
            };

            let is_profitable = if is_long {
                exit_price > trade.entry_price
            } else {
                exit_price < trade.entry_price
            };

            trade.profit_loss = if is_profitable {
                (price_diff * trade.amount / trade.entry_price).try_into().unwrap()
            } else {
                -((price_diff * trade.amount / trade.entry_price).try_into().unwrap())
            };

            // Calculate and award XP (direct internal call - no inter-contract overhead!)
            let xp_earned = TradingImpl::calculate_trade_xp(@self, trade.amount, is_profitable, trade.is_mock);
            trade.xp_earned = xp_earned;

            self.trades.entry(trade_id).write(trade);

            // Award XP and update streak directly
            UserManagementImpl::add_xp(ref self, caller, xp_earned);
            UserManagementImpl::update_streak(ref self, caller);

            self.emit(Event::TradeClosed(TradeClosed {
                user: caller,
                trade_id,
                exit_price,
                profit_loss: trade.profit_loss,
                xp_earned,
            }));

            self.emit(Event::XPEarned(XPEarned {
                user: caller,
                amount: xp_earned,
                source: 'trade',
            }));
        }
    }
}