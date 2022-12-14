%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from tests.setup import (
    Contracts,
    deploy_game,
    run_modules_manager,
    run_minter,
    time_warp,
    set_facilities_levels,
    _set_resource_levels,
    reset_facilities_timelock,
    reset_que,
    reset_buildings_timelock,
)
from tests.interfaces import NoGame, ERC20
from utils.formulas import Formulas
from facilities.library import (
    _robot_factory_upgrade_cost,
    _shipyard_upgrade_cost,
    _research_lab_upgrade_cost,
    _nanite_factory_upgrade_cost,
    FacilitiesQue,
    ROBOT_FACTORY_ID,
    SHIPYARD_ID,
    RESEARCH_LAB_ID,
    NANITE_FACTORY_ID,
)

from facilities.IFacilities import IFacilities

@external
func test_upgrade_facilities_base{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 1);
    %{
        stop_prank_callable1 = start_prank(
                   ids.addresses.owner, target_contract_address=ids.addresses.game)
    %}
    NoGame.generatePlanet(addresses.game);
    let (prev_robot, prev_shipyard, prev_lab, prev_nanite) = NoGame.getFacilitiesLevels(
        addresses.game, addresses.owner
    );
    let (robot, shipyard, lab, nanite) = NoGame.getFacilitiesUpgradeCost(
        addresses.game, addresses.owner
    );

    _set_resource_levels(addresses.metal, addresses.owner, robot.metal);
    _set_resource_levels(addresses.crystal, addresses.owner, robot.crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, robot.deuterium);
    let (robot_time) = Formulas.buildings_production_time(robot.metal, robot.crystal, 0, 0);
    NoGame.robotUpgradeStart(addresses.game);
    time_warp(robot_time, addresses.facilities);
    NoGame.robotUpgradeComplete(addresses.game);

    _set_resource_levels(addresses.metal, addresses.owner, shipyard.metal);
    _set_resource_levels(addresses.crystal, addresses.owner, shipyard.crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, shipyard.deuterium);
    %{ store(ids.addresses.game, "NoGame_robot_factory_level", [2], [1,0]) %}
    time_warp(0, addresses.facilities);
    let (shipyard_time) = Formulas.buildings_production_time(nanite.metal, nanite.crystal, 2, 0);
    NoGame.shipyardUpgradeStart(addresses.game);
    time_warp(shipyard_time, addresses.facilities);
    NoGame.shipyardUpgradeComplete(addresses.game);

    _set_resource_levels(addresses.metal, addresses.owner, lab.metal);
    _set_resource_levels(addresses.crystal, addresses.owner, lab.crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, lab.deuterium);
    time_warp(0, addresses.facilities);
    let (lab_time) = Formulas.buildings_production_time(nanite.metal, nanite.crystal, 2, 0);
    NoGame.researchUpgradeStart(addresses.game);
    time_warp(lab_time, addresses.facilities);
    NoGame.researchUpgradeComplete(addresses.game);

    _set_resource_levels(addresses.metal, addresses.owner, nanite.metal);
    _set_resource_levels(addresses.crystal, addresses.owner, nanite.crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, nanite.deuterium);
    %{ store(ids.addresses.game, "NoGame_computer_tech", [10], [1,0]) %}
    %{ store(ids.addresses.game, "NoGame_robot_factory_level", [10], [1,0]) %}
    time_warp(0, addresses.facilities);
    let (nanite_time) = Formulas.buildings_production_time(nanite.metal, nanite.crystal, 10, 0);
    NoGame.naniteUpgradeStart(addresses.game);
    time_warp(nanite_time, addresses.facilities);
    NoGame.naniteUpgradeComplete(addresses.game);
    %{ store(ids.addresses.game, "NoGame_robot_factory_level", [10], [1,0]) %}

    let (new_robot, new_shipyard, new_lab, new_nanite) = NoGame.getFacilitiesLevels(
        addresses.game, addresses.owner
    );

    assert new_robot = prev_robot + 10;
    assert new_shipyard = prev_shipyard + 1;
    assert new_lab = prev_lab + 1;
    assert new_nanite = prev_nanite + 1;

    return ();
}

