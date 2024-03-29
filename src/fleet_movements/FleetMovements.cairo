%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from fleet_movements.library import FleetMovements, EspionageReport
from main.structs import Fleet, EspionageQue, AttackQue, Defence

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    no_game_address: felt
) {
    FleetMovements.initializer(no_game_address);
    return ();
}

@view
func getEspionageQueStatus{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, mission_id: felt
) -> (res: EspionageQue) {
    let res = FleetMovements.get_espionage_que_status(caller, mission_id);
    return (res,);
}

@view
func getAttackQueStatus{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, mission_id: felt
) -> (res: AttackQue) {
    let res = FleetMovements.get_attack_que_status(caller, mission_id);
    return (res,);
}

@external
func sendSpyMission{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, ships: Fleet, destination: Uint256
) -> (mission_id: felt, fuel_consumption: felt) {
    let (mission_id, fuel_consumption) = FleetMovements.send_spy_mission(
        caller, ships, destination
    );
    return (mission_id, fuel_consumption);
}

@external
func readEspionageReport{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, mission_id: felt
) -> (res: EspionageReport) {
    let res = FleetMovements.read_espionage_report(caller, mission_id);
    return (res,);
}

@external
func sendAttackMission{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, ships: Fleet, destination: Uint256
) -> (mission_id: felt, fuel_consumption: felt) {
    let (mission_id, fuel_consumption) = FleetMovements.send_attack_mission(
        caller, ships, destination
    );
    return (mission_id, fuel_consumption);
}

@external
func launchAttack{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, mission_id: felt
) -> (
    new_attacker_fleet: Fleet,
    attacker_lost_fleet: Fleet,
    new_defender_fleet: Fleet,
    defender_lost_fleet: Fleet,
    new_defender_defences: Defence,
    defender_lost_defences: Defence,
) {
    let (
        new_attacker_fleet,
        attacker_lost_fleet,
        new_defender_fleet,
        defender_lost_fleet,
        new_defender_defences,
        defender_lost_defences,
    ) = FleetMovements.launch_attack(caller, mission_id);
    return (
        new_attacker_fleet,
        attacker_lost_fleet,
        new_defender_fleet,
        defender_lost_fleet,
        new_defender_defences,
        defender_lost_defences,
    );
}
