%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.bool import TRUE

func safe_ships_sub{range_check_ptr}(lhs: felt, rhs: felt) -> felt {
    let (valid) = is_le_felt(rhs, lhs);
    if (valid == TRUE) {
        return lhs - rhs;
    } else {
        return 0;
    }
}