@external
func test_upgrades_costs{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 1);
    %{ callable_1 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.game) %}
    NoGame.generatePlanet(addresses.game);

    tempvar inputs = new (1, 5, 10, 20, 30, 45);
    let inputs_len = 6;

    %{ print("\n***test_robot_upgrades_cost***" ) %}
    _test_robot_cost_recursive(inputs_len, inputs, addresses);
    %{ print("\n***test_shipyard_upgrades_cost***" ) %}
    _test_shipyard_cost_recursive(inputs_len, inputs, addresses);
    %{ print("\n***test_lab_upgrades_cost***" ) %}
    _test_lab_cost_recursive(inputs_len, inputs, addresses);
    %{ print("\n***test_nanite_upgrades_cost***" ) %}
    _test_nanite_cost_recursive(inputs_len, inputs, addresses);

    return ();
}

@external
func test_upgrades_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 1);
    %{ callable_1 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.game) %}
    NoGame.generatePlanet(addresses.game);

    tempvar inputs = new (1, 5, 10, 20, 30, 45);
    let inputs_len = 6;

    %{ print("\n***test_robot_upgrades_time***" ) %}
    _test_robot_time_recursive(inputs_len, inputs, addresses);
    %{ print("\n***test_shipyard_upgrades_time***" ) %}
    _test_shipyard_time_recursive(inputs_len, inputs, addresses);
    %{ print("\n***test_lab_upgrades_time***" ) %}
    _test_lab_time_recursive(inputs_len, inputs, addresses);
    %{ print("\n***test_nanite_upgrades_time***" ) %}
    _test_nanite_time_recursive(inputs_len, inputs, addresses);

    return ();
}

@external
func test_busy_que_reverts{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 1);
    %{ callable_1 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.game) %}
    NoGame.generatePlanet(addresses.game);

    _set_resource_levels(addresses.metal, addresses.owner, 2000000);
    _set_resource_levels(addresses.crystal, addresses.owner, 2000000);
    _set_resource_levels(addresses.deuterium, addresses.owner, 2000000);

    NoGame.robotUpgradeStart(addresses.game);
    %{ expect_revert(error_message="FACILITIES::QUE IS BUSY!!!") %}
    NoGame.shipyardUpgradeStart(addresses.game);
    reset_buildings_timelock(addresses.game);
    NoGame.shipyardUpgradeStart(addresses.game);
    %{ expect_revert(error_message="FACILITIES::QUE IS BUSY!!!") %}
    NoGame.robotUpgradeStart(addresses.game);
    reset_buildings_timelock(addresses.game);

    NoGame.researchUpgradeStart(addresses.game);
    %{ expect_revert(error_message="FACILITIES::QUE IS BUSY!!!") %}
    NoGame.naniteUpgradeStart(addresses.game);
    reset_buildings_timelock(addresses.game);

    NoGame.naniteUpgradeStart(addresses.game);
    %{ expect_revert(error_message="FACILITIES::QUE IS BUSY!!!") %}
    NoGame.researchUpgradeStart(addresses.game);
    reset_buildings_timelock(addresses.game);

    return ();
}

