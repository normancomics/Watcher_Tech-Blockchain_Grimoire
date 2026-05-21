````solidity`
`// SPDX-License-Identifier: MIT`
`pragma solidity ^0.8.20;`

`import "@openzeppelin/contracts/token/ERC721/ERC721.sol";`
`import "@openzeppelin/contracts/access/Ownable.sol";`
`import "@openzeppelin/contracts/utils/Counters.sol";`

`/**`
 `* @title AngelicHierarchy`
 `* @dev Implements Pseudo-Dionysian nine-tier celestial hierarchy`
 `* as governance NFT system with hierarchical voting weights`
 `*/`
`contract AngelicHierarchy is ERC721, Ownable {`
    `using Counters for Counters.Counter;`
    
    `// Angel rank enumeration (9 orders)`
    `enum Rank {`
        `Angels,        // 1 - Closest to humanity`
        `Archangels,    // 2`
        `Principalities,// 3`
        `Powers,        // 4`
        `Virtues,       // 5`
        `Dominions,     // 6`
        `Thrones,       // 7`
        `Cherubim,      // 8`
        `Seraphim       // 9 - Closest to divine`
    `}`
    
    `// Planetary governors (7 classical planets)`
    `enum Planet {`
        `Luna,     // Monday`
        `Mars,     // Tuesday`
        `Mercury,  // Wednesday`
        `Jupiter,  // Thursday`
        `Venus,    // Friday`
        `Saturn,   // Saturday`
        `Sol       // Sunday`
    `}`
    
    `struct Angel {`
        `Rank rank;`
        `string name;`
        `Planet governor;`
        `bool soulBound; // Cannot be transferred once bound`
        `uint256 mintedAt;`
    `}`
    
    `// State variables`
    `Counters.Counter private _tokenIds;`
    `mapping(uint256 => Angel) public angels;`
    `mapping(address => uint256[]) public angelsByAddress;`
    
    `// Decree system for governance`
    `struct Decree {`
        `uint256 id;`
        `string description;`
        `uint256 votesFor;`
        `uint256 votesAgainst;`
        `uint256 createdAt;`
        `uint256 executionTime; // Time-lock`
        `bool executed;`
        `mapping(address => bool) hasVoted;`
    `}`
    
    `Counters.Counter private _decreeIds;`
    `mapping(uint256 => Decree) public decrees;`
    
    `// Events`
    `event AngelMinted(`
        `uint256 indexed tokenId,`
        `address indexed owner,`
        `Rank rank,`
        `string name`
    `);`
    `event DecreeCreated(uint256 indexed decreeId, string description);`
    `event DecreeVoted(uint256 indexed decreeId, address indexed voter, bool support);`
    `event DecreeExecuted(uint256 indexed decreeId);`
    
    `constructor() ERC721("AngelicHierarchy", "ANGEL") {}`
    
    `/**`
     `* @dev Mint new angel NFT`
     `* @param recipient Address receiving the angel`
     `* @param rank Hierarchical rank (0-8)`
     `* @param name Angel's name`
     `* @param governor Planetary governor assignment`
     `* @param soulBound Whether token is soul-bound (non-transferable)`
     `*/`
    `function mintAngel(`
        `address recipient,`
        `Rank rank,`
        `string memory name,`
        `Planet governor,`
        `bool soulBound`
    `) external onlyOwner returns (uint256) {`
        `_tokenIds.increment();`
        `uint256 newTokenId = _tokenIds.current();`
        
        `_safeMint(recipient, newTokenId);`
        
        `angels[newTokenId] = Angel({`
            `rank: rank,`
            `name: name,`
            `governor: governor,`
            `soulBound: soulBound,`
            `mintedAt: block.timestamp`
        `});`
        
        `angelsByAddress[recipient].push(newTokenId);`
        
        `emit AngelMinted(newTokenId, recipient, rank, name);`
        
        `return newTokenId;`
    `}`
    
    `/**`
     `* @dev Get voting weight based on hierarchical rank`
     `* @param tokenId Angel NFT ID`
     `* @return Voting weight (1-9)`
     `*/`
    `function getVotingWeight(uint256 tokenId) public view returns (uint256) {`
        `require(_exists(tokenId), "Angel does not exist");`
        `return uint256(angels[tokenId].rank) + 1; // Enum is 0-indexed`
    `}`
    
    `/**`
     `* @dev Get total voting power for an address`
     `* @param voter Address to check`
     `* @return Total voting weight across all angels`
     `*/`
    `function getVotingPower(address voter) public view returns (uint256) {`
        `uint256[] memory ownedAngels = angelsByAddress[voter];`
        `uint256 totalPower = 0;`
        
        `for (uint256 i = 0; i < ownedAngels.length; i++) {`
            `if (ownerOf(ownedAngels[i]) == voter) {`
                `totalPower += getVotingWeight(ownedAngels[i]);`
            `}`
        `}`
        
        `return totalPower;`
    `}`
    
    `/**`
     `* @dev Create new decree (governance proposal)`
     `* @param description Decree description`
     `* @param timeLock Delay before execution (seconds)`
     `*/`
    `function createDecree(`
        `string memory description,`
        `uint256 timeLock`
    `) external returns (uint256) {`
        `require(getVotingPower(msg.sender) > 0, "No voting power");`
        
        `_decreeIds.increment();`
        `uint256 decreeId = _decreeIds.current();`
        
        `Decree storage newDecree = decrees[decreeId];`
        `newDecree.id = decreeId;`
        `newDecree.description = description;`
        `newDecree.createdAt = block.timestamp;`
        `newDecree.executionTime = block.timestamp + timeLock;`
        `newDecree.executed = false;`
        
        `emit DecreeCreated(decreeId, description);`
        
        `return decreeId;`
    `}`
    
    `/**`
     `* @dev Vote on decree`
     `* @param decreeId Decree to vote on`
     `* @param support True for yes, false for no`
     `*/`
    `function voteOnDecree(uint256 decreeId, bool support) external {`
        `Decree storage decree = decrees[decreeId];`
        `require(!decree.executed, "Already executed");`
        `require(!decree.hasVoted[msg.sender], "Already voted");`
        
        `uint256 votingPower = getVotingPower(msg.sender);`
        `require(votingPower > 0, "No voting power");`
        
        `if (support) {`
            `decree.votesFor += votingPower;`
        `} else {`
            `decree.votesAgainst += votingPower;`
        `}`
        
        `decree.hasVoted[msg.sender] = true;`
        
        `emit DecreeVoted(decreeId, msg.sender, support);`
    `}`
    
    `/**`
     `* @dev Execute decree after time-lock expires`
     `* @param decreeId Decree to execute`
     `*/`
    `function executeDecree(uint256 decreeId) external {`
        `Decree storage decree = decrees[decreeId];`
        `require(!decree.executed, "Already executed");`
        `require(`
            `block.timestamp >= decree.executionTime,`
            `"Time-lock not expired"`
        `);`
        `require(`
            `decree.votesFor > decree.votesAgainst,`
            `"Insufficient votes"`
        `);`
        
        `decree.executed = true;`
        
        `emit DecreeExecuted(decreeId);`
        
        `// Actual execution logic would go here`
    `}`
    
    `/**`
     `* @dev Override transfer to enforce soul-bound property`
     `*/`
    `function _transfer(`
        `address from,`
        `address to,`
        `uint256 tokenId`
    `) internal virtual override {`
        `require(`
            `!angels[tokenId].soulBound,`
            `"Soul-bound angels cannot be transferred"`
        `);`
        `super._transfer(from, to, tokenId);`
    `}`
    
    `/**`
     `* @dev Get angels by planetary governor`
     `* @param planet Planetary governor to query`
     `* @return Array of token IDs`
     `*/`
    `function getAngelsByPlanet(Planet planet)`
        `external`
        `view`
        `returns (uint256[] memory)`
    `{`
        `uint256 count = 0;`
        `uint256 total = _tokenIds.current();`
        
        `// Count matching angels`
        `for (uint256 i = 1; i <= total; i++) {`
            `if (angels[i].governor == planet) {`
                `count++;`
            `}`
        `}`
        
        `// Populate array`
        `uint256[] memory result = new uint256[](count);`
        `uint256 index = 0;`
        
        `for (uint256 i = 1; i <= total; i++) {`
            `if (angels[i].governor == planet) {`
                `result[index] = i;`
                `index++;`
            `}`
        `}`
        
        `return result;`
    `}`
`}`
