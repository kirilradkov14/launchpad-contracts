# Launchpad Contracts

A decentralized token launchpad platform built on Ethereum using an exponential bonding curve for price discovery and fair token distribution.

## Overview

This project implements a decentralized token launchpad system using advanced smart contract patterns and mathematical models. It features an exponential bonding curve for price discovery, proxy-factory pattern for efficient deployment, and comprehensive testing using Foundry.

## Key Features

### Exponential Bonding Curve

The platform uses an exponential bonding curve to determine token prices, implementing the following formulas:

**Buy Formula:**
```
T = (e^(-k·S) - e^(-k·(S + E))) / (k·P₀)
```
Where:
- T: Tokens received
- S: Current ETH supply
- E: ETH amount sent
- k: Curve steepness
- P₀: Initial price

**Sell Formula:**
```
S' = -ln(1 - k·P₀·(Tₜₒₜₐₗ - Tᵢₙ)) / k
E = S - S'
```
Where:
- S': New ETH supply
- Tₜₒₜₐₗ: Total tokens sold
- Tᵢₙ: Tokens being sold
- E: ETH returned

### Proxy-Factory Pattern

The project utilizes the proxy-factory pattern for:
- Gas-efficient contract deployment
- Upgradeable contract architecture
- Standardized launchpad creation

## Project Structure

```
├── src/
│   ├── LaunchpadFactory.sol    # Factory contract for deploying launchpads
│   ├── Launchpad.sol           # Main launchpad implementation
│   ├── libraries/              # Helper libraries
│   │   ├── Formula.sol         # Bonding curve calculations
│   │   └── Math64x64.sol       # Fixed-point math operations
│   └── interfaces/             # Contract interfaces
├── test/                       # Test suite
└── script/                     # Deployment scripts
```

## Installation

1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone the repository:
```bash
git clone https://github.com/yourusername/launchpad-contracts.git
cd launchpad-contracts
```

3. Install dependencies:
```bash
forge install
```

## Usage

### Build
```bash
forge build
```

### Test
```bash
forge test
```

### Deploy
```bash
forge script script/Launchpad.s.sol:LaunchpadScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## Testing

The project includes comprehensive tests covering:
- Bonding curve calculations
- Proxy deployment pattern
- Token economics
- Integration with Uniswap V2

Run specific test suites:
```bash
forge test --match-contract Formula     # Test bonding curve calculations
forge test --match-contract Proxy       # Test proxy pattern
forge test --match-contract Launchpad   # Test core functionality
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
