// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {GmxV2Lens} from "../src/GmxV2Lens.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GmxV2LensTest is Test {
    GmxV2Lens public lens;

    function setUp() public {
        uint256 arbFork = vm.createFork("arbitrum");
        vm.selectFork(arbFork);

        GmxV2Lens lensImp = new GmxV2Lens();
        ERC1967Proxy lensProxy = new ERC1967Proxy(
            address(lensImp),
            abi.encodeCall(GmxV2Lens.initialize, ())
        );
        lens = GmxV2Lens(address(lensProxy));
    }

    function testLensMarketData() public view {
        address market = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;
        GmxV2Lens.MarketDataState memory marketState = lens.getMarketData(
            market
        );

        console.log("Market Token:", marketState.marketToken);
    }

    // function testLensUUPSUpgradeable() public {
    //     bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    //     assertEq(address(lens), address(lens));

    //     // upgrade to new implementation address
    //     GmxV2Lens newImplementation = new GmxV2Lens();
    //     lens.upgradeToAndCall(address(newImplementation), "");
    //     assertEq(
    //         address(
    //             uint160(uint256(vm.load(address(lens), implementationSlot)))
    //         ),
    //         address(newImplementation)
    //     );

    //     // test upgrade after renounce ownership
    //     lens.renounceOwnership();
    //     assertEq(lens.owner(), address(0));

    //     vm.expectRevert();
    //     lens.upgradeToAndCall(address(newImplementation), "");
    // }
}
