#[test_only]
module defiralia_staking::scripts_tests {
    use std::string;

    use aptos_framework::coin;
    use aptos_framework::timestamp;

    use aptos_token::token::{Self, get_token_id};

    use defiralia_staking::scripts;
    use defiralia_staking::stake;
    use defiralia_staking::stake_nft_tests::{create_collecton, create_token};
    use defiralia_staking::stake_test_helpers::{StakeCoin, RewardCoin, new_account_with_stake_coins, mint_default_coin, new_account};
    use defiralia_staking::stake_tests::initialize_test;

    const ONE_COIN: u64 = 1000000;

    const WEEK_IN_SECONDS: u64 = 604800;

    const START_TIME: u64 = 682981200;

    #[test]
    fun test_script_register_pool() {
        let (defiralia_staking, _) = initialize_test();

        coin::register<RewardCoin>(&defiralia_staking);

        let reward_coins = mint_default_coin<RewardCoin>(1000 * ONE_COIN);
        let duration = 100000000;
        coin::deposit(@defiralia_staking, reward_coins);
        assert!(coin::balance<RewardCoin>(@defiralia_staking) == 1000000000, 1);
        scripts::register_pool<StakeCoin, RewardCoin>(&defiralia_staking, 1000 * ONE_COIN, duration);

        assert!(coin::balance<RewardCoin>(@defiralia_staking) == 0, 1);

        let (reward_per_sec, accum_reward, last_updated, reward_coin_amount, scale) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@defiralia_staking);
        let end_ts = stake::get_end_timestamp<StakeCoin, RewardCoin>(@defiralia_staking);
        assert!(end_ts == START_TIME + duration, 1);
        assert!(reward_per_sec == 10, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == 682981200, 1);
        assert!(reward_coin_amount == 1000 * ONE_COIN, 1);
        assert!(scale == 1000000000000, 1);
        assert!(stake::pool_exists<StakeCoin, RewardCoin>(@defiralia_staking), 1);
    }

    #[test]
    fun test_script_register_pool_with_nft_collection() {
        let (defiralia_staking, _) = initialize_test();

        coin::register<RewardCoin>(&defiralia_staking);

        let collection_name = string::utf8(b"Test Collection");
        create_collecton(@collection_owner, collection_name);

        let reward_coins = mint_default_coin<RewardCoin>(1000 * ONE_COIN);
        let duration = 100000000;
        coin::deposit(@defiralia_staking, reward_coins);
        assert!(coin::balance<RewardCoin>(@defiralia_staking) == 1000000000, 1);
        scripts::register_pool_with_collection<StakeCoin, RewardCoin>(
            &defiralia_staking,
            1000 * ONE_COIN,
            duration,
            @collection_owner,
            collection_name,
            10,
        );

        assert!(coin::balance<RewardCoin>(@defiralia_staking) == 0, 1);

        let (reward_per_sec, accum_reward, last_updated, reward_coin_amount, scale) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@defiralia_staking);
        let end_ts = stake::get_end_timestamp<StakeCoin, RewardCoin>(@defiralia_staking);
        assert!(end_ts == START_TIME + duration, 1);
        assert!(reward_per_sec == 10, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == 682981200, 1);
        assert!(reward_coin_amount == 1000 * ONE_COIN, 1);
        assert!(scale == 1000000000000, 1);
        assert!(stake::pool_exists<StakeCoin, RewardCoin>(@defiralia_staking), 1);

        let (collection_owner_addr, coll_name, boost_percent) =
                stake::get_boost_config<StakeCoin, RewardCoin>(@defiralia_staking);
        assert!(collection_owner_addr == @collection_owner, 1);
        assert!(coll_name == collection_name, 1);
        assert!(boost_percent == 10, 1);
    }

    #[test]
    fun test_scripts_end_to_end() {
        let (defiralia_staking, emergency_admin) = initialize_test();

        coin::register<RewardCoin>(&defiralia_staking);

        let pool_address = @defiralia_staking;

        let reward_coins = mint_default_coin<RewardCoin>(1000 * ONE_COIN);
        let duration = 100000000;
        coin::deposit(@defiralia_staking, reward_coins);
        assert!(coin::balance<RewardCoin>(@defiralia_staking) == 1000000000, 1);

        scripts::register_pool<StakeCoin, RewardCoin>(&defiralia_staking, 1000 * ONE_COIN, duration);

        assert!(coin::balance<RewardCoin>(@defiralia_staking) == 0, 1);

        let (reward_per_sec, accum_reward, last_updated, reward_coin_amount, scale) =
            stake::get_pool_info<StakeCoin, RewardCoin>(pool_address);
        let end_ts = stake::get_end_timestamp<StakeCoin, RewardCoin>(@defiralia_staking);
        assert!(end_ts == START_TIME + duration, 1);
        assert!(reward_per_sec == 10, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == 682981200, 1);
        assert!(reward_coin_amount == 1000 * ONE_COIN, 1);
        assert!(scale == 1000000000000, 1);

        let alice_acc = new_account_with_stake_coins(@alice, 100 * ONE_COIN);

        // check no stakes
        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(pool_address, @alice), 1);
        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(pool_address, @bob), 1);

        scripts::stake<StakeCoin, RewardCoin>(&alice_acc, pool_address, 10 * ONE_COIN);

        assert!(coin::balance<StakeCoin>(@alice) == 90 * ONE_COIN, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(pool_address, @alice) == 10 * ONE_COIN, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(pool_address) == 10 * ONE_COIN, 1);

        // wait one week to unstake
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS);

        scripts::unstake<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking, 5 * ONE_COIN);

        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@defiralia_staking, @alice) == 5 * ONE_COIN, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@defiralia_staking) == 5 * ONE_COIN, 1);

        coin::register<RewardCoin>(&alice_acc);

        scripts::harvest<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking);

        assert!(coin::balance<RewardCoin>(@alice) == 6048000, 1);

        scripts::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @defiralia_staking);
        scripts::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking);

        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@defiralia_staking, @alice), 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@defiralia_staking) == 0, 1);
        assert!(coin::balance<StakeCoin>(@alice) == 100 * ONE_COIN, 1);
    }

    #[test]
    fun test_script_stake() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 10 * ONE_COIN);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        scripts::register_pool<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
        );

        scripts::stake<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            10 * ONE_COIN,
        );

        let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_staked = stake::get_user_stake<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        assert!(total_staked == 10 * ONE_COIN, 1);
        assert!(user_staked == 10 * ONE_COIN, 1);
        assert!(total_boosted == 0, 1);
        assert!(user_boosted == 0, 1);
        assert!(coin::balance<StakeCoin>(@alice) == 0, 1);
    }

    #[test]
    fun test_script_unstake() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 10 * ONE_COIN);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        scripts::register_pool<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
        );

        scripts::stake<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            10 * ONE_COIN,
        );

        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS);

        scripts::unstake<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            10 * ONE_COIN,
        );

        let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_staked = stake::get_user_stake<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        assert!(total_staked == 0, 1);
        assert!(user_staked == 0, 1);
        assert!(total_boosted == 0, 1);
        assert!(user_boosted == 0, 1);
        assert!(coin::balance<StakeCoin>(@alice) == 10 * ONE_COIN, 1);
    }

    #[test]
    fun test_script_harvest() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 10 * ONE_COIN);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        let duration = 15768000;
        scripts::register_pool<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
        );

        scripts::stake<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            10 * ONE_COIN,
        );

        timestamp::update_global_time_for_test_secs(START_TIME + duration);

        scripts::harvest<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking
        );

        assert!(coin::balance<RewardCoin>(@alice) == 15768000000000, 1);
    }

    #[test]
    fun test_script_harvest_reward_coin_registered() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 10 * ONE_COIN);

        coin::register<RewardCoin>(&alice_acc);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        let duration = 15768000;
        scripts::register_pool<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
        );

        scripts::stake<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            10 * ONE_COIN,
        );

        timestamp::update_global_time_for_test_secs(START_TIME + duration);

        scripts::harvest<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking
        );

        assert!(coin::balance<RewardCoin>(@alice) == 15768000000000, 1);
    }

    #[test]
    fun test_script_stake_and_boost() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 10 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);

        let token_name = string::utf8(b"Token");
        let nft = create_token(&collection_owner, collection_name, token_name);
        let token_id = get_token_id(&nft);
        token::deposit_token(&alice_acc, nft);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        scripts::register_pool_with_collection<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
            @collection_owner,
            collection_name,
            5,
        );

        scripts::stake_and_boost<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            10 * ONE_COIN,
            @collection_owner,
            collection_name,
            token_name,
            0
        );

        let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_staked = stake::get_user_stake<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        assert!(total_staked == 10 * ONE_COIN, 1);
        assert!(user_staked == 10 * ONE_COIN, 1);
        assert!(total_boosted == 500000, 1);
        assert!(user_boosted == 500000, 1);
        assert!(coin::balance<StakeCoin>(@alice) == 0, 1);
        assert!(token::balance_of(@alice, token_id) == 0, 1);
    }

    #[test]
    fun test_script_unstake_and_remove_boost() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 10 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let token_name = string::utf8(b"Token");
        let nft = create_token(&collection_owner, collection_name, token_name);
        let token_id = token::get_token_id(&nft);
        token::deposit_token(&alice_acc, nft);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        scripts::register_pool_with_collection<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
            @collection_owner,
            collection_name,
            5,
        );

        scripts::stake_and_boost<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            10 * ONE_COIN,
            @collection_owner,
            collection_name,
            token_name,
            0
        );

        // wait one week to unstake
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS);

        scripts::unstake_and_remove_boost<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            5 * ONE_COIN,
        );

        let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_staked = stake::get_user_stake<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        assert!(total_staked == 5 * ONE_COIN, 1);
        assert!(user_staked == 5 * ONE_COIN, 1);
        assert!(total_boosted == 0, 1);
        assert!(user_boosted == 0, 1);
        assert!(coin::balance<StakeCoin>(@alice) == 5 * ONE_COIN, 1);
        assert!(token::balance_of(@alice, token_id) == 1, 1);
    }

    #[test]
    fun test_script_boost() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 100 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let token_name = string::utf8(b"Token");
        let nft = create_token(&collection_owner, collection_name, token_name);
        let token_id = token::get_token_id(&nft);
        token::deposit_token(&alice_acc, nft);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        scripts::register_pool_with_collection<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
            @collection_owner,
            collection_name,
            5,
        );

        scripts::stake<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking, 10 * ONE_COIN);
        scripts::boost<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            @collection_owner,
            collection_name,
            token_name,
            0
        );

        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        assert!(total_boosted == 500000, 1);
        assert!(user_boosted == 500000, 1);
        assert!(token::balance_of(@alice, token_id) == 0, 1);
    }

    #[test]
    fun test_script_remove_boost() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 100 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let token_name = string::utf8(b"Token");
        let nft = create_token(&collection_owner, collection_name, token_name);
        let token_id = token::get_token_id(&nft);
        token::deposit_token(&alice_acc, nft);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        scripts::register_pool_with_collection<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
            @collection_owner,
            collection_name,
            5,
        );

        scripts::stake<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking, 10 * ONE_COIN);
        scripts::boost<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            @collection_owner,
            collection_name,
            token_name,
            0,
        );
        scripts::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking);

        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@defiralia_staking);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@defiralia_staking, @alice);
        assert!(total_boosted == 0, 1);
        assert!(user_boosted == 0, 1);
        assert!(token::balance_of(@alice, token_id) == 1, 1);
    }

    #[test]
    fun test_script_deposit_reward_coins() {
        let (defiralia_staking, _) = initialize_test();
        let alice_acc = new_account(@alice);

        coin::register<RewardCoin>(&defiralia_staking);
        coin::register<RewardCoin>(&alice_acc);

        let reward_coins = mint_default_coin<RewardCoin>(1000 * ONE_COIN);
        let duration = 100000000;
        coin::deposit(@defiralia_staking, reward_coins);
        scripts::register_pool<StakeCoin, RewardCoin>(&defiralia_staking, 1000 * ONE_COIN, duration);

        let reward_coins = mint_default_coin<RewardCoin>(1 * ONE_COIN);
        coin::deposit(@alice, reward_coins);
        assert!(coin::balance<RewardCoin>(@alice) == 1000000, 1);
        scripts::deposit_reward_coins<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking, 1 * ONE_COIN);

        let (_, _, _, reward_coin_amount, _) = stake::get_pool_info<StakeCoin, RewardCoin>(@defiralia_staking);
        assert!(reward_coin_amount == 1001000000, 1);
        assert!(coin::balance<RewardCoin>(@alice) == 0, 1);
    }

    #[test]
    fun test_script_enable_emergency() {
        let (defiralia_staking, emergency_admin) = initialize_test();

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards
        scripts::register_pool<StakeCoin, RewardCoin>(&defiralia_staking, 15768000000000, 15768000);

        scripts::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @defiralia_staking);

        assert!(stake::is_emergency<StakeCoin, RewardCoin>(@defiralia_staking), 1);
    }

    #[test]
    fun test_script_emergency_unstake() {
        let (defiralia_staking, emergency_admin) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 10 * ONE_COIN);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards
        scripts::register_pool<StakeCoin, RewardCoin>(&defiralia_staking, 15768000000000, 15768000);

        scripts::stake<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking, 10 * ONE_COIN);
        scripts::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @defiralia_staking);
        scripts::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking);

        assert!(coin::balance<StakeCoin>(@alice) == 10 * ONE_COIN, 1);
    }

    #[test]
    fun test_script_emergency_unstake_with_boost() {
        let (defiralia_staking, emergency_admin) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 10 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let token_name = string::utf8(b"Token");
        let nft = create_token(&collection_owner, collection_name, token_name);
        let token_id = token::get_token_id(&nft);
        token::deposit_token(&alice_acc, nft);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        coin::register<RewardCoin>(&defiralia_staking);
        coin::deposit(@defiralia_staking, reward_coins);

        // register staking pool with rewards and boost config
        scripts::register_pool_with_collection<StakeCoin, RewardCoin>(
            &defiralia_staking,
            15768000000000,
            15768000,
            @collection_owner,
            collection_name,
            5,
        );

        scripts::stake<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking, 10 * ONE_COIN);
        scripts::boost<StakeCoin, RewardCoin>(
            &alice_acc,
            @defiralia_staking,
            @collection_owner,
            collection_name,
            token_name,
            0
        );
        scripts::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @defiralia_staking);
        scripts::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @defiralia_staking);

        assert!(coin::balance<StakeCoin>(@alice) == 10 * ONE_COIN, 1);
        assert!(token::balance_of(@alice, token_id) == 1, 1);
    }

    #[test]
    fun test_script_withdraw_reward_to_treasury() {
        let (defiralia_staking, _) = initialize_test();
        let treasury = new_account(@treasury);

        coin::register<RewardCoin>(&defiralia_staking);
        coin::register<RewardCoin>(&treasury);

        let reward_coins = mint_default_coin<RewardCoin>(1000 * ONE_COIN);
        let duration = 100000000;
        coin::deposit(@defiralia_staking, reward_coins);
        scripts::register_pool<StakeCoin, RewardCoin>(&defiralia_staking, 1000 * ONE_COIN, duration);

        timestamp::update_global_time_for_test_secs(START_TIME + duration + 7257600);

        scripts::withdraw_reward_to_treasury<StakeCoin, RewardCoin>(&treasury, @defiralia_staking, 1000000000);
        assert!(coin::balance<RewardCoin>(@treasury) == 1000000000, 1);
    }

    #[test]
    fun test_script_withdraw_reward_to_treasury_no_reward_coin_registered() {
        let (defiralia_staking, _) = initialize_test();
        let treasury = new_account(@treasury);

        coin::register<RewardCoin>(&defiralia_staking);

        let reward_coins = mint_default_coin<RewardCoin>(1000 * ONE_COIN);
        let duration = 100000000;
        coin::deposit(@defiralia_staking, reward_coins);
        scripts::register_pool<StakeCoin, RewardCoin>(&defiralia_staking, 1000 * ONE_COIN, duration);

        timestamp::update_global_time_for_test_secs(START_TIME + duration + 7257600);

        scripts::withdraw_reward_to_treasury<StakeCoin, RewardCoin>(&treasury, @defiralia_staking, 1000000000);
        assert!(coin::balance<RewardCoin>(@treasury) == 1000000000, 1);
    }
}
