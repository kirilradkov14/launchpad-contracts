// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Token} from "./token/Token.sol";
import {ILaunchpadFactory} from "./interfaces//launchpad/ILaunchpadFactory.sol";
import {ILaunchpad} from "./interfaces/launchpad/ILaunchpad.sol";

contract LaunchpadFactory is Ownable(msg.sender), Pausable, ILaunchpadFactory {
    using Address for address;

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    address public immutable implementation;
    address public immutable uniswapV2Router;
    address public immutable tokenDeployer;

    address[] public allLaunchpads;

    error LaunchpadFactoryInvalidImplementation();
    error LaunchpadFactoryInvalidRouter();
    error LaunchpadFactoryInitializationFailed();
    error LaunchpadFactoryDeployFailed();
    error LaunchpadFactoryTokenDeploymentFailed();

    event LaunchpadCreation(address indexed launchpad, address indexed token);

    constructor(address _implementation, address _uniswapV2Router) {
        if (_implementation == address(0)) revert LaunchpadFactoryInvalidImplementation();
        if (_uniswapV2Router == address(0)) revert LaunchpadFactoryInvalidRouter();

        implementation = _implementation;
        uniswapV2Router = _uniswapV2Router;
    }

    /**
     * @notice Creates a new launchpad instance and deploys a corresponding token.
     * @dev Uses a salted deterministic deployment
     * @param _name The name of the token to be deployed.
     * @param _symbol The symbol of the token to be deployed.
     * @return launchpad The address of the newly created launchpad.
     */
    function createLaunchpad(string memory _name, string memory _symbol)
        external
        whenNotPaused
        returns (address launchpad)
    {
        address impl = implementation;

        assembly ("memory-safe") {
            // Cleans the upper 96 bits of the `impl` word, then packs the first 3 bytes
            // of the `impl` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, impl)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `impl` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, impl), 0x5af43d82803e903d91602b57fd5bf3))
            launchpad := create(0, 0x09, 0x37)
        }

        if (launchpad == address(0)) revert LaunchpadFactoryDeployFailed();

        address token = _deployToken(launchpad, _name, _symbol);

        bytes memory data = abi.encodeCall(ILaunchpad.initialize, (token, uniswapV2Router));
        (bool success,) = launchpad.call(data);

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

    /**
     * @dev Deploy ERC20 token using create
     * @param _beneficiary The address that will receive the initial supply.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @return token The address of the deployed token.
     */
    function _deployToken(address _beneficiary, string memory _name, string memory _symbol)
        internal
        whenNotPaused
        returns (address token)
    {
        token = address(new Token(TOTAL_SUPPLY, _beneficiary, _name, _symbol));
        if (token == address(0)) revert LaunchpadFactoryTokenDeploymentFailed();
    }
}
