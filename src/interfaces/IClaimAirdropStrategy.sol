// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

interface IClaimAirdropStrategy {
    function claim(address to_, bytes memory data_) external;
}
