# smart-contracts

A collection of smart contracts meant to extend ERC20 and ERC721 tokens.

These contracts have been unlicensed and are freely available for any use, but be aware that they import code from contracts with different (but still permissable) licenses.

## Contract Extensions
These are meant to extend existing contracts by adding modifiers and/or access controls.

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
An extension of the `Delegated` contract that allows ownership access for a smart contract to be leased out on a daily basis in exchange for ERC20 tokens at a price set by the contract owner. Calls to `owner()` will still show the original owner, but `tenant()` is available to confirm the address is currently leasing the contract.

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

### Restricted
Another extension of `Ownable` that manages access by enforcing a banlist via the `onlyAllowed` modifier. In effect, this allows the contract owner to make every address a delegate by default, and then remove access from untrusted accounts selectively:
```
import {Restricted} from "https://github.com/whitgroves/solidity-contracts/blob/main/Restricted.sol";

contract MyContract is Restricted {

    constructor(address initialOwner) Restricted(initialOwner) {}

    function getTransactionHistory(...) public { ... }

    function makeTransaction(...) public Restricted { ... }
}
```
The owner may ban or reinstate any account using `banAccount()` or `reinstateAccount()`, and any user can see which addresses are banned via `isBanned()`.

### InputValidated
A simple contract that supplies input validation for `address` so it can be subclassed instead of rewritten. Makes the `nonZeroAddress` modifier and `_requireNonZeroAddress()` function available to all inherited classes:
```
import {InputValidated} from "https://github.com/whitgroves/solidity-contracts/blob/main/InputValidated.sol";

contract MyContract is InputValidated {

    function balanceOf(address user) public nonZeroAddress(user) { ... }

    function transferTo(address to) public nonZeroAddress(to) {
        address sender = _requireNonZeroAddress(msg.sender);
        ...
    }
}
```

## Standalone Contracts
These contracts are abstract and must be subclassed, but other than that can be deployed as-is.

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

In addition, a public `mint()` function wraps ERC20's `_mint()` so the contract owner or their delegates can create additional tokens, but does not allow increases above the target supply; if more tokens are needed, the owner will need to increase the supply target, which will emit the `SupplyTargetChanged` event for any off-chain listeners.

Similarly, a public `burn()` function is available so tokens may be burned manually, but only by the account that holds them.

### ERC721
My implementation of `IERC721`, with `mint()` and `burn()` functions added. Functionally a delegated version of OpenZeppelin's [`ERC721`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol) contract, except it doesn't implement `IERC721Metadata`. Created for extensibility of per-item access permissions.

### LeasableERC721
An extension of `ERC721` that implements `Leasable`-like permissions on individual tokens. Calls to `ownerOf()` will still show the original owner's address, but `tenantOf()` is made available to confirm rentership in the application layer.

To make use of this extension, include a call to `_requireOwnership()` or `_requireApproved()` at the start of your subclass methods, which will restrict specific actions to owners and approved operators, while transferring that authority to the tenant while leased:

```
import {LeasableERC721} from "https://github.com/whitgroves/solidity-contracts/blob/main/LeasableERC721.sol";

contract MyNFT is LeasableERC721 {

    constructor(address initialOwner) LeasableERC721(initialOwner) {}

    function updateStatus(..., uint tokenId) public {
        _requireOwnership(tokenId);
        ...
    }

    function updateMetadata(..., uint tokenId) public {
        _requireOriginalOwnership(tokenId);
        ...
    }
}
```
As shown above, `_requireOriginalOwnership()` is also available for actions which should be more restricted, including revocation of a token's lease.

Also note that in constrast to `Leasable`, approved operators will still have authority to act on each token, except to initiate transfers.