import "@stdlib/common.tolk"
import "imports/op.tolk"
import "imports/minter_utils.tolk"

const oneDay: int = 86400;

global ctxIsMinted: bool;
global ctxStartTime: int;
global ctxMinterAddress: slice;
global ctxOwnerAddress: slice;
global ctxServicePublicKey: int;
global ctxContentNftItem: cell;

@inline
fun loadData() {
    var ds: slice = getContractData().beginParse();
        ctxIsMinted = ds.loadBool();
        ctxStartTime = ds.loadUint(32);
        ctxMinterAddress = ds.loadAddress();
        ctxOwnerAddress = ds.loadAddress();
        ctxServicePublicKey = ds.loadUint(256);
        ctxContentNftItem = ds.loadRef();
    ds.assertEndOfSlice();
}

@inline
fun saveData() {
    setContractData(
        beginCell()
            .storeBool(ctxIsMinted)
            .storeUint(ctxStartTime, 32)
            .storeSlice(ctxMinterAddress)
            .storeSlice(ctxOwnerAddress)
            .storeUint(ctxServicePublicKey, 256)
            .storeRef(ctxContentNftItem)
        .endCell()
    );
}

@inline
fun mintItem(queryId: int) {
    var msg: cell = beginCell()
        .storeUint(BOUNCEABLE, 6)
        .storeSlice(ctxMinterAddress)
        .storeCoins(0)
        .storeUint(1, 107)
        .storeRef(
            beginCell()
                .storeUint(opInternalMintItem, 32)
                .storeUint(queryId, 64)
                .storeSlice(ctxOwnerAddress)
                .storeRef(ctxContentNftItem)
            .endCell()
        )
        .endCell();
    sendMessage(msg, SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

@inline
fun isMintAllowed(): bool {
    if (now() < ctxStartTime) {
        return false;
    }
    if (now() > ctxStartTime + oneDay * 7) {
        return false;
    }
    return true;
}

@inline
fun calculatePrice(): int {
    if (now() > ctxStartTime + oneDay * 7) {
        return ton("20"); // 20 TON
    }
    if (now() > ctxStartTime + oneDay * 6) {
        return ton("15"); // 15 TON
    }
    if (now() > ctxStartTime + oneDay * 5) {
        return ton("10"); // 10 TON
    }
    if (now() > ctxStartTime + oneDay * 4) {
        return ton("8"); // 8 TON
    }
    if (now() > ctxStartTime + oneDay * 3) {
        return ton("5"); // 5 TON
    }
    if (now() > ctxStartTime + oneDay * 2) {
        return ton("3"); // 3 TON
    }
    if (now() > ctxStartTime + oneDay) {
        return ton("2"); // 2 TON
    }
    return ton("1"); // 1 TON
}

@inline
fun verifySignature(signature: slice): bool {
    return isSignatureValid(ctxContentNftItem.cellHash(), signature, ctxServicePublicKey);
}

fun onInternalMessage(msgValue: int, inMsgFull: cell, inMsgBody: slice) {
    if (inMsgBody.isEndOfSlice()) { // ignore empty messages
      return;
    }

    var cs: slice = inMsgFull.beginParse();
    val flags: int = cs.loadMessageFlags();
    if (isMessageBounced(flags)) {
      return;
    }

    var fromAddress: slice = cs.loadAddress();
    var op: int = inMsgBody.loadMessageOp();
    var queryId: int = inMsgBody.loadMessageQueryId();

    if (op == opMintItem) {
        loadData();
        // todo: gas checking
        assert(ctxIsMinted == false) throw errorMintedAlready;
        assert(isSliceBitsEqual(fromAddress, ctxOwnerAddress)) throw errorNotOwnerTryingToMint;
        assert(isMintAllowed()) throw errorMintNotAllowed;
        assert(msgValue >= calculatePrice()) throw errorNotEnoughFundsToMint;

        val signature = inMsgBody.loadBits(512);
        assert(verifySignature(signature)) throw errorSignatureInvalid;

        ctxIsMinted = true;
        saveData();
        mintItem(queryId);
        return;
    }

  throw 999;
}