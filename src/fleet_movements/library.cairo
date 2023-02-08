%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.math import (
    abs_value,
    assert_not_zero,
    sqrt,
    unsigned_div_rem,
    assert_lt_felt,
    assert_le_felt,
)
from starkware.cairo.common.math_cmp import is_not_zero, is_nn, is_le_felt
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_timestamp
from shipyard.ships_performance import FleetPerformance
from defences.defences_performance import DefencesPerformance
from main.INoGame import INoGame
from main.structs import (
    PlanetResources,
    ResourcesBuildings,
    FacilitiesBuildings,
    Fleet,
    TechLevels,
    EspionageQue,
    AttackQue,
    EspionageReport,
    Defence,
    BattleReport,
)
from token.erc20.interfaces.IERC20 import IERC20
from token.erc721.interfaces.IERC721 import IERC721

const SCALER = 10 ** 9;
const E18 = 10 ** 18;
const SPY_MISSION_ID = 100;
const ATTACK_MISSION_ID = 101;

@storage_var
func FleetMovements_no_game_address() -> (address: felt) {
}

@storage_var
func FleetMovements_espionage_que_details(planet_id: Uint256, mission_id: felt) -> (
    res: EspionageQue
) {
}

@storage_var
func FleetMovements_attack_que_details(planet_id: Uint256, mission_id: felt) -> (res: AttackQue) {
}

@storage_var
func FleetMovements_active_missions(planet_id: Uint256) -> (res: felt) {
}

namespace FleetMovements {
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        no_game_address: felt
    ) {
        FleetMovements_no_game_address.write(no_game_address);
        return ();
    }

    func get_espionage_que_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt, mission_id: felt
    ) -> EspionageQue {
        let planet_id = get_planet_id(caller);
        let (res) = FleetMovements_espionage_que_details.read(planet_id, mission_id);
        return res;
    }

    func get_attack_que_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt, mission_id: felt
    ) -> AttackQue {
        let planet_id = get_planet_id(caller);
        let (res) = FleetMovements_attack_que_details.read(planet_id, mission_id);
        return res;
    }

    func send_spy_mission{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt, ships: Fleet, destination: Uint256
    ) -> (mission_id: felt, fuel_consumption: felt) {
        alloc_locals;
        check_fleet_composition(caller, ships);
        let (game) = FleetMovements_no_game_address.read();
        INoGame.updateFleetLevels(game, caller, ships);
        let planet_id = get_planet_id(caller);
        let distance = calculate_distance(planet_id.low, destination.low);
        let fuel_consumption = check_enough_fuel(caller, ships, distance * 2);
        let speed = calculate_speed(ships);
        let travel_time = calculate_travel_time(distance, speed);
        let mission_id = set_espionage_que(planet_id, destination, travel_time);
        return (mission_id, fuel_consumption);
    }

    func send_attack_mission{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt, ships: Fleet, destination: Uint256
    ) -> (mission_id: felt, fuel_consumption: felt) {
        alloc_locals;
        check_fleet_composition(caller, ships);
        let (game) = FleetMovements_no_game_address.read();
        let planet_id = get_planet_id(caller);
        let distance = calculate_distance(planet_id.low, destination.low);
        let fuel_consumption = check_enough_fuel(caller, ships, distance * 2);
        let speed = calculate_speed(ships);
        let travel_time = calculate_travel_time(distance, speed);
        let mission_id = set_attack_que(planet_id, destination, travel_time);
        return (mission_id, fuel_consumption);
    }

    func launch_attack{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt, mission_id: felt
    ) -> (
        new_attacker_fleet: Fleet,
        attacker_lost_fleet: Fleet,
        new_defender_fleet: Fleet,
        defender_lost_fleet: Fleet,
        new_defender_defences: Defence,
        defender_lost_defences: Defence,
    ) {
        alloc_locals;
        let (time_now) = get_block_timestamp();
        let que_details = get_attack_que_status(caller, mission_id);
        with_attr error_message("Ships are still travelling to destination") {
            assert_le_felt(que_details.time_end, time_now);
        }
        let attacker = que_details.planet_id;
        let defender = que_details.destination;
        let attacker_fleet = get_fleet_on_planet(attacker);
        let defender_fleet = get_fleet_on_planet(defender);
        let defender_defences = get_defences_on_planet(defender);
        let (attacker_damage, defender_damage) = calculate_battle_outcome(
            attacker_fleet, defender_fleet, defender_defences
        );

        let damaged_attacker_fleet = calculate_lost_fleet(attacker_fleet, attacker_damage);
        let new_attacker_fleet = calculate_new_fleet(attacker_fleet, damaged_attacker_fleet);

        let (defender_damage, _) = unsigned_div_rem(defender_damage, 2);
        let damaged_defender_fleet = calculate_lost_fleet(defender_fleet, defender_damage);
        let new_defender_fleet = calculate_new_fleet(defender_fleet, damaged_defender_fleet);

        let damaged_defences = calculate_lost_defences(defender_defences, defender_damage);
        let new_defender_defences = calculate_new_defences(defender_defences, damaged_defences);
        let planet_id = get_planet_id(caller);
        reduce_active_missions(planet_id);
        return (
            new_attacker_fleet,
            damaged_attacker_fleet,
            new_defender_fleet,
            damaged_defender_fleet,
            new_defender_defences,
            damaged_defences,
        );
    }

    func read_espionage_report{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt, mission_id: felt
    ) -> EspionageReport {
        alloc_locals;
        let planet_id = get_planet_id(caller);
        let (que_details) = FleetMovements_espionage_que_details.read(planet_id, mission_id);
        check_espionage_timelock_expired(que_details);
        let destination = que_details.destination;
        let espionage_difference = get_espionage_power_difference(planet_id, destination);
        reduce_active_missions(planet_id);

        if (espionage_difference == 0) {
            return spy_report_0(planet_id, destination);
        }
        if (espionage_difference == 1) {
            return spy_report_1(planet_id, destination);
        }
        if (espionage_difference == 2) {
            return spy_report_2(planet_id, destination);
        }
        if (espionage_difference == 3) {
            return spy_report_3(planet_id, destination);
        }
        if (espionage_difference == 4) {
            return spy_report_4(planet_id, destination);
        } else {
            return spy_report_5(planet_id, destination);
        }
    }
}

