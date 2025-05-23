import "@stdlib/tvm-dicts"
import "op-codes.tolk"
// NFT collection smart contract

// storage scheme
// default#_ royalty_factor:uint16 royalty_base:uint16 royalty_address:MsgAddress = RoyaltyParams;
// storage#_ owner_address:MsgAddress next_item_index:uint64
//           ^[collection_content:^Cell common_content:^Cell]
//           nft_item_code:^Cell
//           royalty_params:^RoyaltyParams
//           = Storage;

@inline
fun loadData(): (slice, int, cell, cell, cell) {
  var ds = getContractData().beginParse();
  return 
    (ds.loadAddress(), // owner_address
     ds.loadUint(64), // next_item_index
     ds.loadRef(), // content
     ds.loadRef(), // nft_item_code
     ds.loadRef()  // royalty_params
     );
}

@inline
fun saveData(ownerAddress: slice, nextItemIndex: int, content: cell, nftItemCode: cell, royaltyParams: cell) {
  setContractData(beginCell()
    .storeSlice(ownerAddress)
    .storeUint(nextItemIndex, 64)
    .storeRef(content)
    .storeRef(nftItemCode)
    .storeRef(royaltyParams)
    .endCell());
}

fun calculateNftItemStateInit(itemIndex: int, nftItemCode: cell): cell {
  var data: cell = beginCell().storeUint(itemIndex, 64).storeSlice(getMyAddress()).endCell();
  return beginCell().storeUint(0, 2).storeDict(nftItemCode).storeDict(data).storeUint(0, 1).endCell();
}

fun calculateNftItemAddress(wc: int, stateInit: cell): slice {
  return beginCell().storeUint(4, 3)
                     .storeInt(wc, 8)
                     .storeUint(cellHash(stateInit), 256)
                     .endCell()
                     .beginParse();
}

fun deployNftItem(itemIndex: int, nftItemCode: cell, amount: int, nftContent: cell) {
  var stateInit: cell = calculateNftItemStateInit(itemIndex, nftItemCode);
  var nftAddress: slice = calculateNftItemAddress(BASECHAIN, stateInit);
  var msg = beginCell()
            .storeUint(0x18, 6)
            .storeSlice(nftAddress)
            .storeCoins(amount)
            .storeUint(4 + 2 + 1, 1 + 4 + 4 + 64 + 32 + 1 + 1 + 1)
            .storeRef(stateInit)
            .storeRef(nftContent);
  sendRawMessage(msg.endCell(), 1); // pay transfer fees separately, revert on errors
}

@inline
fun sendRoyaltyParams(toAddress: slice, queryId: int, data: slice) {
  var msg = beginCell()
    .storeUint(0x10, 6) // nobounce - int_msg_info$0 ihr_disabled:Bool bounce:Bool bounced:Bool src:MsgAddress -> 011000
    .storeSlice(toAddress)
    .storeCoins(0)
    .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
    .storeUint(`op::report_royalty_params`(), 32)
    .storeUint(queryId, 64)
    .storeSlice(data);
  sendRawMessage(msg.endCell(), 64); // carry all the remaining value of the inbound message
}

fun onInternalMessage(inMsgFull: cell, inMsgBody: slice) {
    if (inMsgBody.isEndOfSlice()) { // ignore empty messages
        return;
    }
    var cs: slice = inMsgFull.beginParse();
    var flags: int = cs.loadUint(4);
    
    if (flags & 1) { // ignore all bounced messages
        return;
    }
    var senderAddress: slice = cs.loadAddress();

    var op: int = inMsgBody.loadUint(32);
    var queryId: int = inMsgBody.loadUint(64);

    var (ownerAddress, nextItemIndex, content, nftItemCode, royaltyParams) = loadData();

    if (op == `op::get_royalty_params`()) {
        sendRoyaltyParams(senderAddress, queryId, royaltyParams.beginParse());
        return;
    }

    assert(isSliceBitsEqual(senderAddress, ownerAddress)) throw 401;
    
  
    if (op == 1) { // deploy new nft
        deployNftItem(nextItemIndex, nftItemCode, inMsgBody.loadCoins(), inMsgBody.loadRef());
        nextItemIndex += 1;
        saveData(ownerAddress, nextItemIndex, content, nftItemCode, royaltyParams);
      return;
    }
    if (op == 2) { // batch deploy of new nfts
      var counter: int = 0;
      var deployList: cell = inMsgBody.loadRef();
      do {
        var (inMsgItemIndex, item, isF) = deployList.uDictDeleteFirstAndGet(64);
        if (isF) {
          counter += 1;
          if (counter >= 250) { // Limit due to limits of action list size
            throw 399;
          }

          deployNftItem(nextItemIndex, nftItemCode, item.loadCoins(), item.loadRef());
          nextItemIndex += 1;
        }
      } while (!isF);
      saveData(ownerAddress, nextItemIndex, content, nftItemCode, royaltyParams);
      return;
    }
    if (op == 3) { // change owner
      var newOwner: slice = inMsgBody.loadAddress();
      saveData(newOwner, nextItemIndex, content, nftItemCode, royaltyParams);
      return;
    }
    throw 0xffff;
}

// Get methods

get get_collection_data(): (int, cell, slice) {
  var (ownerAddress, nextItemIndex, content, _, _) = loadData();
  var cs: slice = content.beginParse();
  return (nextItemIndex, cs.loadRef(), ownerAddress);
}

get get_nft_address_by_index(index: int): slice {
    var (_, _, _, nftItemCode, _) = loadData();
    var stateInit: cell = calculateNftItemStateInit(index, nftItemCode);
    return calculateNftItemAddress(BASECHAIN, stateInit);
}

get royalty_params(): (int, int, slice) {
     var (_, _, _, _, royalty) = loadData();
     var rs: slice = royalty.beginParse();
     return (rs.loadUint(16), rs.loadUint(16), rs.loadAddress());
}

get get_nft_content(index: int, individualNftContent: cell): cell {
  var (_, _, content, _, _) = loadData();
  var cs: slice = content.beginParse();
  cs.loadRef();
  var commonContent: slice = cs.loadRef().beginParse();
  return (beginCell()
                      .storeUint(1, 8) // offchain tag
                      .storeSlice(commonContent)
                      .storeRef(individualNftContent)
          .endCell());
}
