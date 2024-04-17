// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./IMarket.sol";
import "./IMarketUtils.sol";
import "./IReaderUtils.sol";

interface IReader {
    function getMarket(
        address dataStore,
        address key
    ) external view returns (IMarket.Props memory);

    function getMarketInfo(
        address dataStore,
        IMarketUtils.MarketPrices memory prices,
        address marketKey
    ) external view returns (IReaderUtils.MarketInfo memory);
}
