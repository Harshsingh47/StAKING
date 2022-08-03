// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ERC721.sol";

interface Token {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (uint256);    
}

contract Staking  {
    
    // boolean to prevent reentrancy
    bool internal locked;

    // Library usage
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    

    // Contract owner
    address public owner;

    // Reward token 
    uint public interestRate = 5;

    // Penalty if user unstake token before the given timePeriod
    uint public penaltyRate = 10;

    // Timestamp related variables
    uint256 public initialTimestamp;
    bool public timestampSet;
    uint256 public timePeriod;
   
     struct StakeInfo {        
        uint256 amount; 
        uint256 claimed;       
    }


    // Token amount variables
    mapping(address => uint256) public alreadyWithdrawn;
    mapping(address => uint256) public balances;
    mapping(address => bool) public addressStaked;
    mapping(address => StakeInfo) public stakeInfos;


    uint256 public contractBalance;

    // ERC20 contract address
    Token public erc20Token;

    // Events
    event tokensStaked(address from, uint256 amount);
    event TokensUnstaked(address to, uint256 amount);
    event interestClaimed(address indexed from, uint256 amount);
    event penaltyClaimed(address indexed from, uint256 amount);

    /// Deploys contract and links the ERC20 token which we are staking, also sets owner as msg.sender and sets timestampSet bool to false.
    // _erc20_contract_address.
    constructor(Token _erc20_contract_address) {
        // Set contract owner
        owner = msg.sender;
        // Timestamp values not set yet
        timestampSet = false;
        // Set the erc20 contract address which this timelock is deliberately paired to
        require(address(_erc20_contract_address) != address(0), "_erc20_contract_address address can not be zero");
        erc20Token = _erc20_contract_address;
        // Initialize the reentrancy variable to not locked
        locked = false;
    }

    // Modifier
    /**
     * @dev Prevents reentrancy
     */
    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    // Modifier
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Message sender must be the contract's owner.");
        _;
    }

    // Modifier
    /**
     * @dev Throws if timestamp already set.
     */
    modifier timestampNotSet() {
        require(timestampSet == false, "The time stamp has already been set.");
        _;
    }

    // Modifier
    /**
     * @dev Throws if timestamp not set.
     */
    modifier timestampIsSet() {
        require(timestampSet == true, "Please set the time stamp first, then try again.");
        _;
    }

  
    function setTimestamp() public onlyOwner timestampNotSet  {
        timestampSet = true;
        initialTimestamp = block.timestamp;
        timePeriod = initialTimestamp.add(200);
    }

    function claimReward() internal returns (bool){
        require(addressStaked[msg.sender] == true, "You are not participated");
        require(block.timestamp >= timePeriod, "Stake Time is not over yet");
        require(stakeInfos[msg.sender].claimed == 0, "Already claimed");

        uint256 stakeAmount = stakeInfos[msg.sender].amount;
        uint256 totalTokens = stakeAmount + (stakeAmount * interestRate / 100);
        stakeInfos[msg.sender].claimed == totalTokens;
        erc20Token.transfer(msg.sender, totalTokens);

        emit interestClaimed(msg.sender, totalTokens);

        return true;
    }

    function penalty() internal returns (bool) {
        require(addressStaked[msg.sender] == true, "You are not participated");
        require(block.timestamp < timePeriod, "Stake Time is over");

        uint256 stakeAmount = stakeInfos[msg.sender].amount;
        uint256 totalTokens = stakeAmount - (stakeAmount * penaltyRate / 100);
        alreadyWithdrawn[msg.sender] = alreadyWithdrawn[msg.sender].add(totalTokens);
        // erc20Token.transfer(msg.sender, totalTokens);
        emit penaltyClaimed(msg.sender, totalTokens);

        return true;
    }

    /// @dev Allows the contract owner to allocate official ERC20 tokens to each future recipient (only one at a time).
    /// @param token, the official ERC20 token which this contract exclusively accepts.
    /// @param amount to allocate to recipient.
    function stakeTokens(address _nft, uint _tokenId, string memory _tokenUri, Token token, uint256 amount) public timestampIsSet noReentrant {
        require(token == erc20Token, "You are only allowed to stake the official erc20 token address which was passed into this contract's constructor");
        require(amount <= token.balanceOf(msg.sender), "Not enough STATE tokens in your wallet, please try lesser amount");
        require(addressStaked[msg.sender] == false, "You already participated");
        token.transferFrom(msg.sender, address(this), amount);
        addressStaked[msg.sender] = true;
        balances[msg.sender] = balances[msg.sender].add(amount);

        NFT _nftContract = NFT(_nft);
        _nftContract.safeMint(msg.sender, _tokenId, _tokenUri);
        stakeInfos[msg.sender] = StakeInfo({                
                amount: amount,
                claimed: 0
            });
        emit tokensStaked(msg.sender, amount);
    }

    
    function unstakeTokens(address _nft, uint tokenId, Token token, uint256 amount) public timestampIsSet noReentrant {
        require(balances[msg.sender] >= amount, "Insufficient token balance, try lesser amount");
        require(token == erc20Token, "Token parameter must be the same as the erc20 contract address which was passed into the constructor");
        NFT _nftContract = NFT(_nft);
        if(block.timestamp < timePeriod) {
            balances[msg.sender] = balances[msg.sender].sub(amount);
            require(_nftContract.ownerOf(tokenId) == msg.sender,"You are not the owner");
            penalty();
            _nftContract.burn(tokenId);
            emit TokensUnstaked(msg.sender, amount);
        }
        else if (block.timestamp >= timePeriod) {
            balances[msg.sender] = balances[msg.sender].add(amount);
            require(_nftContract.ownerOf(tokenId) == msg.sender,"You are not the owner");
            _nftContract.burn(tokenId);
            claimReward();
        
            emit TokensUnstaked(msg.sender, amount);
        } else {
            revert("Tokens are only available after correct time period has elapsed");
        }
    }

}