// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@devest/contracts/DeVest.sol";
import "@devest/contracts/VestingToken.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract DvTicket is Context, DeVest, ReentrancyGuard, VestingToken {

    event booked(address indexed customer, uint256 indexed ticketId);
    event transferred(address indexed sender, address indexed reciver, uint256 indexed ticketId);

    // ---

    uint256 public price;

    uint256 public totalSupply;
    uint256 public purchased = 0;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _tickets;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // for exchange
    mapping(uint256 => address) private _offeredTickets; // mapping of offered tickets to their owners
    mapping(uint256 => uint256) private _offeredPrices; // mapping of offered tickets to their offered prices

    // Properties
    string internal _name;           // name of the tangible
    string internal _symbol;         // symbol of the tangible
    string internal _tokenURI;   // total supply of shares (10^decimals)

    /**
    */
    constructor(address _tokenAddress, string memory __name, string memory __symbol, string memory __tokenURI, address _factory, address _owner)
    DeVest(_owner, _factory) VestingToken(_tokenAddress) {

        _symbol =  __symbol;
        _name = __name;
        _tokenURI = __tokenURI;
    }

    /**
     *  Initialize TST as tangible
     */
    function initialize(uint tax, uint256 _totalSupply, uint256 _price) public onlyOwner nonReentrant virtual{
        require(tax >= 0 && tax <= 1000, 'Invalid tax value');
        require(totalSupply >= 0 && totalSupply <= 10000, 'Max 10 decimals');

        totalSupply = _totalSupply;
        price = _price;

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

        // cancel offer if ticket is offered for sale
        if (isForSale2(ticketId))
            _offeredTickets[ticketId] = address(0);

        _tickets[ticketId] = to;
        _balances[_msgSender()] -= 1;
        _balances[to] += 1;

        emit transferred(_msgSender(), to, ticketId);
    }

    // Purchase ticket
    function purchase(uint256 ticketId) external payable {
        //require(address(0) == ownerOf(ticketId), "Ticket not available");
        require(ticketId < totalSupply, "Ticket sold out");
        require(_msgSender() != ownerOf(ticketId), "You already own this ticket");
        require(isForSale(ticketId), "Ticket not for sale");

        // check if its original ticket or ticket offered for sale
        if(_offeredTickets[ticketId] != address(0)){
            __allowance(_msgSender(), _offeredPrices[ticketId]);
            __transferFrom(_msgSender(), _offeredTickets[ticketId], _offeredPrices[ticketId]);

            _balances[_offeredTickets[ticketId]] -= 1;
            _offeredTickets[ticketId] = address(0);
        } else {
            require(address(0) == ownerOf(ticketId), "Ticket not available");
            __allowance(_msgSender(), price);
            __transferFrom(_msgSender(), address(this), price);
            // assigned ticket to buyer
            purchased++;
        }

        _tickets[ticketId] = _msgSender();
        _balances[_msgSender()] += 1;

        emit booked(_msgSender(), ticketId);
    }

    function isForSale(uint256 ticketId) public view returns (bool) {
        return _offeredTickets[ticketId] != address(0) || ownerOf(ticketId) == address(0);
    }

    function isForSale2(uint256 ticketId) public view returns (bool) {
        return _offeredTickets[ticketId] != address(0);
    }


    function priceOf(uint256 ticketId) public view returns (uint256) {
        return _offeredPrices[ticketId];
    }

    /**
     *  Offer ticket for sales
     */
    function offer(uint256 ticketId, uint256 _price) public { //payable takeFee {
        require(ownerOf(ticketId) == _msgSender(), "You don't own this ticket");
        require(_price > 0, "Price must be greater than zero");
        require(isForSale(ticketId) == false, "Already for sale");

        _offeredTickets[ticketId] = msg.sender;
        _offeredPrices[ticketId] = _price;
    }

    function cancel(uint256 ticketId) public {
        require(ownerOf(ticketId) == _msgSender(), "You don't own this ticket");
        require(isForSale(ticketId), "Ticket not for sale");

        _offeredTickets[ticketId] = address(0);
    }

    /**
     *  Withdraw tokens from purchases from this contract
    */
    function withdraw() external onlyOwner {
        __transfer(_owner, __balanceOf(address(this)));
    }

    /**
    * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 /*tokenId*/) external view returns (string memory){
        return _tokenURI;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool){
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId;
    }
}
