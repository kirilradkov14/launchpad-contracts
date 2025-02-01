// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILaunchpadFactory {
    function createLaunchpad(string memory _name, string memory _symbol) external returns (address launchpad);
}
