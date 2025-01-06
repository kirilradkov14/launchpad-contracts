// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Token } from "./Token.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ITokenDeployer } from "../interfaces/ITokenDeployer.sol";

/**
 * @title TokenDeployer
 * @notice Handles salted deployment of ERC20 tokens using CREATE2.
 */
contract TokenDeployer is Ownable, Pausable, ITokenDeployer {

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    error TokenDeployerDeploymentFailed();

    constructor()Ownable(msg.sender){}

    /**
     * @dev Deploy ERC20 token using create2
     * @param _beneficiary The address that will receive the initial supply.
     * @param _salt The salt for the create2 deployment.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @return predictedAddress The address of the deployed token.
     */
    function deployTokenWithCreate2(
        address _beneficiary,
        bytes32 _salt,
        string memory _name, 
        string memory _symbol
    ) 
        external
        whenNotPaused
        returns (address predictedAddress)
    {
        predictedAddress = address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            _salt,
            keccak256(abi.encodePacked(
                type(Token).creationCode,
                abi.encode(TOTAL_SUPPLY, _beneficiary, _name, _symbol)
            ))
        )))));

        Token token = new Token{salt: _salt}(TOTAL_SUPPLY, _beneficiary, _name, _symbol);

        if (address(token) != predictedAddress) revert TokenDeployerDeploymentFailed();
    }

    /**
     * @dev Allows the owner to pause the factory, disabling launchpad creation.
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Allows the owner to unpause the factory, enabling launchpad creation.
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}