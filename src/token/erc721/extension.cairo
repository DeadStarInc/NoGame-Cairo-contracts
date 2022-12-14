%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_check

@storage_var
func ERC721_nogame_owner_to_id(owner: felt) -> (token_id: Uint256) {
}

namespace ERC721_nogame {
    func assert_no_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        balance: Uint256
    ) {
        with_attr error_message("ERC721_nogame: balance is not a valid Uint256") {
            uint256_check(balance);
        }
        with_attr error_message("ERC721_nogame: receiver already owns a token") {
            assert balance.low = 0;
        }
        return ();
    }

    func owner_to_planet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> Uint256 {
        let (token_id) = ERC721_nogame_owner_to_id.read(caller);
        with_attr error_message("ERC721_nogame: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        return token_id;
    }

    func update_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt, to: felt, token_id: Uint256
    ) {
        with_attr error_message("ERC721_nogame: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        ERC721_nogame_owner_to_id.write(from_, Uint256(0, 0));
        ERC721_nogame_owner_to_id.write(to, token_id);
        return ();
    }
}
