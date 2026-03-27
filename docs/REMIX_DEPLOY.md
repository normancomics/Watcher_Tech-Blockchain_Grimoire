# ⛧ Deploying the Watcher Tech Blockchain Grimoire NFT via Remix

```
╔══════════════════════════════════════════════════════════════╗
║   ⛧  WATCHER TECH BLOCKCHAIN GRIMOIRE — REMIX DEPLOY GUIDE  ║
║        normancomics.eth  ·  0.033 ETH/mint  ·  333 max       ║
╚══════════════════════════════════════════════════════════════╝
```

This guide walks you through deploying `WatcherTechGrimoireNFT.sol` on
[remix.ethereum.org](https://remix.ethereum.org) so anyone on Ethereum can
find and mint a Grimoire edition for **0.033 ETH**.

---

## Part 1 — Prepare Your Metadata (IPFS / Arweave)

Before deploying, you need a **base URI** pointing to your NFT metadata JSON files.

### Option A — Upload to IPFS via Pinata or NFT.Storage

1. Create a folder named `metadata/` on your computer.
2. For each token (0–332) create a JSON file named `0.json`, `1.json`, etc.

   ```json
   {
     "name": "Watcher Tech Blockchain Grimoire #0",
     "description": "An on-chain grimoire reverse-engineering antediluvian Watcher transmissions into modern blockchain, DeFi, AI, and quantum frameworks. Compiled from the Book of Enoch, Zohar, Testament of Solomon, and Solomonic Grimoires.",
     "image": "ipfs://YOUR_IMAGE_CID",
     "external_url": "https://github.com/normancomics/Watcher_Tech-Blockchain_Grimoire",
     "attributes": [
       { "trait_type": "Author",     "value": "normancomics.eth" },
       { "trait_type": "Edition",    "value": "1 of 333" },
       { "trait_type": "Year",       "value": "2026" },
       { "trait_type": "Grimoire",   "value": "Watcher Tech Blockchain Grimoire" },
       { "trait_type": "Chain",      "value": "Ethereum Mainnet" },
       { "trait_type": "Price",      "value": "0.033 ETH" }
     ]
   }
   ```

3. Upload the folder to [Pinata](https://pinata.cloud) or [NFT.Storage](https://nft.storage).
4. Note the CID — your **base URI** will be `ipfs://<CID>/`
   (e.g. `ipfs://QmYourCIDHere/`).

---

## Part 2 — Open Remix and Load the Contract

```
  ┌──────────────────────────────────────────────────────┐
  │  1. Go to https://remix.ethereum.org                 │
  │  2. In the File Explorer (left panel) click the      │
  │     "+" icon to create a new file.                   │
  │  3. Name it: WatcherTechGrimoireNFT.sol              │
  │  4. Paste the full contents of                       │
  │     contracts/WatcherTechGrimoireNFT.sol             │
  │     into the editor.                                 │
  └──────────────────────────────────────────────────────┘
```

Remix's built-in OpenZeppelin plugin resolves all `@openzeppelin/contracts`
imports automatically — **no npm install needed**.

---

## Part 3 — Compile

```
  ┌──────────────────────────────────────────────────────┐
  │  1. Click the "Solidity Compiler" icon (left panel). │
  │  2. Compiler version: 0.8.20                         │
  │  3. Enable "Optimization" → 200 runs.                │
  │  4. Click "Compile WatcherTechGrimoireNFT.sol".      │
  │  5. Green ✓ = success.                               │
  └──────────────────────────────────────────────────────┘
```

---

## Part 4 — Deploy to Ethereum Mainnet

```
  ┌──────────────────────────────────────────────────────┐
  │  1. Click the "Deploy & Run Transactions" icon.      │
  │                                                      │
  │  2. ENVIRONMENT:                                     │
  │       → Injected Provider — MetaMask                 │
  │     Make sure MetaMask is on Ethereum Mainnet.       │
  │                                                      │
  │  3. CONTRACT: WatcherTechGrimoireNFT                 │
  │                                                      │
  │  4. CONSTRUCTOR ARGUMENT — BASEURI:                  │
  │     Paste your IPFS base URI in the field:           │
  │       ipfs://QmYourCIDHere/                          │
  │     (include the trailing slash)                     │
  │                                                      │
  │  5. Click "Deploy" and confirm in MetaMask.          │
  │     Gas estimate: ~1.5–2M gas (~$10–40 at 2026 ETH)  │
  └──────────────────────────────────────────────────────┘
```

> **Save your contract address** once deployed — you'll need it for
> OpenSea, aggregators, and your front end.

---

## Part 5 — Mint Your First Token

In the **Deployed Contracts** panel, expand your contract and call:

```
  publicMint()   value: 0.033 ETH   → click "transact"
```

This mints token #0 to your wallet.

---

## Part 6 — List on OpenSea / Aggregators

1. Go to [opensea.io/asset/ethereum/<YOUR_CONTRACT_ADDRESS>/0](https://opensea.io)
   and click **"Edit"** to add a collection name, description, and banner image.
2. Set collection name: **"Watcher Tech Blockchain Grimoire"**
3. Add the GitHub repo link in the description:
   `https://github.com/normancomics/Watcher_Tech-Blockchain_Grimoire`
4. Upload the grimoire sigil image as the collection logo/banner.
5. The contract's ERC-2981 on-chain royalty (6.66%) will be automatically
   respected by OpenSea and compatible marketplaces.

---

## Part 7 — Verify on Etherscan

1. In Remix: **Plugin Manager** → enable **"Etherscan - Contract Verification"**.
2. Paste your Etherscan API key.
3. Click **"Verify & Publish"** — this makes your source code publicly
   readable on Etherscan so buyers can trust the contract.

---

## Contract Summary

```
╔══════════════════════════════════════════════════════════════╗
║  Contract     WatcherTechGrimoireNFT                         ║
║  Symbol       WTGRIM                                         ║
║  Standard     ERC-721 + ERC-2981 (royalties)                 ║
║  Max Supply   333 editions                                   ║
║  Mint Price   0.033 ETH (owner-adjustable)                   ║
║  Royalties    6.66 % on secondary sales (on-chain ERC-2981)  ║
║  Author       normancomics.eth                               ║
╚══════════════════════════════════════════════════════════════╝
```

### Key Functions

| Function | Who | Description |
|---|---|---|
| `publicMint()` | Anyone | Mint 1 token for 0.033 ETH |
| `ownerMint(to)` | Owner | Gift-mint to any address |
| `withdraw()` | Owner | Pull all ETH to owner wallet |
| `setMintPrice(price)` | Owner | Update the mint price |
| `setBaseURI(uri)` | Owner | Update metadata base URI |
| `setDefaultRoyalty(addr, bps)` | Owner | Change royalty recipient/rate |
| `addAlwaysFreeMinter(addr)` | Owner | Grant unlimited free mints |
| `addOneTimeFreeMinter(addr)` | Owner | Grant one-time free mint |
| `grimoireInfo()` | Anyone | On-chain title/author/lore strings |
| `tokenURI(tokenId)` | Anyone | Returns metadata URI for a token |
| `totalSupply()` | Anyone | Current number of minted tokens |

---

## Testnet Trial Run (Recommended Before Mainnet)

Deploy first on **Sepolia testnet** to verify everything works:

1. In MetaMask, switch network to **Sepolia**.
2. Get free Sepolia ETH from [sepoliafaucet.com](https://sepoliafaucet.com).
3. In Remix → **Environment: Injected Provider (Sepolia)**.
4. Deploy with a test URI (e.g. `https://example.com/test/`).
5. Call `publicMint()` with 0.033 ETH — confirm token is minted.
6. Verify on [sepolia.etherscan.io](https://sepolia.etherscan.io).
7. When satisfied, repeat on Mainnet.

---

```
⛧  The Grimoire is sealed. The Words are on-chain. The Knowledge is immutable.

    "They taught men to make swords… and the art of making bracelets and
     ornaments… and all kinds of costly stones and all colouring tinctures.
     And there arose much godlessness."  — 1 Enoch 8
```
