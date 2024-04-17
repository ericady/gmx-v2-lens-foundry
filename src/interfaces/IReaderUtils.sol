// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./IMarket.sol";
import "./IMarketUtils.sol";

interface IReaderUtils {
    struct VirtualInventory {
        uint256 virtualPoolAmountForLongToken;
        uint256 virtualPoolAmountForShortToken;
        int256 virtualInventoryForPositions;
    }

    struct BaseFundingValues {
        IMarketUtils.PositionType fundingFeeAmountPerSize;
        IMarketUtils.PositionType claimableFundingAmountPerSize;
    }

    struct MarketInfo {
        IMarket.Props market;
        uint256 borrowingFactorPerSecondForLongs;
        uint256 borrowingFactorPerSecondForShorts;
        BaseFundingValues baseFunding;
        IMarketUtils.GetNextFundingAmountPerSizeResult nextFunding;
        VirtualInventory virtualInventory;
        bool isDisabled;
    }
}
