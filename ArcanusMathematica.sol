// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:dev-run-script ./scripts/deploy.js
contract ArcanusMathematica is ERC721, Ownable {
    uint256 public tokenIdCounter;
    uint256 public mintPrice = 0.033 ether;

    string public constant GRIMOIRE_TITLE = "ARCANUS MATHEMATICA";
    string public constant GRIMOIRE_METADATA = "Occult and apocryphal revelations concerning non-human entities teaching mankind the arts of mathematics, geometry, mensuration, astronomy, and sacred calculations. Compiled from the Book of Enoch, Zohar, Testament of Solomon, and Solomonic Grimoires. Preserved as a permanent immutable blockchain grimoire.";

    error InsufficientETH();

    constructor() ERC721("ArcanusMathematica", "ARCMATH") Ownable(msg.sender) {}

    function mintGrimoire(address to) public onlyOwner {
        uint256 tokenId = tokenIdCounter++;
        _safeMint(to, tokenId);
    }

    function publicMint() public payable {
        if (msg.value < mintPrice) revert InsufficientETH();
        uint256 tokenId = tokenIdCounter++;
        _safeMint(msg.sender, tokenId);
    }

    function setMintPrice(uint256 _newPrice) public onlyOwner {
        mintPrice = _newPrice;
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        payable(owner()).transfer(amount);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "ipfs://QmArcanusMathematicaFullGrimoireHash";
    }
}