@external
func test_wrong_resource_reverts{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 1);
    %{ callable_1 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.game) %}
    NoGame.generatePlanet(addresses.game);

    _set_resource_levels(addresses.metal, addresses.owner, 2000000);
    _set_resource_levels(addresses.crystal, addresses.owner, 2000000);
    _set_resource_levels(addresses.deuterium, addresses.owner, 2000000);

    NoGame.robotUpgradeStart(addresses.game);
    %{ stop_warp = warp(1000) %}
    %{ expect_revert(error_message="FACILITIES::TRIED TO COMPLETE THE WRONG FACILITY!!!") %}
    NoGame.shipyardUpgradeComplete(addresses.game);
    reset_buildings_timelock(addresses.game);

    NoGame.shipyardUpgradeStart(addresses.game);
    %{ stop_warp = warp(2000) %}
    %{ expect_revert(error_message="FACILITIES::TRIED TO COMPLETE THE WRONG FACILITY!!!") %}
    NoGame.robotUpgradeComplete(addresses.game);
    reset_buildings_timelock(addresses.game);

    NoGame.researchUpgradeStart(addresses.game);
    %{ stop_warp = warp(3000) %}
    %{ expect_revert(error_message="FACILITIES::TRIED TO COMPLETE THE WRONG FACILITY!!!") %}
    NoGame.naniteUpgradeComplete(addresses.game);
    reset_buildings_timelock(addresses.game);

    NoGame.naniteUpgradeStart(addresses.game);
    %{ stop_warp = warp(40000) %}
    %{ expect_revert(error_message="FACILITIES::TRIED TO COMPLETE THE WRONG FACILITY!!!") %}
    NoGame.researchUpgradeComplete(addresses.game);
    reset_buildings_timelock(addresses.game);

    return ();
}

@external
func test_enough_resources_reverts{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 1);
    %{ callable_1 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.game) %}
    NoGame.generatePlanet(addresses.game);

    %{ store(ids.addresses.metal, "ERC20_balances", [0,0], key=[ids.addresses.owner]) %}

    %{ expect_revert(error_message="FACILITIES::NOT ENOUGH RESOURCES!!!") %}
    NoGame.robotUpgradeStart(addresses.game);

    %{ expect_revert(error_message="FACILITIES::NOT ENOUGH RESOURCES!!!") %}
    NoGame.shipyardUpgradeStart(addresses.game);

    %{ expect_revert(error_message="FACILITIES::NOT ENOUGH RESOURCES!!!") %}
    NoGame.researchUpgradeStart(addresses.game);

    %{ expect_revert(error_message="FACILITIES::NOT ENOUGH RESOURCES!!!") %}
    NoGame.naniteUpgradeStart(addresses.game);

    return ();
}

@external
func test_timelock_expired_reverts{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 1);
    %{ callable_1 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.game) %}
    NoGame.generatePlanet(addresses.game);

    _set_resource_levels(addresses.metal, addresses.owner, 2000000);
    _set_resource_levels(addresses.crystal, addresses.owner, 2000000);
    _set_resource_levels(addresses.deuterium, addresses.owner, 2000000);

    NoGame.robotUpgradeStart(addresses.game);
    %{ expect_revert(error_message="FACILITIES::TIMELOCK NOT YET EXPIRED!!!") %}
    NoGame.robotUpgradeComplete(addresses.game);
    reset_buildings_timelock(addresses.game);
    reset_que(addresses.facilities, addresses.owner, ROBOT_FACTORY_ID);

    NoGame.shipyardUpgradeStart(addresses.game);
    %{ expect_revert(error_message="FACILITIES::TIMELOCK NOT YET EXPIRED!!!") %}
    NoGame.shipyardUpgradeComplete(addresses.game);
    reset_buildings_timelock(addresses.game);
    reset_que(addresses.facilities, addresses.owner, SHIPYARD_ID);

    NoGame.researchUpgradeStart(addresses.game);
    %{ expect_revert(error_message="FACILITIES::TIMELOCK NOT YET EXPIRED!!!") %}
    NoGame.researchUpgradeComplete(addresses.game);
    reset_buildings_timelock(addresses.game);
    reset_que(addresses.facilities, addresses.owner, RESEARCH_LAB_ID);

    NoGame.naniteUpgradeStart(addresses.game);
    %{ expect_revert(error_message="FACILITIES::TIMELOCK NOT YET EXPIRED!!!") %}
    NoGame.naniteUpgradeComplete(addresses.game);
    reset_buildings_timelock(addresses.game);
    reset_que(addresses.facilities, addresses.owner, NANITE_FACTORY_ID);

    return ();
}
//######################################################################################################
//                                           PRIVATE FUNC                                              #
//######################################################################################################

