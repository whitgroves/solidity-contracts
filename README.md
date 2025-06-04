# smart-contracts

A collection of smart contracts meant to be used interoperably to extend ERC20 tokens.

These contracts have been unlicensed and are freely available for any use, but be aware that they import code from contracts with different (but still permissable) licenses.

## Contract Extensions

### Delegated.sol
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

### StakingPool.sol
A revision of [StakingPool](https://github.com/whitgroves/staking-pool) using inherited access and emergency stop controls. Note that in this version, the only way to destake a pool is to retire it.

To use, deploy the contract pointing to the contract address for the ERC20 token you want to setup staking for, then transfer and distribute funds as needed. Secondary contracts can be added as delegates to automate the distribution process entirely on-chain.
