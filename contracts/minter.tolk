import "@stdlib/common.tolk"
import "imports/op.tolk"
import "imports/minter_utils.tolk"

global ctxAdminAddress: slice;
global ctxCollectionAddress: slice;
global ctxServicePublicKey: int;
global ctxStartTime: int;
global ctxMinterItemCode: cell;

@inline
fun loadData() {
  var ds: slice = getContractData().beginParse();
  ctxAdminAddress = ds.loadAddress();
  ctxCollectionAddress = ds.loadAddress();
  ctxServicePublicKey = ds.loadUint(256);
  ctxStartTime = ds.loadUint(32);
  ctxMinterItemCode = ds.loadRef();
  ds.assertEndOfSlice();
}

// @inline
// fun saveData() {
//   setContractData(
//     beginCell()
//       .storeSlice(ctxAdminAddress)
//       .storeSlice(ctxCollectionAddress)
//       .storeUint(ctxServicePublicKey)
//         .storeUint(ctxStartTime, 32)
//       .storeRef(ctxMinterItemCode)
//     .endCell()
//   );
// }

@inline
fun sendTon(to: slice, amount: int) {
  var msg: cell = beginCell()
            .storeUint(NON_BOUNCEABLE, 6)
            .storeSlice(to)
            .storeCoins(amount)
            .storeUint(0, 107)
            .endCell();
    sendMessage(msg, SEND_MODE_IGNORE_ERRORS | SEND_MODE_PAY_FEES_SEPARATELY);
}

@inline
fun sendMintItem(toUser: slice, content: cell, queryId: int) {
    var msg: cell = beginCell()
        .storeUint(BOUNCEABLE, 6)
        .storeSlice(ctxCollectionAddress)
        .storeCoins(0)
        .storeUint(1, 107)
        .storeRef(
            beginCell()
                .storeUint(1, 32) // mint item
                .storeUint(queryId, 64)
                .storeUint(0, 64) // item index (not used with this type of collection)
                .storeCoins(ton("0.05")) // (todo: Maybe less?)
                .storeRef(content)
            .endCell()
        )
        .endCell();
    sendMessage(msg, SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

fun onInternalMessage(inMsgFull: cell, inMsgBody: slice) {
    if (inMsgBody.isEndOfSlice()) { // ignore empty messages
      return;
    }

    var cs: slice = inMsgFull.beginParse();
    val flags: int = cs.loadMessageFlags();
    if (isMessageBounced(flags)) {
      return;
    }

    val fromAddress: slice = cs.loadAddress();
    val op: int = inMsgBody.loadMessageOp();
    val queryId: int = inMsgBody.loadMessageQueryId();

    if (op == opInternalMintItem) {
      var (toUser: slice, content: cell) = (inMsgBody.loadAddress(), inMsgBody.loadRef());
      loadData();
      val minterItemAddress = calculateMinterItemAddress(toUser, getMyAddress(), ctxServicePublicKey, ctxStartTime, content, ctxMinterItemCode);
      assert(isSliceBitsEqual(fromAddress, minterItemAddress)) throw errorMintItemAddressMismatch;

      sendMintItem(toUser, content, queryId);
      return;
    }

    if (op == opAdminClaim) {
        loadData();
        assert(isSliceBitsEqual(fromAddress, ctxAdminAddress)) throw errorNotAdmin;
        val toSendAmount: int = getMyOriginalBalance() - ton("0.1");
        assert(toSendAmount > 0) throw errorNotEnoughBalance;

        sendTon(ctxAdminAddress, toSendAmount);
        return;
    }

  throw 999;
}