# multisig-utils

## contract address
```0x227bef3eb77e5700dccbaa6bc1cdc854433efc9b998be1cd9074befefa97c89c```

## functions

### flush_and_create_transaction (_with_hash)

parameters are same as
* 0x1::multisig_account::create_transaction
* 0x1::multisig_account::create_transaction_with_hash

Create a new multis account transaction. 
If there are existing transactions that have not been executed, reject them all so that only one new transaction remains.

### create_multisig_account

parameters are same as
* 0x1::multisig_account::create

Since Multisig accounts use sequence numbers when creating them, it can be difficult to get a determined address.
In this case, utilize a resource account to ensure that user always get a fixed address.

### get_next_multisig_account_address (view)

parameters are same as
* 0x1::multisig_account::get_next_multisig_account_address

Get what addresses are created by calling create_multisig_account