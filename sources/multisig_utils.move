module multisig_utils::multisig_utils {
    use aptos_framework::multisig_account;

    public entry fun flush_and_create_transaction(
        _owner: &signer,
        _multisig_account: address,
        _payload: vector<u8>,
    ) {
        flush_pending_transactions(_owner, _multisig_account);
        multisig_account::create_transaction(_owner, _multisig_account, _payload);
    }

    fun flush_pending_transactions(
        _owner: &signer,
        _multisig_account: address
    ) {
        let from_seq = multisig_account::last_resolved_sequence_number(_multisig_account) + 1;
        let to_seq = multisig_account::next_sequence_number(_multisig_account) - 1;
        multisig_account::vote_transactions(_owner, _multisig_account, from_seq, to_seq, false); // reject all
        multisig_account::execute_rejected_transactions(_owner, _multisig_account, to_seq);
    }

    #[test_only]
    use std::features;
    #[test_only]
    use std::signer::address_of;
    #[test_only]
    use std::vector;
    #[test_only]
    use aptos_framework::aptos_account;
    #[test_only]
    use aptos_framework::aptos_coin;
    #[test_only]
    use aptos_framework::timestamp;

    #[test(aptos_framework = @aptos_framework, coffee = @0xC0FFEE)]
    fun T_flush_and_create_transaction(aptos_framework: &signer, coffee: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        aptos_coin::ensure_initialized_with_apt_fa_metadata_for_test();
        aptos_account::create_account(address_of(coffee));
        features::change_feature_flags_for_testing(aptos_framework, vector[features::get_auids()], vector[]);

        let multisig_addr = multisig_account::get_next_multisig_account_address(address_of(coffee));

        multisig_account::create(
            coffee,
            1,
            vector[],
            vector[],
        );

        let payload: vector<u8> = vector[1, 2, 3];
        multisig_account::create_transaction(coffee, multisig_addr, payload);
        multisig_account::create_transaction(coffee, multisig_addr, payload);
        multisig_account::create_transaction(coffee, multisig_addr, payload);
        let pending_txs = multisig_account::get_pending_transactions(multisig_addr);
        assert!(vector::length(&pending_txs) == 3, 0);

        flush_and_create_transaction(coffee, multisig_addr, payload);
        pending_txs = multisig_account::get_pending_transactions(multisig_addr);
        assert!(vector::length(&pending_txs) == 1, 0);
        assert!(multisig_account::next_sequence_number(multisig_addr) == 5, 0);
    }
}