func check_enough_fuel{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, ships: Fleet, distance: felt
) -> felt {
    alloc_locals;
    let (game) = FleetMovements_no_game_address.read();
    let (_, _, _, deuterium_addr) = INoGame.getTokensAddresses(game);
    let (deuterium_available) = IERC20.balanceOf(deuterium_addr, caller);
    let fuel_required = calculate_fuel_consumption(ships, distance);
    with_attr error_message("FLEET MOVEMENTS::Insufficient deuterium available to send the fleet") {
        assert_le_felt(fuel_required * E18, deuterium_available.low);
    }
    return fuel_required;
}

func check_fleet_composition{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, ships: Fleet
) {
    let (game) = FleetMovements_no_game_address.read();
    let (fleet_available) = INoGame.getFleetLevels(game, caller);

    // Checks that no solar satellite are part of the fleet sent to mission.
    with_attr error_message("FLEET MOVEMENTS::Solar satellite can not be sent on mission") {
        assert_lt_felt(ships.solar_satellite, 1);
    }

    with_attr error_message("FLEET MOVEMENTS::Not enough cargo ships available") {
        assert_le_felt(ships.cargo, fleet_available.cargo);
    }

    with_attr error_message("FLEET MOVEMENTS::Not enough recycler ships available") {
        assert_le_felt(ships.recycler, fleet_available.recycler);
    }

    with_attr error_message("FLEET MOVEMENTS::Not enough espionage probes available") {
        assert_le_felt(ships.espionage_probe, fleet_available.espionage_probe);
    }

    with_attr error_message("FLEET MOVEMENTS::Not enough light fighters available") {
        assert_le_felt(ships.light_fighter, fleet_available.light_fighter);
    }

    with_attr error_message("FLEET MOVEMENTS::Not enough cruisers available") {
        assert_le_felt(ships.cruiser, fleet_available.cruiser);
    }

    with_attr error_message("FLEET MOVEMENTS::Not enough battleships available") {
        assert_le_felt(ships.battle_ship, fleet_available.battle_ship);
    }

    with_attr error_message("FLEET MOVEMENTS::Not enough death star available") {
        assert_le_felt(ships.death_star, fleet_available.death_star);
    }
    return ();
}

func get_owners_from_planet_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256
) -> felt {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (res) = IERC721.ownerOf(erc721, planet_id);
    return res;
}

