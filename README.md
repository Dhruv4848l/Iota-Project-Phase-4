# IOTA Enterprise Digital Product Passport (DPP) Portal

[![Solidity](https://img.shields.io/badge/Solidity-0.8.33-informational?logo=solidity)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://book.getfoundry.sh/)
[![Frontend](https://img.shields.io/badge/Frontend-Live-blueviolet)](https://iota-dpp.vercel.app)

> 🚀 **Live Portal Frontend:** [iota-dpp.vercel.app](https://iota-dpp.vercel.app)  
> 🔗 **Network:** Ethereum Sepolia Testnet | **Chain ID:** 11155111  
> 📖 **Architecture & Deep Dive Documentation:** [docs/PROJECT_GUIDE.md](docs/PROJECT_GUIDE.md)

---

## Overview

This repository implements a **blockchain-enabled Digital Product Passport (DPP)** system. Designed for high-value manufacturing (like investment casting foundries producing safety-critical aerospace turbine blades), it decouples the industrial lifecycle into **7 separate ERC-721 NFT contracts** coordinated by a central orchestrator portal. 

This architecture records and links workers, machinery telemetry, calibrations, QA inspection scores, and ERP logistics onto the blockchain.

```
                  ┌──────────────────────┐
                  │  TraceabilityPortal  │
                  └──────────┬───────────┘
         ┌─────┬─────┬───────┼───────┬─────┬─────┐
         ▼     ▼     ▼       ▼       ▼     ▼     ▼
       ⚙️     👤    ⛓       🔩      📜    🔧    💼
      Eq    Mp    Pr      Pd      Ql    Mt    Bz
```

---

## Decoupled Smart Contract Deployments (Sepolia)

| Contract | Address | Description |
|---|---|---|
| 🛡️ **TraceabilityPortal (Portal)** | `0x8C6e7e14958658b2559c689734Df50b626BFD69A` | Central gateway for mints and passport lookups. |
| ⚙️ **EquipmentNFT** | `0x53F3cB642E2985fb7fE97a96788c7457B19d8a55` | Machinery asset telemetry & calibration. |
| 👤 **ManpowerNFT** | `0xa0e928EC402466c27E36aAAc4Fae9DC8dAf0743d` | Operator qualification & signatures. |
| ⛓ **ProcessNFT** | `0xE04Ac7A16f060596148e52264ccf960b24bAC780` | Melt casting process parameters. |
| 🔩 **ProductNFT** | `0x305e2de338AE963E88747CF5d36f02106766Ee19` | Final physical casting component passport. |
| 📜 **QualityNFT** | `0xbF723D781f6e799e7d9F3f1D4D0B0a86FEe93e6a` | NDT QA score and AI defect model logs. |
| 🔧 **MaintenanceNFT** | `0x97B739a219bA5E247fD68aB178353965f313b171` | Preventive care & downtime logs. |
| 💼 **BusinessNFT** | `0x1F060B42De10B29eFf7b837E85F621a650EBFC44` | Commercial order POs and logistics trail. |

---

## Project Structure

```
Iota-Project-Phase-4/
├── docs/
│   └── PROJECT_GUIDE.md          # Comprehensive architectural specs
├── script/
│   └── DeployV3.s.sol            # Decoupled deploy & link scripts
├── src/
│   ├── TraceabilityPortal.sol    # Coordinator Portal
│   ├── EquipmentNFT.sol          # Stage 1
│   ├── ManpowerNFT.sol           # Stage 2
│   ├── ProcessNFT.sol            # Stage 3
│   ├── ProductNFT.sol            # Stage 4
│   ├── QualityNFT.sol            # Stage 5
│   ├── MaintenanceNFT.sol        # Stage 6
│   └── BusinessNFT.sol           # Stage 7
├── test/
│   └── TraceabilityPortal.t.sol  # Pipeline integration tests
├── index.html                    # Redesigned digital twin frontend dashboard
├── foundry.toml
└── README.md
```

---

## Quick Start

### 1. Installation
Clone the repository and fetch the submodules containing OpenZeppelin libraries:
```bash
git clone --recurse-submodules https://github.com/Dhruv4848l/Iota-Project-Phase-4.git
cd Iota-Project-Phase-4
```

### 2. Build and Test
Compile the contracts and run the unit integration test suite:
```bash
# Compile contracts
forge build

# Run tests
forge test -vv
```

### 3. Launch Frontend Locally
To test MetaMask interaction locally:
```bash
# Start a local web server (prevents MetaMask file:// origin blocks)
npx serve
```
Then navigate to `http://localhost:3000` in your web browser.

---

For a deep dive into the engineering logic, AI defect rating indicators, and step-by-step metadata schemas, read [docs/PROJECT_GUIDE.md](docs/PROJECT_GUIDE.md).
