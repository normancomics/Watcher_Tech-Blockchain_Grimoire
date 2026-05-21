`solidity`
`// Deploy`
`CipherAlphabet cipher = new CipherAlphabet();`

`// Mint letter NFTs for "ATTACK"`
`cipher.batchMintLetters(alice, [0, 19, 19, 0, 2, 10]);`
`// A, T, T, A, C, K`

`// Create encrypted message`
`bytes32 msgHash = keccak256(abi.encodePacked("ATTACK AT DAWN"));`
`uint256 msgId = cipher.createMessage(`
    `msgHash,`
    `[0, 19, 19, 0, 2, 10]  // Requires A, T, T, A, C, K`
`);`

`// Alice attempts decryption (owns required letters)`
`cipher.decryptMessage(msgId);`

`// Owner reveals plaintext`
`cipher.revealMessage(msgId, "ATTACK AT DAWN");`

`// Encode new message using current cipher`
`string memory encoded = cipher.encode("ATTACK AT DAWN");`
`// Returns: "DWWDFN DW GDZQ" (Caesar +3)`
