{ address public conjurer; uint256 public bindingExpiration;

`modifier onlyAuthorizedConjurer() {`
    `require(hasCorrectSeal(msg.sender), "Invalid seal");`
    `require(isPlanetaryHourCorrect(), "Wrong hour");`
    `_;`
`}`

`function invoke(string memory request)` 
    `public` 
    `onlyAuthorizedConjurer` 
    `returns (string memory)` 
`{`
    `// Execute request`
    `// Return result`
    `// Update state`
`}`

`function dismiss() public {`
    `require(msg.sender == conjurer, "Unauthorized");`
    `// Terminate binding`
    `// Return to infernal hierarchy`
`}`

}