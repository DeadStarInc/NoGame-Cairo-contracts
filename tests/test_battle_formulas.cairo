%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from main.structs import Fleet, Defence
from shipyard.ships_performance import FleetPerformance

from fleet_movements.library import (
    get_total_defences_shield_power,
    get_total_defences_structural_power,
    get_total_defences_weapons_power,
    get_total_fleet_shield_power,
    get_total_fleet_structural_integrity,
    get_total_fleet_weapon_power,
    calculate_battle_outcome,
    calculate_attacker_damage,
    calculate_defender_damage,
    get_number_of_ships,
    get_damaged_ships,
    calculate_new_fleet,
)

@external
func test_battle_round{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let ATTACKER_FLEET = Fleet(10, 0, 0, 0, 0, 0, 10, 0);
    let DEFENDER_FLEET = Fleet(0, 0, 0, 10, 0, 0, 0, 0);
    let DEFENCES = Defence(10, 0, 0, 0, 0, 0, 0, 0);
    let expected = (att_points_left=601600, def_points_left=0);
    let actual = calculate_battle_outcome(ATTACKER_FLEET, DEFENDER_FLEET, DEFENCES);
    assert expected = actual;

    let att_damage = calculate_attacker_damage(ATTACKER_FLEET, actual[0]);
    assert att_damage = 40500;

    let def_damage = calculate_defender_damage(DEFENDER_FLEET, DEFENCES, actual[1]);
    assert def_damage = 40210;
    return ();
}

@external
func test_get_different_ships{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let ATTACKER_FLEET = Fleet(1, 0, 0, 0, 0, 0, 0, 0);
    let actual = get_number_of_ships(ATTACKER_FLEET);
    assert actual = 1;

    let ATTACKER_FLEET = Fleet(1, 1, 0, 0, 0, 0, 0, 0);
    let actual = get_number_of_ships(ATTACKER_FLEET);
    assert actual = 2;

    let ATTACKER_FLEET = Fleet(1, 1, 1, 0, 0, 0, 0, 0);
    let actual = get_number_of_ships(ATTACKER_FLEET);
    assert actual = 3;

    let ATTACKER_FLEET = Fleet(1, 1, 1, 1, 0, 0, 0, 0);
    let actual = get_number_of_ships(ATTACKER_FLEET);
    assert actual = 4;

    let ATTACKER_FLEET = Fleet(1, 1, 1, 1, 1, 0, 0, 0);
    let actual = get_number_of_ships(ATTACKER_FLEET);
    assert actual = 5;

    let ATTACKER_FLEET = Fleet(1, 1, 1, 1, 1, 1, 0, 0);
    let actual = get_number_of_ships(ATTACKER_FLEET);
    assert actual = 6;

    let ATTACKER_FLEET = Fleet(1, 1, 1, 1, 1, 1, 1, 0);
    let actual = get_number_of_ships(ATTACKER_FLEET);
    assert actual = 7;

    let ATTACKER_FLEET = Fleet(1, 1, 1, 1, 1, 1, 1, 1);
    let actual = get_number_of_ships(ATTACKER_FLEET);
    assert actual = 8;

    return ();
}

@external
func test_get_damaged_ships{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let n_ships = 10;
    let integrity = FleetPerformance.Cargo.structural_integrity;
    let shield = FleetPerformance.Cargo.shield_power;

    let damage = 2000;
    let actual = get_damaged_ships(n_ships, integrity, shield, damage);
    assert actual = 0;

    let damage = 4000;
    let actual = get_damaged_ships(n_ships, integrity, shield, damage);
    assert actual = 0;

    let damage = 6000;
    let actual = get_damaged_ships(n_ships, integrity, shield, damage);
    assert actual = 1;

    let damage = 8000;
    let actual = get_damaged_ships(n_ships, integrity, shield, damage);
    assert actual = 1;

    let damage = 40000;
    let actual = get_damaged_ships(0, integrity, shield, damage);
    assert actual = 0;

    return ();
}

@external
func test_calculate_new_fleet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let fleet = Fleet(10, 10, 0, 0, 0, 0, 0, 0);
    let damaged = Fleet(2, 3, 0, 0, 0, 0, 0, 0);
    let new_fleet = calculate_new_fleet(fleet, damaged);
    assert new_fleet = Fleet(8, 7, 0, 0, 0, 0, 0, 0);

    return ();
}

@external
func test_fleet_shield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let FLEET = Fleet(10, 0, 0, 0, 0, 0, 0, 0);
    let expected = 100;
    let actual = get_total_fleet_shield_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 0, 0, 0, 0, 0, 0);
    let expected = 200;
    let actual = get_total_fleet_shield_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 0, 0, 0, 0, 0);
    let expected = 200;
    let actual = get_total_fleet_shield_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 0, 0, 0, 0);
    let expected = 210;
    let actual = get_total_fleet_shield_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 0, 0, 0);
    let expected = 310;
    let actual = get_total_fleet_shield_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 10, 0, 0);
    let expected = 810;
    let actual = get_total_fleet_shield_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 10, 10, 0);
    let expected = 2810;
    let actual = get_total_fleet_shield_power(FLEET);
    assert expected = actual;

    return ();
}

