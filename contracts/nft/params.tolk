import "@stdlib/common.tolk"

@inline
fun forceChain(addr: slice) {
  var (wc: int, _) = parseStandardAddress(addr);
  assert(wc == BASECHAIN) throw 333;
}
