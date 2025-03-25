// Minter utils
@inline
fun packMinterItemData(ownerAddress: slice, minterAddress: slice, publicKey: int, startTime: int, content: cell): cell {
  return beginCell()
      .storeBool(false)
      .storeUint(startTime, 32)
      .storeSlice(minterAddress)
      .storeSlice(ownerAddress)
      .storeUint(publicKey, 256)
      .storeRef(content)
  .endCell();
}

@inline
fun calculateMinterItemStateInit(ownerAddress: slice, minterAddress: slice, publicKey: int, startTime: int, content: cell, minterItemCode: cell): cell {
  return beginCell()
  .storeUint(0, 2)
  .storeDict(minterItemCode)
  .storeDict(packMinterItemData(ownerAddress, minterAddress, publicKey, startTime, content))
  .storeUint(0, 1)
  .endCell();
}

@inline
fun calculateAddress(stateInit: cell): slice {
  return beginCell().storeUint(4, 3)
  .storeInt(0, 8)
  .storeUint(stateInit.cellHash(), 256)
  .endCell()
  .beginParse();
}

@inline
fun calculateMinterItemAddress(ownerAddress: slice, minterAddress: slice, publicKey: int, startTime: int, content: cell, minterItemCode: cell): slice {
  return calculateAddress(calculateMinterItemStateInit(ownerAddress, minterAddress, publicKey, startTime, content, minterItemCode));
}