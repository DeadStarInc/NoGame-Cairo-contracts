%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from main.structs import TechCosts, ResearchQue
from research.library import ResearchLab

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    no_game_address: felt
) {
    ResearchLab.initializer(no_game_address);
    return ();
}

@external
func getQueStatus{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (status: ResearchQue) {
    let (res) = ResearchLab.que_status(caller);
    return (res,);
}

@external
func getUpgradesCost{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (costs: TechCosts) {
    alloc_locals;
    let (costs) = ResearchLab.upgrades_cost(caller);
    return (costs,);
}

// ######### UPGRADES FUNCS ############################

@external
func energyTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.energy_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func energyTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.energy_tech_upgrade_complete(caller);
    return ();
}

@external
func computerTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.computer_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func computerTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.computer_tech_upgrade_complete(caller);
    return ();
}

@external
func laserTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.laser_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func laserTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.laser_tech_upgrade_complete(caller);
    return ();
}

@external
func armourTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.armour_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func armourTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.armour_tech_upgrade_complete(caller);
    return ();
}

@external
func ionTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.ion_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func ionTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.ion_tech_upgrade_complete(caller);
    return ();
}

@external
func espionageTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.espionage_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func espionageTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.espionage_tech_upgrade_complete(caller);
    return ();
}

@external
func plasmaTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.plasma_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func plasmaTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.plasma_tech_upgrade_complete(caller);
    return ();
}

@external
func weaponsTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.weapons_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func weaponsTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.weapons_tech_upgrade_complete(caller);
    return ();
}

@external
func shieldingTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.shielding_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func shieldingTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.shielding_tech_upgrade_complete(caller);
    return ();
}

@external
func hyperspaceTechUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.hyperspace_tech_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func hyperspaceTechUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.hyperspace_tech_upgrade_complete(caller);
    return ();
}

@external
func astrophysicsUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.astrophysics_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func astrophysicsUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.astrophysics_upgrade_complete(caller);
    return ();
}

@external
func combustionDriveUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.combustion_drive_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func combustionDriveUpgradeComplete{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(caller: felt) {
    ResearchLab.combustion_drive_upgrade_complete(caller);
    return ();
}

@external
func hyperspaceDriveUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.hyperspace_drive_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func hyperspaceDriveUpgradeComplete{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(caller: felt) {
    ResearchLab.hyperspace_drive_upgrade_complete(caller);
    return ();
}

@external
func impulseDriveUpgradeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, current_tech_level: felt
) -> (metal: felt, crystal: felt, deuterium: felt, time_end: felt) {
    let (
        metal_required, crystal_required, deuterium_required, time_end
    ) = ResearchLab.impulse_drive_upgrade_start(caller, current_tech_level);
    return (metal_required, crystal_required, deuterium_required, time_end);
}

@external
func impulseDriveUpgradeComplete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    ResearchLab.impulse_drive_upgrade_complete(caller);
    return ();
}
