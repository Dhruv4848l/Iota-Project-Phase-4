# IOTA Manufacturing Digital Product Passport (DPP)

[![CI](https://github.com/Dhruv4848l/Iota-Project-Phase-4/actions/workflows/test.yml/badge.svg)](https://github.com/Dhruv4848l/Iota-Project-Phase-4/actions/workflows/test.yml)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.33-informational?logo=solidity)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://book.getfoundry.sh/)
[![Deployed](https://img.shields.io/badge/Contract-Deployed-brightgreen)](https://sepolia.etherscan.io/address/0xc6e9D390Ba802079eb1e7d4399F4d38daF97A5f8)
[![Frontend](https://img.shields.io/badge/Frontend-Live-blueviolet)](https://iota-dpp.vercel.app)

> 🚀 **Deployed Contract Address:** `0xc6e9D390Ba802079eb1e7d4399F4d38daF97A5f8`
> 🔗 **Network:** Ethereum Sepolia Testnet | **Chain ID:** 11155111
> 📋 **Explorer:** [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xc6e9D390Ba802079eb1e7d4399F4d38daF97A5f8)
> 🌐 **Live Frontend:** [iota-dpp.vercel.app](https://iota-dpp.vercel.app)

A **blockchain-based Digital Product Passport (DPP)** system built on the IOTA EVM, designed for investment casting foundries supplying safety-critical aerospace components (e.g., turbine blades). Each physical part or piece of equipment is represented as an ERC-721 NFT, carrying a complete, tamper-proof lifecycle record from manufacture through end-of-life.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Smart Contract: ManufacturingDPP](#smart-contract-manufacturingdpp)
  - [Roles & Access Control](#roles--access-control)
  - [Lifecycle Stages](#lifecycle-stages)
  - [Key Functions](#key-functions)
  - [Events (On-chain Audit Trail)](#events-on-chain-audit-trail)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
  - [Clone the Repository](#clone-the-repository)
  - [Install Dependencies](#install-dependencies)
  - [Build](#build)
  - [Run Tests](#run-tests)
  - [Format Code](#format-code)
  - [Deploy](#deploy)
- [IOTA Notarization](#iota-notarization)
- [IPFS Metadata](#ipfs-metadata)
- [CI/CD](#cicd)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

The **ManufacturingDPP** contract provides an immutable, on-chain record for every aerospace part produced at an investment casting foundry. Key capabilities:

| Feature | Description |
|---|---|
| **ERC-721 NFT** | Each part/equipment is a unique, transferable token |
| **Role-Based Access Control** | Only authorised stakeholders can write data at each stage |
| **Hierarchical Part Trees** | Parent equipment tokens link to child sub-part tokens |
| **Dynamic IPFS Metadata** | Off-chain JSON updated via IPFS at every lifecycle transition |
| **IOTA Notarization Anchoring** | Every state change references an IOTA notarization hash for off-chain verification |
| **Immutable Event Audit Log** | All significant actions emit events permanently stored on-chain |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  IOTA EVM (Layer 1)                     │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │           ManufacturingDPP.sol (ERC-721)         │   │
│  │                                                  │   │
│  │  ┌─────────┐  ┌──────────┐  ┌─────────────────┐ │   │
│  │  │ ERC-721 │  │AccessCtrl│  │  Lifecycle FSM  │ │   │
│  │  └─────────┘  └──────────┘  └─────────────────┘ │   │
│  │                                                  │   │
│  │  Token Hierarchy:                                │   │
│  │  Equipment (parent) ──▶ Part(s) (children)       │   │
│  └──────────────────────────────────────────────────┘   │
│                       │                                  │
│              Events anchor to                            │
│                       │                                  │
│  ┌────────────────────▼─────────────────────────────┐   │
│  │         IOTA Notarization Layer                  │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
          │
          │  tokenUris[] → IPFS CID
          ▼
┌─────────────────────┐
│   IPFS / Filecoin   │  (Dynamic JSON metadata per token)
└─────────────────────┘
```

---

## Smart Contract: ManufacturingDPP

**File:** [`src/ManufacturingDPP.sol`](src/ManufacturingDPP.sol)  
**Solidity Version:** `0.8.33`  
**Token Standard:** ERC-721 (OpenZeppelin)  
**Access Control:** OpenZeppelin `AccessControl`  
**Token Name / Symbol:** `IOTA Manufacturing DPP` / `DPP`

### Roles & Access Control

| Role | Constant | Description |
|---|---|---|
| `ADMIN_ROLE` | `keccak256("ADMIN_ROLE")` | Super-admin (foundry owner / consortium admin). Can assign/revoke all roles, mint tokens, and override any stage. Granted to deployer at construction. |
| `FOUNDRY_ROLE` | `keccak256("FOUNDRY_ROLE")` | Investment casting foundry operators. Write access during Manufacturing & Inspection stage. |
| `MACHINING_ROLE` | `keccak256("MACHINING_ROLE")` | External machining/finishing vendors. Write access during Assembly & Integration stage. |
| `OEM_ROLE` | `keccak256("OEM_ROLE")` | Original Equipment Manufacturer. Manages token during Operation & Usage stage and authorises handoff to MRO. |
| `MRO_ROLE` | `keccak256("MRO_ROLE")` | Maintenance, Repair & Overhaul providers. Write access during Maintenance & End-of-Life stages. |

> All roles are administered by `ADMIN_ROLE`. The deployer automatically receives `ADMIN_ROLE` at construction.

### Lifecycle Stages

Parts progress through a **finite state machine** of five stages:

```
ManufacturingAndInspection
        │
        ▼  (FOUNDRY / MACHINING / ADMIN)
AssemblyAndIntegration
        │
        ▼  (OEM / ADMIN)
OperationAndUsage
        │
        ▼  (OEM / MRO / ADMIN)
MaintenanceAndService
        │
        ▼  (MRO / ADMIN)
EndOfLifeAndRecycling
```

Each stage gate enforces role restrictions on both **metadata updates** (`updateMetadata`) and **stage transitions** (`updateLifecycleStage`).

### Key Functions

#### Minting

| Function | Role Required | Description |
|---|---|---|
| `mintEquipment(to, equipmentId, initialURI)` | `ADMIN_ROLE` | Mints a top-level equipment token (e.g., turbine assembly). Sets initial stage to `ManufacturingAndInspection`. |
| `mintPart(to, partId, equipmentId, initialURI)` | `ADMIN_ROLE` | Mints a sub-part token and links it to an existing parent equipment token. |

#### Lifecycle Management

| Function | Role Required | Description |
|---|---|---|
| `updateMetadata(tokenId, newURI, notarizationHash)` | Stage-gated (see table above) | Updates the IPFS metadata URI for a token. Emits `MetadataUpdated`. |
| `updateLifecycleStage(tokenId, newStage, notarizationHash)` | Stage-gated (see FSM above) | Advances the token to a new lifecycle stage. Emits `LifecycleStageUpdated`. |
| `recordOwnershipTransfer(tokenId, to, newOwner, notarizationHash)` | Token owner | Transfers physical custody and ERC-721 ownership to a new stakeholder. Emits `OwnershipTransferred`. |
| `recordMaintenance(tokenId, details, notarizationHash)` | `MRO_ROLE` | Appends an immutable maintenance log entry. Emits `MaintenanceLogged`. |
| `addCertification(tokenId, certType, documentHash, notarizationHash)` | Any authorised role | Attaches compliance documents (NDT, X-Ray, FAA certs). Emits `CertificationAdded`. |
| `recordProcessStep(tokenId, step, details, notarizationHash)` | `FOUNDRY_ROLE` | Logs a specific manufacturing step (e.g., "Wax Pattern Creation"). Emits `ProcessStepRecorded`. |

#### View Functions

| Function | Description |
|---|---|
| `exists(tokenId)` | Returns `true` if the token has been minted. |
| `getChildren(equipmentId)` | Returns array of child part token IDs for a parent equipment token. |
| `getChildCount(equipmentId)` | Returns count of child parts. |
| `getRoles(account)` | Returns a tuple of booleans for all five roles held by an address. |
| `getTokenInfo(tokenId)` | Returns `(owner, stage, uri, parentId, childCount)` in one call. |
| `tokenURI(tokenId)` | ERC-721 standard: returns the IPFS URI for a token's metadata. |

### Events (On-chain Audit Trail)

| Event | Trigger | Key Parameters |
|---|---|---|
| `OwnershipTransferred` | Custody handoff | `tokenId`, `from`, `to`, `newOwner`, `notarizationHash` |
| `MaintenanceLogged` | MRO repair logged | `tokenId`, `details`, `notarizationHash` |
| `CertificationAdded` | Cert document attached | `tokenId`, `certType`, `documentHash`, `notarizationHash` |
| `LifecycleStageUpdated` | Stage transition | `tokenId`, `newStage`, `notarizationHash` |
| `ProcessStepRecorded` | Foundry process step | `tokenId`, `step`, `details`, `notarizationHash` |
| `MetadataUpdated` | IPFS URI refreshed | `tokenId`, `newURI`, `notarizationHash` |

---

## Project Structure

```
Iota-Project-Phase-4/
├── src/
│   └── ManufacturingDPP.sol      # Main DPP smart contract
├── lib/
│   ├── forge-std/                 # Foundry standard library (submodule)
│   └── openzeppelin-contracts/    # OpenZeppelin contracts (submodule)
├── .github/
│   └── workflows/
│       └── test.yml               # GitHub Actions CI pipeline
├── foundry.toml                   # Foundry configuration
├── foundry.lock                   # Dependency lock file
├── .gitmodules                    # Git submodule configuration
└── README.md
```

---

## Prerequisites

- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** — Solidity build & test toolchain
- **Git** — For cloning with submodules

### Install Foundry

**Linux / macOS:**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**Windows (via PowerShell):**
Download the latest `foundry_nightly_win32_amd64.zip` from the [Foundry releases page](https://github.com/foundry-rs/foundry/releases) and add the extracted binaries to your `PATH`.

---

## Getting Started

### Clone the Repository

```bash
git clone --recurse-submodules https://github.com/Dhruv4848l/Iota-Project-Phase-4.git
cd Iota-Project-Phase-4
```

If you already cloned without `--recurse-submodules`, initialise submodules manually:

```bash
git submodule update --init --recursive
```

### Install Dependencies

Dependencies (`forge-std` and `openzeppelin-contracts`) are included as Git submodules in `lib/`. No additional package manager is required.

### Build

```bash
forge build
```

Outputs compiled artifacts to `out/`. Use `--sizes` to see contract bytecode sizes:

```bash
forge build --sizes
```

### Run Tests

```bash
forge test
```

For verbose output with traces:

```bash
forge test -vvv
```

Gas snapshots:

```bash
forge snapshot
```

### Format Code

Check formatting:

```bash
forge fmt --check
```

Apply formatting:

```bash
forge fmt
```

### Deploy

```bash
forge script script/<YourScript>.s.sol \
  --rpc-url <YOUR_RPC_URL> \
  --private-key <YOUR_PRIVATE_KEY> \
  --broadcast
```

> **Note:** Never commit private keys. Use environment variables or a `.env` file (added to `.gitignore`).

#### IOTA EVM Testnet

| Parameter | Value |
|---|---|
| Network Name | IOTA EVM Testnet |
| RPC URL | `https://json-rpc.evm.testnet.iotaledger.net` |
| Chain ID | `1075` |
| Explorer | https://explorer.evm.testnet.iotaledger.net |

#### IOTA EVM Mainnet

| Parameter | Value |
|---|---|
| Network Name | IOTA EVM |
| RPC URL | `https://json-rpc.evm.iotaledger.net` |
| Chain ID | `8822` |
| Explorer | https://explorer.evm.iotaledger.net |

---

## IOTA Notarization

Every state-changing function accepts a `notarizationHash` (`bytes32`) parameter. This hash links the on-chain event to an **IOTA Notarization object** — an immutable, timestamped anchor on the IOTA Tangle that provides off-chain data integrity verification.

**Workflow:**
1. Generate or capture the relevant off-chain data (sensor readings, quality reports, shipping documents).
2. Upload the data to IPFS and obtain a CID.
3. Submit the data hash to IOTA Notarization to obtain an `objectId` / transaction hash.
4. Call the relevant contract function with the `notarizationHash` to anchor it permanently on-chain.

---

## IPFS Metadata

Each token's `tokenURI` points to a JSON document on IPFS. The recommended metadata schema follows ERC-721 Metadata standard, extended with DPP-specific fields:

```json
{
  "name": "Turbine Blade #42",
  "description": "Investment cast IN718 turbine blade for aerospace engine",
  "image": "ipfs://<image-cid>",
  "attributes": [
    { "trait_type": "Part Number",       "value": "TBL-IN718-042" },
    { "trait_type": "Material",          "value": "Inconel 718" },
    { "trait_type": "Lifecycle Stage",   "value": "ManufacturingAndInspection" },
    { "trait_type": "Foundry",           "value": "IOTA Casting Ltd." },
    { "trait_type": "Cast Date",         "display_type": "date", "value": 1717200000 },
    { "trait_type": "Certifications",    "value": "NDT, X-Ray, FAA Form 8130-3" }
  ],
  "dpp": {
    "notarization_hash": "0x...",
    "ipfs_version": 1
  }
}
```

---

## CI/CD

A GitHub Actions pipeline (`.github/workflows/test.yml`) runs on every push and pull request:

| Step | Command |
|---|---|
| Install Foundry | `foundry-rs/foundry-toolchain@v1` |
| Check formatting | `forge fmt --check` |
| Build | `forge build --sizes` |
| Test | `forge test -vvv` |

---

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feat/your-feature`.
3. Make your changes and ensure all tests pass: `forge test`.
4. Ensure code is formatted: `forge fmt`.
5. Open a pull request targeting the `main` branch.

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

*Built with [Foundry](https://book.getfoundry.sh/) · Powered by [IOTA EVM](https://wiki.iota.org/build/networks-endpoints/) · Secured by [OpenZeppelin](https://openzeppelin.com/contracts/)*
