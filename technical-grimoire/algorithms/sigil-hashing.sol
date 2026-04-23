// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SigilHashing
 * @notice Symbolic input → deterministic output hash function
 * @dev Implements a Solidity hash function that accepts symbolic/esoteric
 *      inputs (planetary sigils, elemental symbols, gematria values)
 *      and produces deterministic, reproducible cryptographic outputs.
 *
 * Esoteric Framework:
 *   - Planetary Sigils: Each planet has a classical sigil used in ceremonial magic
 *   - Elemental Symbols: Fire, Water, Air, Earth as computational modifiers
 *   - Gematria: Hebrew numerological values as hash seeds
 *   - Kamea (Magic Squares): Planetary number squares as transformation matrices
 *
 * References:
 *   - Heinrich Cornelius Agrippa, Three Books of Occult Philosophy (1531)
 *   - Francis Barrett, The Magus (1801)
 *   - rosicrucian-cryptography.md (steganographic traditions)
 */

// ─── Planetary Sigil Enum ────────────────────────────────────────────────────

enum Planet {
    Saturn,   // ♄ — contraction, limitation, time
    Jupiter,  // ♃ — expansion, abundance, wisdom
    Mars,     // ♂ — action, conflict, energy
    Sun,      // ☉ — identity, authority, illumination
    Venus,    // ♀ — harmony, value, attraction
    Mercury,  // ☿ — communication, commerce, intellect
    Moon      // ☽ — reflection, emotion, cyclical change
}

enum Element {
    Fire,     // △ — transformation, energy, will
    Water,    // ▽ — emotion, flow, intuition
    Air,      // △̄ — intellect, communication, movement
    Earth     // ▽̄ — material, stability, foundation
}

// ─── Planetary Kamea (Magic Square) Constants ────────────────────────────────

/**
 * @notice Magic square constants for each planet
 * @dev Each planet's kamea has: order, magic constant (row/col/diag sum)
 *      Saturn: 3×3, sum=15
 *      Jupiter: 4×4, sum=34
 *      Mars: 5×5, sum=65
 *      Sun: 6×6, sum=111
 *      Venus: 7×7, sum=175
 *      Mercury: 8×8, sum=260
 *      Moon: 9×9, sum=369
 */
library PlanetaryKamea {
    function getMagicConstant(Planet planet) internal pure returns (uint256) {
        if (planet == Planet.Saturn)  return 15;
        if (planet == Planet.Jupiter) return 34;
        if (planet == Planet.Mars)    return 65;
        if (planet == Planet.Sun)     return 111;
        if (planet == Planet.Venus)   return 175;
        if (planet == Planet.Mercury) return 260;
        if (planet == Planet.Moon)    return 369;
        revert("Unknown planet");
    }

    function getOrder(Planet planet) internal pure returns (uint256) {
        if (planet == Planet.Saturn)  return 3;
        if (planet == Planet.Jupiter) return 4;
        if (planet == Planet.Mars)    return 5;
        if (planet == Planet.Sun)     return 6;
        if (planet == Planet.Venus)   return 7;
        if (planet == Planet.Mercury) return 8;
        if (planet == Planet.Moon)    return 9;
        revert("Unknown planet");
    }
}

// ─── Elemental Modifiers ─────────────────────────────────────────────────────

