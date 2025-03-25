import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export type MinterConfig = {
    isMinted: boolean;
    startTime: bigint;
    minterAddress: Address;
    ownerAddress: Address;
    servicePublicKey: bigint;
    contentNftItem: Cell;
};

export function minterConfigToCell(config: MinterConfig): Cell {
    return beginCell()
        .storeBit(config.isMinted)
        .storeUint(config.startTime, 32)
        .storeAddress(config.minterAddress)
        .storeAddress(config.ownerAddress)
        .storeUint(config.servicePublicKey, 256)
        .storeRef(config.contentNftItem)
        .endCell();
}

export class MinterItem implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new MinterItem(address);
    }

    static createFromConfig(config: MinterConfig, code: Cell, workchain = 0) {
        const data = minterConfigToCell(config);
        const init = { code, data };
        return new MinterItem(contractAddress(workchain, init), init);
    }

    async sendDeployWithMint(provider: ContractProvider, via: Sender, value: bigint, signature: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell()
                .storeUint(0x90231E2C, 32)
                .storeUint(0, 64)
                .storeUint(signature, 512)
                .endCell(),
        });
    }
}
