// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/** 
 * @title RaulMedinaTokenBase
 * @author Raúl Medina
 *
 * @notice Implements a contract to create tokens with the requested requirements.
 */
contract RaulMedinaToken is ERC20 {

    /// @notice Set the owner of the contract, he's the only one who can mint it.
    address private owner;

    /** 
     * @notice
     * @dev Sets the values for 'initialMintValue', 'name' and 'symbol'.
     * All values are immutable: they can only be set once during construction.
     *
     * @param initialIntegerValueToMint is the initial integer value to mint.
     * @param name of the token.
     * @param symbol of the token, usually a shorter version of the name.
    */
    constructor
    (
        string memory name, 
        string memory symbol, 
        uint256 initialIntegerValueToMint
    ) ERC20(name, symbol) 
    {
        owner = msg.sender;
        mint(initialIntegerValueToMint);
    }

    /**
     * @notice This will be reverted if the sender is not the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can execute this function");
        _;
    }

    /**
     * @dev Creates a 'value' amount of tokens and assigns them to 'owner'.
     * Only the owner can execute this function
     */
    function mint(uint256 value) public onlyOwner {
        _mint(msg.sender, value * 10 ** decimals());
    }
}
