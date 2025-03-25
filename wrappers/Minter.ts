import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export type MinterConfig = {
    adminAddress: Address;
    collectionAddress: Address;
    servicePublicKey: bigint;
    startTime: bigint;
    minterItemCode: Cell;
};

export function minterConfigToCell(config: MinterConfig): Cell {
    return beginCell()
        .storeAddress(config.adminAddress)
        .storeAddress(config.collectionAddress)
        .storeUint(config.servicePublicKey, 256)
        .storeUint(config.startTime, 32)
        .storeRef(config.minterItemCode)
    .endCell();
}

export class Minter implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new Minter(address);
    }

    static createFromConfig(config: MinterConfig, code: Cell, workchain = 0) {
        const data = minterConfigToCell(config);
        const init = { code, data };
        return new Minter(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }
}