@external
func test_fleet_struct{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let FLEET = Fleet(10, 0, 0, 0, 0, 0, 0, 0);
    let expected = 40000;
    let actual = get_total_fleet_structural_integrity(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 0, 0, 0, 0, 0, 0);
    let expected = 200000;
    let actual = get_total_fleet_structural_integrity(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 0, 0, 0, 0, 0);
    let expected = 210000;
    let actual = get_total_fleet_structural_integrity(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 0, 0, 0, 0);
    let expected = 230000;
    let actual = get_total_fleet_structural_integrity(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 0, 0, 0);
    let expected = 270000;
    let actual = get_total_fleet_structural_integrity(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 10, 0, 0);
    let expected = 540000;
    let actual = get_total_fleet_structural_integrity(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 10, 10, 0);
    let expected = 1140000;
    let actual = get_total_fleet_structural_integrity(FLEET);
    assert expected = actual;

    return ();
}

@external
func test_fleet_weapons{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let FLEET = Fleet(10, 0, 0, 0, 0, 0, 0, 0);
    let expected = 50;
    let actual = get_total_fleet_weapon_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 0, 0, 0, 0, 0, 0);
    let expected = 60;
    let actual = get_total_fleet_weapon_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 0, 0, 0, 0, 0);
    let expected = 60;
    let actual = get_total_fleet_weapon_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 0, 0, 0, 0);
    let expected = 70;
    let actual = get_total_fleet_weapon_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 0, 0, 0);
    let expected = 570;
    let actual = get_total_fleet_weapon_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 10, 0, 0);
    let expected = 4570;
    let actual = get_total_fleet_weapon_power(FLEET);
    assert expected = actual;

    let FLEET = Fleet(10, 10, 10, 10, 10, 10, 10, 0);
    let expected = 14570;
    let actual = get_total_fleet_weapon_power(FLEET);
    assert expected = actual;

    return ();
}

@external
func test_defence_shield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let DEFENCES = Defence(10, 0, 0, 0, 0, 0, 0, 0);
    let expected = 200;
    let actual = get_total_defences_shield_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 0, 0, 0, 0, 0, 0);
    let expected = 450;
    let actual = get_total_defences_shield_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 0, 0, 0, 0, 0);
    let expected = 1450;
    let actual = get_total_defences_shield_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 0, 0, 0, 0);
    let expected = 6450;
    let actual = get_total_defences_shield_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 0, 0, 0);
    let expected = 8450;
    let actual = get_total_defences_shield_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 0, 0);
    let expected = 11450;
    let actual = get_total_defences_shield_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 1, 0);
    let expected = 13450;
    let actual = get_total_defences_shield_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 1, 1);
    let expected = 23450;
    let actual = get_total_defences_shield_power(DEFENCES);
    assert expected = actual;

    return ();
}

@external
func test_defence_struct{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let DEFENCES = Defence(10, 0, 0, 0, 0, 0, 0, 0);
    let expected = 20000;
    let actual = get_total_defences_structural_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 0, 0, 0, 0, 0, 0);
    let expected = 40000;
    let actual = get_total_defences_structural_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 0, 0, 0, 0, 0);
    let expected = 120000;
    let actual = get_total_defences_structural_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 0, 0, 0, 0);
    let expected = 200000;
    let actual = get_total_defences_structural_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 0, 0, 0);
    let expected = 550000;
    let actual = get_total_defences_structural_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 0, 0);
    let expected = 1550000;
    let actual = get_total_defences_structural_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 1, 0);
    let expected = 1570000;
    let actual = get_total_defences_structural_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 1, 1);
    let expected = 1670000;
    let actual = get_total_defences_structural_power(DEFENCES);
    assert expected = actual;

    return ();
}

@external
func test_defence_weapons{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let DEFENCES = Defence(10, 0, 0, 0, 0, 0, 0, 0);
    let expected = 800;
    let actual = get_total_defences_weapons_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 0, 0, 0, 0, 0, 0);
    let expected = 1800;
    let actual = get_total_defences_weapons_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 0, 0, 0, 0, 0);
    let expected = 4300;
    let actual = get_total_defences_weapons_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 0, 0, 0, 0);
    let expected = 5800;
    let actual = get_total_defences_weapons_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 0, 0, 0);
    let expected = 16800;
    let actual = get_total_defences_weapons_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 0, 0);
    let expected = 46800;
    let actual = get_total_defences_weapons_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 1, 0);
    let expected = 46801;
    let actual = get_total_defences_weapons_power(DEFENCES);
    assert expected = actual;

    let DEFENCES = Defence(10, 10, 10, 10, 10, 10, 1, 1);
    let expected = 46802;
    let actual = get_total_defences_weapons_power(DEFENCES);
    assert expected = actual;

    return ();
}
