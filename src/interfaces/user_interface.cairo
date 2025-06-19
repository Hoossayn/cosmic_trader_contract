use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct User {
    pub address: ContractAddress,
    pub xp: u256,
    pub level: u32,
    pub current_streak: u32,
    pub max_streak: u32,
    pub join_timestamp: u64,
    pub total_trades: u64,
    pub total_volume: u256,
    pub is_active: bool,
}

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct StreakInfo {
    pub current_streak: u32,
    pub last_trade_day: u64,
    pub streak_multiplier: u32,
}

#[starknet::interface]
pub trait IUserManagement<TContractState> {
    // User registration and profile management
    fn register_user(ref self: TContractState);
    fn get_user_profile(self: @TContractState, user: ContractAddress) -> User;
    fn is_user_registered(self: @TContractState, user: ContractAddress) -> bool;
    
    // XP and level management
    fn add_xp(ref self: TContractState, user: ContractAddress, xp_amount: u256);
    fn get_user_xp(self: @TContractState, user: ContractAddress) -> u256;
    fn get_user_level(self: @TContractState, user: ContractAddress) -> u32;
    fn calculate_level_from_xp(self: @TContractState, xp: u256) -> u32;
    
    // Streak management
    fn update_streak(ref self: TContractState, user: ContractAddress);
    fn get_streak_info(self: @TContractState, user: ContractAddress) -> StreakInfo;
    fn reset_streak(ref self: TContractState, user: ContractAddress);
    
    // Trading stats
    fn update_trading_stats(ref self: TContractState, user: ContractAddress, volume: u256);
    fn get_total_trades(self: @TContractState, user: ContractAddress) -> u64;
    fn get_total_volume(self: @TContractState, user: ContractAddress) -> u256;
    
    // Admin functions
    fn set_xp_multiplier(ref self: TContractState, multiplier: u32);
    fn get_total_users(self: @TContractState) -> u64;
} 