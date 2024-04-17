// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {GmxV2Lens} from "../src/GmxV2Lens.sol";

contract GmxV2LensTest is Test {
    GmxV2Lens public counter;

    function setUp() public {
        counter = new GmxV2Lens();
    }
}