library ElementalModifier {
    /**
     * @notice Apply elemental transformation to a hash
     * @dev Each element modifies the hash in a distinct, deterministic way:
     *   Fire:  XOR with the hash of "fire" → transformation
     *   Water: Bitwise rotation right by 8 → flow
     *   Air:   Bitwise rotation left by 16 → movement
     *   Earth: AND with stability mask → grounding
     */
    function apply(bytes32 inputHash, Element element) 
        internal 
        pure 
        returns (bytes32) 
    {
        if (element == Element.Fire) {
            // Fire transforms: XOR with fire-seed
            bytes32 fireSeed = keccak256(abi.encodePacked("FIRE_ELEMENT_IGNIS"));
            return inputHash ^ fireSeed;
        }
        
        if (element == Element.Water) {
            // Water flows: rotate right by 8 bits
            return bytes32(
                (uint256(inputHash) >> 8) | (uint256(inputHash) << 248)
            );
        }
        
        if (element == Element.Air) {
            // Air moves: rotate left by 16 bits
            return bytes32(
                (uint256(inputHash) << 16) | (uint256(inputHash) >> 240)
            );
        }
        
        if (element == Element.Earth) {
            // Earth grounds: AND with stability mask (clears high bits)
            uint256 stabilityMask = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            return bytes32(uint256(inputHash) & stabilityMask);
        }
        
        revert("Unknown element");
    }
}

// ─── Gematria Encoder ─────────────────────────────────────────────────────────

library GematriaEncoder {
    /**
     * @notice Compute the gematria value of a string
     * @dev Implements standard Hebrew gematria (Mispar Gadol)
     *      Maps ASCII letters to their Hebrew letter equivalents
     *      Non-alphabetic characters contribute 0
     *
     * Note: This is a simplified ASCII→Hebrew mapping for demonstration.
     *       Full implementation in gematria-encoding.ts (TypeScript layer)
     */
    function computeValue(string memory word) internal pure returns (uint256) {
        bytes memory wordBytes = bytes(word);
        uint256 total = 0;
        
        for (uint256 i = 0; i < wordBytes.length; i++) {
            uint8 char = uint8(wordBytes[i]);
            total += _letterValue(char);
        }
        
        return total;
    }
    
    function _letterValue(uint8 char) private pure returns (uint256) {
        // A-Z mapping to approximate Hebrew gematria values
        if (char >= 65 && char <= 90) {
            // Uppercase A-Z
            uint8 idx = char - 65;
            return _hebrewValue(idx);
        }
        if (char >= 97 && char <= 122) {
            // Lowercase a-z
            uint8 idx = char - 97;
            return _hebrewValue(idx);
        }
        return 0;
    }
    
    function _hebrewValue(uint8 idx) private pure returns (uint256) {
        // Aleph=1 through Tav=400 (simplified 26-letter mapping)
        uint256[26] memory values = [
            uint256(1),   // A → Aleph
            uint256(2),   // B → Bet
            uint256(3),   // C → Gimel
            uint256(4),   // D → Dalet
            uint256(5),   // E → Hey
            uint256(6),   // F → Vav
            uint256(7),   // G → Zayin
            uint256(8),   // H → Chet
            uint256(9),   // I → Tet
            uint256(10),  // J → Yod
            uint256(20),  // K → Kaf
            uint256(30),  // L → Lamed
            uint256(40),  // M → Mem
            uint256(50),  // N → Nun
            uint256(60),  // O → Samech
            uint256(70),  // P → Ayin
            uint256(80),  // Q → Pey
            uint256(90),  // R → Tzadi
            uint256(100), // S → Kuf
            uint256(200), // T → Resh
            uint256(300), // U → Shin
            uint256(400), // V → Tav
            uint256(500), // W → Final Kaf
            uint256(600), // X → Final Mem
            uint256(700), // Y → Final Nun
            uint256(800)  // Z → Final Pey
        ];
        
        if (idx < 26) return values[idx];
        return 0;
    }
}

// ─── Main SigilHashing Contract ───────────────────────────────────────────────

