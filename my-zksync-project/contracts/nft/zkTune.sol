// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SongNFT} from "./songNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title zkTune - A Decentralized Music Streaming Platform
 * @author Adam Cryptab
 * @notice zkTune is a decentralized music platform that enables artists to upload songs,
 *         mint NFTs, and earn royalties while users can stream music and collect NFTs.
 *         The platform maintains a registry of artists, users, and songs with their
 *         associated metadata and streaming statistics.
 */
contract zkTune {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error zkTune__NotRegisteredArtist();
    error zkTune__SongDoesNotExist();
    error zkTune__ArtistAlreadyRegistered();
    error zkTune__UserAlreadyRegistered();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Artist {
        string name;
        string profileURI;
    }

    struct User {
        string name;
        string profileURI;
    }

    struct Song {
        uint256 id;
        address artist;
        string title;
        string audioURI;
        string coverURI;
        uint256 streamCount;
        address songNFTAddress;
    }

    /*//////////////////////////////////////////////////////////////
                               MAPPINGS
    //////////////////////////////////////////////////////////////*/
    mapping(address => Artist) public artists; // mapping of address to artist
    mapping(address => User) public users; // mapping of address to user
    mapping(uint256 => Song) public songs; // mapping of song ID to song
    mapping(uint256 => mapping(address => bool)) public userHasNFT; // mapping of song ID to user address to boolean
    mapping(address => uint256[]) public artistSongs; // mapping of artist address to song IDs
    mapping(address => uint256[]) public userStreams; // mapping of user address to song IDs
    mapping(uint256 => Artist) public artistId; // mapping of artist ID to artist

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    address[] public artistAddresses; // array of artist addresses
    uint256[] public songIds; // array of song IDs
    uint256 public _currentSongId; // current song ID
    uint256 private _currentArtistId; // current artist ID
    uint256 public totalSongs; // total number of songs
    uint256 public totalUsers; // total number of users
    uint256 public totalArtists; // total number of artists

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ArtistRegistered(address indexed artist, string name);
    event UserRegistered(address indexed user, string name);
    event SongUploaded(uint256 indexed songId, address indexed artist, string title);
    event SongStreamed(uint256 indexed songId, address indexed user);

    constructor() {
        _currentSongId = 0;
        _currentArtistId = 0;
        totalSongs = 0;
        totalUsers = 0;
        totalArtists = 0;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Modifier to check if the sender is a registered artist
     */
    modifier onlyRegisteredArtist() {
        if(bytes(artists[msg.sender].name).length == 0) {
            revert zkTune__NotRegisteredArtist();
        }
        _;
    }

    /**
     * @notice Modifier to check if the song exists
     */
    modifier songExists(uint256 _songId) {
        if(songs[_songId].id == 0) {
            revert zkTune__SongDoesNotExist();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Register an artist
     * @param _name The name of the artist
     * @param _profileURI The profile URI of the artist
     */
    function registerArtist(string memory _name, string memory _profileURI) external {
        if(bytes(artists[msg.sender].name).length != 0) {
            revert zkTune__ArtistAlreadyRegistered();
        }
        _currentArtistId++;
        uint256 newArtistId = _currentArtistId;
        artists[msg.sender] = Artist(
            _name,
            _profileURI
        );

        artistId[newArtistId] = Artist(
            _name, 
            _profileURI
        );
        
        artistAddresses.push(msg.sender);
        totalArtists++;

        emit ArtistRegistered(msg.sender, _name);
    }

    /**
     * @notice Register a user
     * @param _name The name of the user
     * @param _profileURI The profile URI of the user
     */
    function registerUser(string memory _name, string memory _profileURI) external {
        if(bytes(users[msg.sender].name).length != 0) {
            revert zkTune__UserAlreadyRegistered();
        }
        users[msg.sender] = User(
            _name,
            _profileURI
        );
        totalUsers++;

        emit UserRegistered(msg.sender, _name);
    }

    /**
     * @notice Upload a song
     * @param _title The title of the song
     * @param _audioURI The audio URI of the song
     * @param _coverURI The cover URI of the song
     * @param nftPrice The price of the NFT
     */
    function uploadSong(string memory _title, string memory _audioURI, string memory _coverURI, uint256 nftPrice) external onlyRegisteredArtist {
        _currentSongId++;

        uint256 newSongId = _currentSongId;

        SongNFT songNFT = new SongNFT(_title, "ZKT", nftPrice, _audioURI, msg.sender, _coverURI);

        songs[newSongId] = Song(
            newSongId,
            msg.sender,
            _title,
            _audioURI,
            _coverURI,
            0,
            address(songNFT)
        );
        artistSongs[msg.sender].push(newSongId);

        totalSongs++;

        emit SongUploaded(newSongId, msg.sender, _title);
    }

    /**
     * @notice Stream a song
     * @param _songId The ID of the song
     * @return The audio URI of the song
     */
    function streamSong(uint256 _songId) external payable songExists(_songId) returns (string memory) {
        Song storage song = songs[_songId]; // retrieve the song from the mapping
        SongNFT songNFT = SongNFT(song.songNFTAddress); // retrieve the songNFT contract

        // If a user has already streamed the song, return the audioURI
        if(userHasNFT[_songId][msg.sender]) {
            return song.audioURI;
        } else {
            // If a user has not streamed the song, mint the NFT and set the userHasNFT mapping to true
            songNFT.mintNFT{value: msg.value}(msg.sender);
            userHasNFT[_songId][msg.sender] = true;
        }
        song.streamCount++;
        userStreams[msg.sender].push(_songId);

        emit SongStreamed(_songId, msg.sender);

        return song.audioURI;
    }

    /**
     * @notice Get all songs
     * @return An array of all songs
     */
    function getAllSongs() external view returns (Song[] memory) {
        Song[] memory allSongs = new Song[](songIds.length); // create an array of song Structs
        for(uint256 i = 0; i < songIds.length; i++) {
            allSongs[i] = songs[songIds[i]];
        }
        return allSongs; 
    }

    function getAllArtists() external view returns (Artist[] memory) {
        Artist[] memory allArtists = new Artist[](artistAddresses.length);
        for (uint256 i = 0; i < artistAddresses.length; i++) {
            allArtists[i] = artists[artistAddresses[i]];
        }
        return allArtists;
    }

    function getSongsByArtist(address _artist) external view returns (Song[] memory) {
        uint256[] memory artistSongIds = artistSongs[_artist];
        Song[] memory artistSongsArray = new Song[](artistSongIds.length);
        
        for (uint256 i = 0; i < artistSongIds.length; i++) {
            artistSongsArray[i] = songs[artistSongIds[i]];
        }
        return artistSongsArray;
    }

    function getSongsStreamedByUser(address _user) external view returns (Song[] memory) {
        uint256[] memory userStreamIds = userStreams[_user];
        Song[] memory userStreamedSongs = new Song[](userStreamIds.length);

        for (uint256 i = 0; i < userStreamIds.length; i++) {
            userStreamedSongs[i] = songs[userStreamIds[i]];
        }
        return userStreamedSongs;
    }
}
