// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ITokenDeployer {
    function deployTokenWithCreate2(address _beneficiary, bytes32 _salt, string memory _name, string memory _symbol)
        external
        returns (address predictedAddress);
}
