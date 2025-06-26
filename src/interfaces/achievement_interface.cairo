use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Achievement {
    pub id: u32,
    pub name: felt252,
    pub description: felt252,
    pub category: AchievementCategory,
    pub xp_reward: u256,
    pub rarity: AchievementRarity,
    pub requirement_type: RequirementType,
    pub requirement_value: u256,
    pub is_active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum AchievementCategory {
    #[default]
    Trading,
    Streak,
    Volume,
    Social,
    Milestone,
    Seasonal,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum AchievementRarity {
    #[default]
    Common,
    Rare,
    Epic,
    Legendary,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum RequirementType {
    #[default]
    TotalTrades,
    TotalVolume,
    ConsecutiveStreak,
    ProfitableStreak,
    DailyTrading,
    FirstTrade,
    LevelReached,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct UserAchievement {
    pub user: ContractAddress,
    pub achievement_id: u32,
    pub earned_timestamp: u64,
    pub token_id: u256,
}

#[starknet::interface]
pub trait IAchievementNFT<TContractState> {
    // Achievement management
    fn create_achievement(
        ref self: TContractState,
        name: felt252,
        description: felt252,
        category: AchievementCategory,
        xp_reward: u256,
        rarity: AchievementRarity,
        requirement_type: RequirementType,
        requirement_value: u256
    ) -> u32;
    
    fn get_achievement(self: @TContractState, achievement_id: u32) -> Achievement;
    fn get_all_achievements(self: @TContractState) -> Array<Achievement>;
    fn get_achievements_by_category(self: @TContractState, category: AchievementCategory) -> Array<Achievement>;
    
    // Achievement earning and NFT minting
    fn check_and_award_achievements(ref self: TContractState, user: ContractAddress);
    fn mint_achievement_nft(ref self: TContractState, user: ContractAddress, achievement_id: u32) -> u256;
    fn has_achievement(self: @TContractState, user: ContractAddress, achievement_id: u32) -> bool;
    
    // User achievement queries
    fn get_user_achievements(self: @TContractState, user: ContractAddress) -> Array<UserAchievement>;
    fn get_user_achievement_count(self: @TContractState, user: ContractAddress) -> u32;
    fn get_user_achievements_by_category(self: @TContractState, user: ContractAddress, category: AchievementCategory) -> Array<UserAchievement>;
    fn get_achievement_progress(self: @TContractState, user: ContractAddress, achievement_id: u32) -> (u256, u256); // current, required
    
    // NFT metadata and display
    fn get_token_metadata(self: @TContractState, token_id: u256) -> (felt252, felt252, AchievementRarity); // name, description, rarity
    fn get_user_nft_collection(self: @TContractState, user: ContractAddress) -> Array<u256>;
    
    // Statistics
    fn get_achievement_statistics(self: @TContractState, achievement_id: u32) -> (u32, u32); // total_earned, unique_holders
    fn get_rarest_achievements(self: @TContractState, limit: u32) -> Array<Achievement>;
    
    // Admin functions
    fn toggle_achievement_active(ref self: TContractState, achievement_id: u32);
    fn update_achievement_requirements(ref self: TContractState, achievement_id: u32, new_value: u256);
} 