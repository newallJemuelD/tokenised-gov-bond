// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Whitelist {
    address public admin;
    mapping(address => bool) public isWhitelisted;

    event Whitelisted(address indexed account, bool status);

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
        isWhitelisted[msg.sender] = true;
        emit Whitelisted(msg.sender, true);
    }

    function setWhitelisted(address account, bool status) external onlyAdmin {
        isWhitelisted[account] = status;
        emit Whitelisted(account, status);
    }
}