contract SigilHashing {
    using PlanetaryKamea for Planet;
    using ElementalModifier for bytes32;
    using GematriaEncoder for string;
    
    // ─── Events ──────────────────────────────────────────────────────────────
    
    event SigilComputed(
        address indexed caller,
        bytes32 indexed sigilHash,
        Planet planet,
        Element element,
        uint256 gematriaValue,
        uint256 timestamp
    );
    
    // ─── Core Hash Functions ──────────────────────────────────────────────────
    
    /**
     * @notice Compute a sigil hash from symbolic inputs
     * @param symbolName The name of the symbol (word, name, or phrase)
     * @param planet The ruling planet for this sigil
     * @param element The elemental modifier
     * @return sigilHash The deterministic symbolic hash output
     *
     * Example:
     *   computeSigilHash("ETHEREUM", Planet.Mercury, Element.Air)
     *   → deterministic hash incorporating all symbolic layers
     */
    function computeSigilHash(
        string calldata symbolName,
        Planet planet,
        Element element
    ) external returns (bytes32 sigilHash) {
        sigilHash = _buildSigilHash(symbolName, planet, element);
        
        emit SigilComputed(
            msg.sender,
            sigilHash,
            planet,
            element,
            symbolName.computeValue(),
            block.timestamp
        );
    }
    
    /**
     * @notice View function — compute sigil hash without emitting event
     */
    function viewSigilHash(
        string calldata symbolName,
        Planet planet,
        Element element
    ) external pure returns (bytes32) {
        return _buildSigilHash(symbolName, planet, element);
    }
    
    /**
     * @notice Compute hash from raw gematria value and planetary constant
     * @dev Useful when the symbolic value is already computed off-chain
     */
    function hashFromGematria(
        uint256 gematriaValue,
        Planet planet,
        Element element
    ) external pure returns (bytes32 sigilHash) {
        uint256 magicConstant = planet.getMagicConstant();
        uint256 kameasOrder   = planet.getOrder();
        
        // Step 1: Bind gematria to planetary square
        bytes32 planetaryBinding = keccak256(
            abi.encodePacked(gematriaValue * magicConstant, kameasOrder)
        );
        
        // Step 2: Apply elemental transformation
        sigilHash = planetaryBinding.apply(element);
    }
    
    // ─── Composite Sigil Functions ────────────────────────────────────────────
    
    /**
     * @notice Combine multiple sigils into a compound hash
     * @dev Used for multi-symbol ritual construction
     */
    function compoundSigil(
        bytes32[] calldata sigilHashes
    ) external pure returns (bytes32) {
        require(sigilHashes.length > 0, "No sigils provided");
        
        bytes32 compound = sigilHashes[0];
        for (uint256 i = 1; i < sigilHashes.length; i++) {
            compound = keccak256(abi.encodePacked(compound, sigilHashes[i]));
        }
        
        return compound;
    }
    
    /**
     * @notice Verify that a sigil hash matches given symbolic inputs
     * @dev Enables zero-knowledge verification of symbolic knowledge
     */
    function verifySigil(
        bytes32 claimedHash,
        string calldata symbolName,
        Planet planet,
        Element element
    ) external pure returns (bool) {
        bytes32 expectedHash = _buildSigilHash(symbolName, planet, element);
        return claimedHash == expectedHash;
    }
    
    // ─── Internal Helpers ─────────────────────────────────────────────────────
    
    function _buildSigilHash(
        string calldata symbolName,
        Planet planet,
        Element element
    ) internal pure returns (bytes32) {
        // Step 1: Compute gematria value of the symbol name
        uint256 gematriaValue = symbolName.computeValue();
        
        // Step 2: Get planetary magic square constants
        uint256 magicConstant = planet.getMagicConstant();
        uint256 kameasOrder   = planet.getOrder();
        
        // Step 3: Initial hash — symbol + planetary binding
        bytes32 baseHash = keccak256(
            abi.encodePacked(
                symbolName,
                gematriaValue,
                magicConstant,
                kameasOrder,
                uint256(planet)
            )
        );
        
        // Step 4: Apply elemental transformation
        bytes32 elementalHash = baseHash.apply(element);
        
        // Step 5: Final seal — bind all inputs together
        return keccak256(
            abi.encodePacked(elementalHash, uint256(element), gematriaValue)
        );
    }
}
