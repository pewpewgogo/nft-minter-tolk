import "@stdlib/common.tolk"

const opMintItem = stringCrc32("mintItem"); // 0x90231E2C
const opInternalMintItem = stringCrc32("internalMintItem"); // 0x0505DC31
const opAdminClaim = stringCrc32("adminClaim"); // 0x1B9403D8

const errorMintNotAllowed = 201;
const errorNotOwnerTryingToMint = 202;
const errorNotEnoughFundsToMint = 203;
const errorMintedAlready = 204;
const errorSignatureInvalid = 205;
const errorMintItemAddressMismatch = 206;
const errorNotAdmin = 207;
const errorNotEnoughBalance = 208;