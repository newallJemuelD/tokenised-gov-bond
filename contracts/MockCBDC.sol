// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Whitelist.sol";

contract MockCBDC {
    string public name = "Mock Wholesale CBDC";
    string public symbol = "wGBP";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public centralBank;     // issuer of CBDC
    bool public paused;
    Whitelist public whitelist;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Paused(bool status);
    event Mint(address indexed to, uint256 amount);

    modifier onlyCentralBank() {
        require(msg.sender == centralBank, "not central bank");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    modifier onlyWhitelisted(address a) {
        require(whitelist.isWhitelisted(a), "not whitelisted");
        _;
    }

    constructor(address _centralBank, address _whitelist) {
        centralBank = _centralBank;
        whitelist = Whitelist(_whitelist);
    }

    function setPaused(bool status) external onlyCentralBank {
        paused = status;
        emit Paused(status);
    }

    function mint(address to, uint256 amount)
        external
        onlyCentralBank
        onlyWhitelisted(to)
    {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount)
        external
        whenNotPaused
        onlyWhitelisted(msg.sender)
        onlyWhitelisted(to)
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        whenNotPaused
        onlyWhitelisted(from)
        onlyWhitelisted(to)
        returns (bool)
    {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance too low");
        allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "balance too low");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