func _test_robot_cost_recursive{syscall_ptr: felt*, range_check_ptr}(
    inputs_len: felt, inputs: felt*, addresses: Contracts
) {
    if (inputs_len == 0) {
        return ();
    }
    let input = [inputs];
    let (cost_metal, cost_crystal, cost_deuterium) = _robot_factory_upgrade_cost(input);
    %{ print(f"Cost_level {ids.input}: {ids.cost_metal}\t {ids.cost_crystal}\t {ids.cost_deuterium}") %}
    _set_resource_levels(addresses.metal, addresses.owner, cost_metal);
    _set_resource_levels(addresses.crystal, addresses.owner, cost_crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, cost_deuterium);
    set_facilities_levels(addresses.game, id=1, robot=input, shipyard=0, research=0, nanite=0);
    NoGame.robotUpgradeStart(addresses.game);
    let (metal_balance) = ERC20.balanceOf(addresses.metal, addresses.owner);
    let (crystal_balance) = ERC20.balanceOf(addresses.crystal, addresses.owner);
    let (deuterium_balance) = ERC20.balanceOf(addresses.deuterium, addresses.owner);
    assert metal_balance = Uint256(0, 0);
    assert crystal_balance = Uint256(0, 0);
    assert deuterium_balance = Uint256(0, 0);
    reset_buildings_timelock(addresses.game);

    _test_robot_cost_recursive(inputs_len - 1, inputs + 1, addresses);
    return ();
}

func _test_shipyard_cost_recursive{syscall_ptr: felt*, range_check_ptr}(
    inputs_len: felt, inputs: felt*, addresses: Contracts
) {
    if (inputs_len == 0) {
        return ();
    }
    let input = [inputs];
    let (cost_metal, cost_crystal, cost_deuterium) = _shipyard_upgrade_cost(input);
    %{ print(f"Cost_level {ids.input}: {ids.cost_metal}\t {ids.cost_crystal}\t {ids.cost_deuterium}") %}
    _set_resource_levels(addresses.metal, addresses.owner, cost_metal);
    _set_resource_levels(addresses.crystal, addresses.owner, cost_crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, cost_deuterium);
    set_facilities_levels(addresses.game, id=1, robot=2, shipyard=input, research=0, nanite=0);
    NoGame.shipyardUpgradeStart(addresses.game);
    let (metal_balance) = ERC20.balanceOf(addresses.metal, addresses.owner);
    let (crystal_balance) = ERC20.balanceOf(addresses.crystal, addresses.owner);
    let (deuterium_balance) = ERC20.balanceOf(addresses.deuterium, addresses.owner);
    assert metal_balance = Uint256(0, 0);
    assert crystal_balance = Uint256(0, 0);
    assert deuterium_balance = Uint256(0, 0);
    reset_buildings_timelock(addresses.game);

    _test_shipyard_cost_recursive(inputs_len - 1, inputs + 1, addresses);
    return ();
}

func _test_lab_cost_recursive{syscall_ptr: felt*, range_check_ptr}(
    inputs_len: felt, inputs: felt*, addresses: Contracts
) {
    if (inputs_len == 0) {
        return ();
    }
    let input = [inputs];
    let (cost_metal, cost_crystal, cost_deuterium) = _research_lab_upgrade_cost(input);
    %{ print(f"Cost_level {ids.input}: {ids.cost_metal}\t {ids.cost_crystal}\t {ids.cost_deuterium}") %}
    _set_resource_levels(addresses.metal, addresses.owner, cost_metal);
    _set_resource_levels(addresses.crystal, addresses.owner, cost_crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, cost_deuterium);
    set_facilities_levels(addresses.game, id=1, robot=0, shipyard=0, research=input, nanite=0);
    NoGame.researchUpgradeStart(addresses.game);
    let (metal_balance) = ERC20.balanceOf(addresses.metal, addresses.owner);
    let (crystal_balance) = ERC20.balanceOf(addresses.crystal, addresses.owner);
    let (deuterium_balance) = ERC20.balanceOf(addresses.deuterium, addresses.owner);
    assert metal_balance = Uint256(0, 0);
    assert crystal_balance = Uint256(0, 0);
    assert deuterium_balance = Uint256(0, 0);
    reset_buildings_timelock(addresses.game);

    _test_lab_cost_recursive(inputs_len - 1, inputs + 1, addresses);
    return ();
}

