# smart-contracts

A collection of smart contracts meant to extend ERC20 and ERC721 tokens.

These contracts have been unlicensed and are freely available for any use, but be aware that they import code from contracts with different (but still permissable) licenses.

## Contract Extensions

### Delegated
An extension of OpenZeppelin's [Ownable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol) contract which adds the `onlyDelegate` modifier for privileged calls to certain contract functions, while preserving `onlyOwner` for more restricted access: 

```
import {Delegated} from "https://github.com/whitgroves/solidity-contracts/blob/main/Delegated.sol";

contract MyContract is Delegated {

    constructor(address initialOwner) Delegated(initialOwner) {}

    function burn(...) public onlyDelegate { ... }

    function mint(...) public onlyOwner { ... }
}
```

### Leasable
An extension of the `Delegated` contract that allows ownership access for a smart contract to be leased out on a daily basis in exchange for ERC20 tokens at a price set by the contract owner.

Under the hood, internal members of Ownable have been overriden so the existing `onlyOwner` modifier will treat the current tenant as the owner, while making `whileLeased`, `whileNotLeased`, and `onlyOriginalOwner` available for control over which functions should be accessible to borrowers:
```
import {Leasable} from "https://github.com/whitgroves/solidity-contracts/blob/main/Leasable.sol";

contract MyContract is Leasable {

    constructor(address initialOwner) Leasable(initialOwner) {}

    function updateConnections(...) public whileLeased onlyOwner { ... }

    function transferOwnership(...) public notWhileLeased onlyOriginalOwner { ... }
}
```
The contract can be leased out directly or by proxy via `startLease()` and `startLeaseFor()`, although both require a spending allowance by the tenant so the Leasable contract can transfer funds.

Similarly, the original owner and the tenant can revoke or terminate the lease early via `revokeLease()` and `terminateLease()`, which requires an allowance by the owner to reverse the transaction. Note that even if the lease is revoked on the same day, the tenant will always be charged for at least 1 day's use.

## Standalone Contracts

### StakingPool
A revision of [StakingPool](https://github.com/whitgroves/staking-pool) using inherited access and emergency stop controls. Note that in this version, the only way to destake a pool is to retire it.

To use, deploy the contract pointing to the contract address for the ERC20 token you want to setup staking for, then transfer and distribute funds as needed. Secondary contracts can be added as delegates to automate the distribution process entirely on-chain.

### ManagedSupplyERC20
An extension of OpenZeppelin's [ERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol) contract which implements a manually adjustable tax, automatic burn rate, and delegated minting function restricted by the token's target supply. The contract is abstract, but can be subclassed and deployed rather easily:
```
import {ManagedSupplyERC20} from "https://github.com/whitgroves/solidity-contracts/blob/main/ManagedSupplyERC20.sol";

contract TestToken is ManagedSupplyERC20 {
    constructor() ManagedSupplyERC20("Your Own Distributed Ledger", "YODL", <initial owner>, <target supply>) {
        _mint(<initial holder>, <initial supply>);
    }
}
```

After that, the contract will behave as a standard ERC20 token, except that up to 20% of each transaction may be diverted to an address set by `setTaxAddress()` or burned to maintain the supply target set by `setTargetSupply()`.

Because the 20% limit is shared and enforced by `setTaxRate()` and `burnRate()`, high inflation will prevent raises in the tax rate, and a high tax rate will throttle the burn rate until the supply reaches its target.

In addition, the public `mint()` function wraps ERC20's `_mint()` so the contract owner or their delegates can create additional tokens, but does not allow increases above the target supply; if more tokens are needed, the owner will need to increase the supply target, which will emit the `SupplyTargetChanged` event for any off-chain listeners.

### ERC721
My implementation of `IERC721`, with `mint()` and `burn()` functions added. Functionally a delegated version of OpenZeppelin's [`ERC721`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol) contract, except it doesn't implement `IERC721Metadata`. Created for extensibility of per-item access permissions.

### LeasableERC721
An extension of `ERC721` that implements `Leasable`-like permissions on individual tokens.

Note that in contract to `Leasable`, approved operators will still have authority to act on each token, except to initiate transfers.