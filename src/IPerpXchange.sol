// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPerpXchange {
    // Errors
    error PerpX__InvalidAmount();
    error PerpX__InsufficientCollateral();
    error PerpX__InvalidSize();
    error PerpX__OpenPositionExists();
    error PerpX__InvalidPositionId();
    error PerpX__NotOwner();
    error PerpX__InvalidCollateral();
    error PerpX__NoLiquidationNeeded();
    error PerpX__NoPositionChosen();
    error PerpX__InsufficientLiquidity();
    error PerpX__InvalidPosition();
    error PerpX__NoUserPositions();

    // Enum
    enum PositionAction {
        Open,
        Close,
        IncreaseSize,
        DecreaseSize
    }
}
