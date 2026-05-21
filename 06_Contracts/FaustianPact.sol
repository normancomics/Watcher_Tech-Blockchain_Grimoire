{ address public faust; address public mephistopheles; uint256 public pactDuration = 24 * 365 days; uint256 public pactStart;

`struct Terms {`
    `bool knowledgeProvided;`
    `bool powerGranted;`
    `bool soulClaimed;`
`}`

`Terms public terms;`

`constructor(address _faust, address _mephistopheles) {`
    `faust = _faust;`
    `mephistopheles = _mephistopheles;`
    `pactStart = block.timestamp;`
`}`

`function provideKnowledge() external {`
    `require(msg.sender == mephistopheles, "Only demon");`
    `terms.knowledgeProvided = true;`
`}`

`function grantPower() external {`
    `require(msg.sender == mephistopheles, "Only demon");`
    `terms.powerGranted = true;`
`}`

`function claimSoul() external {`
    `require(msg.sender == mephistopheles, "Only demon");`
    `require(block.timestamp >= pactStart + pactDuration, "Not yet");`
    `terms.soulClaimed = true;`
    `// Soul transfer logic`
`}`

