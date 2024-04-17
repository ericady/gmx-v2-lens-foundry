// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMarket {
    struct Props {
        address marketToken;
        address indexToken;
        address longToken;
        address shortToken;
    }
}
