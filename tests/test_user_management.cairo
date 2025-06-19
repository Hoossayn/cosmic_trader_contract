use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp};

use cosmic_trader_contract::interfaces::user_interface::{IUserManagementDispatcher, IUserManagementDispatcherTrait};

fn deploy_user_management() -> (IUserManagementDispatcher, ContractAddress) {
    let contract = declare("UserManagement").unwrap().contract_class();
    let owner = contract_address_const::<'owner'>();
    let constructor_args = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    (IUserManagementDispatcher { contract_address }, owner)
}

#[test]
fn test_user_registration() {
    let (user_management, _owner) = deploy_user_management();
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
    let (user_management, _owner) = deploy_user_management();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    
    // Register user twice
    user_management.register_user();
    user_management.register_user(); // Should panic
    
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
fn test_xp_addition_and_level_calculation() {
    let (user_management, _owner) = deploy_user_management();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    stop_cheat_caller_address(user_management.contract_address);
    
    // Add XP (assuming this would be called by trading contract)
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
    let (user_management, _owner) = deploy_user_management();
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
fn test_streak_multiplier() {
    let (user_management, _owner) = deploy_user_management();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    stop_cheat_caller_address(user_management.contract_address);
    
    // Build up a 10-day streak
    let mut day = 1;
    while day <= 10 {
        start_cheat_block_timestamp(user_management.contract_address, 86400 * day);
        user_management.update_streak(user);
        day += 1;
    };
    
    let streak_info = user_management.get_streak_info(user);
    assert(streak_info.current_streak == 10, 'Should have 10-day streak');
    assert(streak_info.streak_multiplier == 130, 'Multiplier should be 130%');
    
    stop_cheat_block_timestamp(user_management.contract_address);
}

#[test]
fn test_trading_stats_update() {
    let (user_management, _owner) = deploy_user_management();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    stop_cheat_caller_address(user_management.contract_address);
    
    // Update trading stats
    user_management.update_trading_stats(user, 1000);
    
    let profile = user_management.get_user_profile(user);
    assert(profile.total_trades == 1, 'Should have 1 trade');
    assert(profile.total_volume == 1000, 'Volume should be 1000');
    
    // Add more trades
    user_management.update_trading_stats(user, 2000);
    user_management.update_trading_stats(user, 1500);
    
    let profile = user_management.get_user_profile(user);
    assert(profile.total_trades == 3, 'Should have 3 trades');
    assert(profile.total_volume == 4500, 'Volume should be 4500');
}

#[test]
fn test_xp_multiplier() {
    let (user_management, owner) = deploy_user_management();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.register_user();
    stop_cheat_caller_address(user_management.contract_address);
    
    // Set XP multiplier as owner
    start_cheat_caller_address(user_management.contract_address, owner);
    user_management.set_xp_multiplier(150); // 150% multiplier
    stop_cheat_caller_address(user_management.contract_address);
    
    // Add XP and verify multiplier effect
    user_management.add_xp(user, 1000);
    
    let profile = user_management.get_user_profile(user);
    assert(profile.xp == 1500, 'XP should be 1500 (1000 * 1.5)');
}

#[test]
#[should_panic(expected: 'Only owner')]
fn test_unauthorized_xp_multiplier_change() {
    let (user_management, _owner) = deploy_user_management();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(user_management.contract_address, user);
    user_management.set_xp_multiplier(200); // Should panic - not owner
    stop_cheat_caller_address(user_management.contract_address);
}

#[test]
fn test_user_count() {
    let (user_management, _owner) = deploy_user_management();
    
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