import { toNano } from '@ton/core';
import { Minter } from '../wrappers/Minter';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const minter = provider.open(Minter.createFromConfig({

    }, await compile('MinterItem')));

    await minter.sendDeploy(provider.sender(), toNano('0.05'));

    await provider.waitForDeploy(minter.address);

    // run methods on `minter`
}
