# smart-contracts

A collection of smart contracts meant to be used interoperably to extend ERC20 tokens.

These contracts have been unlicensed and are freely available for any use, but be aware that they import code from contracts with different (but still permissable) licenses.

## Contract Extensions

### Delegated
An extension of OpenZeppelin's Ownable contract to allow for delegated calls to contract functions. 
Makes the `onlyDelegate` modifier available for use, similar to `onlyOwner`:

```
import "https://github.com/whitgroves/solidity-contracts/blob/main/Delegated.sol";

contract MyContract is Delegated {

    constructor(address initialOwner) Delegated(initialOwner) {}

    function restrictedFunction() public onlyOwner { ... }

    function delegatedFunction() public onlyDelegate { ... }
}
```

## Standalone Contracts

### StakingPool
A revision of [StakingPool](https://github.com/whitgroves/staking-pool) using inherited access and emergency stop controls. Note that in this version, the only way to destake a pool is to retire it.

To use, deploy the contract pointing to the contract address for the ERC20 token you want to setup staking for, then transfer and distribute funds as needed. Secondary contracts can be added as delegates to automate the distribution process entirely on-chain.

### ManagedSupplyERC20
An extension of OpenZeppelin's ERC20 which implements a manually adjustable tax, automatic burn rate, and a delegated minting function, which is restricted by the token's target supply. The contract is abstract, but can be subclassed and deployed rather easily:
```
import "https://github.com/whitgroves/solidity-contracts/blob/main/ManagedSupplyERC20.sol";

contract TestToken is ManagedSupplyERC20 {
    constructor() ManagedSupplyERC20("Your Own Distributed Ledger", "YODL", <initial owner>, <target supply>) {
        _mint(<initial holder>, <initial supply>);
    }
}
```

Note that while the tax rate is adjustable, the contract will soft-enforce a 20% tax + burn rate on transactions; if this is not desired, you will need to override `setTaxRate()` and `burnRate()` in your implementation, or raise the target supply cap until the burn rate drops. 