import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Cell, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { MinterItem } from '../wrappers/MinterItem';
import nacl from 'tweetnacl';
import { convertPublicKeyToBigInt } from '../wrappers/utils';

describe('MinterItem', () => {
    let code: Cell;

    beforeAll(async () => {
        code = await compile('MinterItem');
    });

    let blockchain: Blockchain;
    let minter: SandboxContract<TreasuryContract>;
    let minterItem: SandboxContract<MinterItem>;
    let owner: SandboxContract<TreasuryContract>;
    let keys;
    const content = beginCell().storeStringTail('https://example.com/nft.json').endCell()

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        owner = await blockchain.treasury('owner');
        minter = await blockchain.treasury('minter');
        keys = nacl.sign.keyPair();

        minterItem = blockchain.openContract(MinterItem.createFromConfig({
            isMinted: false,
            startTime: BigInt(Math.floor(new Date().getTime() / 1000)),
            minterAddress: minter.address,
            ownerAddress: owner.address,
            servicePublicKey: convertPublicKeyToBigInt(keys.publicKey),
            contentNftItem: content,
        }, code));

        const signature = BigInt('0x' + Buffer.from(nacl.sign.detached(content.hash(), keys.secretKey)).toString('hex'));
        const deployResult = await minterItem.sendDeployWithMint(owner.getSender(), toNano('2'), signature);

        expect(deployResult.transactions).toHaveTransaction({
            from: owner.address,
            to: minterItem.address,
            deploy: true,
            success: true,
            outMessagesCount: 1,
        });

        expect(deployResult.transactions).toHaveTransaction({
            from: minterItem.address,
            to: minter.address,
        })
    });

    it('should deploy', async () => {
        const user = await blockchain.treasury('user');
    });
});
