// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./IPrice.sol";

interface IOracle {
    function getPrimaryPrice(
        address token
    ) external view returns (IPrice.Props memory);
}
