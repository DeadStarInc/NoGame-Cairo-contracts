%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from main.structs import Cost
from resources.library import Resources

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    no_game_address: felt
) {
    Resources.initializer(no_game_address);
    return ();
}

@external
func metalUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (metal: felt, crystal: felt, time_unlocked: felt) {
    let (metal_required, crystal_required, time_unlocked) = Resources.metal_upgrade_start(caller);
    return (metal_required, crystal_required, time_unlocked);
}

@external
func metalUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (success: felt) {
    Resources.metal_upgrade_complete(caller);
    return (TRUE,);
}

@external
func crystalUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (metal: felt, crystal: felt, time_unlocked: felt) {
    let (metal_required, crystal_required, time_unlocked) = Resources.crystal_upgrade_start(caller);
    return (metal_required, crystal_required, time_unlocked);
}

@external
func crystalUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (success: felt) {
    Resources.crystal_upgrade_complete(caller);
    return (TRUE,);
}

@external
func deuteriumUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (metal: felt, crystal: felt, time_unlocked: felt) {
    let (metal_required, crystal_required, time_unlocked) = Resources.deuterium_upgrade_start(
        caller
    );
    return (metal_required, crystal_required, time_unlocked);
}

@external
func deuteriumUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (success: felt) {
    Resources.deuterium_upgrade_complete(caller);
    return (TRUE,);
}

@external
func solarPlantUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (metal: felt, crystal: felt, time_unlocked: felt) {
    let (metal_required, crystal_required, time_unlocked) = Resources.solar_plant_upgrade_start(
        caller
    );
    return (metal_required, crystal_required, time_unlocked);
}

@external
func solarPlantUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (success: felt) {
    Resources.solar_plant_upgrade_complete(caller);
    return (TRUE,);
}

@external
func getUpgradeCost{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (metal_mine: Cost, crystal_mine: Cost, deuterium_mine: Cost, solar_plant: Cost) {
    let (metal, crystal, deuterium, solar_plant) = Resources.upgrades_cost(caller);
    return (metal, crystal, deuterium, solar_plant);
}
