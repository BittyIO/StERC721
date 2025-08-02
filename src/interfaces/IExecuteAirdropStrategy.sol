// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

interface IExecuteAirdropStrategy {
    function execute(address to_, bytes memory data_) external;
}
