export const convertPublicKeyToBigInt = (publicKey: Uint8Array): bigint => {
    const hex = Buffer.from(publicKey).toString('hex');
    return BigInt('0x' + hex);
}