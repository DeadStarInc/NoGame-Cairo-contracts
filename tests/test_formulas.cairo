%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from resources.library import (
    _metal_building_cost,
    _crystal_building_cost,
    _deuterium_building_cost,
    _solar_plant_building_cost,
)
from fleet_movements.library import (
    calculate_distance,
    calculate_travel_time,
    calculate_speed,
    fuel_consumption_formula,
    calculate_fuel_consumption,
    get_ship_consumption,
)
from shipyard.ships_performance import FleetPerformance
from main.structs import Fleet
from utils.formulas import Formulas
from facilities.library import _set_timelock_and_que
from tests.setup import get_expected_cost

@external
func test_metal{syscall_ptr: felt*, range_check_ptr}() {
    let (metal, crystal) = _metal_building_cost(1);
    let (exp_metal, exp_crystal) = get_expected_cost(60, 15, 15, 1);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _metal_building_cost(5);
    let (exp_metal, exp_crystal) = get_expected_cost(60, 15, 15, 5);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _metal_building_cost(10);
    let (exp_metal, exp_crystal) = get_expected_cost(60, 15, 15, 10);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _metal_building_cost(15);
    let (exp_metal, exp_crystal) = get_expected_cost(60, 15, 15, 15);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _metal_building_cost(20);
    let (exp_metal, exp_crystal) = get_expected_cost(60, 15, 15, 20);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _metal_building_cost(30);
    let (exp_metal, exp_crystal) = get_expected_cost(60, 15, 15, 30);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _metal_building_cost(45);
    let (exp_metal, exp_crystal) = get_expected_cost(60, 15, 15, 45);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    return ();
}

@external
func test_crystal{syscall_ptr: felt*, range_check_ptr}() {
    let (metal, crystal) = _crystal_building_cost(1);
    let (exp_metal, exp_crystal) = get_expected_cost(48, 24, 16, 1);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _crystal_building_cost(5);
    let (exp_metal, exp_crystal) = get_expected_cost(48, 24, 16, 5);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _crystal_building_cost(10);
    let (exp_metal, exp_crystal) = get_expected_cost(48, 24, 16, 10);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _crystal_building_cost(15);
    let (exp_metal, exp_crystal) = get_expected_cost(48, 24, 16, 15);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _crystal_building_cost(20);
    let (exp_metal, exp_crystal) = get_expected_cost(48, 24, 16, 20);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _crystal_building_cost(30);
    let (exp_metal, exp_crystal) = get_expected_cost(48, 24, 16, 30);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _crystal_building_cost(45);
    let (exp_metal, exp_crystal) = get_expected_cost(48, 24, 16, 45);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    return ();
}

@external
func test_deuterium{syscall_ptr: felt*, range_check_ptr}() {
    let (metal, crystal) = _deuterium_building_cost(1);
    let (exp_metal, exp_crystal) = get_expected_cost(225, 75, 15, 1);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _deuterium_building_cost(5);
    let (exp_metal, exp_crystal) = get_expected_cost(225, 75, 15, 5);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _deuterium_building_cost(10);
    let (exp_metal, exp_crystal) = get_expected_cost(225, 75, 15, 10);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _deuterium_building_cost(15);
    let (exp_metal, exp_crystal) = get_expected_cost(225, 75, 15, 15);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _deuterium_building_cost(20);
    let (exp_metal, exp_crystal) = get_expected_cost(225, 75, 15, 20);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _deuterium_building_cost(30);
    let (exp_metal, exp_crystal) = get_expected_cost(225, 75, 15, 30);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _deuterium_building_cost(45);
    let (exp_metal, exp_crystal) = get_expected_cost(225, 75, 15, 45);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    return ();
}

