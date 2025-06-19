use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp};

use cosmic_trader_contract::interfaces::trading_interface::{ITradingDispatcher, ITradingDispatcherTrait, TradeDirection};

fn deploy_trading() -> (ITradingDispatcher, ContractAddress) {
    let contract = declare("Trading").unwrap().contract_class();
    let owner = contract_address_const::<'owner'>();
    let user_management_contract = contract_address_const::<'user_mgmt'>();
    let constructor_args = array![owner.into(), user_management_contract.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    (ITradingDispatcher { contract_address }, owner)
}

#[test]
fn test_mock_session_lifecycle() {
    let (trading, _owner) = deploy_trading();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    start_cheat_block_timestamp(trading.contract_address, 1000);
    
    // Start mock session
    let session_id = trading.start_mock_session();
    assert(session_id == 1, 'Session ID should be 1');
    
    let session = trading.get_trading_session(session_id);
    assert(session.user == user, 'Wrong session user');
    assert(session.is_mock_session == true, 'Should be mock session');
    assert(session.start_time == 1000, 'Wrong start time');
    assert(session.end_time == 0, 'End time should be 0');
    
    // End session
    start_cheat_block_timestamp(trading.contract_address, 2000);
    trading.end_mock_session(session_id);
    
    let session = trading.get_trading_session(session_id);
    assert(session.end_time == 2000, 'Wrong end time');
    
    stop_cheat_caller_address(trading.contract_address);
    stop_cheat_block_timestamp(trading.contract_address);
}

#[test]
fn test_mock_trade_placement() {
    let (trading, _owner) = deploy_trading();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    start_cheat_block_timestamp(trading.contract_address, 1000);
    
    // Place mock trade
    let trade_id = trading.place_mock_trade(
        'ETH/USD',    // asset
        1000,         // amount (in wei equivalent)
        TradeDirection::Long,
        2000          // price
    );
    
    assert(trade_id == 1, 'Trade ID should be 1');
    
    let trade = trading.get_trade(trade_id);
    assert(trade.id == trade_id, 'Wrong trade ID');
    assert(trade.trader == user, 'Wrong trader');
    assert(trade.asset == 'ETH/USD', 'Wrong asset');
    assert(trade.amount == 1000, 'Wrong amount');
    assert(trade.entry_price == 2000, 'Wrong entry price');
    assert(trade.is_mock == true, 'Should be mock trade');
    assert(trade.exit_price == 0, 'Exit price should be 0');
    assert(trade.timestamp == 1000, 'Wrong timestamp');
    
    stop_cheat_caller_address(trading.contract_address);
    stop_cheat_block_timestamp(trading.contract_address);
}

#[test]
fn test_mock_trade_closure_profitable() {
    let (trading, _owner) = deploy_trading();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    start_cheat_block_timestamp(trading.contract_address, 1000);
    
    // Place and close profitable long trade
    let trade_id = trading.place_mock_trade(
        'ETH/USD',
        1000,
        TradeDirection::Long,
        2000  // entry price
    );
    
    start_cheat_block_timestamp(trading.contract_address, 2000);
    trading.close_mock_trade(trade_id, 2200); // exit at higher price (profitable)
    
    let trade = trading.get_trade(trade_id);
    assert(trade.exit_price == 2200, 'Wrong exit price');
    assert(trade.profit_loss != 0, 'Should have P&L');
    assert(trade.xp_earned > 0, 'Should earn XP');
    
    stop_cheat_caller_address(trading.contract_address);
    stop_cheat_block_timestamp(trading.contract_address);
}

#[test]
fn test_mock_trade_closure_loss() {
    let (trading, _owner) = deploy_trading();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    start_cheat_block_timestamp(trading.contract_address, 1000);
    
    // Place and close losing short trade
    let trade_id = trading.place_mock_trade(
        'ETH/USD',
        1000,
        TradeDirection::Short,
        2000  // entry price
    );
    
    start_cheat_block_timestamp(trading.contract_address, 2000);
    trading.close_mock_trade(trade_id, 2200); // exit at higher price (loss for short)
    
    let trade = trading.get_trade(trade_id);
    assert(trade.exit_price == 2200, 'Wrong exit price');
    assert(trade.profit_loss != 0, 'Should have P&L');
    assert(trade.xp_earned > 0, 'Should still earn some XP');
    
    stop_cheat_caller_address(trading.contract_address);
    stop_cheat_block_timestamp(trading.contract_address);
}

#[test]
fn test_xp_calculation() {
    let (trading, _owner) = deploy_trading();
    
    // Test profitable mock trade XP
    let xp_profitable_mock = trading.calculate_trade_xp(1000, true, true);
    let xp_profitable_real = trading.calculate_trade_xp(1000, true, false);
    let xp_loss_mock = trading.calculate_trade_xp(1000, false, true);
    let xp_loss_real = trading.calculate_trade_xp(1000, false, false);
    
    // Profitable trades should give more XP than losing trades
    assert(xp_profitable_mock > xp_loss_mock, 'Profitable should give more XP');
    assert(xp_profitable_real > xp_loss_real, 'Profitable should give more XP');
    
    // Real trades should give more XP than mock trades
    assert(xp_profitable_real > xp_profitable_mock, 'Real should give more XP');
    assert(xp_loss_real > xp_loss_mock, 'Real should give more XP');
}

#[test]
fn test_user_trades_retrieval() {
    let (trading, _owner) = deploy_trading();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    
    // Place multiple trades
    let trade_id1 = trading.place_mock_trade('ETH/USD', 1000, TradeDirection::Long, 2000);
    let trade_id2 = trading.place_mock_trade('BTC/USD', 500, TradeDirection::Short, 45000);
    let trade_id3 = trading.place_real_trade('SOL/USD', 2000, TradeDirection::Long, 100);
    
    let user_trades = trading.get_user_trades(user);
    assert(user_trades.len() == 3, 'Should have 3 trades');
    
    let active_trades = trading.get_active_trades(user);
    assert(active_trades.len() == 3, 'All trades should be active');
    
    // Close one trade
    trading.close_mock_trade(trade_id1, 2100);
    
    let active_trades = trading.get_active_trades(user);
    assert(active_trades.len() == 2, 'Should have 2 active trades');
    
    stop_cheat_caller_address(trading.contract_address);
}

#[test]
fn test_daily_volume_tracking() {
    let (trading, _owner) = deploy_trading();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    start_cheat_block_timestamp(trading.contract_address, 86400); // Day 1
    
    // Place trades on day 1
    trading.place_mock_trade('ETH/USD', 1000, TradeDirection::Long, 2000);
    trading.place_mock_trade('BTC/USD', 500, TradeDirection::Short, 45000);
    
    let daily_volume = trading.get_daily_trading_volume(user);
    assert(daily_volume == 1500, 'Daily volume should be 1500');
    
    // Move to day 2
    start_cheat_block_timestamp(trading.contract_address, 86400 * 2);
    
    let daily_volume = trading.get_daily_trading_volume(user);
    assert(daily_volume == 0, 'New day volume should be 0');
    
    trading.place_mock_trade('SOL/USD', 2000, TradeDirection::Long, 100);
    
    let daily_volume = trading.get_daily_trading_volume(user);
    assert(daily_volume == 2000, 'Day 2 volume should be 2000');
    
    stop_cheat_caller_address(trading.contract_address);
    stop_cheat_block_timestamp(trading.contract_address);
}

#[test]
fn test_trading_statistics() {
    let (trading, _owner) = deploy_trading();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    
    // Place and close some trades
    let trade_id1 = trading.place_mock_trade('ETH/USD', 1000, TradeDirection::Long, 2000);
    let trade_id2 = trading.place_mock_trade('BTC/USD', 500, TradeDirection::Short, 45000);
    
    trading.close_mock_trade(trade_id1, 2200); // Profitable
    trading.close_mock_trade(trade_id2, 44000); // Profitable short
    
    let (total_trades, total_volume, total_pnl) = trading.get_user_trading_stats(user);
    assert(total_trades == 2, 'Should have 2 trades');
    assert(total_volume == 1500, 'Total volume should be 1500');
    assert(total_pnl != 0, 'Should have P&L');
    
    stop_cheat_caller_address(trading.contract_address);
}

#[test]
fn test_admin_functions() {
    let (trading, owner) = deploy_trading();
    
    start_cheat_caller_address(trading.contract_address, owner);
    
    // Test setting XP rate
    trading.set_base_xp_rate(20);
    
    // Test setting mock multiplier
    trading.set_mock_trade_multiplier(75);
    
    stop_cheat_caller_address(trading.contract_address);
    
    // Verify the changes affect XP calculation
    let xp_before = trading.calculate_trade_xp(1000, true, true);
    
    let user = contract_address_const::<'user1'>();
    start_cheat_caller_address(trading.contract_address, user);
    let trade_id = trading.place_mock_trade('ETH/USD', 1000, TradeDirection::Long, 2000);
    trading.close_mock_trade(trade_id, 2200);
    stop_cheat_caller_address(trading.contract_address);
    
    let trade = trading.get_trade(trade_id);
    // XP should be affected by the new rates
    assert(trade.xp_earned > 0, 'Should earn XP with new rates');
}

#[test]
#[should_panic(expected: 'Only owner')]
fn test_unauthorized_admin_access() {
    let (trading, _owner) = deploy_trading();
    let user = contract_address_const::<'user1'>();
    
    start_cheat_caller_address(trading.contract_address, user);
    trading.set_base_xp_rate(50); // Should panic - not owner
    stop_cheat_caller_address(trading.contract_address);
} 