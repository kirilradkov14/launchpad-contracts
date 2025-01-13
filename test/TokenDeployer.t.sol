// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/token/TokenDeployer.sol";
import "../src/token/Token.sol";

contract TokenDeployerTest is Test {
    TokenDeployer deployer;
    address owner;
    address beneficiary;
    bytes32 salt;

    function setUp() public {
        owner = address(this); // Test contract deploys TokenDeployer
        beneficiary = vm.addr(1); // Random test address for beneficiary
        salt = keccak256("test-salt"); // Static salt for consistent deployment address

        deployer = new TokenDeployer();
    }

    function testDeployToken() public {
        string memory name = "Test Token";
        string memory symbol = "TST";

        address predictedAddress = deployer.deployTokenWithCreate2(beneficiary, salt, name, symbol);

        Token deployedToken = Token(predictedAddress);

        // Validate that the deployed token has the correct initial parameters
        assertEq(deployedToken.totalSupply(), deployer.TOTAL_SUPPLY());
        assertEq(deployedToken.balanceOf(beneficiary), deployer.TOTAL_SUPPLY());
        assertEq(deployedToken.name(), name);
        assertEq(deployedToken.symbol(), symbol);
    }

    function testFailDeployTokenWithSameSalt() public {
        string memory name = "Test Token";
        string memory symbol = "TST";

        deployer.deployTokenWithCreate2(beneficiary, salt, name, symbol);
        deployer.deployTokenWithCreate2(beneficiary, salt, name, symbol); // Should revert
    }

    function testPause() public {
        deployer.pause();
        assertTrue(deployer.paused());

        vm.expectRevert();
        deployer.deployTokenWithCreate2(beneficiary, salt, "Test Token", "TST");
    }

    function testUnpause() public {
        deployer.pause();
        deployer.unpause();
        assertFalse(deployer.paused());

        deployer.deployTokenWithCreate2(beneficiary, salt, "Test Token", "TST");
    }
}