func get_espionage_power_difference{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(planet_id: Uint256, destination: Uint256) -> felt {
    alloc_locals;
    let attacker_addr = get_owners_from_planet_id(planet_id);
    let target_addr = get_owners_from_planet_id(destination);
    let (game) = FleetMovements_no_game_address.read();
    let (target_tech_levels: TechLevels) = INoGame.getTechLevels(game, target_addr);
    let target_espionage_level = target_tech_levels.espionage_tech;

    let target_fleet: Fleet = INoGame.getFleetLevels(game, target_addr);
    let target_probes_num = target_fleet.espionage_probe;
    let target_espionage_power = target_espionage_level * target_probes_num;

    let (attacker_tech_level: TechLevels) = INoGame.getTechLevels(game, attacker_addr);
    let attacker_espionage_level = attacker_tech_level.espionage_tech;
    let attacker_fleet: Fleet = INoGame.getFleetLevels(game, attacker_addr);
    let attacker_probes_num = attacker_fleet.espionage_probe;
    let attacker_espionage_power = attacker_espionage_level * attacker_probes_num;

    let diff = attacker_espionage_power - target_espionage_power;
    let cond_1 = is_nn(diff);
    let cond_2 = is_not_zero(diff);
    if (cond_1 * cond_2 == FALSE) {
        return 0;
    } else {
        return diff;
    }
}

func calculate_distance{range_check_ptr}(p1_position: felt, p2_position: felt) -> felt {
    let zero_check_1 = is_not_zero(p1_position);
    let zero_check_2 = is_not_zero(p2_position);
    if (zero_check_1 * zero_check_2 == FALSE) {
        return 0;
    }

    let fact1 = abs_value(p2_position - p1_position);
    let distance = 1000 + 5 * fact1;
    return distance;
}

func calculate_travel_time{range_check_ptr}(distance: felt, speed: felt) -> felt {
    let (fact1, _) = unsigned_div_rem(SCALER * distance, speed);
    let fact2 = sqrt(fact1);
    let (res, _) = unsigned_div_rem(fact2, 2);
    return res;
}

func calculate_fuel_consumption{range_check_ptr}(ships: Fleet, distance: felt) -> felt {
    alloc_locals;
    let cargo_consumption = get_ship_consumption(
        ships.cargo, FleetPerformance.Cargo.fuel_consumption, distance
    );
    let recycler_consumption = get_ship_consumption(
        ships.recycler, FleetPerformance.Recycler.fuel_consumption, distance
    );
    let probe_consumption = get_ship_consumption(
        ships.espionage_probe, FleetPerformance.EspionageProbe.fuel_consumption, distance
    );
    let fighter_consumption = get_ship_consumption(
        ships.light_fighter, FleetPerformance.LightFighter.fuel_consumption, distance
    );
    let cruiser_consumption = get_ship_consumption(
        ships.cruiser, FleetPerformance.Cruiser.fuel_consumption, distance
    );
    let bs_consumption = get_ship_consumption(
        ships.battle_ship, FleetPerformance.BattleShip.fuel_consumption, distance
    );
    let death_consumption = get_ship_consumption(
        ships.death_star, FleetPerformance.Deathstar.fuel_consumption, distance
    );

    return cargo_consumption + recycler_consumption + probe_consumption + fighter_consumption +
        cruiser_consumption + bs_consumption + death_consumption;
}

func get_ship_consumption{range_check_ptr}(n_ships: felt, base_cost: felt, distance: felt) -> felt {
    alloc_locals;
    let cond = is_not_zero(n_ships);
    if (cond == TRUE) {
        let consumption = fuel_consumption_formula(base_cost, distance);
        return consumption * n_ships;
    } else {
        return 0;
    }
}

func fuel_consumption_formula{range_check_ptr}(base_cost: felt, distance: felt) -> felt {
    alloc_locals;
    let fact1 = base_cost * distance;
    let (fact2, _) = unsigned_div_rem(fact1, 3500);
    let res = fact2 + 1;
    return res;
}

func calculate_speed{range_check_ptr}(fleet: Fleet) -> felt {
    let cond_1 = is_not_zero(fleet.death_star);
    if (cond_1 == TRUE) {
        return FleetPerformance.Deathstar.base_speed;
    }

    let cond_2 = is_not_zero(fleet.recycler);
    if (cond_2 == TRUE) {
        return FleetPerformance.Recycler.base_speed;
    }

    let cond_3 = is_not_zero(fleet.cargo);
    if (cond_3 == TRUE) {
        return FleetPerformance.Cargo.base_speed;
    }

    let cond_4 = is_not_zero(fleet.battle_ship);
    if (cond_4 == TRUE) {
        return FleetPerformance.BattleShip.base_speed;
    }

    let cond_5 = is_not_zero(fleet.light_fighter);
    if (cond_5 == TRUE) {
        return FleetPerformance.LightFighter.base_speed;
    }

    let cond_6 = is_not_zero(fleet.cruiser);
    if (cond_6 == TRUE) {
        return FleetPerformance.Cruiser.base_speed;
    } else {
        return FleetPerformance.EspionageProbe.base_speed;
    }
}

func check_espionage_timelock_expired{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(que_details: EspionageQue) {
    let (time_now) = get_block_timestamp();
    with_attr error_message("FLEET MOVEMENTS::Timelock not yet expired") {
        let time_end = que_details.time_end;
        assert_le_felt(time_end, time_now);
    }
    return ();
}

func check_attack_timelock_expired{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    que_details: AttackQue
) {
    let (time_now) = get_block_timestamp();
    with_attr error_message("FLEET MOVEMENTS::Timelock not yet expired") {
        let time_end = que_details.time_end;
        assert_le_felt(time_end, time_now);
    }
    return ();
}

func get_planet_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) -> Uint256 {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (planet_id) = IERC721.ownerToPlanet(erc721, caller);
    return planet_id;
}

func reduce_active_missions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256
) {
    let (active_missions) = FleetMovements_active_missions.read(planet_id);
    FleetMovements_active_missions.write(planet_id, active_missions - 1);
    return ();
}

func set_espionage_que{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    starting_planet: Uint256, destination: Uint256, travel_time: felt
) -> felt {
    let (time_now) = get_block_timestamp();
    let time_end = time_now + travel_time;
    let (active_missions) = FleetMovements_active_missions.read(starting_planet);
    let new_que_point = EspionageQue(
        planet_id=starting_planet,
        mission_id=active_missions + 1,
        time_end=time_end,
        destination=destination,
    );
    let sender_addr = get_owners_from_planet_id(starting_planet);
    FleetMovements_espionage_que_details.write(starting_planet, active_missions + 1, new_que_point);
    FleetMovements_active_missions.write(starting_planet, active_missions + 1);
    return (active_missions + 1);
}

func set_attack_que{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    starting_planet: Uint256, destination: Uint256, travel_time: felt
) -> felt {
    let (time_now) = get_block_timestamp();
    let time_end = time_now + travel_time;
    let (active_missions) = FleetMovements_active_missions.read(starting_planet);
    let new_que_point = AttackQue(
        planet_id=starting_planet,
        mission_id=active_missions + 1,
        time_end=time_end,
        destination=destination,
    );
    let sender_addr = get_owners_from_planet_id(starting_planet);
    FleetMovements_attack_que_details.write(starting_planet, active_missions + 1, new_que_point);
    FleetMovements_active_missions.write(starting_planet, active_missions + 1);
    return (active_missions + 1);
}

