use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp};

use cosmic_trader_contract::interfaces::user_interface::{IUserManagementDispatcher, IUserManagementDispatcherTrait};
use cosmic_trader_contract::interfaces::trading_interface::{ITradingDispatcher, ITradingDispatcherTrait, TradeDirection};

fn deploy_cosmic_trader() -> (IUserManagementDispatcher, ITradingDispatcher, ContractAddress) {
    let contract = declare("CosmicTrader").unwrap().contract_class();
    let owner = contract_address_const::<'owner'>();
    let constructor_args = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    
    let user_management = IUserManagementDispatcher { contract_address };
    let trading = ITradingDispatcher { contract_address };
    
    (user_management, trading, owner)
}

#[test]
fn test_user_registration() {
    let (user_management, _trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    start_cheat_block_timestamp(user_management.contract_address, 1000);
    
    // Register user
    user_management.register_user();
    
    // Verify registration
    assert(user_management.is_user_registered(user), 'User should be registered');
    
    let profile = user_management.get_user_profile(user);
    assert(profile.address == user, 'Wrong user address');
    assert(profile.xp == 0, 'Initial XP should be 0');
    assert(profile.level == 1, 'Initial level should be 1');
    assert(profile.current_streak == 0, 'Initial streak should be 0');
    assert(profile.join_timestamp == 1000, 'Wrong join timestamp');
    assert(profile.is_active == true, 'User should be active');
    
    stop_cheat_caller_address(user_management.contract_address);
    stop_cheat_block_timestamp(user_management.contract_address);
}

#[test]
#[should_panic(expected: 'User already registered')]
fn test_duplicate_registration() {
    let (user_management, _trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    
    // Register user twice
    user_management.register_user();
    user_management.register_user(); // Should panic
    
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
fn test_xp_addition_and_level_calculation() {
    let (user_management, _trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    stop_cheat_caller_address(user_management.contract_address);
    
    // Add XP
    user_management.add_xp(user, 500);
    
    let profile = user_management.get_user_profile(user);
    assert(profile.xp == 500, 'XP should be 500');
    assert(profile.level == 1, 'Should still be level 1');
    
    // Add more XP to reach level 2
    user_management.add_xp(user, 600);
    
    let profile = user_management.get_user_profile(user);
    assert(profile.xp == 1100, 'XP should be 1100');
    assert(profile.level == 2, 'Should be level 2');
    
    // Test level calculation directly
    let level = user_management.calculate_level_from_xp(2500);
    assert(level == 4, 'Level should be 4 for 2500 XP');
}

#[test]
fn test_streak_management() {
    let (user_management, _trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    stop_cheat_caller_address(user_management.contract_address);
    
    // Start with day 1
    start_cheat_block_timestamp(user_management.contract_address, 86400); // Day 1
    user_management.update_streak(user);
    
    let streak_info = user_management.get_streak_info(user);
    assert(streak_info.current_streak == 1, 'First day streak should be 1');
    
    // Continue to day 2
    start_cheat_block_timestamp(user_management.contract_address, 86400 * 2); // Day 2
    user_management.update_streak(user);
    
    let streak_info = user_management.get_streak_info(user);
    assert(streak_info.current_streak == 2, 'Second day streak should be 2');
    
    let profile = user_management.get_user_profile(user);
    assert(profile.current_streak == 2, 'Profile streak should be 2');
    assert(profile.max_streak == 2, 'Max streak should be 2');
    
    // Skip a day (break streak)
    start_cheat_block_timestamp(user_management.contract_address, 86400 * 4); // Day 4 (skip day 3)
    user_management.update_streak(user);
    
    let streak_info = user_management.get_streak_info(user);
    assert(streak_info.current_streak == 1, 'Broken streak should reset to 1');
    
    let profile = user_management.get_user_profile(user);
    assert(profile.current_streak == 1, 'Profile streak should be 1');
    assert(profile.max_streak == 2, 'Max streak should remain 2');
    
    stop_cheat_block_timestamp(user_management.contract_address);
}

#[test]
fn test_mock_trading_session() {
    let (user_management, trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    
    // Start mock session
    let _session_id = trading.start_mock_session();
    assert(_session_id == 1, 'Session ID should be 1');
    
    let session = trading.get_trading_session(_session_id);
    assert(session.user == user, 'Session user should match');
    assert(session.is_mock_session == true, 'Should be mock session');
    
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
#[should_panic(expected: 'User not registered')]
fn test_trading_requires_registration() {
    let (_user_management, trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    
    // Try to start session without registration - should panic
    trading.start_mock_session();
    
    stop_cheat_caller_address(trading.contract_address);
}

#[test]
fn test_integrated_trading_and_xp() {
    let (user_management, trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    
    // Start mock session
    let _session_id = trading.start_mock_session();
    
    // Place a mock trade
    let trade_id = trading.place_mock_trade('BTC', 1000, TradeDirection::Long, 50000);
    assert(trade_id == 1, 'Trade ID should be 1');
    
    // Check initial XP (should be 0)
    let profile_before = user_management.get_user_profile(user);
    assert(profile_before.xp == 0, 'Initial XP should be 0');
    
    // Close the trade with profit
    trading.close_mock_trade(trade_id, 55000); // 10% profit
    
    // Check that XP was awarded automatically
    let profile_after = user_management.get_user_profile(user);
    assert(profile_after.xp > 0, 'XP should be awarded');
    assert(profile_after.total_trades == 1, 'Trade count should be 1');
    assert(profile_after.total_volume == 1000, 'Volume should be 1000');
    
    // Note: Streak only updates on consecutive different days, so it remains 0 for same-day trading
    
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
fn test_trade_xp_calculation() {
    let (user_management, trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    
    // Test XP calculation for profitable trade
    let xp_profitable = trading.calculate_trade_xp(1000, true, true); // Mock profitable trade
    
    // Test XP calculation for unprofitable trade
    let xp_unprofitable = trading.calculate_trade_xp(1000, false, true); // Mock unprofitable trade
    
    // Profitable trades should give more XP
    assert(xp_profitable > xp_unprofitable, 'More XP for profit');
    
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
fn test_multiple_trades_and_stats() {
    let (user_management, trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    
    // Place multiple trades
    let trade1 = trading.place_mock_trade('BTC', 1000, TradeDirection::Long, 50000);
    let trade2 = trading.place_mock_trade('ETH', 2000, TradeDirection::Short, 3000);
    
    // Close trades
    trading.close_mock_trade(trade1, 55000); // Profit
    trading.close_mock_trade(trade2, 2800);  // Profit for short
    
    // Check aggregated stats
    let profile = user_management.get_user_profile(user);
    assert(profile.total_trades == 2, 'Should have 2 trades');
    assert(profile.total_volume == 3000, 'Total volume should be 3000');
    assert(profile.xp > 0, 'Should have earned XP');
    
    // Check trading stats function
    let (total_trades, total_volume, _total_pnl) = trading.get_user_trading_stats(user);
    assert(total_trades == 2, 'Should show 2 trades');
    assert(total_volume == 3000, 'Volume should be 3000');
    
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
fn test_owner_controls() {
    let (user_management, trading, owner) = deploy_cosmic_trader();
    
    start_cheat_caller_address(user_management.contract_address, owner);
    
    // Test XP multiplier
    user_management.set_xp_multiplier(150); // 150% multiplier
    
    // Test base XP rate
    trading.set_base_xp_rate(20); // 20 XP per $1
    
    // Test mock trade multiplier
    trading.set_mock_trade_multiplier(75); // 75% for mock trades
    
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
#[should_panic(expected: 'Only owner allowed')]
fn test_unauthorized_owner_functions() {
    let (user_management, _trading, _owner) = deploy_cosmic_trader();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    
    // Non-owner trying to set multiplier - should panic
    user_management.set_xp_multiplier(200);
    
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
fn test_user_count() {
    let (user_management, _trading, _owner) = deploy_cosmic_trader();
    
    assert(user_management.get_total_users() == 0, 'Initial count should be 0');
    
    // Register first user
    let user1 = contract_address_const::<'user1'>();
    start_cheat_caller_address(user_management.contract_address, user1);
    user_management.register_user();
    stop_cheat_caller_address(user_management.contract_address);
    
    assert(user_management.get_total_users() == 1, 'Count should be 1');
    
    // Register second user
    let user2 = contract_address_const::<'user2'>();
    start_cheat_caller_address(user_management.contract_address, user2);
    user_management.register_user();
    stop_cheat_caller_address(user_management.contract_address);
    
    assert(user_management.get_total_users() == 2, 'Count should be 2');
} 