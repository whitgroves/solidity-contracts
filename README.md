# smart-contracts

A collection of smart contracts meant to be used interoperably to extend ERC20 tokens.

These contracts have been unlicensed and are freely available for any use, but be aware that they import code from contracts with different (but still permissable) licenses.

## Contracts

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