func spy_report_0{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256, destination: Uint256
) -> EspionageReport {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (target_addr) = IERC721.ownerOf(erc721, destination);
    let (attacker_addr) = IERC721.ownerOf(erc721, planet_id);
    let (
        metal_available, crystal_available, deuterium_available, _
    ) = INoGame.getResourcesAvailable(game, target_addr);
    let planet_resources = PlanetResources(metal_available, crystal_available, deuterium_available);
    let report = EspionageReport(
        PlanetResources(0, 0, 0),
        ResourcesBuildings(0, 0, 0, 0),
        Fleet(0, 0, 0, 0, 0, 0, 0, 0),
        FacilitiesBuildings(0, 0, 0, 0),
        TechLevels(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    );
    return report;
}

func spy_report_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256, destination: Uint256
) -> EspionageReport {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (target_addr) = IERC721.ownerOf(erc721, destination);
    let (attacker_addr) = IERC721.ownerOf(erc721, planet_id);
    let (
        metal_available, crystal_available, deuterium_available, _
    ) = INoGame.getResourcesAvailable(game, target_addr);
    let planet_resources = PlanetResources(metal_available, crystal_available, deuterium_available);
    let report = EspionageReport(
        planet_resources,
        ResourcesBuildings(0, 0, 0, 0),
        Fleet(0, 0, 0, 0, 0, 0, 0, 0),
        FacilitiesBuildings(0, 0, 0, 0),
        TechLevels(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    );
    return report;
}

func spy_report_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256, destination: Uint256
) -> EspionageReport {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (target_addr) = IERC721.ownerOf(erc721, destination);
    let (attacker_addr) = IERC721.ownerOf(erc721, planet_id);
    let (
        metal_available, crystal_available, deuterium_available, _
    ) = INoGame.getResourcesAvailable(game, target_addr);
    let planet_resources = PlanetResources(metal_available, crystal_available, deuterium_available);
    let (
        metal_level, crystal_level, deuterium_level, solar_plant_level
    ) = INoGame.getResourcesBuildingsLevels(game, target_addr);
    let resources_buildings = ResourcesBuildings(
        metal_level, crystal_level, deuterium_level, solar_plant_level
    );

    let report = EspionageReport(
        planet_resources,
        resources_buildings,
        Fleet(0, 0, 0, 0, 0, 0, 0, 0),
        FacilitiesBuildings(0, 0, 0, 0),
        TechLevels(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    );
    return report;
}

func spy_report_3{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256, destination: Uint256
) -> EspionageReport {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (target_addr) = IERC721.ownerOf(erc721, destination);
    let (attacker_addr) = IERC721.ownerOf(erc721, planet_id);
    let (
        metal_available, crystal_available, deuterium_available, _
    ) = INoGame.getResourcesAvailable(game, target_addr);
    let planet_resources = PlanetResources(metal_available, crystal_available, deuterium_available);
    let (
        metal_level, crystal_level, deuterium_level, solar_plant_level
    ) = INoGame.getResourcesBuildingsLevels(game, target_addr);
    let resources_buildings = ResourcesBuildings(
        metal_level, crystal_level, deuterium_level, solar_plant_level
    );
    let (fleet_on_the_planet) = INoGame.getFleetLevels(game, target_addr);
    let fleet = fleet_on_the_planet;
    let report = EspionageReport(
        planet_resources,
        resources_buildings,
        fleet_on_the_planet,
        FacilitiesBuildings(0, 0, 0, 0),
        TechLevels(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    );
    return report;
}

func spy_report_4{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256, destination: Uint256
) -> EspionageReport {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (target_addr) = IERC721.ownerOf(erc721, destination);
    let (attacker_addr) = IERC721.ownerOf(erc721, planet_id);
    let (
        metal_available, crystal_available, deuterium_available, _
    ) = INoGame.getResourcesAvailable(game, target_addr);
    let planet_resources = PlanetResources(metal_available, crystal_available, deuterium_available);
    let (
        metal_level, crystal_level, deuterium_level, solar_plant_level
    ) = INoGame.getResourcesBuildingsLevels(game, target_addr);
    let resources_buildings = ResourcesBuildings(
        metal_level, crystal_level, deuterium_level, solar_plant_level
    );
    let (fleet_on_the_planet) = INoGame.getFleetLevels(game, target_addr);
    let fleet = fleet_on_the_planet;
    let (robot, shipyard, lab, nanite) = INoGame.getFacilitiesLevels(game, target_addr);
    let facilities = FacilitiesBuildings(robot, shipyard, lab, nanite);
    let report = EspionageReport(
        planet_resources,
        resources_buildings,
        fleet_on_the_planet,
        facilities,
        TechLevels(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    );
    return report;
}

func spy_report_5{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256, destination: Uint256
) -> EspionageReport {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (target_addr) = IERC721.ownerOf(erc721, destination);
    let (attacker_addr) = IERC721.ownerOf(erc721, planet_id);
    let (
        metal_available, crystal_available, deuterium_available, _
    ) = INoGame.getResourcesAvailable(game, target_addr);
    let planet_resources = PlanetResources(metal_available, crystal_available, deuterium_available);
    let (
        metal_level, crystal_level, deuterium_level, solar_plant_level
    ) = INoGame.getResourcesBuildingsLevels(game, target_addr);
    let resources_buildings = ResourcesBuildings(
        metal_level, crystal_level, deuterium_level, solar_plant_level
    );
    let (fleet_on_the_planet) = INoGame.getFleetLevels(game, target_addr);
    let fleet = fleet_on_the_planet;
    let (robot, shipyard, lab, nanite) = INoGame.getFacilitiesLevels(game, target_addr);
    let facilities = FacilitiesBuildings(robot, shipyard, lab, nanite);
    let (tech_on_planet) = INoGame.getTechLevels(game, target_addr);
    let tech_levels = tech_on_planet;
    let report = EspionageReport(
        planet_resources, resources_buildings, fleet_on_the_planet, facilities, tech_levels
    );
    return report;
}

func get_total_fleet_shield_power{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    fleet: Fleet
) -> felt {
    // cargos
    let cargo = fleet.cargo;
    let cargo_shield = cargo * FleetPerformance.Cargo.shield_power;
    // recyclers
    let recycler = fleet.recycler;
    let recycler_shield = recycler * FleetPerformance.Recycler.shield_power;
    // espionage probes
    let probes = fleet.recycler;
    let probe_shield = probes * FleetPerformance.EspionageProbe.shield_power;
    // solar satellites
    let satellites = fleet.solar_satellite;
    let satellites_shield = satellites * FleetPerformance.SolarSatellite.shield_power;
    // light fighter
    let fighters = fleet.light_fighter;
    let fighter_shield = fighters * FleetPerformance.LightFighter.shield_power;
    // Cruiser
    let cruiser = fleet.cruiser;
    let cruiser_shield = cruiser * FleetPerformance.Cruiser.shield_power;
    // battleships
    let battleships = fleet.battle_ship;
    let bs_shield = battleships * FleetPerformance.BattleShip.shield_power;
    return cargo_shield + recycler_shield + probe_shield + satellites_shield + fighter_shield +
        cruiser_shield + bs_shield;
}

func get_total_fleet_structural_integrity{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(fleet: Fleet) -> felt {
    // cargos
    let cargo = fleet.cargo;
    let cargo_struct = cargo * FleetPerformance.Cargo.structural_integrity;
    // recyclers
    let recycler = fleet.recycler;
    let recycler_struct = recycler * FleetPerformance.Recycler.structural_integrity;
    // espionage probes
    let probes = fleet.espionage_probe;
    let probe_struct = probes * FleetPerformance.EspionageProbe.structural_integrity;
    // solar satellites
    let satellites = fleet.solar_satellite;
    let satellites_struct = satellites * FleetPerformance.SolarSatellite.structural_integrity;
    // light fighter
    let fighters = fleet.light_fighter;
    let fighter_struct = fighters * FleetPerformance.LightFighter.structural_integrity;
    // Cruiser
    let cruiser = fleet.cruiser;
    let cruiser_struct = cruiser * FleetPerformance.Cruiser.structural_integrity;
    // battleships
    let battleships = fleet.battle_ship;
    let bs_struct = battleships * FleetPerformance.BattleShip.structural_integrity;
    return cargo_struct + recycler_struct + probe_struct + satellites_struct + fighter_struct +
        cruiser_struct + bs_struct;
}

func get_total_fleet_weapon_power{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    fleet: Fleet
) -> felt {
    // cargos
    let cargo = fleet.cargo;
    let cargo_weapon = cargo * FleetPerformance.Cargo.weapon_power;
    // recyclers
    let recycler = fleet.recycler;
    let recycler_weapon = recycler * FleetPerformance.Recycler.weapon_power;
    // espionage probes
    let probes = fleet.recycler;
    let probe_weapon = probes * FleetPerformance.EspionageProbe.weapon_power;
    // solar satellites
    let satellites = fleet.solar_satellite;
    let satellites_weapon = satellites * FleetPerformance.SolarSatellite.weapon_power;
    // light fighter
    let fighters = fleet.light_fighter;
    let fighter_weapon = fighters * FleetPerformance.LightFighter.weapon_power;
    // Cruiser
    let cruiser = fleet.cruiser;
    let cruiser_weapon = cruiser * FleetPerformance.Cruiser.weapon_power;
    // battleships
    let battleships = fleet.battle_ship;
    let bs_weapon = battleships * FleetPerformance.BattleShip.weapon_power;
    return cargo_weapon + recycler_weapon + probe_weapon + satellites_weapon + fighter_weapon +
        cruiser_weapon + bs_weapon;
}

func get_total_defences_shield_power{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(defences: Defence) -> felt {
    // rocket launcher
    let rocket = defences.rocket;
    let rocket_shield = DefencesPerformance.Rocket.shield_power * rocket;
    // light laser
    let l_laser = defences.light_laser;
    let l_laser_shield = DefencesPerformance.LightLaser.shield_power * l_laser;
    // heavy laser
    let h_laser = defences.heavy_laser;
    let h_laser_shield = DefencesPerformance.HeavyLaser.shield_power * h_laser;
    // ion cannon
    let ion = defences.ion_cannon;
    let ion_shield = DefencesPerformance.IonCannon.shield_power * ion;
    // gauss cannon
    let gauss = defences.gauss;
    let gauss_shield = DefencesPerformance.GaussCannon.shield_power * gauss;
    // plasma turret
    let plasma = defences.plasma_turret;
    let plasma_shield = DefencesPerformance.PlasmaTurret.shield_power * plasma;
    // small dome
    let s_dome = defences.small_dome;
    let small_dome = DefencesPerformance.SmallDome.shield_power * s_dome;
    // large dome
    let l_dome = defences.large_dome;
    let large_dome = DefencesPerformance.LargeDome.shield_power * l_dome;

    let res = rocket_shield + l_laser_shield + h_laser_shield + ion_shield + gauss_shield +
        plasma_shield + small_dome + large_dome;
    return res;
}

func get_total_defences_structural_power{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(defences: Defence) -> felt {
    // rocket launcher
    let rocket = defences.rocket;
    let rocket_struct = DefencesPerformance.Rocket.structural_integrity * rocket;
    // light laser
    let l_laser = defences.light_laser;
    let l_laser_struct = DefencesPerformance.LightLaser.structural_integrity * l_laser;
    // heavy laser
    let h_laser = defences.heavy_laser;
    let h_laser_struct = DefencesPerformance.HeavyLaser.structural_integrity * h_laser;
    // ion cannon
    let ion = defences.ion_cannon;
    let ion_struct = DefencesPerformance.IonCannon.structural_integrity * ion;
    // gauss cannon
    let gauss = defences.gauss;
    let gauss_struct = DefencesPerformance.GaussCannon.structural_integrity * gauss;
    // plasma turret
    let plasma = defences.plasma_turret;
    let plasma_struct = DefencesPerformance.PlasmaTurret.structural_integrity * plasma;
    // small dome
    let s_dome = defences.small_dome;
    let small_dome = DefencesPerformance.SmallDome.structural_integrity * s_dome;
    // large dome
    let l_dome = defences.large_dome;
    let large_dome = DefencesPerformance.LargeDome.structural_integrity * l_dome;

    let res = rocket_struct + l_laser_struct + h_laser_struct + ion_struct + gauss_struct +
        plasma_struct + small_dome + large_dome;
    return res;
}

func get_total_defences_weapons_power{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(defences: Defence) -> felt {
    // rocket launcher
    let rocket = defences.rocket;
    let rocket_weapon = DefencesPerformance.Rocket.weapon_power * rocket;
    // light laser
    let l_laser = defences.light_laser;
    let l_laser_weapon = DefencesPerformance.LightLaser.weapon_power * l_laser;
    // heavy laser
    let h_laser = defences.heavy_laser;
    let h_laser_weapons = DefencesPerformance.HeavyLaser.weapon_power * h_laser;
    // ion cannon
    let ion = defences.ion_cannon;
    let ion_weapon = DefencesPerformance.IonCannon.weapon_power * ion;
    // gauss cannon
    let gauss = defences.gauss;
    let gauss_weapon = DefencesPerformance.GaussCannon.weapon_power * gauss;
    // plasma turret
    let plasma = defences.plasma_turret;
    let plasma_weapon = DefencesPerformance.PlasmaTurret.weapon_power * plasma;
    // small dome
    let s_dome = defences.small_dome;
    let small_dome = DefencesPerformance.SmallDome.weapon_power;
    // large dome
    let l_dome = defences.large_dome;
    let large_dome = DefencesPerformance.LargeDome.weapon_power;

    let res = rocket_weapon + l_laser_weapon + h_laser_weapons + ion_weapon + gauss_weapon +
        plasma_weapon + small_dome * s_dome + large_dome * l_dome;
    return res;
}

func get_damaged_ships{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n_ships: felt, struct_integrity: felt, shield_power: felt, damage: felt
) -> felt {
    let cond = is_not_zero(n_ships);
    if (cond == TRUE) {
        let (ships_damaged, _) = unsigned_div_rem(damage, struct_integrity + shield_power);
        return ships_damaged;
    } else {
        return 0;
    }
}

func calculate_lost_defences{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    defences: Defence, damage: felt
) -> Defence {
    alloc_locals;
    let n_defence = get_numeber_of_defences(defences);
    let cond = is_not_zero(n_defence);
    if (cond == TRUE) {
        let (damage_per_defence, _) = unsigned_div_rem(damage, n_defence);

        let rocket_damage = get_damaged_ships(
            defences.rocket,
            DefencesPerformance.Rocket.structural_integrity,
            DefencesPerformance.Rocket.shield_power,
            damage_per_defence,
        );

        let light_laser_damage = get_damaged_ships(
            defences.light_laser,
            DefencesPerformance.LightLaser.structural_integrity,
            DefencesPerformance.LightLaser.shield_power,
            damage_per_defence,
        );

        let heavy_laser_damage = get_damaged_ships(
            defences.heavy_laser,
            DefencesPerformance.HeavyLaser.structural_integrity,
            DefencesPerformance.HeavyLaser.shield_power,
            damage_per_defence,
        );

        let ion_cannon_damage = get_damaged_ships(
            defences.ion_cannon,
            DefencesPerformance.IonCannon.structural_integrity,
            DefencesPerformance.IonCannon.shield_power,
            damage_per_defence,
        );

        let gauss_damage = get_damaged_ships(
            defences.gauss,
            DefencesPerformance.GaussCannon.structural_integrity,
            DefencesPerformance.GaussCannon.shield_power,
            damage_per_defence,
        );

        let plasma_damage = get_damaged_ships(
            defences.plasma_turret,
            DefencesPerformance.PlasmaTurret.structural_integrity,
            DefencesPerformance.PlasmaTurret.shield_power,
            damage_per_defence,
        );

        let small_dome_damage = get_damaged_ships(
            defences.small_dome,
            DefencesPerformance.SmallDome.structural_integrity,
            DefencesPerformance.SmallDome.shield_power,
            damage_per_defence,
        );

        let large_dome_damage = get_damaged_ships(
            defences.large_dome,
            DefencesPerformance.LargeDome.structural_integrity,
            DefencesPerformance.LargeDome.shield_power,
            damage_per_defence,
        );

        let damaged_defences = Defence(
            rocket_damage,
            light_laser_damage,
            heavy_laser_damage,
            ion_cannon_damage,
            gauss_damage,
            plasma_damage,
            small_dome_damage,
            large_dome_damage,
        );
        return damaged_defences;
    } else {
        let no_defences = Defence(0,0,0,0,0,0,0,0);
        return no_defences;
    }
}

func calculate_new_defences{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    defence: Defence, damaged: Defence
) -> Defence {
    alloc_locals;
    let new_rocket = safe_ships_sub(defence.rocket, damaged.rocket);
    let new_light_laser = safe_ships_sub(defence.light_laser, damaged.light_laser);
    let new_heavy_laser = safe_ships_sub(defence.heavy_laser, damaged.heavy_laser);
    let new_ion_cannon = safe_ships_sub(defence.ion_cannon, damaged.ion_cannon);
    let new_gauss = safe_ships_sub(defence.gauss, damaged.gauss);
    let new_plasma = safe_ships_sub(defence.plasma_turret, damaged.plasma_turret);
    let new_small_dome = safe_ships_sub(defence.small_dome, damaged.small_dome);
    let new_large_dome = safe_ships_sub(defence.large_dome, damaged.large_dome);

    let new_defences = Defence(
        new_rocket,
        new_light_laser,
        new_heavy_laser,
        new_ion_cannon,
        new_gauss,
        new_plasma,
        new_small_dome,
        new_large_dome,
    );
    return new_defences;
}

func calculate_new_fleet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    fleet: Fleet, damaged: Fleet
) -> Fleet {
    alloc_locals;
    let cargo = safe_ships_sub(fleet.cargo, damaged.cargo);
    let recycler = safe_ships_sub(fleet.recycler, damaged.recycler);
    let probe = safe_ships_sub(fleet.espionage_probe, damaged.espionage_probe);
    let satellite = safe_ships_sub(fleet.solar_satellite, damaged.solar_satellite);
    let fighter = safe_ships_sub(fleet.light_fighter, damaged.light_fighter);
    let cruiser = safe_ships_sub(fleet.cruiser, damaged.cruiser);
    let bs = safe_ships_sub(fleet.battle_ship, damaged.battle_ship);
    let dead = safe_ships_sub(fleet.death_star, damaged.death_star);
    let new_fleet =Fleet(cargo, recycler, probe, satellite, fighter, cruiser, bs, dead);
    return new_fleet;
}

func calculate_lost_fleet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    fleet: Fleet, damage: felt
) -> Fleet {
    alloc_locals;
    let n_ships = get_number_of_ships(fleet);
    let (damage_per_ship, _) = unsigned_div_rem(damage, n_ships);

    let cargo_damaged = get_damaged_ships(
        fleet.cargo, FleetPerformance.Cargo.structural_integrity, FleetPerformance.Cargo.shield_power,  damage_per_ship
    );

    let recycler_damaged = get_damaged_ships(
        fleet.recycler, FleetPerformance.Recycler.structural_integrity,FleetPerformance.Recycler.shield_power, damage_per_ship
    );

    let probe_damaged = get_damaged_ships(
        fleet.espionage_probe, FleetPerformance.EspionageProbe.structural_integrity,FleetPerformance.EspionageProbe.shield_power, damage_per_ship
    );

    let satellite_damaged = get_damaged_ships(
        fleet.solar_satellite, FleetPerformance.SolarSatellite.structural_integrity,FleetPerformance.SolarSatellite.shield_power, damage_per_ship
    );

    let fighter_damaged = get_damaged_ships(
        fleet.light_fighter, FleetPerformance.LightFighter.structural_integrity,FleetPerformance.LightFighter.shield_power, damage_per_ship
    );

    let cruiser_damaged = get_damaged_ships(
        fleet.cruiser, FleetPerformance.Cruiser.structural_integrity,FleetPerformance.Cruiser.shield_power, damage_per_ship
    );

    let bs_damaged = get_damaged_ships(
        fleet.battle_ship, FleetPerformance.BattleShip.structural_integrity,FleetPerformance.BattleShip.shield_power, damage_per_ship
    );

    let dead_damaged = get_damaged_ships(
        fleet.death_star, FleetPerformance.Deathstar.structural_integrity,FleetPerformance.Deathstar.shield_power, damage_per_ship
    );

    let damaged_fleet = Fleet(
        cargo_damaged,
        recycler_damaged,
        probe_damaged,
        satellite_damaged,
        fighter_damaged,
        cruiser_damaged,
        bs_damaged,
        dead_damaged,
    );
    return damaged_fleet;
}

func get_numeber_of_defences{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    defences: Defence
) -> felt {
    let rocket = is_not_zero(defences.rocket);
    let light_laser = is_not_zero(defences.light_laser);
    let heavy_laser = is_not_zero(defences.heavy_laser);
    let ion_cannon = is_not_zero(defences.ion_cannon);
    let gauss = is_not_zero(defences.gauss);
    let plasma_turret = is_not_zero(defences.plasma_turret);
    let small_dome = is_not_zero(defences.small_dome);
    let large_dome = is_not_zero(defences.large_dome);
    return rocket + light_laser + heavy_laser + ion_cannon + gauss + plasma_turret + small_dome +
        large_dome;
}

func get_number_of_ships{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    fleet: Fleet
) -> felt {
    let cargo = is_not_zero(fleet.cargo);
    let recycler = is_not_zero(fleet.recycler);
    let probe = is_not_zero(fleet.espionage_probe);
    let satellite = is_not_zero(fleet.solar_satellite);
    let fighter = is_not_zero(fleet.light_fighter);
    let cruiser = is_not_zero(fleet.cruiser);
    let bs = is_not_zero(fleet.battle_ship);
    let deathstar = is_not_zero(fleet.death_star);

    return cargo + recycler + probe + satellite + fighter + cruiser + bs + deathstar;
}

func calculate_attacker_damage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    fleet: Fleet, points_left: felt
) -> felt {
    let shield = get_total_fleet_shield_power(fleet);
    let structural_integrity = get_total_fleet_structural_integrity(fleet);
    return shield + structural_integrity - points_left;
}

func calculate_defender_damage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    fleet: Fleet, defences: Defence, points_left: felt
) -> felt {
    let shield_1 = get_total_fleet_shield_power(fleet);
    let shield_2 = get_total_defences_shield_power(defences);
    let integrity_1 = get_total_fleet_structural_integrity(fleet);
    let integrity_2 = get_total_defences_structural_power(defences);
    return shield_1 + shield_2 + integrity_1 + integrity_2 - points_left;
}

func calculate_battle_outcome{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    attacker_fleet: Fleet, defender_fleet: Fleet, defences: Defence
) -> (att_points_left: felt, def_points_left: felt) {
    alloc_locals;
    let attacker_shield = get_total_fleet_shield_power(attacker_fleet);
    let attacker_str_integrity = get_total_fleet_structural_integrity(attacker_fleet);
    let attacker_weapons_a = get_total_fleet_weapon_power(attacker_fleet);
    let attacker_weapons = attacker_weapons_a * 50;

    let defender_shield_1 = get_total_fleet_shield_power(defender_fleet);
    let defender_shield_2 = get_total_defences_shield_power(defences);
    let defender_str_integrity_1 = get_total_fleet_structural_integrity(defender_fleet);
    let defender_str_integrity_2 = get_total_defences_structural_power(defences);
    let defender_weapons_1_a = get_total_fleet_weapon_power(defender_fleet);
    let defender_weapons_2_a = get_total_defences_weapons_power(defences);
    let defender_weapons_1 = defender_weapons_1_a * 50;
    let defender_weapons_2 = defender_weapons_2_a * 50;

    let attacker_points = attacker_shield + attacker_str_integrity - defender_weapons_1 -
        defender_weapons_2;
    let defender_points = defender_shield_1 + defender_shield_2 + defender_str_integrity_1 +
        defender_str_integrity_2 - attacker_weapons * 5;
    let cond_1 = is_nn(attacker_points);
    let cond_2 = is_nn(defender_points);
    if (cond_1 == FALSE and cond_2 == FALSE) {
        return (0, 0);
    }
    if (cond_1 == FALSE) {
        return (0, defender_points);
    }
    if (cond_2 == FALSE) {
        return (attacker_points, 0);
    }
    return (attacker_points, defender_points);
}

func get_fleet_on_planet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256
) -> Fleet {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (defender_addr) = IERC721.ownerOf(erc721, planet_id);
    let (defender_fleet: Fleet) = INoGame.getFleetLevels(game, defender_addr);
    return defender_fleet;
}

func get_defences_on_planet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256
) -> Defence {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (defender_addr) = IERC721.ownerOf(erc721, planet_id);
    let (defender_defences) = INoGame.getDefencesLevels(game, defender_addr);
    return defender_defences;
}

func safe_ships_sub{range_check_ptr}(lhs: felt, rhs: felt) -> felt {
    let valid = is_le_felt(rhs, lhs);
    if (valid == TRUE) {
        return lhs - rhs;
    } else {
        return 0;
    }
}

func get_planet_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    planet_id: Uint256
) -> (owner: felt) {
    let (game) = FleetMovements_no_game_address.read();
    let (erc721, _, _, _) = INoGame.getTokensAddresses(game);
    let (owner) = IERC721.ownerOf(erc721, planet_id);
    return (owner);
}