func _test_nanite_cost_recursive{syscall_ptr: felt*, range_check_ptr}(
    inputs_len: felt, inputs: felt*, addresses: Contracts
) {
    if (inputs_len == 0) {
        return ();
    }
    let input = [inputs];
    let (cost_metal, cost_crystal, cost_deuterium) = _nanite_factory_upgrade_cost(input);
    %{ print(f"Cost_level {ids.input}: {ids.cost_metal}\t {ids.cost_crystal}\t {ids.cost_deuterium}") %}
    _set_resource_levels(addresses.metal, addresses.owner, cost_metal);
    _set_resource_levels(addresses.crystal, addresses.owner, cost_crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, cost_deuterium);
    set_facilities_levels(addresses.game, id=1, robot=10, shipyard=0, research=0, nanite=input);
    %{ store(ids.addresses.game, "NoGame_computer_tech", [10], [1,0]) %}
    NoGame.naniteUpgradeStart(addresses.game);
    let (metal_balance) = ERC20.balanceOf(addresses.metal, addresses.owner);
    let (crystal_balance) = ERC20.balanceOf(addresses.crystal, addresses.owner);
    let (deuterium_balance) = ERC20.balanceOf(addresses.deuterium, addresses.owner);
    assert metal_balance = Uint256(0, 0);
    assert crystal_balance = Uint256(0, 0);
    assert deuterium_balance = Uint256(0, 0);
    reset_buildings_timelock(addresses.game);

    _test_nanite_cost_recursive(inputs_len - 1, inputs + 1, addresses);
    return ();
}

func _test_robot_time_recursive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    inputs_len: felt, inputs: felt*, addresses: Contracts
) {
    if (inputs_len == 0) {
        return ();
    }
    let input = [inputs];
    let (cost_metal, cost_crystal, cost_deuterium) = _robot_factory_upgrade_cost(input);
    %{ print(f"Cost_level {ids.input}: m: {ids.cost_metal}\tc: {ids.cost_crystal}\td: {ids.cost_deuterium}") %}
    _set_resource_levels(addresses.metal, addresses.owner, cost_metal);
    _set_resource_levels(addresses.crystal, addresses.owner, cost_crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, cost_deuterium);
    set_facilities_levels(addresses.game, id=1, robot=input, shipyard=0, research=0, nanite=0);
    NoGame.robotUpgradeStart(addresses.game);

    let (expected_time) = Formulas.buildings_production_time(cost_metal, cost_crystal, input, 0);
    let (que_details) = NoGame.getBuildingQueStatus(addresses.game, addresses.owner);
    %{ print(f"expected_time: {ids.expected_time}\tactual_time: {ids.que_details.lock_end}\n") %}
    assert expected_time = que_details.lock_end;
    reset_buildings_timelock(addresses.game);

    _test_robot_time_recursive(inputs_len - 1, inputs + 1, addresses);
    return ();
}

