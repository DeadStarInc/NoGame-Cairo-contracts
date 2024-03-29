%lang starknet

from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, assert_not_zero, assert_le_felt
from starkware.cairo.common.math_cmp import is_le_felt, is_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address
from token.erc721.interfaces.IERC721 import IERC721
from defences.IDefences import IDefences
from fleet_movements.IFleetMovements import IFleetMovements
from main.storage import (
    NoGame_modules_manager,
    NoGame_resources_timer,
    NoGame_number_of_planets,
    NoGame_metal_mine_level,
    NoGame_crystal_mine_level,
    NoGame_deuterium_mine_level,
    NoGame_solar_plant_level,
    NoGame_resources_que_status,
    NoGame_planets_spent_resources,
    NoGame_shipyard_level,
    NoGame_robot_factory_level,
    NoGame_research_lab_level,
    NoGame_nanite_factory_level,
    NoGame_energy_tech,
    NoGame_laser_tech,
    NoGame_armour_tech,
    NoGame_astrophysics,
    NoGame_espionage_tech,
    NoGame_hyperspace_drive,
    NoGame_computer_tech,
    NoGame_hyperspace_tech,
    NoGame_impulse_drive,
    NoGame_ion_tech,
    NoGame_plasma_tech,
    NoGame_weapons_tech,
    NoGame_shielding_tech,
    NoGame_combustion_drive,
    NoGame_ships_cargo,
    NoGame_ships_recycler,
    NoGame_ships_espionage_probe,
    NoGame_ships_solar_satellite,
    NoGame_ships_light_fighter,
    NoGame_ships_cruiser,
    NoGame_ships_battleship,
    NoGame_ships_deathstar,
    NoGame_shipyard_que_status,
    NoGame_research_que_status,
    NoGame_rocket,
    NoGame_ligth_laser,
    NoGame_heavy_laser,
    NoGame_ion_cannon,
    NoGame_gauss,
    NoGame_plasma_turret,
    NoGame_small_dome,
    NoGame_large_dome,
    NoGame_max_slots,
    NoGame_active_missions,
)
from facilities.IFacilities import IFacilities
from manager.IModulesManager import IModulesManager
from resources.IResources import IResources
from resources.library import METAL_MINE_ID, CRYSTAL_MINE_ID, DEUTERIUM_MINE_ID, SOLAR_PLANT_ID
from facilities.library import ROBOT_FACTORY_ID, SHIPYARD_ID, RESEARCH_LAB_ID, NANITE_FACTORY_ID
from research.IResearchLab import IResearchLab
from research.library import (
    ARMOUR_TECH_ID,
    ASTROPHYSICS_TECH_ID,
    COMBUSTION_DRIVE_ID,
    COMPUTER_TECH_ID,
    ENERGY_TECH_ID,
    ESPIONAGE_TECH_ID,
    HYPERSPACE_DRIVE_ID,
    HYPERSPACE_TECH_ID,
    IMPULSE_DRIVE_ID,
    ION_TECH_ID,
    LASER_TECH_ID,
    PLASMA_TECH_ID,
    SHIELDING_TECH_ID,
    WEAPONS_TECH_ID,
)
from shipyard.IShipyard import IShipyard
from shipyard.library import (
    CARGO_SHIP_ID,
    RECYCLER_SHIP_ID,
    ESPIONAGE_PROBE_ID,
    SOLAR_SATELLITE_ID,
    LIGHT_FIGHTER_ID,
    CRUISER_ID,
    BATTLESHIP_ID,
    DEATHSTAR_ID,
)
from defences.library import (
    ROCKET_LAUNCHER_ID,
    LIGHT_LASER_ID,
    HEAVY_LASER_ID,
    ION_CANNON_ID,
    GAUSS_CANNON_ID,
    PLASMA_TURRET_ID,
    SMALL_DOME_ID,
    LARGE_DOME_ID,
)
from token.erc20.interfaces.IERC20 import IERC20
from utils.formulas import Formulas
from main.structs import (
    BuildingQue,
    Cost,
    TechLevels,
    TechCosts,
    ResearchQue,
    Defence,
    DefenceQue,
    DefenceCosts,
    Fleet,
    ShipyardQue,
    ShipsCosts,
    ResourcesQue,
    EspionageReport,
    BattleReport,
)

const E18 = 10 ** 18;

@event
func resourcesSpent(planet_id: Uint256, spent: felt) {
}

@event
func techSpent(planet_id: Uint256, spent: felt) {
}

@event
func fleetSpent(planet_id: Uint256, spent: felt) {
}

@event
func defenceSpent(planet_id: Uint256, spent: felt) {
}

