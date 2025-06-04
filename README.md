# smart-contracts

A collection of smart contracts meant to be used interoperably to extend ERC20 tokens.

All contracts have been unlicensed and are freely available for public or private use.


## Contracts

### Delegated.sol
An extension of OpenZeppelin's Ownable contract to allow for delegated calls to contract functions. 
Makes the `onlyDelegate` modifier available for use, similar to `onlyOwner`:

```
contract MyContract is Delegated {

    constructor(address initialOwner) Delegated(initialOwner) {}

    function restrictedFunction() public onlyOwner { ... }

    function delegatedFunction() public onlyDelegate { ... }
}
```
