@pure
fun `op::transfer`(): int
    asm "0x5fcc3d14 PUSHINT";
@pure
fun `op::ownership_assigned`(): int
    asm "0x05138d91 PUSHINT";
@pure
fun `op::excesses`(): int
    asm "0xd53276db PUSHINT";
@pure
fun `op::get_static_data`(): int
    asm "0x2fcb26a2 PUSHINT";
@pure
fun `op::report_static_data`(): int
    asm "0x8b771735 PUSHINT";
@pure
fun `op::get_royalty_params`(): int
    asm "0x693d3950 PUSHINT";
@pure
fun `op::report_royalty_params`(): int
    asm "0xa8cb00ad PUSHINT";

// NFTEditable
@pure
fun `op::edit_content`(): int
    asm "0x1a0b9d51 PUSHINT";
@pure
fun `op::transfer_editorship`(): int
    asm "0x1c04412a PUSHINT";
@pure
fun `op::editorship_assigned`(): int
    asm "0x511a4463 PUSHINT";