namespace NoGame {
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        modules_manager: felt
    ) {
        NoGame_modules_manager.write(modules_manager);
        return ();
    }

    //#########################################################################################
    //                                      VIEW FUNCTIONS                                    #
    //#########################################################################################

    func number_of_planets{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        res: felt
    ) {
        let (n_planets) = NoGame_number_of_planets.read();
        return (n_planets,);
    }

    func tokens_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        erc721: felt, erc20_metal: felt, erc20_crystal: felt, erc20_deuterium: felt
    ) {
        let (modules_manager) = NoGame_modules_manager.read();
        let (erc721) = IModulesManager.getERC721Address(modules_manager);
        let (metal, crystal, deuterium) = IModulesManager.getResourcesAddresses(modules_manager);
        return (erc721, metal, crystal, deuterium);
    }

    func modules_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        _resources: felt,
        _facilities: felt,
        _shipyard: felt,
        _research: felt,
        _defences: felt,
        _fleet: felt,
    ) {
        let (modules_manager) = NoGame_modules_manager.read();
        let (
            resources, facilities, shipyard, research_lab, defences, fleet
        ) = IModulesManager.getModulesAddresses(modules_manager);
        return (resources, facilities, shipyard, research_lab, defences, fleet);
    }

    func player_points{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (points: felt) {
        let (points) = _calculate_player_points(caller);
        return (points,);
    }

    func resources_buildings_levels{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(caller: felt) -> (
        metal_mine: felt, crystal_mine: felt, deuterium_mine: felt, solar_plant: felt
    ) {
        let (planet_id) = _get_planet_id(caller);
        let (metal) = NoGame_metal_mine_level.read(planet_id);
        let (crystal) = NoGame_crystal_mine_level.read(planet_id);
        let (deuterium) = NoGame_deuterium_mine_level.read(planet_id);
        let (solar_plant) = NoGame_solar_plant_level.read(planet_id);
        return (metal, crystal, deuterium, solar_plant);
    }

    func resources_upgrades_cost{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (up_metal: Cost, up_crystal: Cost, up_deuturium: Cost, up_solar: Cost) {
        alloc_locals;
        let (modules_manager) = NoGame_modules_manager.read();
        let (resources, _, _, _) = IModulesManager.getModulesAddresses(modules_manager);
        let (metal_mine, crystal_mine, deuterium_mine, solar_plant) = IResources.getUpgradeCost(
            resources, caller
        );
        return (metal_mine, crystal_mine, deuterium_mine, solar_plant);
    }

    func facilities_levels{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (robot_factory: felt, shipyard: felt, research_lab: felt, nanite_factory: felt) {
        let (planet_id) = _get_planet_id(caller);
        let (robot_factory) = NoGame_robot_factory_level.read(planet_id);
        let (research_lab) = NoGame_research_lab_level.read(planet_id);
        let (shipyard) = NoGame_shipyard_level.read(planet_id);
        let (nanite) = NoGame_nanite_factory_level.read(planet_id);
        return (robot_factory, shipyard, research_lab, nanite);
    }

    func facilities_upgrades_cost{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (up_metal: Cost, up_crystal: Cost, up_deuturium: Cost, up_solar: Cost) {
        alloc_locals;
        let (modules_manager) = NoGame_modules_manager.read(modules_manager);
        let (_, facilities, _, _) = IModulesManager.getModulesAddresses();
        let (robot, shipyard, research, nanite) = IFacilities.getUpgradeCost(facilities, caller);
        return (robot, shipyard, research, nanite);
    }

    func tech_levels{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (result: TechLevels) {
        let (planet_id) = _get_planet_id(caller);
        let (armour_tech) = NoGame_armour_tech.read(planet_id);
        let (astrophysics) = NoGame_astrophysics.read(planet_id);
        let (combustion_drive) = NoGame_combustion_drive.read(planet_id);
        let (computer_tech) = NoGame_computer_tech.read(planet_id);
        let (energy_tech) = NoGame_energy_tech.read(planet_id);
        let (espionage_tech) = NoGame_espionage_tech.read(planet_id);
        let (hyperspace_drive) = NoGame_hyperspace_drive.read(planet_id);
        let (hyperspace_tech) = NoGame_hyperspace_tech.read(planet_id);
        let (impulse_drive) = NoGame_impulse_drive.read(planet_id);
        let (ion_tech) = NoGame_ion_tech.read(planet_id);
        let (laser_tech) = NoGame_laser_tech.read(planet_id);
        let (plasma_tech) = NoGame_plasma_tech.read(planet_id);
        let (shielding_tech) = NoGame_shielding_tech.read(planet_id);
        let (weapons_tech) = NoGame_weapons_tech.read(planet_id);

        return (
            TechLevels(
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
            ),
        );
    }

    func tech_upgrades_cost{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (
        armour_tech: Cost,
        astrophysics: Cost,
        combustion_drive: Cost,
        computer_tech: Cost,
        energy_tech: Cost,
        espionage_tech: Cost,
        hyperspace_drive: Cost,
        hyperspace_tech: Cost,
        impulse_drive: Cost,
        ion_tech: Cost,
        laser_tech: Cost,
        plasma_tech: Cost,
        shielding_tech: Cost,
        weapons_tech: Cost,
    ) {
        let (costs: TechCosts) = IResearchLab.getUpgradesCost(caller);
        return (
            costs.armour_tech,
            costs.astrophysics,
            costs.combustion_drive,
            costs.computer_tech,
            costs.energy_tech,
            costs.espionage_tech,
            costs.hyperspace_drive,
            costs.hyperspace_tech,
            costs.impulse_drive,
            costs.ion_tech,
            costs.laser_tech,
            costs.plasma_tech,
            costs.shielding_tech,
            costs.weapons_tech,
        );
    }

    func fleet_levels{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (result: Fleet) {
        let (planet_id) = _get_planet_id(caller);
        let (cargo) = NoGame_ships_cargo.read(planet_id);
        let (recycler) = NoGame_ships_recycler.read(planet_id);
        let (espionage_probe) = NoGame_ships_espionage_probe.read(planet_id);
        let (satellite) = NoGame_ships_solar_satellite.read(planet_id);
        let (light_fighter) = NoGame_ships_light_fighter.read(planet_id);
        let (cruiser) = NoGame_ships_cruiser.read(planet_id);
        let (battleship) = NoGame_ships_battleship.read(planet_id);
        let (deathstar) = NoGame_ships_deathstar.read(planet_id);
        return (
            Fleet(
                cargo,
                recycler,
                espionage_probe,
                satellite,
                light_fighter,
                cruiser,
                battleship,
                deathstar,
            ),
        );
    }

    func defence_levels{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (result: Defence) {
        let (planet_id) = _get_planet_id(caller);
        let (rocket) = NoGame_rocket.read(planet_id);
        let (light_laser) = NoGame_ligth_laser.read(planet_id);
        let (heavy_laser) = NoGame_heavy_laser.read(planet_id);
        let (ion_cannon) = NoGame_ion_cannon.read(planet_id);
        let (gauss) = NoGame_gauss.read(planet_id);
        let (plasma_turette) = NoGame_plasma_turret.read(planet_id);
        let (small_dome) = NoGame_small_dome.read(planet_id);
        let (large_dome) = NoGame_large_dome.read(planet_id);

        return (
            Defence(
                rocket,
                light_laser,
                heavy_laser,
                ion_cannon,
                gauss,
                plasma_turette,
                small_dome,
                large_dome,
            ),
        );
    }

    func resources_available{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (metal: felt, crystal: felt, deuterium: felt, energy: felt) {
        alloc_locals;
        let (metal_available, crystal_available, deuterium_available) = _get_available_erc20s(
            caller
        );
        let (
            metal_produced, crystal_produced, deuterium_produced, energy_available
        ) = _calculate_production(caller);
        return (
            metal_available + metal_produced * E18,
            crystal_available + crystal_produced * E18,
            deuterium_available + deuterium_produced * E18,
            energy_available,
        );
    }

    func resources_que{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) -> (que_status: ResourcesQue) {
        let (planet_id) = _get_planet_id(caller);
        let (status) = NoGame_resources_que_status.read(planet_id);
        return (status,);
    }

    //#########################################################################################
    //                                      GENERAL PUBLIC FUNCTIONS                          #
    //#########################################################################################

    func generate_planet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) {
        alloc_locals;
        assert_not_zero(caller);
        let (time_now) = get_block_timestamp();
        let (modules_manager) = NoGame_modules_manager.read();
        let (erc721) = IModulesManager.getERC721Address(modules_manager);
        let (has_already_planet) = IERC721.balanceOf(erc721, caller);
        with_attr error_message("NoGame::Only one planet for address is allowed") {
            assert has_already_planet = Uint256(0, 0);
        }
        let (last_id) = NoGame_number_of_planets.read();
        let new_id = last_id + 1;
        let new_planet_id = Uint256(new_id, 0);
        NoGame_resources_timer.write(new_planet_id, time_now);
        let (erc721_owner) = IERC721.ownerOf(erc721, new_planet_id);
        IERC721.transferFrom(erc721, erc721_owner, caller, new_planet_id);
        NoGame_number_of_planets.write(new_id);
        NoGame_solar_plant_level.write(new_planet_id, 1);
        NoGame_max_slots.write(new_planet_id, 1);
        // Transfer resources ERC20 tokens to caller.
        _receive_resources_erc20(
            to=caller, metal_amount=500, crystal_amount=300, deuterium_amount=100
        );
        return ();
    }

    func collect_resources{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt
    ) {
        let (metal_produced, crystal_produced, deuterium_produced, _) = _calculate_production(
            caller
        );
        _receive_resources_erc20(
            to=caller,
            metal_amount=metal_produced,
            crystal_amount=crystal_produced,
            deuterium_amount=deuterium_produced,
        );
        let (manager) = NoGame_modules_manager.read();
        let (erc721_address) = IModulesManager.getERC721Address(manager);
        let (planet_id) = IERC721.ownerToPlanet(erc721_address, caller);
        let (time_now) = get_block_timestamp();
        NoGame_resources_timer.write(planet_id, time_now);
        return ();
    }

    //#########################################################################################
    //                               RESOURCES PUBLIC FUNCTIONS                               #
    //#########################################################################################

    func metal_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (resources_address, _, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal_spent, crystal_spent, time_unlocked) = IResources.metalUpgradeStart(
            resources_address, caller
        );
        _pay_resources_erc20(caller, metal_spent, crystal_spent, 0);
        let (planet_id) = _get_planet_id(caller);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(METAL_MINE_ID, time_unlocked));
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal_spent + crystal_spent;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        return ();
    }

    func metal_upgrade_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (resources_address, _, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        IResources.metalUpgradeComplete(resources_address, caller);
        let (planet_id) = _get_planet_id(caller);
        let (current_level) = NoGame_metal_mine_level.read(planet_id);
        collect_resources(caller);
        NoGame_metal_mine_level.write(planet_id, current_level + 1);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(0, 0));
        return ();
    }

    func crystal_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (resources_address, _, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal_spent, crystal_spent, time_unlocked) = IResources.crystalUpgradeStart(
            resources_address, caller
        );
        _pay_resources_erc20(caller, metal_spent, crystal_spent, 0);
        let (planet_id) = _get_planet_id(caller);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(CRYSTAL_MINE_ID, time_unlocked));
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal_spent + crystal_spent;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        return ();
    }

    func crystal_upgrade_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (resources_address, _, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        IResources.crystalUpgradeComplete(resources_address, caller);
        let (planet_id) = _get_planet_id(caller);
        let (current_level) = NoGame_crystal_mine_level.read(planet_id);
        collect_resources(caller);
        NoGame_crystal_mine_level.write(planet_id, current_level + 1);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(0, 0));
        return ();
    }

    func deuterium_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (resources_address, _, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal_spent, crystal_spent, time_unlocked) = IResources.deuteriumUpgradeStart(
            resources_address, caller
        );
        _pay_resources_erc20(caller, metal_spent, crystal_spent, 0);
        let (planet_id) = _get_planet_id(caller);
        NoGame_resources_que_status.write(
            planet_id, ResourcesQue(DEUTERIUM_MINE_ID, time_unlocked)
        );
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal_spent + crystal_spent;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        return ();
    }

    func deuterium_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (resources_address, _, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        IResources.deuteriumUpgradeComplete(resources_address, caller);
        let (planet_id) = _get_planet_id(caller);
        let (current_level) = NoGame_deuterium_mine_level.read(planet_id);
        collect_resources(caller);
        NoGame_deuterium_mine_level.write(planet_id, current_level + 1);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(0, 0));
        return ();
    }

    func solar_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (resources_address, _, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal_spent, crystal_spent, time_unlocked) = IResources.solarPlantUpgradeStart(
            resources_address, caller
        );
        _pay_resources_erc20(caller, metal_spent, crystal_spent, 0);
        let (planet_id) = _get_planet_id(caller);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(SOLAR_PLANT_ID, time_unlocked));
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal_spent + crystal_spent;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        return ();
    }

    func solar_upgrade_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (resources_address, _, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        IResources.solarPlantUpgradeComplete(resources_address, caller);
        let (planet_id) = _get_planet_id(caller);
        let (current_metal_level) = NoGame_solar_plant_level.read(planet_id);
        collect_resources(caller);
        NoGame_solar_plant_level.write(planet_id, current_metal_level + 1);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(0, 0));
        return ();
    }

    //#########################################################################################
    //                               FACILITIES PUBLIC FUNCTIONS                              #
    //#########################################################################################

    func robot_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (_, facilities_address, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (
            metal_spent, crystal_spent, deuterium_spent, time_unlocked
        ) = IFacilities.robotFactoryUpgradeStart(facilities_address, caller);
        _pay_resources_erc20(caller, metal_spent, crystal_spent, deuterium_spent);
        let (planet_id) = _get_planet_id(caller);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(ROBOT_FACTORY_ID, time_unlocked));
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal_spent + crystal_spent;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        return ();
    }

    func robot_upgrade_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (_, facilities_address, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        IFacilities.robotFactoryUpgradeComplete(facilities_address, caller);
        let (planet_id) = _get_planet_id(caller);
        let (current_robot_level) = NoGame_robot_factory_level.read(planet_id);
        collect_resources(caller);
        NoGame_robot_factory_level.write(planet_id, current_robot_level + 1);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(0, 0));
        return ();
    }

    func shipyard_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (_, facilities_address, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (
            metal_spent, crystal_spent, deuterium_spent, time_unlocked
        ) = IFacilities.shipyardUpgradeStart(facilities_address, caller);
        _pay_resources_erc20(caller, metal_spent, crystal_spent, deuterium_spent);
        let (planet_id) = _get_planet_id(caller);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(SHIPYARD_ID, time_unlocked));
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal_spent + crystal_spent;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        return ();
    }

    func shipyard_upgrade_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (_, facilities_address, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        IFacilities.shipyardUpgradeComplete(facilities_address, caller);
        let (planet_id) = _get_planet_id(caller);
        let (current_shipyard_level) = NoGame_shipyard_level.read(planet_id);
        collect_resources(caller);
        NoGame_shipyard_level.write(planet_id, current_shipyard_level + 1);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(0, 0));
        return ();
    }

    func research_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (_, facilities_address, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (
            metal_spent, crystal_spent, deuterium_spent, time_unlocked
        ) = IFacilities.researchLabUpgradeStart(facilities_address, caller);
        _pay_resources_erc20(caller, metal_spent, crystal_spent, deuterium_spent);
        let (planet_id) = _get_planet_id(caller);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(RESEARCH_LAB_ID, time_unlocked));
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal_spent + crystal_spent;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        return ();
    }

    func research_upgrade_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (_, facilities_address, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        IFacilities.researchLabUpgradeComplete(facilities_address, caller);
        let (planet_id) = _get_planet_id(caller);
        let (current_lab_level) = NoGame_research_lab_level.read(planet_id);
        collect_resources(caller);
        NoGame_research_lab_level.write(planet_id, current_lab_level + 1);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(0, 0));
        return ();
    }

    func nanite_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (_, facilities_address, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (
            metal_spent, crystal_spent, deuterium_spent, time_unlocked
        ) = IFacilities.naniteFactoryUpgradeStart(facilities_address, caller);
        _pay_resources_erc20(caller, metal_spent, crystal_spent, deuterium_spent);
        let (planet_id) = _get_planet_id(caller);
        NoGame_resources_que_status.write(
            planet_id, ResourcesQue(NANITE_FACTORY_ID, time_unlocked)
        );
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal_spent + crystal_spent;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        return ();
    }

    func nanite_upgrade_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (manager) = NoGame_modules_manager.read();
        let (_, facilities_address, _, _, _, _) = IModulesManager.getModulesAddresses(manager);
        IFacilities.naniteFactoryUpgradeComplete(facilities_address, caller);
        let (planet_id) = _get_planet_id(caller);
        let (current_nanite_level) = NoGame_nanite_factory_level.read(planet_id);
        collect_resources(caller);
        NoGame_nanite_factory_level.write(planet_id, current_nanite_level + 1);
        NoGame_resources_que_status.write(planet_id, ResourcesQue(0, 0));
        return ();
    }

    //#############################################################################################
    //                              SHIPYARD PUBLIC FUNCS                                         #
    //#############################################################################################

    func cargo_ship_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IShipyard.cargoShipBuildStart(
            shipyard, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(CARGO_SHIP_ID, number_of_units, time_end)
        );
        fleetSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func cargo_ship_build_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IShipyard.cargoShipBuildComplete(shipyard, caller);
        let (current_units) = NoGame_ships_cargo.read(planet_id);
        NoGame_ships_cargo.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func recycler_ship_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IShipyard.recyclerShipBuildStart(
            shipyard, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(CARGO_SHIP_ID, number_of_units, time_end)
        );
        fleetSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func recycler_ship_build_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IShipyard.recyclerShipBuildComplete(shipyard, caller);
        let (current_units) = NoGame_ships_recycler.read(planet_id);
        NoGame_ships_recycler.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func espionage_probe_build_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(number_of_units: felt) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IShipyard.espionageProbeBuildStart(
            shipyard, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(ESPIONAGE_PROBE_ID, number_of_units, time_end)
        );
        fleetSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func espionage_probe_build_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IShipyard.espionageProbeBuildComplete(shipyard, caller);
        let (current_units) = NoGame_ships_espionage_probe.read(planet_id);
        NoGame_ships_espionage_probe.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func solar_satellite_build_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(number_of_units: felt) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IShipyard.solarSatelliteBuildStart(
            shipyard, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(SOLAR_SATELLITE_ID, number_of_units, time_end)
        );
        fleetSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func solar_satellite_build_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IShipyard.solarSatelliteBuildComplete(shipyard, caller);
        let (current_units) = NoGame_ships_solar_satellite.read(planet_id);
        NoGame_ships_solar_satellite.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func light_fighter_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IShipyard.lightFighterBuildStart(
            shipyard, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(LIGHT_FIGHTER_ID, number_of_units, time_end)
        );
        fleetSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func light_fighter_build_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IShipyard.lightFighterBuildComplete(shipyard, caller);
        let (current_units) = NoGame_ships_light_fighter.read(planet_id);
        NoGame_ships_light_fighter.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func cruiser_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IShipyard.cruiserBuildStart(
            shipyard, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(CRUISER_ID, number_of_units, time_end)
        );
        fleetSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func cruiser_build_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IShipyard.cruiserBuildComplete(shipyard, caller);
        let (current_units) = NoGame_ships_cruiser.read(planet_id);
        NoGame_ships_cruiser.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func battleship_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IShipyard.battleshipBuildStart(
            shipyard, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(BATTLESHIP_ID, number_of_units, time_end)
        );
        fleetSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func battleship_build_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, shipyard, _, _, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IShipyard.battleshipBuildComplete(shipyard, caller);
        let (current_units) = NoGame_ships_battleship.read(planet_id);
        NoGame_ships_battleship.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    //#########################################################################################
    //                                  RESEARCH LAB PUBLIC FUNCTIONS                         #
    //#########################################################################################

    func armour_tech_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_armour_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.armourTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(ARMOUR_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func armour_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.armourTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_armour_tech.read(planet_id);
        NoGame_armour_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    func astrophysics_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_astrophysics.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.astrophysicsUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(ASTROPHYSICS_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func astrophysics_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.astrophysicsUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_astrophysics.read(planet_id);
        NoGame_astrophysics.write(planet_id, current_tech_level + 1);
        return ();
    }

    func combustion_drive_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_combustion_drive.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.combustionDriveUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(COMBUSTION_DRIVE_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func combustion_drive_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.combustionDriveUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_combustion_drive.read(planet_id);
        NoGame_combustion_drive.write(planet_id, current_tech_level + 1);
        return ();
    }

    func computer_tech_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_computer_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.computerTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(COMPUTER_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func computer_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.computerTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_computer_tech.read(planet_id);
        NoGame_computer_tech.write(planet_id, current_tech_level + 1);
        let (current_slots) = NoGame_max_slots.read(planet_id);
        NoGame_max_slots.write(planet_id, current_slots + 1);
        return ();
    }

    func energy_tech_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_energy_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.energyTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(ENERGY_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func energy_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.energyTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_energy_tech.read(planet_id);
        NoGame_energy_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    func espionage_tech_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_espionage_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.espionageTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(ESPIONAGE_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func espionage_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.espionageTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_espionage_tech.read(planet_id);
        NoGame_espionage_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    func hyperspace_drive_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_hyperspace_drive.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.hyperspaceDriveUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(HYPERSPACE_DRIVE_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func hyperspace_drive_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.hyperspaceDriveUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_hyperspace_drive.read(planet_id);
        NoGame_hyperspace_drive.write(planet_id, current_tech_level + 1);
        return ();
    }

    func hyperspace_tech_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_hyperspace_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.hyperspaceTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(HYPERSPACE_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func hyperspace_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.hyperspaceTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_hyperspace_tech.read(planet_id);
        NoGame_hyperspace_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    func impulse_drive_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_impulse_drive.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.impulseDriveUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(IMPULSE_DRIVE_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func impulse_drive_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.impulseDriveUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_impulse_drive.read(planet_id);
        NoGame_impulse_drive.write(planet_id, current_tech_level + 1);
        return ();
    }

    func ion_tech_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_ion_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.ionTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(ION_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func ion_tech_upgrade_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.ionTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_ion_tech.read(planet_id);
        NoGame_ion_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    func laser_tech_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_laser_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.laserTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(LASER_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func laser_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.laserTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_laser_tech.read(planet_id);
        NoGame_laser_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    func plasma_tech_upgrade_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_plasma_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.plasmaTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(PLASMA_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func plasma_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.plasmaTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_plasma_tech.read(planet_id);
        NoGame_plasma_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    func shielding_tech_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_shielding_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.shieldingTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(SHIELDING_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func shielding_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.shieldingTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_shielding_tech.read(planet_id);
        NoGame_shielding_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    func weapons_tech_upgrade_start{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (current_tech_level) = NoGame_weapons_tech.read(planet_id);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IResearchLab.weaponsTechUpgradeStart(
            lab, caller, current_tech_level
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_research_que_status.write(planet_id, ResearchQue(WEAPONS_TECH_ID, time_end));
        techSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func weapons_tech_upgrade_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, lab, _, _) = IModulesManager.getModulesAddresses(manager);
        IResearchLab.weaponsTechUpgradeComplete(lab, caller);
        let (current_tech_level) = NoGame_weapons_tech.read(planet_id);
        NoGame_weapons_tech.write(planet_id, current_tech_level + 1);
        return ();
    }

    //#########################################################################################
    //                                      DEFENCES FUNCTIONS                                #
    //#########################################################################################

    func rocket_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IDefences.rocketBuildStart(
            defences, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(ROCKET_LAUNCHER_ID, number_of_units, time_end)
        );
        defenceSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func rocket_build_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IDefences.rocketBuildComplete(defences, caller);
        let (current_units) = NoGame_rocket.read(planet_id);
        NoGame_rocket.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func light_laser_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IDefences.lightLaserBuildStart(
            defences, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(LIGHT_LASER_ID, number_of_units, time_end)
        );
        defenceSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func light_laser_build_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IDefences.lightLaserBuildComplete(defences, caller);
        let (current_units) = NoGame_ligth_laser.read(planet_id);
        NoGame_ligth_laser.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func heavy_laser_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IDefences.heavyLaserBuildStart(
            defences, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(HEAVY_LASER_ID, number_of_units, time_end)
        );
        defenceSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func heavy_laser_build_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IDefences.heavyLaserBuildComplete(defences, caller);
        let (current_units) = NoGame_heavy_laser.read(planet_id);
        NoGame_heavy_laser.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func ion_cannon_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IDefences.ionCannonBuildStart(
            defences, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(ION_CANNON_ID, number_of_units, time_end)
        );
        defenceSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func ion_cannon_build_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IDefences.ionCannonBuildComplete(defences, caller);
        let (current_units) = NoGame_ion_cannon.read(planet_id);
        NoGame_ion_cannon.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func gauss_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IDefences.gaussBuildStart(
            defences, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(GAUSS_CANNON_ID, number_of_units, time_end)
        );
        defenceSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func gauss_build_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IDefences.gaussBuildComplete(defences, caller);
        let (current_units) = NoGame_gauss.read(planet_id);
        NoGame_gauss.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func plasma_turret_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        number_of_units: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IDefences.plasmaTurretBuildStart(
            defences, caller, number_of_units
        );
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(
            planet_id, ShipyardQue(PLASMA_TURRET_ID, number_of_units, time_end)
        );
        defenceSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func plasma_turret_build_complete{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (units_produced) = IDefences.plasmaTurretBuildComplete(defences, caller);
        let (current_units) = NoGame_plasma_turret.read(planet_id);
        NoGame_plasma_turret.write(planet_id, current_units + units_produced);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func small_dome_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IDefences.smallDomeBuildStart(defences, caller);
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(SMALL_DOME_ID, 1, time_end));
        defenceSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func small_dome_build_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        IDefences.smallDomeBuildComplete(defences, caller);
        let (current_units) = NoGame_small_dome.read(planet_id);
        NoGame_small_dome.write(planet_id, current_units + 1);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    func large_dome_build_start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        let (metal, crystal, deuterium, time_end) = IDefences.largeDomeBuildStart(defences, caller);
        _pay_resources_erc20(caller, metal, crystal, deuterium);
        let (spent_so_far) = NoGame_planets_spent_resources.read(planet_id);
        let new_total_spent = spent_so_far + metal + crystal;
        NoGame_planets_spent_resources.write(planet_id, new_total_spent);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(LARGE_DOME_ID, 1, time_end));
        defenceSpent.emit(planet_id, metal + crystal);
        return ();
    }

    func large_dome_build_complete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, defences, _) = IModulesManager.getModulesAddresses(manager);
        IDefences.largeDomeBuildComplete(defences, caller);
        let (current_units) = NoGame_large_dome.read(planet_id);
        NoGame_large_dome.write(planet_id, current_units + 1);
        NoGame_shipyard_que_status.write(planet_id, ShipyardQue(0, 0, 0));
        return ();
    }

    //#########################################################################################
    //                                      FLEET MOVEMENTS FUNCTIONS                         #
    //#########################################################################################

    func send_spy_mission{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ships: Fleet, destination: Uint256
    ) -> felt {
        alloc_locals;
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, _, fleet) = IModulesManager.getModulesAddresses(manager);
        _check_slots_available(planet_id);
        update_fleet_levels(caller, ships);
        let (mission_id, fuel_consumption) = IFleetMovements.sendSpyMission(
            fleet, caller, ships, destination
        );
        _pay_resources_erc20(caller, 0, 0, fuel_consumption);

        return mission_id;
    }

    func read_espionage_report{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        mission_id: felt
    ) -> EspionageReport {
        alloc_locals;
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, _, fleet) = IModulesManager.getModulesAddresses(manager);
        let (caller) = get_caller_address();
        let (res) = IFleetMovements.readEspionageReport(fleet, caller, mission_id);
        let (planet_id) = _get_planet_id(caller);
        let (active_missions) = NoGame_active_missions.read(planet_id);
        NoGame_active_missions.write(planet_id, active_missions - 1);
        return res;
    }

    func send_attack_mission{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ships: Fleet, destination: Uint256
    ) -> felt {
        alloc_locals;
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, _, fleet) = IModulesManager.getModulesAddresses(manager);
        let (caller) = get_caller_address();
        let (planet_id) = _get_planet_id(caller);
        _check_slots_available(planet_id);
        update_fleet_levels(caller, ships);
        let (mission_id, fuel_consumption) = IFleetMovements.sendAttackMission(
            fleet, caller, ships, destination
        );
        _pay_resources_erc20(caller, 0, 0, fuel_consumption);

        return mission_id;
    }

    func launch_attack{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        mission_id: felt
    ) -> BattleReport {
        let (manager) = NoGame_modules_manager.read();
        let (_, _, _, _, _, fleet) = IModulesManager.getModulesAddresses(manager);
        let (caller) = get_caller_address();
        let (
            new_attacker_fleet,
            damaged_attacker_fleet,
            new_defender_fleet,
            damaged_defender_fleet,
            new_defender_defences,
            damaged_defence,
        ) = IFleetMovements.launchAttack(fleet, caller, mission_id);

        let report = BattleReport(damaged_attacker_fleet, damaged_defender_fleet, damaged_defence);
        return report;
    }
}
//#########################################################################################
//                                      PRIVATE FUNCTIONS                                 #
//#########################################################################################
func update_fleet_levels{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, fleet: Fleet
) {
    let (planet_id) = _get_planet_id(caller);
    NoGame_ships_cargo.write(planet_id, fleet.cargo);
    NoGame_ships_recycler.write(planet_id, fleet.recycler);
    NoGame_ships_espionage_probe.write(planet_id, fleet.espionage_probe);
    NoGame_ships_solar_satellite.write(planet_id, fleet.solar_satellite);
    NoGame_ships_cruiser.write(planet_id, fleet.cruiser);
    NoGame_ships_battleship.write(planet_id, fleet.battle_ship);
    NoGame_ships_deathstar.write(planet_id, fleet.death_star);
    return ();
}