func _test_shipyard_time_recursive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    inputs_len: felt, inputs: felt*, addresses: Contracts
) {
    if (inputs_len == 0) {
        return ();
    }
    let input = [inputs];
    let (cost_metal, cost_crystal, cost_deuterium) = _shipyard_upgrade_cost(input);
    %{ print(f"Cost_level {ids.input}: m: {ids.cost_metal}\tc: {ids.cost_crystal}\td: {ids.cost_deuterium}") %}
    _set_resource_levels(addresses.metal, addresses.owner, cost_metal);
    _set_resource_levels(addresses.crystal, addresses.owner, cost_crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, cost_deuterium);
    set_facilities_levels(addresses.game, id=1, robot=2, shipyard=input, research=0, nanite=0);
    // %{ store(ids.addresses.game, "NoGame_robot_factory_level", [2], [1,0]) %}
    NoGame.shipyardUpgradeStart(addresses.game);

    let (expected_time) = Formulas.buildings_production_time(cost_metal, cost_crystal, 2, 0);
    let (que_details) = NoGame.getBuildingQueStatus(addresses.game, addresses.owner);
    %{ print(f"expected_time: {ids.expected_time}\tactual_time: {ids.que_details.lock_end}\n") %}
    assert expected_time = que_details.lock_end;
    reset_buildings_timelock(addresses.game);

    _test_shipyard_time_recursive(inputs_len - 1, inputs + 1, addresses);
    return ();
}

func _test_lab_time_recursive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    inputs_len: felt, inputs: felt*, addresses: Contracts
) {
    if (inputs_len == 0) {
        return ();
    }
    let input = [inputs];
    let (cost_metal, cost_crystal, cost_deuterium) = _research_lab_upgrade_cost(input);
    %{ print(f"Cost_level {ids.input}: m: {ids.cost_metal}\tc: {ids.cost_crystal}\td: {ids.cost_deuterium}") %}
    _set_resource_levels(addresses.metal, addresses.owner, cost_metal);
    _set_resource_levels(addresses.crystal, addresses.owner, cost_crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, cost_deuterium);
    set_facilities_levels(addresses.game, id=1, robot=0, shipyard=0, research=input, nanite=0);
    NoGame.researchUpgradeStart(addresses.game);

    let (expected_time) = Formulas.buildings_production_time(cost_metal, cost_crystal, 0, 0);
    let (que_details) = NoGame.getBuildingQueStatus(addresses.game, addresses.owner);
    %{ print(f"expected_time: {ids.expected_time}\tactual_time: {ids.que_details.lock_end}\n") %}
    assert expected_time = que_details.lock_end;
    reset_buildings_timelock(addresses.game);

    _test_lab_time_recursive(inputs_len - 1, inputs + 1, addresses);
    return ();
}

func _test_nanite_time_recursive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    inputs_len: felt, inputs: felt*, addresses: Contracts
) {
    if (inputs_len == 0) {
        return ();
    }
    let input = [inputs];
    let (cost_metal, cost_crystal, cost_deuterium) = _nanite_factory_upgrade_cost(input);
    %{ print(f"Cost_level {ids.input}: m: {ids.cost_metal}\tc: {ids.cost_crystal}\td: {ids.cost_deuterium}") %}
    _set_resource_levels(addresses.metal, addresses.owner, cost_metal);
    _set_resource_levels(addresses.crystal, addresses.owner, cost_crystal);
    _set_resource_levels(addresses.deuterium, addresses.owner, cost_deuterium);
    set_facilities_levels(addresses.game, id=1, robot=10, shipyard=0, research=0, nanite=input);
    %{ store(ids.addresses.game, "NoGame_computer_tech", [10], [1,0]) %}

    NoGame.naniteUpgradeStart(addresses.game);

    let (expected_time) = Formulas.buildings_production_time(cost_metal, cost_crystal, 10, input);
    let (que_details) = NoGame.getBuildingQueStatus(addresses.game, addresses.owner);
    %{ print(f"expected_time: {ids.expected_time}\tactual_time: {ids.que_details.lock_end}\n") %}
    assert expected_time = que_details.lock_end;
    reset_buildings_timelock(addresses.game);

    _test_nanite_time_recursive(inputs_len - 1, inputs + 1, addresses);
    return ();
}
