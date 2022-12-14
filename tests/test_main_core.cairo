%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from main.structs import Cost, TechLevels, TechCosts
from utils.formulas import Formulas
from tests.setup import (
    E18,
    Contracts,
    deploy_game,
    run_modules_manager,
    run_minter,
    set_mines_levels,
    time_warp,
)
from tests.interfaces import NoGame, ERC721, ERC20

@external
func test_game_setup{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);

    let (_erc721, _metal, _crystal, _deuterium) = NoGame.getTokensAddresses(addresses.game);
    assert _erc721 = addresses.erc721;
    assert _metal = addresses.metal;
    assert _crystal = addresses.crystal;
    assert _deuterium = addresses.deuterium;

    let (
        _resources, _facilities, _shipyard, _research, _defences, _fleet
    ) = NoGame.getModulesAddresses(addresses.game);
    assert _resources = addresses.resources;
    assert _facilities = addresses.facilities;
    assert _shipyard = addresses.shipyard;
    assert _research = addresses.research;
    assert _defences = addresses.defences;

    return ();
}

@external
func test_generate_planet{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 10);
    %{ stop_prank_callable1 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.game) %}
    // Testing the 'generate_planet' call.
    let (planet_before) = NoGame.numberOfPlanets(addresses.game);
    assert planet_before = 0;

    NoGame.generatePlanet(addresses.game);
    let (new_planet_balance) = NoGame.numberOfPlanets(addresses.game);
    assert new_planet_balance = 1;

    // Testing the ERC721 balance after the 'generate planet' call
    let (erc721_balance) = ERC721.balanceOf(addresses.erc721, addresses.owner);
    assert erc721_balance = Uint256(1, 0);
    let (new_minter_balance) = ERC721.balanceOf(addresses.erc721, addresses.minter);
    assert new_minter_balance = Uint256(9, 0);

    // Testing the ERC20 resources balances
    let (metal_balance) = ERC20.balanceOf(addresses.metal, addresses.owner);
    let (crystal_balance) = ERC20.balanceOf(addresses.crystal, addresses.owner);
    let (deuterium_balance) = ERC20.balanceOf(addresses.deuterium, addresses.owner);
    assert metal_balance = Uint256(500 * E18, 0);
    assert crystal_balance = Uint256(300 * E18, 0);
    assert deuterium_balance = Uint256(100 * E18, 0);
    return ();
}

@external
func test_collect_resources{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 10);
    %{ stop_prank_callable1 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.game) %}
    NoGame.generatePlanet(addresses.game);

    set_mines_levels(game=addresses.game, id=1, m=1, c=1, d=1, s=5);
    time_warp(3600, addresses.game);

    let (exp_metal) = Formulas.metal_mine_production(3600, 1);
    let (exp_crystal) = Formulas.crystal_mine_production(3600, 1);
    let (exp_deuterium) = Formulas.deuterium_mine_production(3600, 1);

    NoGame.collectResources(addresses.game);
    let (actual_metal, actual_crystal, actual_deuterium, _) = NoGame.getResourcesAvailable(
        addresses.game, addresses.owner
    );
    %{ print(f"actual_metal: {ids.actual_metal}\tactual_crystal: {ids.actual_crystal}\tactual_deuterium: {ids.actual_deuterium}") %}
    assert actual_metal = exp_metal * E18 + 500 * E18;
    assert actual_crystal = exp_crystal * E18 + 300 * E18;
    assert actual_deuterium = exp_deuterium * E18 + 100 * E18;

    return ();
}

@external
func test_views_base_levels{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 10);

    // Testing levels for initialized planet
    let (metal, crystal, deuterium, solar_plant) = NoGame.getResourcesBuildingsLevels(
        addresses.game, addresses.owner
    );
    assert metal = 0;
    assert crystal = 0;
    assert deuterium = 0;
    assert solar_plant = 0;

    let (robot, shipyard, research, nanite) = NoGame.getFacilitiesLevels(
        addresses.game, addresses.owner
    );
    assert robot = 0;
    assert shipyard = 0;
    assert research = 0;
    assert nanite = 0;

    let (tech_levels: TechLevels) = NoGame.getTechLevels(addresses.game, addresses.owner);
    assert tech_levels.armour_tech = 0;
    assert tech_levels.astrophysics = 0;
    assert tech_levels.combustion_drive = 0;
    assert tech_levels.computer_tech = 0;
    assert tech_levels.energy_tech = 0;
    assert tech_levels.espionage_tech = 0;
    assert tech_levels.hyperspace_drive = 0;
    assert tech_levels.hyperspace_tech = 0;
    assert tech_levels.impulse_drive = 0;
    assert tech_levels.ion_tech = 0;
    assert tech_levels.laser_tech = 0;
    assert tech_levels.plasma_tech = 0;
    assert tech_levels.shielding_tech = 0;
    assert tech_levels.weapons_tech = 0;

    return ();
}

func test_views_base_costs{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    let addresses: Contracts = deploy_game();
    run_modules_manager(addresses);
    run_minter(addresses, 1);
    // Testing the base buildings costs.
    let (metal_1, crystal_1, deuterium_1, solar_plant_1) = NoGame.getResourcesUpgradeCost(
        addresses.game, addresses.owner
    );
    assert metal_1 = Cost(60, 15, 0, 0);
    assert crystal_1 = Cost(48, 24, 0, 0);
    assert deuterium_1 = Cost(225, 75, 0, 0);
    assert solar_plant_1 = Cost(75, 30, 0, 0);

    // Testing the base facilities costs.
    let (robot_1, shipyard_1, research_1, nanite_1) = NoGame.getFacilitiesUpgradeCost(
        addresses.game, addresses.owner
    );
    assert robot_1 = Cost(400, 120, 200, 0);
    assert shipyard_1 = Cost(400, 200, 100, 0);
    assert research_1 = Cost(200, 400, 200, 0);
    assert nanite_1 = Cost(1000000, 500000, 100000, 0);

    let (
        armour_tech,
        astrophysics,
        combustion_drive,
        computer_tech,
        energy_tech,
        espionage_tech,
        hyperspace_drive,
        hyperspace_tech,
        impulse_drive,
        ion_tech,
        laser_tech,
        plasma_tech,
        shielding_tech,
        weapons_tech,
    ) = NoGame.getTechUpgradeCost(addresses.game, addresses.owner);
    assert armour_tech = Cost(1000, 0, 0, 0);
    assert astrophysics = Cost(4000, 8000, 4000, 0);
    assert combustion_drive = Cost(400, 0, 600, 0);
    assert computer_tech = Cost(0, 400, 600, 0);
    assert energy_tech = Cost(0, 800, 400, 0);
    assert espionage_tech = Cost(200, 1000, 200, 0);
    assert hyperspace_drive = Cost(10000, 20000, 6000, 0);
    assert hyperspace_tech = Cost(0, 4000, 2000, 0);
    assert impulse_drive = Cost(2000, 4000, 600, 0);
    assert ion_tech = Cost(1000, 300, 100, 0);
    assert laser_tech = Cost(200, 100, 0, 0);
    assert plasma_tech = Cost(2000, 4000, 1000, 0);
    assert shielding_tech = Cost(200, 600, 0, 0);
    assert weapons_tech = Cost(800, 200, 0, 0);

    return ();
}
