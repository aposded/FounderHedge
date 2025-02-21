# FounderHedge

A decentralized success-sharing pool for startup founders, built with privacy-preserving technology.

## Overview

FounderHedge allows startup founders to create a mutual support pool where they commit a percentage of their future exits. All transactions and commitments are encrypted, ensuring privacy while maintaining transparency.

## Features

- Privacy-preserving transactions using encrypted smart contracts
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

Contribute an exit to the pool:

```bash
npm start contribute <amount>
```

Example: `npm start contribute 0.1` (contributes 0.1 ETH)

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

### Check Join Window

View the status of the join window:

```bash
npm start window
```

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

### Check Distribution Status

View dividend distribution status:

```bash
npm start distribution
```

## Transaction Parameters

The CLI uses the following parameters for transactions:

- Gas: 100,000 units
- Transaction type: 0x4a (for shielded transactions)

## Recent Changes

1. Gas optimization:

   - Simplified gas parameters
   - Using fixed gas value of 100,000 units
   - Removed maxFeePerGas and maxPriorityFeePerGas for better compatibility

2. Error handling improvements:

   - Better error messages for common failures
   - Detailed feedback for contribution timing
   - Clear status reporting

3. Security enhancements:
   - Added contract verification checks
   - Improved encrypted transaction handling
   - Better state validation

## Contract Architecture

The system consists of three main contracts:

1. `SuccessPool.sol`: Main contract managing membership and contributions
2. `ExitContribution.sol`: Handles contribution processing and verification
3. `DividendDistributor.sol`: Manages dividend calculations and distribution

## Security Considerations

- All sensitive data is encrypted on-chain
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
