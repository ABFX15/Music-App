// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SongNFT is ERC721URIStorage, Ownable {
    error songNFT__InsufficientPayment();
    error songNFT__NoRoyaltiesToPay();
    error NFTSong__TransferFailed();

    // Current token ID
    uint256 private _currentTokenId;
    // NFT price
    uint256 public nftPrice;
    // Artist address   
    address public artist;
    // URI for the audio file
    string public audioURI;
    // Royalty balance
    uint256 public royaltyBalance;
    // URI for the cover image
    string public coverURI;

    event RoyaltyPaid(uint256 indexed tokenId, uint256 amount);
    event NFTMinted(uint256 indexed tokenId, address indexed to, uint256 amount);
    event RoyaltiesPaid(address indexed artist, uint256 amount);
    // Struct to store NFT information
    struct NFTInfo {
        uint256 nftPrice; // price of the NFT/songNFT
        address artist; // address of the artist
        string audioURI; // URI for the audio file
        string coverURI; // URI for the cover image
        uint256 royaltyBalance; // royalty balance
        uint256 currentTokenId; // current token ID
    }

    // Royalty percentage of NFT minting - using 30% here
    uint256 public constant ROYALTY_PERCENTAGE = 30;
    uint256 public constant PRECISION = 100;

    constructor(
        string memory _name, 
        string memory _symbol, 
        uint256 _nftPrice, 
        string memory _audioURI, 
        address _artist, 
        string memory _coverURI
    ) ERC721(_name, _symbol) {
        nftPrice = _nftPrice;
        artist = _artist;
        audioURI = _audioURI;
        coverURI = _coverURI;
        _currentTokenId = 0;
    }

    function mintNFT(address _to) public payable returns (uint256) {
        if (msg.value < nftPrice) {
            revert songNFT__InsufficientPayment();
        }
        // increment token and save it to new ID
        uint256 newtokenId = _currentTokenId;
        // calculate royalty amount
        uint256 royaltyAmount = (msg.value * ROYALTY_PERCENTAGE) / PRECISION;
        // update royalty balance
        royaltyBalance = royaltyBalance + royaltyAmount;
        // mint NFT
        _safeMint(_to, _currentTokenId);
        // set token URI
        _setTokenURI(_currentTokenId, audioURI);
        // increment token ID
        _currentTokenId++;

        // Emits event for royalty paid
        emit RoyaltyPaid(newtokenId, royaltyAmount);
        // Emits event for NFT minted
        emit NFTMinted(newtokenId, _to, msg.value);

        return newtokenId;
    }

    function payRoyalties() external onlyOwner {
        if (royaltyBalance == 0) {
            revert songNFT__NoRoyaltiesToPay();
        }
        uint256 amount = royaltyBalance;
        // reset royalty balance
        royaltyBalance = 0;
        // transfer royalties to artist
        (bool success, ) = payable(artist).call{value: amount}("");
        if (!success) {
            revert NFTSong__TransferFailed();
        }
        // emit event for royalties paid
        emit RoyaltiesPaid(artist,amount);
    }

    function getInfo() public view returns (NFTInfo memory) {
        return NFTInfo(nftPrice, artist, audioURI, coverURI, royaltyBalance, _currentTokenId);
    }
}
