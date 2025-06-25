// Cosmic Trader Contract - Gamified Perpetual Trading on Starknet
// A comprehensive smart contract system for gamified perpetual trading
// including user management, XP tracking, leaderboards, and achievement NFTs

// Core interfaces
pub mod interfaces {
    pub mod user_interface;
    pub mod trading_interface;
    pub mod leaderboard_interface;
    pub mod achievement_interface;
}

// Combined contract implementation
pub mod cosmic_trader;

// Legacy contracts (now deprecated in favor of combined contract)
// pub mod user_management;
// pub mod trading;

// Re-export main contract for easy access
pub use cosmic_trader::CosmicTrader;
