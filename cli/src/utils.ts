import { type ShieldedWalletClient, getShieldedContract } from 'seismic-viem';
import { Abi, Address } from 'viem';

export async function getShieldedContractWithCheck(
  walletClient: ShieldedWalletClient,
  abi: Abi,
  address: Address
) {
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
