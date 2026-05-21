`solidity`
// Deploy
PlanetaryOracle oracle = new PlanetaryOracle();

// Check current planetary hour
(uint256 hour, PlanetaryOracle.Planet governor) = 
    oracle.getCurrentPlanetaryHour();
// Returns: (14, Planet.Mars) = 2 PM on Tuesday

// Lock data with Saturn time-lock (7 days)
bytes32 commitment = keccak256(abi.encodePacked("SECRET"));
uint256 dataId = oracle.lockData(
    commitment,
    PlanetaryOracle.Planet.Saturn
);

// Wait 7 days...

// Reveal data
oracle.revealData(dataId, bytes("SECRET"));

// Retrieve data
bytes memory data = oracle.getData(dataId);

