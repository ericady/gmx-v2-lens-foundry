// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IVault {
    function getMaxPrice(address token) external view returns (uint);

    function getMinPrice(address token) external view returns (uint);
}
