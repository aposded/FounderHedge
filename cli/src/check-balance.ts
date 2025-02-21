import { createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import {
  createShieldedWalletClient,
  getShieldedContract,
  seismicDevnet,
} from 'seismic-viem';
import dotenv from 'dotenv';

dotenv.config();

// USDY ABI for debug functions
const USDY_ABI = [
  {
    name: 'getBalanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'saddress' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getSharesOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'saddress' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'decimals',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
];

async function main() {
  // Initialize account from private key
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error('PRIVATE_KEY environment variable is required');
  }

  // Format private key with proper type
  const formattedPrivateKey = (
    privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`
  ) as `0x${string}`;
  const account = privateKeyToAccount(formattedPrivateKey);
  console.log('Checking balance for account:', account.address);

  // Initialize transport
  const transport = http(process.env.RPC_URL);

  // Initialize shielded wallet client
  const shieldedClient = await createShieldedWalletClient({
    chain: seismicDevnet,
    transport,
    account,
  });

  // Get contract instance
  const contract = getShieldedContract({
    address: process.env.USDY_ADDRESS as `0x${string}`,
    abi: USDY_ABI,
    client: shieldedClient,
  });

  try {
    // Get decimals first
    const decimals = await contract.read.decimals();
    console.log('Decimals:', decimals);

    // Get balance using the debug function
    const balance = await contract.read.getBalanceOf([account.address]);
    console.log('Balance (wei):', balance.toString());
    console.log('Balance (USDY):', Number(balance) / 10 ** Number(decimals));

    // Get shares using the debug function
    const shares = await contract.read.getSharesOf([account.address]);
    console.log('Shares:', shares.toString());
  } catch (error: any) {
    console.error('\nError details:');
    if (error.shortMessage) console.error('Short message:', error.shortMessage);
    if (error.details) console.error('Details:', error.details);
    if (error.metaMessages) console.error('Meta messages:', error.metaMessages);
    throw error;
  }
}

main().catch(console.error);
