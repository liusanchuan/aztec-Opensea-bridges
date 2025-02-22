// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {BridgeTestBase} from "./../../aztec/base/BridgeTestBase.sol";
import {AztecTypes} from "rollup-encoder/libraries/AztecTypes.sol";

// Example-specific imports
import {AddressRegistry} from "../../../bridges/registry/AddressRegistry.sol";
import {ErrorLib} from "../../../bridges/base/ErrorLib.sol";

// @notice The purpose of this test is to directly test convert functionality of the bridge.
contract AddressRegistryUnitTest is BridgeTestBase {
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private rollupProcessor;
    AddressRegistry private bridge;
    uint256 public maxInt = type(uint160).max;
    AztecTypes.AztecAsset private ethAsset =
        AztecTypes.AztecAsset({id: 0, erc20Address: address(0), assetType: AztecTypes.AztecAssetType.ETH});
    AztecTypes.AztecAsset private virtualAsset =
        AztecTypes.AztecAsset({id: 0, erc20Address: address(0), assetType: AztecTypes.AztecAssetType.VIRTUAL});
    AztecTypes.AztecAsset private daiAsset =
        AztecTypes.AztecAsset({id: 1, erc20Address: DAI, assetType: AztecTypes.AztecAssetType.ERC20});

    event AddressRegistered(uint256 indexed addressCount, address indexed registeredAddress);

    // @dev This method exists on RollupProcessor.sol. It's defined here in order to be able to receive ETH like a real
    //      rollup processor would.
    function receiveEthFromBridge(uint256 _interactionNonce) external payable {}

    function setUp() public {
        // In unit tests we set address of rollupProcessor to the address of this test contract
        rollupProcessor = address(this);

        bridge = new AddressRegistry(rollupProcessor);

        // Use the label cheatcode to mark the address with "AddressRegistry Bridge" in the traces
        vm.label(address(bridge), "AddressRegistry Bridge");
    }

    function testInvalidCaller(address _callerAddress) public {
        vm.assume(_callerAddress != rollupProcessor);
        // Use HEVM cheatcode to call from a different address than is address(this)
        vm.prank(_callerAddress);
        vm.expectRevert(ErrorLib.InvalidCaller.selector);
        bridge.convert(emptyAsset, emptyAsset, emptyAsset, emptyAsset, 0, 0, 0, address(0));
    }

    function testInvalidInputAssetType() public {
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        bridge.convert(daiAsset, emptyAsset, emptyAsset, emptyAsset, 0, 0, 0, address(0));
    }

    function testInvalidOutputAssetType() public {
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        bridge.convert(ethAsset, emptyAsset, daiAsset, emptyAsset, 0, 0, 0, address(0));
    }

    function testInvalidInputAmount() public {
        vm.expectRevert(ErrorLib.InvalidInputAmount.selector);

        bridge.convert(
            ethAsset,
            emptyAsset,
            virtualAsset,
            emptyAsset,
            0, // _totalInputValue
            0, // _interactionNonce
            0, // _auxData
            address(0x0)
        );
    }

    function testGetBackMaxVirtualAssets() public {
        vm.warp(block.timestamp + 1 days);

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            ethAsset,
            emptyAsset,
            virtualAsset,
            emptyAsset,
            1, // _totalInputValue
            0, // _interactionNonce
            0, // _auxData
            address(0x0)
        );

        assertEq(outputValueA, maxInt, "Output value A doesn't equal maxInt");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");
    }

    function testRegistringAnAddress() public {
        vm.warp(block.timestamp + 1 days);

        uint160 inputAmount = uint160(0x2e782B05290A7fFfA137a81a2bad2446AD0DdFEA);

        vm.expectEmit(true, true, false, false);
        emit AddressRegistered(0, address(inputAmount));

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            virtualAsset,
            emptyAsset,
            virtualAsset,
            emptyAsset,
            inputAmount, // _totalInputValue
            0, // _interactionNonce
            0, // _auxData
            address(0x0)
        );

        uint256 id = bridge.addressCount() - 1;
        address newlyRegistered = bridge.addresses(id);

        assertEq(address(inputAmount), newlyRegistered, "Address not registered");
        assertEq(outputValueA, 0, "Output value is not 0");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");
    }

    function testRegisterFromEth() public {
        address to = address(0x2e782B05290A7fFfA137a81a2bad2446AD0DdFEA);
        uint256 count = bridge.registerAddress(to);
        address registered = bridge.addresses(count);
        assertEq(to, registered, "Address not registered");
    }
}
