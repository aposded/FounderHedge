import { createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { createShieldedWalletClient, getShieldedContract, seismicDevnet, } from 'seismic-viem';
import dotenv from 'dotenv';
dotenv.config();
// USDY ABI for minting
const USDY_ABI = [
    {
        name: 'decimals',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{ type: 'uint8' }],
    },
    {
        name: 'mint',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [
            { name: 'to', type: 'saddress' },
            { name: 'amount', type: 'suint256' },
        ],
        outputs: [{ type: 'bool' }],
    },
];
async function main() {
    // Initialize account from private key
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
        throw new Error('PRIVATE_KEY environment variable is required');
    }
    // Format private key with proper type
    const formattedPrivateKey = (privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`);
    const account = privateKeyToAccount(formattedPrivateKey);
    console.log('Account:', account.address);
    // Initialize transport
    const transport = http();
    // Initialize wallet client
    const walletClient = await createShieldedWalletClient({
        account,
        chain: seismicDevnet,
        transport,
    });
    // Initialize public client
    const publicClient = createPublicClient({
        chain: seismicDevnet,
        transport,
    });
    // Get contract instance
    const contract = getShieldedContract({
        address: '0x6f4e24AA8BB9f64cB7593d1d59E6d8441F4ebA76',
        abi: USDY_ABI,
        publicClient,
        walletClient,
    });
    try {
        // Get decimals
        const decimals = await contract.read.decimals();
        console.log('Decimals:', decimals);
        // Calculate amount to mint (100 USDY)
        const amount = 100n * BigInt(10 ** Number(decimals));
        console.log('Amount to mint (wei):', amount.toString());
        // Mint tokens directly
        console.log('Minting tokens...');
        const hash = await contract.write.mint([account.address, amount]);
        console.log('Transaction hash:', hash);
        // Wait for confirmation
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        console.log('Transaction confirmed:', receipt.status);
    }
    catch (error) {
        console.error('\nError details:');
        if (error.shortMessage)
            console.error('Short message:', error.shortMessage);
        if (error.details)
            console.error('Details:', error.details);
        if (error.metaMessages)
            console.error('Meta messages:', error.metaMessages);
        throw error;
    }
}
main().catch(console.error);