func update_defence_levels{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, defence: Defence
) {
    let (planet_id) = _get_planet_id(caller);
    NoGame_rocket.write(planet_id, defence.rocket);
    NoGame_ligth_laser.write(planet_id, defence.light_laser);
    NoGame_heavy_laser.write(planet_id, defence.heavy_laser);
    NoGame_ion_cannon.write(planet_id, defence.ion_cannon);
    NoGame_gauss.write(planet_id, defence.gauss);
    NoGame_plasma_turret.write(planet_id, defence.plasma_turret);
    NoGame_small_dome.write(planet_id, defence.small_dome);
    NoGame_large_dome.write(planet_id, defence.large_dome);
    return ();
}

func _get_planet_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (planet_id: Uint256) {
    let (modules_manager) = NoGame_modules_manager.read();
    let (erc721) = IModulesManager.getERC721Address(modules_manager);
    let (planet_id) = IERC721.ownerToPlanet(erc721, caller);

    return (planet_id,);
}

func _calculate_player_points{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (points: felt) {
    let (planet_id) = _get_planet_id(caller);
    let (total_spent) = NoGame_planets_spent_resources.read(planet_id);
    let (points, _) = unsigned_div_rem(total_spent, 1000);
    return (points,);
}

func _calculate_production{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (metal: felt, crystal: felt, deuterium: felt, energy_available: felt) {
    alloc_locals;
    let (manager) = NoGame_modules_manager.read();
    let (erc721) = IModulesManager.getERC721Address(manager);
    let (planet_id) = IERC721.ownerToPlanet(erc721, caller);
    let (metal, crystal, deuterium, solar_plant) = NoGame.resources_buildings_levels(caller);
    let (satellites) = NoGame_ships_solar_satellite.read(planet_id);
    let (energy_available, total_energy_required) = _get_net_energy(
        metal, crystal, deuterium, solar_plant, satellites
    );
    let (time_start) = NoGame_resources_timer.read(planet_id);
    let (time_now) = get_block_timestamp();
    let (metal_produced) = Formulas.metal_mine_production(time_now - time_start, metal);
    let (crystal_produced) = Formulas.crystal_mine_production(time_now - time_start, crystal);
    let (deuterium_produced) = Formulas.deuterium_mine_production(time_now - time_start, deuterium);
    if (energy_available == 0) {
        let (actual_metal, actual_crystal, actual_deuterium) = Formulas.energy_production_scaler(
            metal_produced,
            crystal_produced,
            deuterium_produced,
            total_energy_required,
            energy_available,
        );
        let metal = actual_metal;
        let crystal = actual_crystal;
        let deuterium = actual_deuterium;
        return (metal, crystal, deuterium, energy_available);
    } else {
        let metal = metal_produced;
        let crystal = crystal_produced;
        let deuterium = deuterium_produced;
        return (metal, crystal, deuterium, energy_available);
    }
}

func _check_slots_available{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256
) {
    let (max_slots) = NoGame_max_slots.read(planet_id);
    let (active_missions) = NoGame_active_missions.read(planet_id);
    with_attr error_message("FLEET MOVEMENTS::All fleet slots are full") {
        assert_le_felt(active_missions, max_slots);
    }
    NoGame_active_missions.write(planet_id, active_missions + 1);
    return ();
}

func _get_net_energy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    metal_level: felt,
    crystal_level: felt,
    deuterium_level: felt,
    solar_plant_level: felt,
    satellites: felt,
) -> (net_energy: felt, energy_required: felt) {
    alloc_locals;
    let (metal_consumption) = Formulas.consumption_energy(metal_level);
    let (crystal_consumption) = Formulas.consumption_energy(crystal_level);
    let (deuterium_consumption) = Formulas.consumption_energy_deuterium(deuterium_level);
    let total_energy_required = metal_consumption + crystal_consumption + deuterium_consumption;
    let (energy_from_plant) = Formulas.solar_plant_production(solar_plant_level);
    let energy_from_satellites = 52 * satellites;
    let energy_available = energy_from_plant + energy_from_satellites;
    let not_negative_energy = is_le_felt(total_energy_required, energy_available);
    if (not_negative_energy == FALSE) {
        return (0, total_energy_required);
    } else {
        let net_energy = energy_available - total_energy_required;
        return (net_energy, total_energy_required);
    }
}

func _receive_resources_erc20{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to: felt, metal_amount: felt, crystal_amount: felt, deuterium_amount: felt
) {
    let (manager) = NoGame_modules_manager.read();
    let (metal_address, crystal_address, deuterium_address) = IModulesManager.getResourcesAddresses(
        manager
    );
    let metal = Uint256(metal_amount * E18, 0);
    let crystal = Uint256(crystal_amount * E18, 0);
    let deuterium = Uint256(deuterium_amount * E18, 0);
    IERC20.mint(metal_address, to, metal);
    IERC20.mint(crystal_address, to, crystal);
    IERC20.mint(deuterium_address, to, deuterium);
    return ();
}

func _pay_resources_erc20{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt, metal_amount: felt, crystal_amount: felt, deuterium_amount: felt
) {
    let (manager) = NoGame_modules_manager.read();
    let (metal_address, crystal_address, deuterium_address) = IModulesManager.getResourcesAddresses(
        manager
    );
    let metal = Uint256(metal_amount * E18, 0);
    let crystal = Uint256(crystal_amount * E18, 0);
    let deuterium = Uint256(deuterium_amount * E18, 0);
    IERC20.burn(metal_address, address, metal);
    IERC20.burn(crystal_address, address, crystal);
    IERC20.burn(deuterium_address, address, deuterium);
    let (erc721) = IModulesManager.getERC721Address(manager);
    let (planet_id) = IERC721.ownerToPlanet(erc721, address);
    resourcesSpent.emit(planet_id, metal_amount + crystal_amount);
    return ();
}

func _get_available_erc20s{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> (metal: felt, crystal: felt, deuterium: felt) {
    let (manager) = NoGame_modules_manager.read();
    let (metal_address, crystal_address, deuterium_address) = IModulesManager.getResourcesAddresses(
        manager
    );
    let (metal_available) = IERC20.balanceOf(metal_address, caller);
    let (crystal_available) = IERC20.balanceOf(crystal_address, caller);
    let (deuterium_available) = IERC20.balanceOf(deuterium_address, caller);
    return (metal_available.low, crystal_available.low, deuterium_available.low);
}
