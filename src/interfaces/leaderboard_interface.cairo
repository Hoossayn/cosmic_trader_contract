use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct LeaderboardEntry {
    pub user: ContractAddress,
    pub score: u256,
    pub rank: u32,
    pub last_updated: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum LeaderboardType {
    XP,
    TradingVolume,
    ProfitLoss,
    Streak,
    WeeklyXP,
    MonthlyVolume,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SeasonInfo {
    pub season_id: u32,
    pub start_time: u64,
    pub end_time: u64,
    pub is_active: bool,
    pub total_participants: u32,
}

#[starknet::interface]
pub trait ILeaderboard<TContractState> {
    // Leaderboard management
    fn update_user_score(ref self: TContractState, user: ContractAddress, leaderboard_type: LeaderboardType, score: u256);
    fn get_user_rank(self: @TContractState, user: ContractAddress, leaderboard_type: LeaderboardType) -> u32;
    fn get_user_score(self: @TContractState, user: ContractAddress, leaderboard_type: LeaderboardType) -> u256;
    
    // Top rankings
    fn get_top_users(self: @TContractState, leaderboard_type: LeaderboardType, limit: u32) -> Array<LeaderboardEntry>;
    fn get_leaderboard_around_user(self: @TContractState, user: ContractAddress, leaderboard_type: LeaderboardType, range: u32) -> Array<LeaderboardEntry>;
    
    // Season management
    fn start_new_season(ref self: TContractState, duration: u64) -> u32;
    fn end_current_season(ref self: TContractState);
    fn get_current_season(self: @TContractState) -> SeasonInfo;
    fn get_season_winners(self: @TContractState, season_id: u32, leaderboard_type: LeaderboardType, top_count: u32) -> Array<LeaderboardEntry>;
    
    // Clan/Alliance features (for future implementation)
    fn create_clan(ref self: TContractState, name: felt252) -> u64;
    fn join_clan(ref self: TContractState, clan_id: u64);
    fn get_clan_leaderboard(self: @TContractState, limit: u32) -> Array<LeaderboardEntry>;
    
    // Statistics
    fn get_total_participants(self: @TContractState, leaderboard_type: LeaderboardType) -> u32;
    fn is_user_in_top_percent(self: @TContractState, user: ContractAddress, leaderboard_type: LeaderboardType, percent: u32) -> bool;
    
    // Admin functions
    fn reset_leaderboard(ref self: TContractState, leaderboard_type: LeaderboardType);
    fn set_update_frequency(ref self: TContractState, frequency: u64);
} 