@external
func test_solar{syscall_ptr: felt*, range_check_ptr}() {
    let (metal, crystal) = _solar_plant_building_cost(1);
    let (exp_metal, exp_crystal) = get_expected_cost(75, 30, 15, 1);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _solar_plant_building_cost(5);
    let (exp_metal, exp_crystal) = get_expected_cost(75, 30, 15, 5);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _solar_plant_building_cost(10);
    let (exp_metal, exp_crystal) = get_expected_cost(75, 30, 15, 10);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _solar_plant_building_cost(15);
    let (exp_metal, exp_crystal) = get_expected_cost(75, 30, 15, 15);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _solar_plant_building_cost(20);
    let (exp_metal, exp_crystal) = get_expected_cost(75, 30, 15, 20);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _solar_plant_building_cost(30);
    let (exp_metal, exp_crystal) = get_expected_cost(75, 30, 15, 30);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    let (metal, crystal) = _solar_plant_building_cost(46);
    let (exp_metal, exp_crystal) = get_expected_cost(75, 30, 15, 46);
    assert metal = exp_metal;
    assert crystal = exp_crystal;

    return ();
}

@external
func test_production_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (actual_time) = _set_timelock_and_que(0x0, 01, 10, 20, 1048576000000, 524288000000);
    let (expected_time) = Formulas.buildings_production_time(1048576000000, 524288000000, 10, 20);
    %{ print(ids.actual_time, ids.expected_time) %}
    assert actual_time = expected_time;
    let (actual_time) = _set_timelock_and_que(
        0x0, 01, 10, 45, 35184372088832000000, 17592186044416000000
    );
    let (expected_time) = Formulas.buildings_production_time(
        35184372088832000000, 17592186044416000000, 10, 45
    );
    %{ print(ids.actual_time, ids.expected_time) %}
    assert actual_time = expected_time;
    return ();
}

@external
func test_calculate_distance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let res = calculate_distance(1, 800);
    assert res = 4995;
    return ();
}

@external
func test_calculate_travel_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let distance = calculate_distance(1, 2);
    let speed = FleetPerformance.EspionageProbe.base_speed;
    let res = calculate_travel_time(distance, speed);
    assert res = 50;
    return ();
}

@external
func test_calculate_speed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let fleet = Fleet(0, 0, 1, 0, 0, 0, 0, 0);
    let res = calculate_speed(fleet);
    assert res = 100000000;
    return ();
}

@external
func test_fuel_consumption_formula{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    let res = fuel_consumption_formula(FleetPerformance.Cargo.fuel_consumption, 1005);
    assert res = 3;

    let res = fuel_consumption_formula(FleetPerformance.Recycler.fuel_consumption, 1005);
    assert res = 87;

    let res = fuel_consumption_formula(FleetPerformance.EspionageProbe.fuel_consumption, 1005);
    assert res = 1;

    let res = fuel_consumption_formula(FleetPerformance.LightFighter.fuel_consumption, 1005);
    assert res = 6;

    let res = fuel_consumption_formula(FleetPerformance.Cruiser.fuel_consumption, 1005);
    assert res = 87;

    let res = fuel_consumption_formula(FleetPerformance.BattleShip.fuel_consumption, 1005);
    assert res = 144;

    let res = fuel_consumption_formula(FleetPerformance.Deathstar.fuel_consumption, 1005);
    assert res = 1;

    return ();
}

@external
func test_calculate_fuel_consumption{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    let ships = Fleet(1, 0, 0, 0, 0, 0, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 3;

    let ships = Fleet(10, 0, 0, 0, 0, 0, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 30;

    let ships = Fleet(1, 1, 0, 0, 0, 0, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 90;

    let ships = Fleet(10, 10, 0, 0, 0, 0, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 900;

    let ships = Fleet(1, 1, 1, 0, 0, 0, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 91;

    let ships = Fleet(10, 10, 10, 0, 0, 0, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 910;

    let ships = Fleet(1, 1, 1, 0, 1, 0, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 97;

    let ships = Fleet(10, 10, 10, 0, 10, 0, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 970;

    let ships = Fleet(1, 1, 1, 0, 1, 1, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 184;

    let ships = Fleet(10, 10, 10, 0, 10, 10, 0, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 1840;

    let ships = Fleet(1, 1, 1, 0, 1, 1, 1, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 328;

    let ships = Fleet(10, 10, 10, 0, 10, 10, 10, 0);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 3280;

    let ships = Fleet(1, 1, 1, 0, 1, 1, 1, 1);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 329;

    let ships = Fleet(10, 10, 10, 0, 10, 10, 10, 10);
    let res = calculate_fuel_consumption(ships, 1005);
    assert res = 3290;

    return ();
}
