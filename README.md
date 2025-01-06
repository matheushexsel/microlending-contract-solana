MicroLending Smart Contract

This repository contains the **MicroLending.sol** smart contract, designed for efficient, scalable, and secure decentralized lending. Built for Ethereum-compatible blockchains (e.g., Binance Smart Chain), this contract enables peer-to-peer lending with support for native tokens and ERC-20-based collateral.

Features
1. Complete Loan Lifecycle:
   - Request loans, fund loans, repay loans (partial or full), and liquidate collateral upon default.

2. Collateral Flexibility:
   - Supports both native tokens (e.g., BNB) and ERC-20 tokens as collateral.

3. Partial Repayments:
   - Allows borrowers to repay loans in installments, dynamically recalculating outstanding balances.

4. Dynamic Grace Period:
   - Configurable grace period after loan deadlines to provide borrowers flexibility before liquidation.

5. Platform Fee:
   - A configurable platform fee (default: 0.5%) deducted during loan funding, supporting operational costs.

6. Event Logging:
   - Real-time updates for loan actions (requested, funded, repaid, liquidated) for easier integration with frontend applications.

Efficiency and Security
- Gas Optimization:
  - Minimizes redundant storage writes and optimizes events for cost-effective operations.
- Reentrancy Protection:
  - Ensures external calls (e.g., token transfers) are securely handled after state updates.
- Access Control:
  - Critical functions (e.g., platform configuration) are restricted to the contract owner using a secure `onlyOwner` modifier.

How to Use
1. Prerequisites
- Solidity Compiler v0.8+
- A compatible development environment like **Remix**, **Truffle**, or **Hardhat**.
- Access to a Binance Smart Chain (BSC) node or similar Ethereum-compatible blockchain.

2. Deployment
1. Clone the repository:
   ```bash
   git clone https://github.com/<your-username>/microlending-contract.git
   cd microlending-contract
