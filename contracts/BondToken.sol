// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Whitelist.sol";

contract BondToken {
    // Bond metadata
    string public name;
    string public symbol;
    string public isin;         // e.g., "UKT-2030-4.5"
    uint256 public couponBps;   // 450 = 4.50%
    uint256 public maturity;    // unix timestamp
    string public currency;     // "GBP"

    // Token state (minimal ERC20-like)
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Controls
    address public issuer;      // Treasury/DMO role
    bool public paused;
    Whitelist public whitelist;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Paused(bool status);
    event Mint(address indexed to, uint256 amount);

    modifier onlyIssuer() {
        require(msg.sender == issuer, "not issuer");
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

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _isin,
        uint256 _couponBps,
        uint256 _maturity,
        string memory _currency,
        address _issuer,
        address _whitelist
    ) {
        name = _name;
        symbol = _symbol;
        isin = _isin;
        couponBps = _couponBps;
        maturity = _maturity;
        currency = _currency;
        issuer = _issuer;
        whitelist = Whitelist(_whitelist);
    }

    function setPaused(bool status) external onlyIssuer {
        paused = status;
        emit Paused(status);
    }

    function mint(address to, uint256 amount)
        external
        onlyIssuer
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
