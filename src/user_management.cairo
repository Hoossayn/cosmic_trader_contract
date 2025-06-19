
#[starknet::contract]
pub mod UserManagement {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::{get_caller_address, get_block_timestamp};
    use core::num::traits::Zero;
    
    use super::super::interfaces::user_interface::{User, StreakInfo};

    #[storage]
    pub struct Storage {
        users: Map<ContractAddress, User>,
        streak_info: Map<ContractAddress, StreakInfo>,
        user_count: u64,
        xp_multiplier: u32,
        owner: ContractAddress,
        level_requirements: Map<u32, u256>, // level -> xp required
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UserRegistered: UserRegistered,
        XPAdded: XPAdded,
        LevelUp: LevelUp,
        StreakUpdated: StreakUpdated,
        StreakReset: StreakReset,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UserRegistered {
        user: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct XPAdded {
        user: ContractAddress,
        amount: u256,
        new_total: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LevelUp {
        user: ContractAddress,
        old_level: u32,
        new_level: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreakUpdated {
        user: ContractAddress,
        new_streak: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreakReset {
        user: ContractAddress,
        previous_streak: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.xp_multiplier.write(100); // 100% by default
        self._initialize_level_requirements();
    }

    #[abi(embed_v0)]
    pub impl UserManagementImpl of super::super::interfaces::user_interface::IUserManagement<ContractState> {
        fn register_user(ref self: ContractState) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check if user is already registered
            let existing_user = self.users.entry(caller).read();
            assert(existing_user.address.is_zero(), 'User already registered');

            // Create new user
            let new_user = User {
                address: caller,
                xp: 0,
                level: 1,
                current_streak: 0,
                max_streak: 0,
                join_timestamp: current_time,
                total_trades: 0,
                total_volume: 0,
                is_active: true,
            };

            // Initialize streak info
            let initial_streak = StreakInfo {
                current_streak: 0,
                last_trade_day: 0,
                streak_multiplier: 100,
            };

            self.users.entry(caller).write(new_user);
            self.streak_info.entry(caller).write(initial_streak);
            self.user_count.write(self.user_count.read() + 1);

            self.emit(Event::UserRegistered(UserRegistered { 
                user: caller, 
                timestamp: current_time 
            }));
        }

        fn get_user_profile(self: @ContractState, user: ContractAddress) -> User {
            self.users.entry(user).read()
        }

        fn is_user_registered(self: @ContractState, user: ContractAddress) -> bool {
            !self.users.entry(user).read().address.is_zero()
        }

        fn add_xp(ref self: ContractState, user: ContractAddress, xp_amount: u256) {
            let mut user_data = self.users.entry(user).read();
            assert(!user_data.address.is_zero(), 'User not registered');

            let multiplier = self.xp_multiplier.read();
            let final_xp = (xp_amount * multiplier.into()) / 100;
            
            let old_level = user_data.level;
            user_data.xp += final_xp;
            user_data.level = self.calculate_level_from_xp(user_data.xp);

            self.users.entry(user).write(user_data);

            self.emit(Event::XPAdded(XPAdded {
                user,
                amount: final_xp,
                new_total: user_data.xp,
            }));

            if user_data.level > old_level {
                self.emit(Event::LevelUp(LevelUp {
                    user,
                    old_level,
                    new_level: user_data.level,
                }));
            }
        }

        fn get_user_xp(self: @ContractState, user: ContractAddress) -> u256 {
            self.users.entry(user).read().xp
        }

        fn get_user_level(self: @ContractState, user: ContractAddress) -> u32 {
            self.users.entry(user).read().level
        }

        fn calculate_level_from_xp(self: @ContractState, xp: u256) -> u32 {
            // Simple exponential level calculation: level = sqrt(xp / 1000) + 1
            let mut level = 1;
            let mut required_xp = 1000; // Level 2 requires 1000 XP
            
            while xp >= required_xp && level < 100 { // Cap at level 100
                level += 1;
                required_xp = required_xp * 150 / 100; // Each level requires 50% more XP
            }
            
            level
        }

        fn update_streak(ref self: ContractState, user: ContractAddress) {
            let mut user_data = self.users.entry(user).read();
            let mut streak_data = self.streak_info.entry(user).read();
            
            let current_time = get_block_timestamp();
            let current_day = current_time / 86400; // Convert to days
            let last_trade_day = streak_data.last_trade_day;

            if last_trade_day == 0 {
                // First trade
                streak_data.current_streak = 1;
            } else if current_day == last_trade_day {
                // Same day, no streak change
                return;
            } else if current_day == last_trade_day + 1 {
                // Consecutive day
                streak_data.current_streak += 1;
            } else {
                // Streak broken
                streak_data.current_streak = 1;
            }

            // Update max streak
            if streak_data.current_streak > user_data.max_streak {
                user_data.max_streak = streak_data.current_streak;
            }

            user_data.current_streak = streak_data.current_streak;
            streak_data.last_trade_day = current_day;

            // Calculate streak multiplier (up to 200% at 30+ days)
            let bonus = streak_data.current_streak * 3;
            let max_bonus = if bonus > 100 { 100 } else { bonus };
            streak_data.streak_multiplier = 100 + max_bonus;

            self.users.entry(user).write(user_data);
            self.streak_info.entry(user).write(streak_data);

            self.emit(Event::StreakUpdated(StreakUpdated {
                user,
                new_streak: streak_data.current_streak,
            }));
        }

        fn get_streak_info(self: @ContractState, user: ContractAddress) -> StreakInfo {
            self.streak_info.entry(user).read()
        }

        fn reset_streak(ref self: ContractState, user: ContractAddress) {
            let mut user_data = self.users.entry(user).read();
            let mut streak_data = self.streak_info.entry(user).read();
            
            let old_streak = streak_data.current_streak;
            
            streak_data.current_streak = 0;
            streak_data.streak_multiplier = 100;
            user_data.current_streak = 0;

            self.users.entry(user).write(user_data);
            self.streak_info.entry(user).write(streak_data);

            self.emit(Event::StreakReset(StreakReset {
                user,
                previous_streak: old_streak,
            }));
        }

        fn update_trading_stats(ref self: ContractState, user: ContractAddress, volume: u256) {
            let mut user_data = self.users.entry(user).read();
            assert(!user_data.address.is_zero(), 'User not registered');

            user_data.total_trades += 1;
            user_data.total_volume += volume;

            self.users.entry(user).write(user_data);
        }

        fn get_total_trades(self: @ContractState, user: ContractAddress) -> u64 {
            self.users.entry(user).read().total_trades
        }

        fn get_total_volume(self: @ContractState, user: ContractAddress) -> u256 {
            self.users.entry(user).read().total_volume
        }

        fn set_xp_multiplier(ref self: ContractState, multiplier: u32) {
            assert(get_caller_address() == self.owner.read(), 'Only owner');
            assert(multiplier >= 50 && multiplier <= 300, 'Invalid multiplier');
            self.xp_multiplier.write(multiplier);
        }

        fn get_total_users(self: @ContractState) -> u64 {
            self.user_count.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn _initialize_level_requirements(ref self: ContractState) {
            // Initialize XP requirements for levels 1-10
            let mut level = 1;
            let mut xp_required = 0;
            
            while level <= 10 {
                self.level_requirements.entry(level).write(xp_required);
                xp_required = if level == 1 { 1000 } else { xp_required * 150 / 100 };
                level += 1;
            }
        }
    }
} 