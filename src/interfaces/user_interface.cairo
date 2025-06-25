use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct UserProfile {
    pub address: ContractAddress,
    pub xp: u256,
    pub level: u32,
    pub total_trades: u64,
    pub total_volume: u256,
    pub current_streak: u32,
    pub max_streak: u32,
    pub join_timestamp: u64,
    pub last_activity: u64,
    pub is_active: bool,
}

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct StreakInfo {
    pub current_streak: u32,
    pub max_streak: u32,
    pub last_activity_day: u64,
    pub streak_multiplier: u32,
}

#[starknet::interface]
pub trait IUserManagement<TContractState> {
    // User registration and profile management
    fn register_user(ref self: TContractState);
    fn get_user_profile(self: @TContractState, user: ContractAddress) -> UserProfile;
    fn is_user_registered(self: @TContractState, user: ContractAddress) -> bool;
    
    // XP and level management
    fn add_xp(ref self: TContractState, user: ContractAddress, amount: u256);
    fn calculate_level_from_xp(self: @TContractState, xp: u256) -> u32;
    
    // Streak management
    fn update_streak(ref self: TContractState, user: ContractAddress);
    fn get_streak_info(self: @TContractState, user: ContractAddress) -> StreakInfo;
    
    // Trading stats
    fn update_trading_stats(ref self: TContractState, user: ContractAddress, volume: u256);
    
    // Admin functions
    fn set_xp_multiplier(ref self: TContractState, multiplier: u32);
    fn get_total_users(self: @TContractState) -> u64;
} 