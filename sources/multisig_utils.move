module multisig_utils::multisig_utils {
    use std::bcs;
    use std::signer::address_of;
    use std::string::String;
    use aptos_framework::account;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::aptos_account;
    use aptos_framework::multisig_account;

    struct MasterSignerCap has key {
        signer_cap: SignerCapability
    }
    const MasterSeed: vector<u8> = b"master_resource_account";

    /// When signer is not owner of module
    const E_NOT_AUTHORIZED: u64 = 0;

    public entry fun initialize_master_object(_admin: &signer) {
        assert!(@multisig_utils == address_of(_admin), E_NOT_AUTHORIZED);
        let (_, master_signer_cap) = account::create_resource_account(_admin, MasterSeed);
        move_to(_admin, MasterSignerCap { signer_cap: master_signer_cap });
    }

    public entry fun flush_and_create_transaction_with_hash(
        _owner: &signer,
        _multisig_account: address,
        _payload_hash: vector<u8>,
    ) {
        flush_pending_transactions(_owner, _multisig_account);
        multisig_account::create_transaction_with_hash(_owner, _multisig_account, _payload_hash);
    }

    public entry fun flush_and_create_transaction(
        _owner: &signer,
        _multisig_account: address,
        _payload: vector<u8>,
    ) {
        flush_pending_transactions(_owner, _multisig_account);
        multisig_account::create_transaction(_owner, _multisig_account, _payload);
    }

    inline fun flush_pending_transactions(
        _owner: &signer,
        _multisig_account: address
    ) {
        let from_seq = multisig_account::last_resolved_sequence_number(_multisig_account) + 1;
        let to_seq = multisig_account::next_sequence_number(_multisig_account) - 1;
        if (from_seq < to_seq) {
            multisig_account::vote_transactions(_owner, _multisig_account, from_seq, to_seq, false); // reject all
            multisig_account::execute_rejected_transactions(_owner, _multisig_account, to_seq);
        };
    }

    public entry fun create_multisig_account(
        owner: &signer,
        num_signatures_required: u64,
        metadata_keys: vector<String>,
        metadata_values: vector<vector<u8>>,
    ) acquires MasterSignerCap {
        let owner_address = address_of(owner);
        let master_signer_cap = borrow_global<MasterSignerCap>(@multisig_utils);
        let master_signer = account::create_signer_with_capability(&master_signer_cap.signer_cap);
        let (child_signer, _) = account::create_resource_account(&master_signer, bcs::to_bytes(&owner_address));

        let child_address = address_of(&child_signer);
        if (!account::exists_at(child_address)) {
            aptos_account::create_account(child_address);
        };
        multisig_account::create_with_owners_then_remove_bootstrapper(
            &child_signer,
            vector[owner_address],
            num_signatures_required,
            metadata_keys,
            metadata_values,
        );
    }

    #[view]
    public fun get_next_multisig_account_address(_owner_address: address): address acquires MasterSignerCap {
        let master_signer_cap = borrow_global<MasterSignerCap>(@multisig_utils);
        let master_signer = account::create_signer_with_capability(&master_signer_cap.signer_cap);
        let child_address = account::create_resource_address(&address_of(&master_signer), bcs::to_bytes(&_owner_address));
        if (!account::exists_at(child_address)) {
            aptos_account::create_account(child_address);
        };
        return multisig_account::get_next_multisig_account_address(child_address)
    }

    #[test_only]
    use std::features;
    #[test_only]
    use std::vector;
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

    #[test(admin = @multisig_utils, aptos_framework = @aptos_framework, coffee = @0xC0FFEE)]
    fun T_create_multisig(admin: &signer, aptos_framework: &signer, coffee: &signer) acquires MasterSignerCap {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        aptos_coin::ensure_initialized_with_apt_fa_metadata_for_test();
        aptos_account::create_account(address_of(admin));
        aptos_account::create_account(address_of(coffee));
        features::change_feature_flags_for_testing(aptos_framework, vector[features::get_auids()], vector[]);

        initialize_master_object(admin);

        let multisig_addr = get_next_multisig_account_address(address_of(coffee));
        create_multisig_account(coffee, 1, vector[], vector[]);

        let payload: vector<u8> = vector[1, 2, 3];
        multisig_account::create_transaction(coffee, multisig_addr, payload);

        let pending_txs = multisig_account::get_pending_transactions(multisig_addr);
        assert!(vector::length(&pending_txs) == 1, 0);
    }
}