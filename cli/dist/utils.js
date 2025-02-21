import { getShieldedContract } from 'seismic-viem';
export async function getShieldedContractWithCheck(walletClient, abi, address) {
    const contract = getShieldedContract({
        abi,
        address,
        client: walletClient,
    });
    const code = await walletClient.getCode({
        address,
    });
    if (!code) {
        throw new Error('Contract not found at the specified address');
    }
    return contract;
}
//# sourceMappingURL=utils.js.map