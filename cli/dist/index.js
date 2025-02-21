import { Command } from 'commander';
import { ethers } from 'ethers';
import * as dotenv from 'dotenv';
import { createShieldedWalletClient, getShieldedContract, seismicDevnet, } from 'seismic-viem';
import { createPublicClient, createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { getShieldedContractWithCheck } from './utils.js';
dotenv.config();
const program = new Command();
// Contract addresses
const POOL_ADDRESS = process.env.POOL_ADDRESS;
const RPC_URL = process.env.RPC_URL;
const WETH_ADDRESS = process.env.WETH_ADDRESS;
// Validate environment
if (!POOL_ADDRESS) {
    console.error('Error: POOL_ADDRESS not set in environment');
    process.exit(1);
}
if (!RPC_URL) {
    console.error('Error: RPC_URL not set in environment');
    process.exit(1);
}
if (!process.env.PRIVATE_KEY) {
    console.error('Error: PRIVATE_KEY not set in environment');
    process.exit(1);
}
if (!WETH_ADDRESS) {
    console.error('Error: WETH_ADDRESS not set in environment');
    process.exit(1);
}
// Provider setup
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
// Create base clients
const transport = http(RPC_URL);
const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const basePublicClient = createPublicClient({
    chain: seismicDevnet,
    transport,
});
const baseWalletClient = createWalletClient({
    chain: seismicDevnet,
    transport,
    account,
});
// Initialize clients
let shieldedWalletClient;
async function initializeClients() {
    shieldedWalletClient = await createShieldedWalletClient({
        chain: seismicDevnet,
        transport: http(RPC_URL),
        account,
    });
}
// Verify RPC connection
async function verifyConnection() {
    try {
        await provider.getNetwork();
        return true;
    }
    catch (error) {
        console.error('Error connecting to RPC:', error);
        return false;
    }
}
// Verify contract exists
async function verifyContract() {
    try {
        const code = await provider.getCode(POOL_ADDRESS);
        if (code === '0x') {
            console.error('Error: No contract found at address:', POOL_ADDRESS);
            return false;
        }
        return true;
    }
    catch (error) {
        console.error('Error checking contract:', error);
        return false;
    }
}
// Function selectors (without '0x' prefix)
const SELECTORS = {
    joinPool: ethers.id('joinPool(uint256)').slice(2, 10),
    contributeExit: ethers.id('contributeExit(uint256)').slice(2, 10),
    leavePool: ethers.id('leavePool()').slice(2, 10),
    getCommitmentPercentage: ethers.id('getCommitmentPercentage()').slice(2, 10),
    getTotalContributed: ethers.id('getTotalContributed()').slice(2, 10),
    joinWindowEnds: ethers.id('joinWindowEnds()').slice(2, 10),
    getMemberJoinTime: ethers.id('getMemberJoinTime()').slice(2, 10),
    lastContributionTime: ethers.id('lastContributionTime(address)').slice(2, 10),
    distributionPeriod: ethers.id('distributionPeriod()').slice(2, 10),
    lastDistribution: ethers.id('lastDistribution()').slice(2, 10),
    distributor: ethers.id('distributor()').slice(2, 10),
};
// Error selectors
const ERROR_SELECTORS = {
    JoinWindowStillOpen: '0x305a27a9',
    ContributionTooFrequent: '0x4ec2449e',
    NotMember: '0x7573160d',
    AlreadyMember: '0x69f81d5d',
    JoinWindowExpired: '0x39b12c3e',
    MinMembershipPeriodNotMet: '0x4d2cd97b',
};
// Helper function to encode parameters
function encodeParameter(value) {
    return ethers.zeroPadValue(ethers.toBeHex(value), 32).slice(2);
}
// Helper function to check if error contains a specific selector
function hasErrorSelector(error, selector) {
    const errorData = error.data ||
        error.error?.data ||
        error.info?.error?.data ||
        error.error?.error?.data;
    if (!errorData)
        return false;
    return errorData.includes(selector);
}
// Helper function to get a user-friendly error message
function getErrorMessage(error) {
    if (hasErrorSelector(error, ERROR_SELECTORS.JoinWindowStillOpen)) {
        return 'Join window is still open';
    }
    if (hasErrorSelector(error, ERROR_SELECTORS.ContributionTooFrequent)) {
        return 'Must wait 7 days between contributions';
    }
    if (hasErrorSelector(error, ERROR_SELECTORS.NotMember)) {
        return 'You are not a member of the pool';
    }
    if (hasErrorSelector(error, ERROR_SELECTORS.AlreadyMember)) {
        return 'You are already a member of the pool';
    }
    if (hasErrorSelector(error, ERROR_SELECTORS.JoinWindowExpired)) {
        return 'Join window has expired';
    }
    if (hasErrorSelector(error, ERROR_SELECTORS.MinMembershipPeriodNotMet)) {
        return 'Minimum membership period not met';
    }
    // Check for other common error messages
    if (error.reason)
        return error.reason;
    if (error.message)
        return error.message;
    return 'Unknown error occurred';
}
// Helper function to check membership
async function checkMembership(address) {
    try {
        await provider.call({
            to: POOL_ADDRESS,
            data: `0x${SELECTORS.getCommitmentPercentage}`,
            from: address,
        });
        return true;
    }
    catch (error) {
        if (hasErrorSelector(error, ERROR_SELECTORS.NotMember)) {
            return false;
        }
        throw error;
    }
}
// Helper function to get last contribution time
async function getLastContributionTime(address) {
    try {
        const data = await provider.call({
            to: POOL_ADDRESS,
            data: `0x${SELECTORS.lastContributionTime}${encodeParameter(address)}`,
        });
        return ethers.toNumber(data);
    }
    catch (error) {
        return 0;
    }
}
// Add WETH ABI
const WETH_ABI = [
    {
        name: 'deposit',
        type: 'function',
        stateMutability: 'payable',
        inputs: [],
        outputs: [],
    },
    {
        name: 'approve',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [
            { name: 'spender', type: 'address' },
            { name: 'amount', type: 'uint256' },
        ],
        outputs: [{ type: 'bool' }],
    },
];
program
    .name('founder-hedge')
    .description('CLI to interact with FounderHedge contracts')
    .version('1.0.0');
program
    .command('join')
    .description('Join the success pool')
    .argument('<percentage>', 'Commitment percentage (1-10)')
    .action(async (percentage) => {
    try {
        // Initialize clients first
        await initializeClients();
        // Verify connection and contract
        if (!(await verifyConnection()) || !(await verifyContract())) {
            return;
        }
        console.log('Joining pool with commitment:', percentage, '%');
        console.log('Using pool address:', POOL_ADDRESS);
        // Get shielded contract instance
        const contract = getShieldedContract({
            address: POOL_ADDRESS,
            abi: [
                {
                    name: 'joinPool',
                    type: 'function',
                    stateMutability: 'external',
                    inputs: [{ name: 'commitment', type: 'suint256' }],
                    outputs: [],
                },
            ],
            client: shieldedWalletClient,
        });
        if (!contract || !contract.write || !contract.write.joinPool) {
            console.log('Error: Failed to initialize contract interface');
            return;
        }
        console.log('Sending encrypted join transaction...');
        const hash = await contract.write.joinPool([BigInt(percentage)]);
        if (!hash) {
            console.log('Error: Transaction failed - no hash returned');
            return;
        }
        console.log('Transaction hash:', hash);
        console.log('Waiting for confirmation...');
        // Wait for transaction confirmation
        const receipt = await basePublicClient.waitForTransactionReceipt({
            hash,
        });
        if (receipt?.status === 'success') {
            console.log('\nSuccessfully joined pool!');
            console.log('Commitment percentage:', percentage, '%');
        }
        else {
            console.log('Transaction failed');
        }
    }
    catch (error) {
        // Handle viem errors
        if (error.message.includes('Details: revert:')) {
            // Extract the revert reason after "Details: revert:"
            const match = error.message.match(/Details: revert: (.*?)(?=\n|Version:|$)/);
            if (match) {
                console.log('Error:', match[1]);
                return;
            }
        }
        // Fallback to general error handling
        console.log('Error:', getErrorMessage(error));
    }
});
program
    .command('leave')
    .description('Leave the success pool')
    .action(async () => {
    try {
        // Verify connection and contract
        if (!(await verifyConnection()) || !(await verifyContract())) {
            return;
        }
        // First check if join window is still open
        const windowData = await provider.call({
            to: POOL_ADDRESS,
            data: `0x${SELECTORS.joinWindowEnds}`,
        });
        const windowEnd = ethers.toNumber(windowData);
        const now = Math.floor(Date.now() / 1000);
        if (now <= windowEnd) {
            console.log('Cannot leave while join window is still open');
            console.log('Window ends:', new Date(windowEnd * 1000).toLocaleString());
            return;
        }
        // Check minimum membership period (90 days after join window)
        const minLeaveTime = windowEnd + 90 * 24 * 60 * 60; // 90 days in seconds
        if (now < minLeaveTime) {
            console.log('Minimum membership period not met');
            console.log('You can leave after:', new Date(minLeaveTime * 1000).toLocaleString());
            const daysLeft = Math.ceil((minLeaveTime - now) / (24 * 60 * 60));
            console.log(`(approximately ${daysLeft} days from now)`);
            return;
        }
        // Try to leave
        console.log('Sending leave transaction...');
        const tx = await wallet.sendTransaction({
            to: POOL_ADDRESS,
            data: `0x${SELECTORS.leavePool}`,
        });
        console.log('Transaction hash:', tx.hash);
        const receipt = await tx.wait();
        if (receipt?.status === 1) {
            console.log('Successfully left the pool!');
        }
        else {
            console.log('Transaction failed');
        }
    }
    catch (error) {
        console.log('Error:', getErrorMessage(error));
    }
});
program
    .command('status')
    .description('Get your pool status')
    .action(async () => {
    try {
        // Initialize clients first
        await initializeClients();
        // Verify connection and contract
        if (!(await verifyConnection()) || !(await verifyContract())) {
            return;
        }
        const address = await wallet.getAddress();
        console.log('Checking status for address:', address);
        // Get shielded contract instance
        const contract = await getShieldedContractWithCheck(shieldedWalletClient, [
            {
                name: 'getCommitmentPercentage',
                type: 'function',
                stateMutability: 'view',
                inputs: [],
                outputs: [{ type: 'uint256' }],
            },
            {
                name: 'getMemberJoinTime',
                type: 'function',
                stateMutability: 'view',
                inputs: [],
                outputs: [{ type: 'uint256' }],
            },
        ], POOL_ADDRESS);
        console.log('\nMembership Status:');
        try {
            // Try to get commitment percentage - this will revert if not a member
            const commitment = await contract.read.getCommitmentPercentage();
            console.log('- You ARE a member of the pool');
            console.log('- Your commitment:', Number(commitment), '%');
            // Get join time
            const joinTime = await contract.read.getMemberJoinTime();
            console.log('- Joined at:', new Date(Number(joinTime) * 1000).toLocaleString());
            // Calculate when you can leave (90 days after join)
            const minLeaveTime = Number(joinTime) + 90 * 24 * 60 * 60; // 90 days in seconds
            const now = Math.floor(Date.now() / 1000);
            if (now < minLeaveTime) {
                console.log('\nLeaving Status:');
                console.log('- Can leave after:', new Date(minLeaveTime * 1000).toLocaleString());
                console.log('- Days until eligible:', Math.ceil((minLeaveTime - now) / (24 * 60 * 60)));
            }
            else {
                console.log('\nLeaving Status:');
                console.log('- Eligible to leave: Yes');
            }
        }
        catch (error) {
            if (error.message.includes('Not a member')) {
                console.log('- You are NOT a member of the pool');
                console.log('- You can join using the join command');
                console.log('- Example: founder-hedge join 5  (to commit 5%)');
            }
            else {
                console.log('Error checking membership:', getErrorMessage(error));
            }
        }
    }
    catch (error) {
        console.log('Error:', getErrorMessage(error));
    }
});
program
    .command('window')
    .description('Check join window status')
    .action(async () => {
    try {
        const data = await provider.call({
            to: POOL_ADDRESS,
            data: `0x${SELECTORS.joinWindowEnds}`,
        });
        const windowEnd = ethers.toNumber(data);
        const now = Math.floor(Date.now() / 1000);
        console.log('Join window status:');
        console.log('Current time:', new Date(now * 1000).toLocaleString());
        console.log('Window ends:', new Date(windowEnd * 1000).toLocaleString());
        console.log('Window is:', now > windowEnd ? 'CLOSED' : 'OPEN');
    }
    catch (error) {
        console.error('Error checking window:', error);
    }
});
program
    .command('contribute')
    .description('Contribute an exit to the pool using wETH')
    .argument('<amount>', 'Amount in ETH (e.g., 1.5 for 1.5 ETH)')
    .action(async (amount) => {
    try {
        await initializeClients();
        // Verify connection and contract
        if (!(await verifyConnection()) || !(await verifyContract())) {
            return;
        }
        // First wrap ETH to wETH
        console.log('Wrapping ETH to wETH...');
        const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, wallet);
        // Deposit ETH to get wETH
        const amountWei = ethers.parseEther(amount);
        const depositTx = await wethContract.deposit({ value: amountWei });
        await depositTx.wait();
        console.log('Successfully wrapped ETH to wETH');
        // Approve pool contract to spend wETH - use max amount to hide actual value
        console.log('Approving pool contract to spend wETH...');
        const MAX_APPROVAL = ethers.parseEther('1000000'); // 1M ETH
        const approveTx = await wethContract.approve(POOL_ADDRESS, MAX_APPROVAL);
        await approveTx.wait();
        console.log('Successfully approved wETH spend');
        // Get shielded pool contract instance
        const poolContract = getShieldedContract({
            address: POOL_ADDRESS,
            abi: [
                {
                    name: 'contributeExit',
                    type: 'function',
                    stateMutability: 'nonpayable',
                    inputs: [{ name: 'contribution', type: 'suint256' }],
                    outputs: [],
                },
            ],
            client: shieldedWalletClient,
        });
        if (!poolContract ||
            !poolContract.write ||
            !poolContract.write.contributeExit) {
            console.log('Error: Failed to initialize pool contract interface');
            return;
        }
        // Check contribution timing
        const lastContribution = await getLastContributionTime(await wallet.getAddress());
        const now = Math.floor(Date.now() / 1000);
        const MIN_CONTRIBUTION_INTERVAL = 24 * 60 * 60; // 1 day in seconds
        if (lastContribution > 0 &&
            now < lastContribution + MIN_CONTRIBUTION_INTERVAL) {
            console.log('Error: Must wait 24 hours between contributions');
            const nextPossible = new Date((lastContribution + MIN_CONTRIBUTION_INTERVAL) * 1000);
            console.log('Next possible contribution:', nextPossible.toLocaleString());
            return;
        }
        // Send transaction - let contract handle all encrypted calculations
        console.log('Sending contribution (all values will be encrypted)...');
        const hash = await poolContract.write.contributeExit([amountWei], {
            gas: 400000n,
        });
        if (!hash) {
            console.log('Error: Transaction failed - no hash returned');
            return;
        }
        console.log('Transaction hash:', hash);
        console.log('Waiting for confirmation...');
        // Wait for transaction confirmation
        const receipt = await basePublicClient.waitForTransactionReceipt({
            hash,
        });
        if (receipt?.status === 'success') {
            console.log('\nContribution successful!');
            console.log('All calculations and values are encrypted in the contract');
        }
        else {
            console.log('Transaction failed');
        }
    }
    catch (error) {
        // Handle viem errors
        if (error.message.includes('Details: revert:')) {
            // Extract the revert reason after "Details: revert:"
            const match = error.message.match(/Details: revert: (.*?)(?=\n|Version:|$)/);
            if (match) {
                console.log('Error:', match[1]);
                return;
            }
        }
        // Fallback to general error handling
        console.log('Error:', getErrorMessage(error));
    }
});
program
    .command('next-contribution')
    .description('Check when you can contribute next')
    .action(async () => {
    try {
        // Initialize clients first
        await initializeClients();
        // Verify connection and contract
        if (!(await verifyConnection()) || !(await verifyContract())) {
            return;
        }
        const address = await wallet.getAddress();
        console.log('Checking contribution status for:', address);
        // Check if member using shielded contract
        const membershipContract = getShieldedContract({
            address: POOL_ADDRESS,
            abi: [
                {
                    name: 'getCommitmentPercentage',
                    type: 'function',
                    stateMutability: 'view',
                    inputs: [],
                    outputs: [{ type: 'uint256' }],
                },
            ],
            client: shieldedWalletClient,
        });
        try {
            await membershipContract.read.getCommitmentPercentage();
        }
        catch (error) {
            if (error.message.includes('Not a member')) {
                console.log('You are not a member of the pool');
                return;
            }
            throw error;
        }
        // Get last contribution time
        const lastContribution = await getLastContributionTime(address);
        const now = Math.floor(Date.now() / 1000);
        if (lastContribution === 0) {
            console.log('You have not made any contributions yet');
            console.log('You can contribute now!');
            return;
        }
        const nextContributionTime = lastContribution + 7 * 24 * 60 * 60; // 7 days
        if (now < nextContributionTime) {
            console.log('You need to wait before your next contribution');
            console.log('Next contribution possible after:', new Date(nextContributionTime * 1000).toLocaleString());
            const daysLeft = Math.ceil((nextContributionTime - now) / (24 * 60 * 60));
            console.log(`(approximately ${daysLeft} days from now)`);
        }
        else {
            console.log('You can contribute now!');
        }
    }
    catch (error) {
        console.error('Error checking contribution status:', getErrorMessage(error));
    }
});
program
    .command('distribution')
    .description('Check distribution status')
    .action(async () => {
    try {
        // First check if join window is still open
        const windowData = await provider.call({
            to: POOL_ADDRESS,
            data: `0x${SELECTORS.joinWindowEnds}`,
        });
        const windowEnd = ethers.toNumber(windowData);
        const now = Math.floor(Date.now() / 1000);
        if (now <= windowEnd) {
            console.log('\nJoin window is still open');
            console.log('Distributions will start after:', new Date(windowEnd * 1000).toLocaleString());
            return;
        }
        // Get recent distribution events
        const filter = {
            address: POOL_ADDRESS,
            topics: [ethers.id('DividendsDistributed()')],
            fromBlock: -10000n, // Look back further
        };
        const events = await provider.getLogs(filter);
        if (events.length > 0) {
            const lastEvent = events[events.length - 1];
            const timestamp = await provider.getBlock(lastEvent.blockNumber);
            console.log('\nLast distribution:');
            console.log('Block:', lastEvent.blockNumber);
            console.log('Time:', new Date(Number(timestamp?.timestamp) * 1000).toLocaleString());
            // Next distribution estimate (30 days after last one)
            const nextDist = Number(timestamp?.timestamp) + 30 * 24 * 60 * 60;
            const daysLeft = Math.ceil((nextDist - now) / (24 * 60 * 60));
            console.log('\nNext distribution (estimated):');
            console.log('Time:', new Date(nextDist * 1000).toLocaleString());
            console.log(`Approximately ${daysLeft} days from now`);
        }
        else {
            console.log('\nNo distribution events found yet');
            if (now > windowEnd) {
                console.log('Distributions should start soon');
            }
        }
        // Show member count if available
        try {
            const memberData = await provider.call({
                to: POOL_ADDRESS,
                data: `0x${ethers.id('memberCount()').slice(2, 10)}`,
            });
            const count = ethers.toNumber(memberData);
            console.log('\nCurrent member count:', count);
        }
        catch (error) {
            // Ignore member count errors
        }
    }
    catch (error) {
        console.error('Error checking distribution status:', error);
    }
});
program.parse();
//# sourceMappingURL=index.js.map