# smart-contracts

A collection of smart contracts meant to provide [access controls](#ownership--access-controls) or extend [ERC20](#erc20-extensions) and [ERC721](#erc721-extensions) tokens through inherited modifiers and/or methods.

These contracts have been unlicensed and are freely available for any use, but be aware that they import code from contracts with different (but still permissable) licenses.

All are abstract, but most include a code snippet showing how to use them in a minimal subclass.

## Ownership & Access Controls

### InputValidated
A simple contract that supplies input validations so they can be inherited instead of rewritten. Makes several errors, modifiers, and internal functions available to its subclasses:
```
import {InputValidated} from "https://github.com/whitgroves/solidity-contracts/blob/main/InputValidated.sol";

contract MyContract is InputValidated {

    function balanceOf(address user) public nonZeroAddress(user) { 
        if (msg.sender != user) revert UnauthorizedAccessRequest(msg.sender);
        ...
    }

    function transferTo(address to) public nonZeroAddress(to) {
        address sender = _requireNonZeroAddress(msg.sender);
        ...
    }
}
```

### Delegated
An extension of OpenZeppelin's [Ownable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol) contract which adds the `onlyDelegate` modifier for privileged calls to certain contract functions, while preserving `onlyOwner` for more restricted access: 
```
import {Delegated} from "https://github.com/whitgroves/solidity-contracts/blob/main/Delegated.sol";

contract MyContract is Delegated {

    constructor() Delegated(msg.sender) {}

    function burn(...) public onlyDelegate { ... }

    function mint(...) public onlyOwner { ... }
}
```
The contract owner is treated as a delegate for all operations, but will not remain delegated unless explicitly added before transferring ownership.

### TimeDelegated
An extension of `Delegated` that enables time-based delegation for a number of days via an overload to `addDelegate()`. Delgates can add other delegates within the `maxExpiryDays()` set by the owner.
```
import {TimeDelegated} from "https://github.com/whitgroves/solidity-contracts/blob/main/TimeDelegated.sol";

contract MyContract is TimeDelegated {

    constructor() TimeDelegated(msg.sender, 365) {} // delegates can sub-delegate for up to a year

    function burn(...) public onlyDelegate { ... }

    function mint(...) public onlyOwner { ... }
}
```
Owner calls to `addDelegate()` without a time limit will set expiry time to `type(uint).max` days, which is basically forever.

### Restricted
Another extension of `Ownable` that manages access by enforcing a banlist via the `onlyAllowed` modifier. In effect, this allows the contract owner to make every address a delegate by default, and then remove access from untrusted accounts selectively:
```
import {Restricted} from "https://github.com/whitgroves/solidity-contracts/blob/main/Restricted.sol";

contract MyContract is Restricted {

    constructor() Restricted(msg.sender) {}

    function getTransactionHistory(...) public { ... }

    function makeTransaction(...) public Restricted { ... }
}
```
The owner may ban or reinstate any account using `banAccount()` or `reinstateAccount()`, and any user can see which addresses are banned via `isBanned()`.

### AccessControlled
An extension of OpenZeppelin;s `Ownable` and `Pausable` that implements both `Delegated` and `Restricted`. All features work as described above, except that banning an account will also remove their delegate status, and banned accounts cannot be delegated.
```
import {AccessControlled} from "https://github.com/whitgroves/solidity-contracts/blob/main/AccessControlled.sol";

contract MyContract is AccessControlled {

    constructor() AccessControlled(msg.sender) {}

    function burn(...) public onlyAllowed { ... }

    function mint(...) public onlyDelegate { ... }

    function transferOwnership(...) public onlyOwner { ... }
}
```

### Leasable
An extension of `AccessControlled` that allows ownership for a smart contract to be leased out on a daily basis in exchange for ERC20 tokens at a price set by the contract owner. Calls to `owner()` will still show the original owner, but `tenant()` is available to confirm the address currently leasing the contract.

Under the hood, internal members of Ownable have been overriden so the existing `onlyOwner` modifier will treat the current tenant as the owner, while making `whileLeased`, `whileNotLeased`, and `onlyOriginalOwner` available for control over which functions should be accessible to borrowers:
```
import {Leasable} from "https://github.com/whitgroves/solidity-contracts/blob/main/Leasable.sol";

contract MyContract is Leasable {

    constructor() Leasable(msg.sender) {}

    function updateConnections(...) public whileLeased onlyOwner { ... }

    function transferOwnership(...) public notWhileLeased onlyOriginalOwner { ... }
}
```
The contract can be leased out directly or by proxy via `startLease()` and `startLeaseFor()`, although both require a spending allowance by the tenant so the Leasable contract can transfer funds.

Similarly, the original owner and the tenant can revoke or terminate the lease early via `revokeLease()` and `terminateLease()`, which requires an allowance by the owner to reverse the transaction. Note that even if the lease is revoked on the same day, the tenant will always be charged for at least 1 day's use.

### DemocraticallyOwned
An extension of `AccessControlled` that changes ownership by vote. Voters are allowed to participate based on ownership of an `ERC20` or `ERC721` token specified by the initial owner at construction:
```
import {DemocraticallyOwned} from "https://github.com/whitgroves/solidity-contracts/blob/main/DemocraticallyOwned.sol";

contract MyContract is DemocraticallyOwned {

    constructor() DemocraticallyOwned(<ERC20/721 token address>, msg.sender) {}

    function manageFunds(...) public notDuringElection onlyOwner { ... }

}
```
Elections are started by a call to `transferOwnership` or `renounceOwnership`, which will kick-off a nomination period followed by an election period, (1 and 3 days by default), after which ownership will be locked until any valid participant calls `tally()` to count the votes and transfer ownership of the contract.

The modifiers `duringNomination`, `notDuringNomination`, `duringElection`, and `notDuringElection` are available as control gates for subclass activities, and the minimal interface `IERC20orERC721` is included for calls to `balanceOf` to ensure voters, candidates, and owners can only participate when holding at least 1 of the underlying token.

### MajorityOwned
An extension of `AccessControlled` where ownership is determined by the balance of an underlying ERC20 or ERC721 token. While the contract is unpaused, any account can call `claimOwnership()` to take ownership if they hold more of the underlying token than the current owner.

Note that this allows contracts with renounced ownership to be reclaimed later, unless the token has implemented their burn function in a non-standard way.

## ERC20 Extensions

### AccessControlledERC20
An `AccessControlled` implementation of ERC20 with [Pausable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol) controls. Internal functions for `_mint()` and `_burn()` are included for extensibility, but optional interface members `name()`, `symbol()`, and `decimals()` must be implemented in the subclass:
```
import {AccessControlledERC20} from "https://github.com/whitgroves/solidity-contracts/blob/main/AccessControlledERC20.sol";

contract MyToken is AccessControlledERC20 {
    
    constructor() AccessControlledERC20(msg.sender) {}

    function name() external pure returns(string memory) { return "Your Own Distributed Ledger"; }

    function symbol() external pure returns(string memory) { return "YODL"; }

    function decimals() external pure returns(uint) { return 18; }

    function mint(address to, uint amount) external onlyDelegate { _mint(to,amount); }

    function burn(uint amount) external { _burn(_msgSender(), amount); }

    function _transfer(address _from, address _to, uint256 _value) internal override onlyAllowed returns (bool success) {
        ... // custom pre-transfer logic
        return super._transfer(_from, _to, _value);
    }

}
```

### TaxableERC20
An extension of `AccessControlledERC20` that implements an adjustable transaction tax of up to 99%:
```
import {TaxableERC20} from "https://github.com/whitgroves/solidity-contracts/blob/main/TaxableERC20.sol";

contract MyToken is TaxableERC20 {
    
    constructor() TaxableERC20(msg.sender) { // default max rate is 99%
        _mint(msg.sender, 1000);
        setTaxAddress(msg.sender);
        setTaxRate(15); // 15%
    }

    function name() external pure returns(string memory) { return "Transfer Tax Token"; }

    function symbol() external pure returns(string memory) { return "T3"; }

    function decimals() external pure returns(uint) { return 18; }

}
```
Both `setTaxRate()` and `setTaxAddress()` will accept 0 or `address(0)` as inputs, which disables tax collection. Otherwise, the contract will collect the tax on each transaction and transfer it to another address (such as a `StakingPool`).

In addition, any address can be designated as tax-exempt via `setTaxExempt()`, which will skip tax collection on transfers to or from it. By default, the zero address and tax address are exempt to make minting, burning, and transfers of collected funds tax-free.

Note that both `transfer()` and `transferFrom()` have been routed to go through a new function, `_processTransfer()`, which wraps internal calls to `_transfer()` via `_collectTax()`. This is to avoid overriding `_transfer()` itself, which causes infinite recursion through calls to `super._transfer()` in derived classes.

Finally, keep in mind that transferring ownership does *not* update the tax address automatically, so if some form of this is desired, you will need to override `Ownable.transferOwnership()` and/or `Ownable.renounceOwnership()` in your subclass.

### ProgressivelyTaxableERC20
An extension of `TaxableERC20` that implements tax brackets instead of a flat rate. `setTaxRate()` has been overriden to apply a clamp on taxes for all brackets at once, and overloaded to allow creation of new brackets or updates to existing ones.

When any of these are changed, they will emit the `TaxBracketChanged` event.

Deployment is similar to `TaxableERC20`:
```
import {ProgressivelyTaxableERC20} from "https://github.com/whitgroves/solidity-contracts/blob/main/ProgressivelyTaxableERC20.sol";

contract MyToken is ProgressivelyTaxableERC20 {
    
    constructor() ProgressivelyTaxableERC20(msg.sender) {
        _mint(msg.sender, 100000);
        setTaxAddress(msg.sender);
        setTaxRate(10, 1); // brackets are ordered here, but will self-sort on addition
        setTaxRate(100, 2);
        setTaxRate(1000, 3);
        setTaxRate(10000, 5);
    }

    function name() external pure returns(string memory) { return "1040 Token"; }

    function symbol() external pure returns(string memory) { return "IRS"; }

    function decimals() external pure returns(uint) { return 18; }

}
```

### ManagedSupplyERC20
An extension `TaxableERC20` contract above which implements an automatic burn rate and delegated minting function based on the token's target supply.

The contract can be deployed similar to the above, except a target supply must be set on construction:
```
import {ManagedSupplyERC20} from "https://github.com/whitgroves/solidity-contracts/blob/main/ManagedSupplyERC20.sol";

contract MyToken is ManagedSupplyERC20 {
    
    constructor() ManagedSupplyERC20(msg.sender, 10000) {} // `mint()` is public so tokens can be minted later

    function name() external pure returns(string memory) { return "Central Reserve Token"; }

    function symbol() external pure returns(string memory) { return "VOLKER"; }

    function decimals() external pure returns(uint) { return 18; }
}
```
Similar to `TaxableERC20`, the contract will collect a % of transactions between non-exempt addresses to be taxed and/or burned to maintain the supply target set by `setTargetSupply()`. This function is treated as owner-only, unless the owner sets an update buffer via `setTargetSupplyUpdateBuffer()`, which will then treat target supply updates as delegated.

Because the tax limit is shared and enforced by `setTaxRate()` and `burnRate()`, high inflation will prevent raises in the tax rate, and a high tax rate will throttle the burn rate until the supply reaches its target.

In addition, a public `mint()` function wraps ERC20's `_mint()` so the contract owner or their delegates can create additional tokens, but does not allow increases above the target supply; if more tokens are needed, the owner will need to increase the supply target, which will emit the `SupplyTargetChanged` event for any off-chain listeners.

Similarly, a public `burn()` function is available so tokens may be burned manually, but only by the account that holds them.

### TradeableERC20
Another extension of `AccessControlledERC20` that allows trades of that token in exchange for any other ERC20 token. Deployment is similar to `ManagedSupplyERC20`:
```
import {TradeableERC20} from "https://github.com/whitgroves/solidity-contracts/blob/main/TradeableERC20.sol";

contract MyToken is TradeableERC20 {
    
    constructor() TradeableERC20(msg.sender) {
        _mint(msg.sender, 10000);
    }

    function name() external pure returns(string memory) { return "Anycoin"; }

    function symbol() external pure returns(string memory) { return "BABEL"; }

    function decimals() external pure returns(uint) { return 18; }
}
```
Each account can then set their own trade rates using `makeBuyOffer()` to buy a specified currency in exhange for this token, `makeSellOffer()` to sell this token in exhange for a specific currency, or `makeTradeOffer()` to set the price for open trades. 

Note that setting the exchange rate to 0 for a token rejects all trades in that currency, and all trade rates are 0 by default.

A trader looking to enter the token can see buy and sell prices via `getSellOffer()` and `getBuyOffer()`, then (assuming the trade offers are above 0) make the appropriate trade via `buy()` or `sell()`. 

Transfers are routed through this contract, which requires an allowance on the token being exchanged, but will bypass that allowance for this contract's own token; as a consequence, all trades will incur 2 transfers of the buyer's token (buyer->contract->seller) so be aware that any transaction fees on those tokens will be doubled.

Once a trade is complete, the contract will emit the `ERC20TokensTraded` event with the currencies and amounts exchanged for any off-chain listeners.

## ERC721 Extensions

### AccessControlledERC721
An `AccessControlled` implementation of `IERC721`, with `mint()` and `burn()` functions added. Functionally a delegated version of OpenZeppelin's [`ERC721`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol) contract, except it doesn't implement `IERC721Metadata`. Created for extensibility of per-item access permissions.

### LeasableERC721
An extension of `AccessControlledERC721` that implements `Leasable`-like permissions on individual tokens. Calls to `ownerOf()` will still show the original owner's address, but `tenantOf()` is made available to confirm rentership in the application layer.

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

### TradeableERC721
An extension of `AccessControlledERC721` that allows NFTs to be priced and sold in any ERC20 currency similar to `TradeableERC20`, or traded for an `ERC721` token from another collection. 

The owner of any NFT in the collection can call `setPrice()` or `setTrade()` to specify which tokens they will accept in exchange for theirs, then interested parties can call `buy()` or `trade()` to make the trade once the owner has enabled it via `setCanTrade()`.

Once exchanged, the token will be automatically taken off of the market to allow the new owner to update any price(s) before making it tradeable again.

## Other

### IERC20orERC721
A minimal interface to make `balanceOf()` available to contracts that want to check the balance of an account's ERC20 or ERC721 tokens.

### StakingPool
An `AccessControlled` revision of [StakingPool](https://github.com/whitgroves/staking-pool) using OpenZeppelin's [Pausable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol) for emergency stop controls. Note that in this version, the only way to destake a pool is to retire it.

To use, deploy the contract as such:
```
import {StakingPool} from "https://github.com/whitgroves/solidity-contracts/blob/main/StakingPool.sol";

contract TestPool is StakingPool {
    constructor(address tokenAddress_) StakingPool(tokenAddress_, _msgSender()) {}
}
```
Then transfer and distribute funds and call `distribute()` as needed. Secondary users or smart contracts can be added as delegates to offload the distribution process as well.

Note that by default, distributions are allocated to users but not added to their stake; users can set this behavior via `setAutoStake()`, which can also be called by the sublcass if it should be enabled/disabled permanently or by default.

### TreasuryPool
A smart contract that pools ERC20 and ERC721 tokens and authorizes them to be managed or spent by proxy. The owner assigns delegates, then calls `authorize()` to approve spending of a specific currency in the pool, or management of NFTs held at the pool's address.

The contract itself inherits from `DemocraticallyOwned`, so the pool itself is goverened by an ERC20 or ERC721 token specified at construction:

```
import {TreasuryPool} from "https://github.com/whitgroves/solidity-contracts/blob/main/TreasuryPool.sol";
import {IERC20orERC721} from "https://github.com/whitgroves/solidity-contracts/blob/main/IERC20orERC721.sol";

contract TestPool is TreasuryPool {
    constructor(address <your token>) TreasuryPool(<your token>, _msgSender()) {}

    // Override to scale voting power with underlying token ownership.
    function votingPower(address voter) public override view returns (uint) {
        return IERC20orERC721(tokenAddress()).balanceOf(voter);
    }
}
```

Elections will *not* remove prior authorizations, but new authorizations are locked until the election cycle is complete. If ownership changes after the vote, all delegates will be removed and have their authorizations revoked, including the previous owner.

### PaymentSplitter
An `AccessControlled` contract that can hold and redistribute ERC20 tokens to enrolled addresses according to a relative payscale set by the owner or their delegates. Once distributed, these funds can only be withdrawn by the enrolled parties, but the owner can transfer any unallocated funds in a specified currency to another address at any time.

The contract is ready-to-use without any modifications:
```
import {PaymentSplitter} from "https://github.com/whitgroves/solidity-contracts/blob/main/PaymentSplitter.sol";

contract MyPayroll is PaymentSplitter {
    constructor() PaymentSplitter(_msgSender()) {}
}
```