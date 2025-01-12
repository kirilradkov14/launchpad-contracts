// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ITokenDeployer } from "./interfaces/ITokenDeployer.sol";
import { ILaunchpadFactory } from "./interfaces//launchpad/ILaunchpadFactory.sol";
import { ILaunchpad } from "./interfaces/launchpad/ILaunchpad.sol";

contract LaunchpadFactory is Ownable(msg.sender), Pausable, ILaunchpadFactory{
    using Address for address;

    // initialize(address,address,address)
    bytes4 private constant INITIALIZE_SELECTOR = 0xc0c53b8b;

    address public immutable implementation;
    address public immutable wethAddress;
    address public immutable uniswapV2Router;
    address public immutable tokenDeployer;
    
    address[] public allLaunchpads;

    error LaunchpadFactoryInvalidImplementation();
    error LaunchpadFactoryInvalidWETH();
    error LaunchpadFactoryInvalidRouter();
    error LaunchpadFactoryInvalidTokenDeployer();
    error LaunchpadFactoryInitializationFailed();
    error LaunchpadFactoryInvalidToken();
    error LaunchpadFactoryDeployFailed();

    event LaunchpadCreation(address indexed launchpad, address indexed token);

    constructor(
        address _implementation,
        address _weth,
        address _uniswapV2Router,
        address _tokenDeployer
    ) {
        if (_implementation == address(0)) revert LaunchpadFactoryInvalidImplementation();
        if (_weth == address(0)) revert LaunchpadFactoryInvalidWETH();
        if (_uniswapV2Router == address(0)) revert LaunchpadFactoryInvalidRouter();
        if (_tokenDeployer == address(0)) revert LaunchpadFactoryInvalidTokenDeployer();

        implementation = _implementation;
        wethAddress = _weth;
        uniswapV2Router = _uniswapV2Router;
        tokenDeployer = _tokenDeployer;
    }

    /**
     * @notice Creates a new launchpad instance and deploys a corresponding token.
     * @dev Uses a salted deterministic deployment
     * @param _name The name of the token to be deployed.
     * @param _symbol The symbol of the token to be deployed.
     * @return launchpad The address of the newly created launchpad.
     */
    function createLaunchpad(
        string memory _name,
        string memory _symbol
    )
        external
        payable
        whenNotPaused
        returns (address launchpad)
    {
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        address impl = implementation;

        assembly ("memory-safe") {
            // Cleans the upper 96 bits of the `impl` word, then packs the first 3 bytes
            // of the `impl` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, impl)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `impl` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, impl), 0x5af43d82803e903d91602b57fd5bf3))
            launchpad := create2(0, 0x09, 0x37, salt)
        }
        
        if (launchpad == address(0)) revert LaunchpadFactoryDeployFailed();
        
        address token = ITokenDeployer(tokenDeployer).deployTokenWithCreate2(
            launchpad,
            salt,
            _name,
            _symbol
        );

        if (token == address(0)) revert LaunchpadFactoryInvalidToken();

        bytes memory data = abi.encodeCall(ILaunchpad.initialize, (token, wethAddress, uniswapV2Router));
        (bool success, ) = launchpad.call(data);

        if (!success) revert LaunchpadFactoryInitializationFailed();

        allLaunchpads.push(launchpad);
        emit LaunchpadCreation(launchpad, token);
        return launchpad;
    }

    /**
     * @dev Returns the total number of launchpads deployed by this factory.
     */
    function allLaunchpadsLength() external view returns (uint256) {
        return allLaunchpads.length;
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