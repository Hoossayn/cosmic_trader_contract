use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct Trade {
    pub id: u64,
    pub trader: ContractAddress,
    pub asset: felt252,
    pub amount: u256,
    pub direction: TradeDirection,
    pub entry_price: u256,
    pub exit_price: u256,
    pub timestamp: u64,
    pub is_mock: bool,
    pub profit_loss: felt252, // Use felt252 for signed values
    pub xp_earned: u256,
}

#[derive(Drop, Serde, starknet::Store, Copy)]
pub enum TradeDirection {
    #[default]
    Long,
    Short,
}

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct TradingSession {
    pub user: ContractAddress,
    pub session_id: u64,
    pub start_time: u64,
    pub end_time: u64,
    pub total_trades: u32,
    pub total_volume: u256,
    pub session_xp: u256,
    pub is_mock_session: bool,
}

#[starknet::interface]
pub trait ITrading<TContractState> {
    // Mock trading for free-to-play mode
    fn start_mock_session(ref self: TContractState) -> u64;
    fn place_mock_trade(
        ref self: TContractState, 
        asset: felt252, 
        amount: u256, 
        direction: TradeDirection, 
        price: u256
    ) -> u64;
    fn close_mock_trade(ref self: TContractState, trade_id: u64, exit_price: u256);
    fn end_mock_session(ref self: TContractState, session_id: u64);
    
    // Real trading integration
    fn place_real_trade(
        ref self: TContractState, 
        asset: felt252, 
        amount: u256, 
        direction: TradeDirection, 
        price: u256
    ) -> u64;
    fn close_real_trade(ref self: TContractState, trade_id: u64, exit_price: u256);
    
    // Trade management and queries
    fn get_trade(self: @TContractState, trade_id: u64) -> Trade;
    fn get_user_trades(self: @TContractState, user: ContractAddress) -> Array<Trade>;
    fn get_active_trades(self: @TContractState, user: ContractAddress) -> Array<Trade>;
    fn get_trading_session(self: @TContractState, session_id: u64) -> TradingSession;
    
    // XP calculation and rewards
    fn calculate_trade_xp(self: @TContractState, volume: u256, is_profitable: bool, is_mock: bool) -> u256;
    fn get_daily_trading_volume(self: @TContractState, user: ContractAddress) -> u256;
    fn get_user_trading_stats(self: @TContractState, user: ContractAddress) -> (u64, u256, felt252); // trades, volume, pnl
    
    // Admin functions
    fn set_base_xp_rate(ref self: TContractState, rate: u256);
    fn set_mock_trade_multiplier(ref self: TContractState, multiplier: u32);
    fn get_total_trades(self: @TContractState) -> u64;
} 