#[starknet::contract]
pub mod Trading {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::{get_caller_address, get_block_timestamp};
    use super::super::interfaces::trading_interface::{Trade, TradeDirection, TradingSession};

    #[storage]
    pub struct Storage {
        trades: Map<u64, Trade>,
        user_trades: Map<ContractAddress, Vec<u64>>,
        active_trades: Map<ContractAddress, Vec<u64>>,
        trading_sessions: Map<u64, TradingSession>,
        user_sessions: Map<ContractAddress, Vec<u64>>,
        trade_counter: u64,
        session_counter: u64,
        base_xp_rate: u256,
        mock_trade_multiplier: u32,
        owner: ContractAddress,
        user_management_contract: ContractAddress,
        daily_volumes: Map<(ContractAddress, u64), u256>, // (user, day) -> volume
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MockSessionStarted: MockSessionStarted,
        TradeOpened: TradeOpened,
        TradeClosed: TradeClosed,
        SessionEnded: SessionEnded,
        XPEarned: XPEarned,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MockSessionStarted {
        user: ContractAddress,
        session_id: u64,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TradeOpened {
        user: ContractAddress,
        trade_id: u64,
        asset: felt252,
        amount: u256,
        direction: TradeDirection,
        price: u256,
        is_mock: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TradeClosed {
        user: ContractAddress,
        trade_id: u64,
        exit_price: u256,
        profit_loss: felt252,
        xp_earned: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SessionEnded {
        user: ContractAddress,
        session_id: u64,
        total_xp: u256,
        total_trades: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct XPEarned {
        user: ContractAddress,
        amount: u256,
        source: felt252, // 'trade', 'streak_bonus', etc.
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        owner: ContractAddress,
        user_management_contract: ContractAddress
    ) {
        self.owner.write(owner);
        self.user_management_contract.write(user_management_contract);
        self.base_xp_rate.write(10); // 10 XP per $1 volume
        self.mock_trade_multiplier.write(50); // 50% XP for mock trades
        self.trade_counter.write(1);
        self.session_counter.write(1);
    }

    #[abi(embed_v0)]
    pub impl TradingImpl of super::super::interfaces::trading_interface::ITrading<ContractState> {
        fn start_mock_session(ref self: ContractState) -> u64 {
            let caller = get_caller_address();
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
            self.user_sessions.entry(caller).append().write(session_id);
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
            // TODO: Integrate with Extended API for real trading
            self._place_trade(asset, amount, direction, price, false)
        }

        fn close_real_trade(ref self: ContractState, trade_id: u64, exit_price: u256) {
            // TODO: Integrate with Extended API for real trade closure
            self._close_trade(trade_id, exit_price);
        }

        fn get_trade(self: @ContractState, trade_id: u64) -> Trade {
            self.trades.entry(trade_id).read()
        }

        fn get_user_trades(self: @ContractState, user: ContractAddress) -> Array<Trade> {
            let trade_ids = self.user_trades.entry(user);
            let mut trades = array![];
            
            for i in 0..trade_ids.len() {
                let trade_id = trade_ids.at(i).read();
                let trade = self.trades.entry(trade_id).read();
                trades.append(trade);
            };
            
            trades
        }

        fn get_active_trades(self: @ContractState, user: ContractAddress) -> Array<Trade> {
            let active_trade_ids = self.active_trades.entry(user);
            let mut trades = array![];
            
            for i in 0..active_trade_ids.len() {
                let trade_id = active_trade_ids.at(i).read();
                let trade = self.trades.entry(trade_id).read();
                if trade.exit_price == 0 { // Trade is still open
                    trades.append(trade);
                }
            };
            
            trades
        }

        fn get_trading_session(self: @ContractState, session_id: u64) -> TradingSession {
            self.trading_sessions.entry(session_id).read()
        }

        fn calculate_trade_xp(self: @ContractState, volume: u256, is_profitable: bool, is_mock: bool) -> u256 {
            let base_rate = self.base_xp_rate.read();
            let mut xp = volume * base_rate / 1000; // Assuming volume is in wei, adjust for actual currency

            // Bonus for profitable trades
            if is_profitable {
                xp = xp * 120 / 100; // 20% bonus
            }

            // Reduce XP for mock trades
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
            
            for i in 0..trade_ids.len() {
                let trade_id = trade_ids.at(i).read();
                let trade = self.trades.entry(trade_id).read();
                total_trades += 1;
                total_volume += trade.amount;
                total_pnl += trade.profit_loss;
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
            self.user_trades.entry(caller).append().write(trade_id);
            self.active_trades.entry(caller).append().write(trade_id);
            self.trade_counter.write(trade_id + 1);

            // Update daily volume
            let current_day = current_time / 86400;
            let daily_key = (caller, current_day);
            let current_daily_volume = self.daily_volumes.entry(daily_key).read();
            self.daily_volumes.entry(daily_key).write(current_daily_volume + amount);

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

            // Simplified P&L calculation (in practice, this would be more complex)
            trade.profit_loss = if is_profitable {
                (price_diff * trade.amount / trade.entry_price).try_into().unwrap()
            } else {
                -((price_diff * trade.amount / trade.entry_price).try_into().unwrap())
            };

            // Calculate and award XP
            let xp_earned = self.calculate_trade_xp(trade.amount, is_profitable, trade.is_mock);
            trade.xp_earned = xp_earned;

            self.trades.entry(trade_id).write(trade);

            // Award XP through user management contract
            // TODO: Call user management contract to add XP and update streak

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