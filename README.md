# FounderHedge

A decentralized success-sharing pool for startup founders, built with privacy-preserving technology.

## Overview

FounderHedge allows startup founders to create a mutual support pool where they commit a percentage
of their future exits. All transactions and commitments are encrypted, ensuring privacy while
maintaining transparency. The system uses wETH (wrapped ETH) for contributions to ensure transaction
values remain private.

## Features

- Privacy-preserving transactions using encrypted smart contracts and wETH
- Commitment range: 1-10% of future exits
- 90-day minimum membership period
- 7-day interval between contributions
- Fair dividend distribution based on commitment percentages
- Emergency controls for contract security

## Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/FounderHedge.git
cd FounderHedge
```

2. Install dependencies:

```bash
cd cli
npm install
```

3. Set up environment variables:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```
PRIVATE_KEY=your_private_key
POOL_ADDRESS=deployed_pool_contract_address
WETH_ADDRESS=weth_contract_address
RPC_URL=your_rpc_endpoint
```

## CLI Commands

### Join Pool

Join the success pool with a specified commitment percentage (1-10%):

```bash
npm start join <percentage>
```

Example: `npm start join 5` (commits 5% of future exits)

### Contribute Exit

Contribute an exit to the pool (automatically converts ETH to wETH):

```bash
npm start contribute <amount>
```

Example: `npm start contribute 0.1` (contributes 0.1 ETH)

The contribute process:

1. Wraps your ETH to wETH
2. Approves the pool contract to spend your wETH
3. Sends the encrypted contribution transaction

### Check Status

View your pool membership status:

```bash
npm start status
```

Shows:

- Membership status
- Commitment percentage
- Join date
- Eligibility to leave

### Check Next Contribution

See when you can make your next contribution:

```bash
npm start next-contribution
```

### Leave Pool

Leave the pool (after minimum membership period):

```bash
npm start leave
```

## Transaction Parameters

The CLI uses the following parameters for transactions:

- Gas: 400,000 units
- Transaction type: 0x4a (for shielded transactions)
- Uses USDY for value privacy

## Contract Architecture

The system consists of three main contracts:

1. `SuccessPool.sol`: Main contract managing membership and contributions
2. `ExitContribution.sol`: Handles contribution processing and verification
3. `DividendDistributor.sol`: Manages dividend calculations and distribution

## Security Considerations

- All sensitive data is encrypted on-chain
- Transaction values hidden through USDY usage
- Minimum intervals prevent spam
- Emergency pause functionality
- Admin controls for security
- Maximum limits on contributions and claims

## Development

To build the CLI:

```bash
npm run build
```

To run tests:

```bash
npm test
```

## License

MIT
