// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@devest/contracts/DeVest.sol";

contract DvTicket is Context, DeVest, ReentrancyGuard {

    event purchased(address indexed customer, uint256 indexed ticketId);
    event transferred(address indexed sender, address indexed reciver, uint256 indexed ticketId);

    // ---

    uint256 private _price;

    uint256 private _totalSupply;
    uint256 private _purchased = 0;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _tickets;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Vesting / Trading token reference
    IERC20 internal _token;

    // Properties
    string internal _name;           // name of the tangible
    string internal _symbol;         // symbol of the tangible
    string internal _tokenURI;   // total supply of shares (10^decimals)

    /**
    */
    constructor(address _tokenAddress, string memory __name, string memory __symbol, string memory __tokenURI, address _factory, address _owner)
    DeVest(_owner, _factory) {

        _token =  IERC20(_tokenAddress);
        _symbol = string(abi.encodePacked("% ", __symbol));
        _name = __name;
        _tokenURI = __tokenURI;
    }

    /**
     *  Initialize TST as tangible
     */
    function initialize(uint tax, uint256 totalSupply, uint256 price) public onlyOwner nonReentrant virtual{
        require(tax >= 0 && tax <= 1000, 'Invalid tax value');
        require(totalSupply >= 0 && totalSupply <= 10000, 'Max 10 decimals');

        _totalSupply = totalSupply;
        _price = price;

        // set attributes
        _setRoyalties(tax, owner());
    }

    function ownerOf(uint256 tokenId) public view returns (address owner) {
        return _tickets[tokenId];
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "Address zero is not a valid owner");
        return _balances[owner];
    }

    // Transfer ticket
    function transfer(address to, uint256 ticketId) external payable takeFee {
        require(_msgSender() == ownerOf(ticketId), "Transfer caller is not owner");
        require(to != address(0), "Transfer to the zero address");

        _tickets[ticketId] = to;
        _balances[_msgSender()] -= 1;
        _balances[to] += 1;

        emit transferred(_msgSender(), to, ticketId);
    }

    // Purchase ticket
    function purchase(uint256 ticketId) external takeFee payable {
        require(_purchased < _totalSupply, "No more tickets available");
        require(address(0) == ownerOf(ticketId), "Ticket not available");

        // check if enough escrow allowed and pick the cash
        __allowance(_msgSender(), _price);
        _token.transferFrom(_msgSender(), address(this), _price);

        // assigned ticket to buyer
        _purchased++;
        _tickets[ticketId] = _msgSender();
        _balances[_msgSender()] += 1;

        emit purchased(_msgSender(), ticketId);
    }

    /**
     *  Withdraw tokens from purchases from this contract
    */
    function withdraw() external onlyOwner {
        _token.transfer(_owner, _token.balanceOf(address(this)));
    }

    /**
     *  Internal token allowance
     */
    function __allowance(address account, uint256 amount) internal view {
        require(_token.allowance(account, address(this)) >= amount, 'Insufficient allowance provided');
    }

    /**
    * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 /*tokenId*/) external view returns (string memory){
        return _tokenURI;
    }

    function supportsInterface(bytes4 /*interfaceId*/) external pure returns (bool){
        return false;
    }

    function getPrice() external view returns (uint256) {
        return _price;
    }

    function getPurchased() external view returns (uint256) {
        return _purchased;
    }

    function getTotalSupply() external view returns (uint256) {
        return _totalSupply;
    }
    
}
