// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./interfaces/IReader.sol";
import "./interfaces/IDataStore.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IMarketUtils.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@gmx-synthetics/contracts/market/Market.sol";
import "@gmx-synthetics/contracts/market/MarketUtils.sol";
import "@gmx-synthetics/contracts/market/MarketPoolValueInfo.sol";
import "@gmx-synthetics/contracts/data/Keys.sol";
import "@gmx-synthetics/contracts/data/DataStore.sol";
import "@gmx-synthetics/contracts/reader/Reader.sol";
import "@gmx-synthetics/contracts/reader/ReaderUtils.sol";
import "@gmx-synthetics/contracts/price/Price.sol";

contract GmxV2Lens is UUPSUpgradeable, OwnableUpgradeable {
    DataStore public constant dataStore =
        DataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);

    Reader constant gmxV2Reader =
        Reader(0xdA5A70c885187DaA71E7553ca9F728464af8d2ad);
    IVault constant gmxVault =
        IVault(0x489ee077994B6658eAfA855C308275EAd8097C4A);

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

    function initialize() external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function getMarketData(
        address marketID
    ) external view returns (MarketDataState memory marketData) {
        Market.Props memory market = gmxV2Reader.getMarket(dataStore, marketID);

        marketData.marketToken = market.marketToken;
        marketData.indexToken = market.indexToken;
        marketData.longToken = market.longToken;
        marketData.shortToken = market.shortToken;

        Price.Props memory indexTokenPrice;
        indexTokenPrice.max = gmxVault.getMaxPrice(market.indexToken);
        indexTokenPrice.min = gmxVault.getMinPrice(market.indexToken);
        Price.Props memory longTokenPrice;
        longTokenPrice.max = gmxVault.getMaxPrice(market.longToken);
        longTokenPrice.min = gmxVault.getMinPrice(market.longToken);
        Price.Props memory shortTokenPrice;
        shortTokenPrice.max = gmxVault.getMaxPrice(market.shortToken);
        shortTokenPrice.min = gmxVault.getMinPrice(market.shortToken);

        MarketPoolValueInfo.Props memory marketPoolInfo = MarketUtils
            .getPoolValueInfo(
                dataStore,
                market,
                indexTokenPrice,
                longTokenPrice,
                shortTokenPrice,
                Keys.MAX_PNL_FACTOR_FOR_DEPOSITS,
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

        MarketUtils.MarketPrices memory prices;
        prices.indexTokenPrice = indexTokenPrice;
        prices.longTokenPrice = longTokenPrice;
        prices.shortTokenPrice = shortTokenPrice;

        ReaderUtils.MarketInfo memory marketInfo = gmxV2Reader.getMarketInfo(
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

        marketData.openInterestLong = MarketUtils.getOpenInterestInTokens(
            dataStore,
            market,
            true
        );
        marketData.openInterestShort = MarketUtils.getOpenInterestInTokens(
            dataStore,
            market,
            false
        );
        marketData.reservedUsdLong = MarketUtils.getReservedUsd(
            dataStore,
            market,
            prices,
            true
        );
        marketData.reservedUsdShort = MarketUtils.getReservedUsd(
            dataStore,
            market,
            prices,
            false
        );
        marketData.maxOpenInterestUsdLong = MarketUtils.getMaxOpenInterest(
            dataStore,
            marketID,
            true
        );
        marketData.maxOpenInterestUsdShort = MarketUtils.getMaxOpenInterest(
            dataStore,
            marketID,
            false
        );
    }
}
