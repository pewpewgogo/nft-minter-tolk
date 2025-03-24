import "@stdlib/common.tolk"
import "op-codes.tolk"
import "params.tolk"
//
//  TON NFT Item Smart Contract
//

/*

    NOTE that this tokens can be transferred within the same workchain.

    This is suitable for most tokens, if you need tokens transferable between workchains there are two solutions:

    1) use more expensive but universal function to calculate message forward fee for arbitrary destination (see `misc/forward-fee-calc.cs`)

    2) use token holder proxies in target workchain (that way even 'non-universal' token can be used from any workchain)

*/

@pure
fun minTonsForStorage(): int
    asm "50000000 PUSHINT"; // 0.05 TON

//
//  Storage
//
//  uint64 index
//  MsgAddressInt collection_address
//  MsgAddressInt owner_address
//  cell content
//

fun loadData(): (int, int, slice, slice, cell) {
    var ds: slice = getContractData().beginParse();
    var (index, collectionAddress) = (ds.loadUint(64), ds.loadAddress());
    if (ds.getRemainingBitsCount() > 0) {
      return (-1, index, collectionAddress, ds.loadAddress(), ds.loadRef());
    } else {  
      return (0, index, collectionAddress, null, null); // nft not initialized yet
    }
}

fun storeData(index: int, collectionAddress: slice, ownerAddress: slice, content: cell) {
    setContractData(
        beginCell()
            .storeUint(index, 64)
            .storeSlice(collectionAddress)
            .storeSlice(ownerAddress)
            .storeRef(content)
            .endCell()
    );
}

@inline
fun sendMsg(toAddress: slice, amount: int, op: int, queryId: int, payload: builder, sendMode: int) {
  var msg = beginCell()
    .storeUint(0x10, 6) // nobounce - int_msg_info$0 ihr_disabled:Bool bounce:Bool bounced:Bool src:MsgAddress -> 010000
    .storeSlice(toAddress)
    .storeCoins(amount)
    .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
    .storeUint(op, 32)
    .storeUint(queryId, 64);

  if (payload != null) {
    msg = msg.storeBuilder(payload);
  }

  sendRawMessage(msg.endCell(), sendMode);
}

@inline
fun transferOwnership(myBalance: int, index: int, collectionAddress: slice, ownerAddress: slice, content: cell, senderAddress: slice, queryId: int, inMsgBody: slice, fwdFees: int) {
    assert(isSliceBitsEqual(senderAddress, ownerAddress)) throw 401;

    var newOwnerAddress: slice = inMsgBody.loadAddress();
    forceChain(newOwnerAddress);
    var responseDestination: slice = inMsgBody.loadAddress();
    inMsgBody.loadInt(1); // this nft don't use custom_payload
    var forwardAmount: int = inMsgBody.loadCoins();
    assert(getRemainingBitsCount(inMsgBody) >= 1) throw 708;

    var restAmount: int = myBalance - minTonsForStorage();
    if (forwardAmount) {
      restAmount -= (forwardAmount + fwdFees);
    }
    var needResponse: bool = responseDestination.preloadUint(2) != 0; // if NOT addr_none: 00
    if (needResponse) {
      restAmount -= fwdFees;
    }

    assert(restAmount >= 0) throw 402; // base nft spends fixed amount of gas, will not check for response

    if (forwardAmount) {
      sendMsg(newOwnerAddress, forwardAmount, `op::ownership_assigned`(), queryId, beginCell().storeSlice(ownerAddress).storeSlice(inMsgBody), 1);  // paying fees, revert on errors
    }
    if (needResponse) {
      forceChain(responseDestination);
      sendMsg(responseDestination, restAmount, `op::excesses`(), queryId, null, 1); // paying fees, revert on errors
    }

    storeData(index, collectionAddress, newOwnerAddress, content);
}

fun onInternalMessage(myBalance: int, msgValue: int, inMsgFull: cell, inMsgBody: slice) {
    if (inMsgBody.isEndOfSlice()) { // ignore empty messages
        return;
    }

    var cs: slice = inMsgFull.beginParse();
    var flags: int = cs.loadUint(4);

    if (flags & 1) { // ignore all bounced messages
        return;
    }
    var senderAddress: slice = cs.loadAddress();

    cs.loadAddress(); // skip dst
    cs.loadCoins(); // skip value
    cs.skipBits(1); // skip extracurrency collection
    cs.loadCoins(); // skip ihr_fee
    var fwdFee: int = mulDivFloor(cs.loadCoins(), 3, 2); // we use message fwd_fee for estimation of forward_payload costs


    var (isInit: int, index: int, collectionAddress: slice, ownerAddress: slice, content: cell) = loadData();
    if (!isInit) {
      assert(isSliceBitsEqual(collectionAddress, senderAddress)) throw 405;
      storeData(index, collectionAddress, inMsgBody.loadAddress(), inMsgBody.loadRef());
      return;
    }

    var op: int = inMsgBody.loadUint(32);
    var queryId: int = inMsgBody.loadUint(64);

    if (op == `op::transfer`()) {
      transferOwnership(myBalance, index, collectionAddress, ownerAddress, content, senderAddress, queryId, inMsgBody, fwdFee);
      return;
    }
    if (op == `op::get_static_data`()) {
      sendMsg(senderAddress, 0, `op::report_static_data`(), queryId, beginCell().storeUint(index, 256).storeSlice(collectionAddress), 64);  // carry all the remaining value of the inbound message
      return;
    }
    throw 0xffff;
}

//
//  GET Methods
//
get get_nft_data(): (int, int, slice, slice, cell) {
  var (isInit: int, index: int, collectionAddress: slice, ownerAddress: slice, content: cell) = loadData();
  return (isInit, index, collectionAddress, ownerAddress, content);
}
