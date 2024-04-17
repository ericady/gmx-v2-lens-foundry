// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./gmx/Keys.sol";
import "./interfaces/IReader.sol";
import "./interfaces/IDataStore.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IMarket.sol";
import "./interfaces/IMarketUtils.sol";

contract GmxV2Lens {
    uint256 public number;
    address public constant dataStore =
        0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;

    IReader constant gmxV2Reader =
        IReader(0xdA5A70c885187DaA71E7553ca9F728464af8d2ad);
    IOracle constant gmxV2Oracle =
        IOracle(0xa11B501c2dd83Acd29F6727570f2502FAaa617F2);
    IMarketUtils constant gmxV2MarketUtils =
        IMarketUtils(0xDd534dAADa2cEb42d65D7079031A33A109B5c0F1);
    bytes32 public constant MAX_PNL_FACTOR_FOR_TRADERS =
        keccak256(abi.encode("MAX_PNL_FACTOR_FOR_TRADERS"));

    struct MarketDataState {
        address marketToken;
        address indexToken;
        address longToken;
        address shortToken;
        uint256 poolValue; // 30 decimals
        uint256 longTokenAmount; // token decimals
        uint256 longTokenUsd; // 30 decimals
        uint256 shortTokenAmount; // token decimals
        uint256 shortTokenUsd; // 30 decimals
        uint256 openInterestLong; // 30 decimals
        uint256 openInterestShort; // 30 decimals
        int256 pnlLong; // 30 decimals
        int256 pnlShort; // 30 decimals
        int256 netPnl; // 30 decimals
        uint256 borrowingFactorPerSecondForLongs; // 30 decimals
        uint256 borrowingFactorPerSecondForShorts; // 30 decimals
        bool longsPayShorts;
        uint256 fundingFactorPerSecond; // 30 decimals
        int256 fundingFactorPerSecondLongs; // 30 decimals
        int256 fundingFactorPerSecondShorts; // 30 decimals
        uint256 reservedUsdLong; // 30 decimals
        uint256 reservedUsdShort; // 30 decimals
        uint256 maxOpenInterestUsdLong; // 30 decimals
        uint256 maxOpenInterestUsdShort; // 30 decimals
    }

    function getMarketData(
        address marketID
    ) external view returns (MarketDataState memory marketData) {
        IMarket.Props memory market = gmxV2Reader.getMarket(
            dataStore,
            marketID
        );

        marketData.marketToken = market.marketToken;
        marketData.indexToken = market.indexToken;
        marketData.longToken = market.longToken;
        marketData.shortToken = market.shortToken;

        IPrice.Props memory indexTokenPrice = gmxV2Oracle.getPrimaryPrice(
            market.indexToken
        );
        IPrice.Props memory longTokenPrice = gmxV2Oracle.getPrimaryPrice(
            market.longToken
        );
        IPrice.Props memory shortTokenPrice = gmxV2Oracle.getPrimaryPrice(
            market.shortToken
        );

        IMarketUtils.MarketPoolValueInfo
            memory marketPoolInfo = gmxV2MarketUtils.getPoolValueInfo(
                dataStore,
                market,
                indexTokenPrice,
                longTokenPrice,
                shortTokenPrice,
                MAX_PNL_FACTOR_FOR_TRADERS,
                true
            );

        marketData.poolValue = uint(marketPoolInfo.poolValue);
        marketData.longTokenAmount = marketPoolInfo.longTokenAmount;
        marketData.longTokenUsd = marketPoolInfo.longTokenUsd;
        marketData.shortTokenAmount = marketPoolInfo.shortTokenAmount;
        marketData.shortTokenUsd = marketPoolInfo.shortTokenUsd;
        marketData.pnlLong = marketPoolInfo.longPnl;
        marketData.pnlShort = marketPoolInfo.shortPnl;
        marketData.netPnl = marketPoolInfo.netPnl;

        IMarketUtils.MarketPrices memory prices;
        prices.indexTokenPrice = indexTokenPrice;
        prices.longTokenPrice = longTokenPrice;
        prices.shortTokenPrice = shortTokenPrice;

        IReaderUtils.MarketInfo memory marketInfo = gmxV2Reader.getMarketInfo(
            dataStore,
            prices,
            marketID
        );
        marketData.borrowingFactorPerSecondForLongs = marketInfo
            .borrowingFactorPerSecondForLongs;
        marketData.borrowingFactorPerSecondForShorts = marketInfo
            .borrowingFactorPerSecondForShorts;
        marketData.longsPayShorts = marketInfo.nextFunding.longsPayShorts;
        marketData.fundingFactorPerSecond = marketInfo
            .nextFunding
            .fundingFactorPerSecond;

        marketData.openInterestLong = getOpenInterestInTokens(market, true);
        marketData.openInterestShort = getOpenInterestInTokens(market, false);
        marketData.reservedUsdLong = getReservedUsd(market, prices, true);
        marketData.reservedUsdShort = getReservedUsd(market, prices, false);
        marketData.maxOpenInterestUsdLong = getMaxOpenInterest(marketID, true);
        marketData.maxOpenInterestUsdShort = getMaxOpenInterest(
            marketID,
            false
        );
    }

    function getOpenInterestInTokens(
        IMarket.Props memory market,
        bool isLong
    ) internal view returns (uint256) {
        uint256 divisor = getPoolDivisor(market.longToken, market.shortToken);
        uint256 openInterestUsingLongTokenAsCollateral = getOpenInterestInTokens(
                market.marketToken,
                market.longToken,
                isLong,
                divisor
            );
        uint256 openInterestUsingShortTokenAsCollateral = getOpenInterestInTokens(
                market.marketToken,
                market.shortToken,
                isLong,
                divisor
            );

        return
            openInterestUsingLongTokenAsCollateral +
            openInterestUsingShortTokenAsCollateral;
    }

    function getOpenInterestInTokens(
        address market,
        address collateralToken,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        return
            IDataStore(dataStore).getUint(
                Keys.openInterestInTokensKey(market, collateralToken, isLong)
            ) / divisor;
    }

    function getPoolDivisor(
        address longToken,
        address shortToken
    ) internal pure returns (uint256) {
        return longToken == shortToken ? 2 : 1;
    }

    function getReservedUsd(
        IMarket.Props memory market,
        IMarketUtils.MarketPrices memory prices,
        bool isLong
    ) internal view returns (uint256) {
        uint256 reservedUsd;
        if (isLong) {
            // for longs calculate the reserved USD based on the open interest and current indexTokenPrice
            // this works well for e.g. an ETH / USD market with long collateral token as WETH
            // the available amount to be reserved would scale with the price of ETH
            // this also works for e.g. a SOL / USD market with long collateral token as WETH
            // if the price of SOL increases more than the price of ETH, additional amounts would be
            // automatically reserved
            uint256 openInterestInTokens = getOpenInterestInTokens(
                market,
                isLong
            );
            reservedUsd = openInterestInTokens * prices.indexTokenPrice.max;
        } else {
            // for shorts use the open interest as the reserved USD value
            // this works well for e.g. an ETH / USD market with short collateral token as USDC
            // the available amount to be reserved would not change with the price of ETH
            reservedUsd = getOpenInterest(market, isLong);
        }

        return reservedUsd;
    }

    function getOpenInterest(
        IMarket.Props memory market
    ) internal view returns (uint256) {
        uint256 longOpenInterest = getOpenInterest(market, true);
        uint256 shortOpenInterest = getOpenInterest(market, false);

        return longOpenInterest + shortOpenInterest;
    }

    function getOpenInterest(
        IMarket.Props memory market,
        bool isLong
    ) internal view returns (uint256) {
        uint256 divisor = getPoolDivisor(market.longToken, market.shortToken);
        uint256 openInterestUsingLongTokenAsCollateral = getOpenInterest(
            market.marketToken,
            market.longToken,
            isLong,
            divisor
        );
        uint256 openInterestUsingShortTokenAsCollateral = getOpenInterest(
            market.marketToken,
            market.shortToken,
            isLong,
            divisor
        );

        return
            openInterestUsingLongTokenAsCollateral +
            openInterestUsingShortTokenAsCollateral;
    }

    function getOpenInterest(
        address market,
        address collateralToken,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        return
            IDataStore(dataStore).getUint(
                Keys.openInterestKey(market, collateralToken, isLong)
            ) / divisor;
    }

    function getMaxOpenInterest(
        address market,
        bool isLong
    ) internal view returns (uint256) {
        return
            IDataStore(dataStore).getUint(
                Keys.maxOpenInterestKey(market, isLong)
            );
    }
}
