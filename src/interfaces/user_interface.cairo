use starknet::ContractAddress;

/// Represents a user's profile in the cosmic trading system
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

/// Information about a user's streak and multipliers
#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct StreakInfo {
    pub current_streak: u32,
    pub max_streak: u32,
    pub last_activity_day: u64,
    pub streak_multiplier: u32,
}

/// Interface for user management operations in the cosmic trading system
#[starknet::interface]
pub trait IUserManagement<TContractState> {
    /// Registers a new user in the system
    /// 
    /// # Panics
    /// 
    /// * If the user is already registered
    fn register_user(ref self: TContractState);
    
    /// Gets the profile information for a specific user
    /// 
    /// # Arguments
    /// 
    /// * `user` - The address of the user to query
    /// 
    /// # Returns
    /// 
    /// The user's complete profile information
    fn get_user_profile(self: @TContractState, user: ContractAddress) -> UserProfile;
    
    /// Checks if a user is registered in the system
    /// 
    /// # Arguments
    /// 
    /// * `user` - The address to check
    /// 
    /// # Returns
    /// 
    /// True if the user is registered, false otherwise
    fn is_user_registered(self: @TContractState, user: ContractAddress) -> bool;
    
    /// Adds XP to a user's account
    /// 
    /// # Arguments
    /// 
    /// * `user` - The user to award XP to
    /// * `amount` - The amount of XP to add
    fn add_xp(ref self: TContractState, user: ContractAddress, amount: u256);
    
    /// Calculates the level based on total XP
    /// 
    /// # Arguments
    /// 
    /// * `xp` - The total XP amount
    /// 
    /// # Returns
    /// 
    /// The corresponding level
    fn calculate_level_from_xp(self: @TContractState, xp: u256) -> u32;
    
    /// Updates a user's daily activity streak
    /// 
    /// # Arguments
    /// 
    /// * `user` - The user whose streak to update
    fn update_streak(ref self: TContractState, user: ContractAddress);
    
    /// Gets streak information for a user
    /// 
    /// # Arguments
    /// 
    /// * `user` - The user to query
    /// 
    /// # Returns
    /// 
    /// Complete streak information including current streak and multipliers
    fn get_streak_info(self: @TContractState, user: ContractAddress) -> StreakInfo;
    
    /// Updates trading statistics for a user
    /// 
    /// # Arguments
    /// 
    /// * `user` - The user whose stats to update
    /// * `volume` - The trading volume to add
    fn update_trading_stats(ref self: TContractState, user: ContractAddress, volume: u256);
    
    /// Sets the global XP multiplier (admin only)
    /// 
    /// # Arguments
    /// 
    /// * `multiplier` - The new multiplier percentage (100 = 100%)
    fn set_xp_multiplier(ref self: TContractState, multiplier: u32);
    
    /// Gets the total number of registered users
    /// 
    /// # Returns
    /// 
    /// The total user count
    fn get_total_users(self: @TContractState) -> u64;
} 