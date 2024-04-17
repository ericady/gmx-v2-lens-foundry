// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IDataStore {
    function getUint(bytes32 key) external view returns (uint256);
}
