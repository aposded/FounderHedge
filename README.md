# 📌 Encrypted Success Pool

A Seismic-powered, encrypted income-sharing pool where successful startup founders contribute a percentage of their exit to immediately distribute dividends to other members. This ensures that founders hedge against failure by benefiting from others' success while keeping all values private.

## 🛠️ How It Works

1. **Founders Join the Pool**

   - Agree to share a fixed percentage (1-10%) of future successful exits
   - No upfront contributions required
   - All commitments remain encrypted
   - Fixed 30-day join window

2. **Founders Exit & Contribute**

   - Submit encrypted exit reports
   - Smart contract verifies and processes the contribution
   - Committed percentage is automatically contributed to the pool
   - Minimum 7 days between contributions

3. **Dividend Distribution**
   - Contributions are automatically distributed to all members
   - All payouts remain encrypted
   - Fair distribution mechanism based on commitment percentages

## 📦 Smart Contracts

- `SuccessPool.sol`: Main contract managing pool entries and contributions with fixed rules
- `ExitContribution.sol`: Processes encrypted exit reports
- `DividendDistributor.sol`: Handles encrypted dividend distribution

## 🚀 Getting Started

### Prerequisites

- Seismic development environment
- sforge installed
- Private key for deployment

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd seismic-success-pool
```

2. Install dependencies:

```bash
sforge install
```

3. Compile contracts:

```bash
sforge build
```

### Deployment

1. Set up your environment variables:

```bash
export PRIVKEY=your_private_key
```

2. Deploy the contracts:

```bash
sforge script script/Deploy.s.sol --broadcast
```

## 🔒 Privacy Features

- All balances and contributions are encrypted using Seismic's native encryption
- Member identities remain private
- Transaction values are hidden
- Pool total value is encrypted

## 🧪 Testing

Run the test suite:

```bash
sforge test
```

## 📜 License

MIT License
