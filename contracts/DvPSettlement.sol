// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Like {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DvPSettlement {
    // Atomic DvP: bond delivery <-> cash payment
    event Settled(
        address indexed buyer,
        address indexed seller,
        address indexed bondToken,
        address cashToken,
        uint256 bondAmount,
        uint256 cashAmount
    );

    function settleDvP(
        address buyer,
        address seller,
        address bondToken,
        address cashToken,
        uint256 bondAmount,
        uint256 cashAmount
    ) external {
        // Preconditions:
        // - seller approved this contract to transfer bondAmount of bondToken
        // - buyer approved this contract to transfer cashAmount of cashToken

        require(IERC20Like(cashToken).transferFrom(buyer, seller, cashAmount), "cash transfer failed");
        require(IERC20Like(bondToken).transferFrom(seller, buyer, bondAmount), "bond transfer failed");

        emit Settled(buyer, seller, bondToken, cashToken, bondAmount, cashAmount);
    }
}
