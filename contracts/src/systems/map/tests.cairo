use core::traits::TryInto;

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

use eternum::constants::{ResourceTypes, WORLD_CONFIG_ID};
use eternum::models::capacity::Capacity;
use eternum::models::combat::{Health};

use eternum::models::map::Tile;
use eternum::models::movable::{Movable};
use eternum::models::owner::Owner;
use eternum::models::owner::{EntityOwner};
use eternum::models::position::{Position, Coord, CoordTrait, Direction};
use eternum::models::quantity::Quantity;
use eternum::models::realm::Realm;
use eternum::models::resources::{Resource, ResourceFoodImpl};
use eternum::models::tick::TickConfig;
use eternum::models::weight::Weight;

use eternum::systems::config::contracts::{
    config_systems, IRealmFreeMintConfigDispatcher, IRealmFreeMintConfigDispatcherTrait,
    IMapConfigDispatcher, IMapConfigDispatcherTrait, IWeightConfigDispatcher,
    IWeightConfigDispatcherTrait
};

use eternum::systems::map::contracts::map_systems;

use eternum::systems::map::contracts::{IMapSystemsDispatcher, IMapSystemsDispatcherTrait};

use eternum::systems::realm::contracts::{
    realm_systems, IRealmSystemsDispatcher, IRealmSystemsDispatcherTrait
};
use eternum::systems::transport::contracts::travel_systems::{
    travel_systems, ITravelSystemsDispatcher, ITravelSystemsDispatcherTrait
};

use eternum::utils::testing::{spawn_eternum, deploy_system};
use starknet::contract_address_const;

const INITIAL_WHEAT_BALANCE: u128 = 7000;
const INITIAL_FISH_BALANCE: u128 = 2000;
const MAP_EXPLORE_WHEAT_BURN_AMOUNT: u128 = 1000;
const MAP_EXPLORE_FISH_BURN_AMOUNT: u128 = 500;

const MAP_EXPLORE_RANDOM_MINT_AMOUNT: u128 = 3;
const MAP_EXPLORE_PRECOMPUTED_RANDOM_MINT_RESOURCE: u8 = 6; // silver
const SHARDS_MINE_FAIL_PROBABILITY_WEIGHT: u128 = 1000;

const TIMESTAMP: u64 = 10000;

const MAX_MOVES_PER_TICK: u8 = 12;
const TICK_INTERVAL_IN_SECONDS: u64 = 3;

fn setup() -> (IWorldDispatcher, u128, u128, IMapSystemsDispatcher) {
    let world = spawn_eternum();

    starknet::testing::set_block_timestamp(TIMESTAMP);

    let config_systems_address = deploy_system(world, config_systems::TEST_CLASS_HASH);

    // set initial food resources
    let initial_resources = array![
        (ResourceTypes::WHEAT, INITIAL_WHEAT_BALANCE), (ResourceTypes::FISH, INITIAL_FISH_BALANCE),
    ];

    let mint_config_index = 0;

    IRealmFreeMintConfigDispatcher { contract_address: config_systems_address }
        .set_mint_config(mint_config_index, initial_resources.span());

    // set weight configuration for rewarded resource (silver)
    IWeightConfigDispatcher { contract_address: config_systems_address }
        .set_weight_config(ResourceTypes::SILVER.into(), 1);

    // set map exploration config
    IMapConfigDispatcher { contract_address: config_systems_address }
        .set_exploration_config(
            MAP_EXPLORE_WHEAT_BURN_AMOUNT,
            MAP_EXPLORE_FISH_BURN_AMOUNT,
            MAP_EXPLORE_RANDOM_MINT_AMOUNT,
            SHARDS_MINE_FAIL_PROBABILITY_WEIGHT
        );

    // set tick config
    let tick_config = TickConfig {
        config_id: WORLD_CONFIG_ID,
        max_moves_per_tick: MAX_MOVES_PER_TICK,
        tick_interval_in_seconds: TICK_INTERVAL_IN_SECONDS
    };
    set!(world, (tick_config));

    // create realm
    let realm_systems_address = deploy_system(world, realm_systems::TEST_CLASS_HASH);
    let realm_systems_dispatcher = IRealmSystemsDispatcher {
        contract_address: realm_systems_address
    };

    let realm_position = Position { x: 20, y: 30, entity_id: 1_u128 };

    let realm_id = 1;
    let resource_types_packed = 1;
    let resource_types_count = 1;
    let cities = 6;
    let harbors = 5;
    let rivers = 5;
    let regions = 5;
    let wonder = 1;
    let order = 1;

    starknet::testing::set_contract_address(contract_address_const::<'realm_owner'>());

    let realm_entity_id = realm_systems_dispatcher
        .create(
            realm_id,
            resource_types_packed,
            resource_types_count,
            cities,
            harbors,
            rivers,
            regions,
            wonder,
            order,
            realm_position.clone(),
        );

    let realm_owner: Owner = get!(world, realm_entity_id, Owner);

    // create realm army unit
    let realm_army_unit_id: u128 = 'army unit'.try_into().unwrap();
    let army_quantity_value: u128 = 7;
    let army_capacity_value_per_soldier: u128 = 7;

    // set army health value to make it alive
    set!(world, (Health { entity_id: realm_army_unit_id, current: 1, lifetime: 1 }));

    set!(
        world,
        (
            Owner { entity_id: realm_army_unit_id, address: realm_owner.address },
            EntityOwner { entity_id: realm_army_unit_id, entity_owner_id: realm_entity_id },
            Quantity { entity_id: realm_army_unit_id, value: army_quantity_value },
            Position { entity_id: realm_army_unit_id, x: realm_position.x, y: realm_position.y },
            Capacity {
                entity_id: realm_army_unit_id, weight_gram: army_capacity_value_per_soldier
            },
            Movable {
                entity_id: realm_army_unit_id,
                sec_per_km: 1,
                blocked: false,
                round_trip: false,
                start_coord_x: 0,
                start_coord_y: 0,
                intermediate_coord_x: 0,
                intermediate_coord_y: 0,
            }
        )
    );

    // deploy map systems
    let map_systems_address = deploy_system(world, map_systems::TEST_CLASS_HASH);
    let map_systems_dispatcher = IMapSystemsDispatcher { contract_address: map_systems_address };

    (world, realm_entity_id, realm_army_unit_id, map_systems_dispatcher)
}


#[test]
fn test_map_explore() {
    let (world, realm_entity_id, realm_army_unit_id, map_systems_dispatcher) = setup();

    starknet::testing::set_contract_address(contract_address_const::<'realm_owner'>());

    starknet::testing::set_transaction_hash('hellothash');

    let mut army_coord: Coord = get!(world, realm_army_unit_id, Position).into();
    let explore_tile_direction: Direction = Direction::West;

    map_systems_dispatcher.explore(realm_army_unit_id, explore_tile_direction);

    let expected_explored_coord = army_coord.neighbor(explore_tile_direction);

    // ensure that Tile model is correct
    let explored_tile: Tile = get!(
        world, (expected_explored_coord.x, expected_explored_coord.y), Tile
    );
    assert_eq!(explored_tile.col, explored_tile._col, "wrong col");
    assert_eq!(explored_tile.row, explored_tile._row, "wrong row");
    assert_eq!(explored_tile.explored_by_id, realm_army_unit_id, "wrong realm owner");
    assert_eq!(explored_tile.explored_at, TIMESTAMP, "wrong exploration time");

    // ensure that the right amount of food was burnt 
    let expected_wheat_balance = INITIAL_WHEAT_BALANCE - MAP_EXPLORE_WHEAT_BURN_AMOUNT;
    let expected_fish_balance = INITIAL_FISH_BALANCE - MAP_EXPLORE_FISH_BURN_AMOUNT;
    let (realm_wheat, realm_fish) = ResourceFoodImpl::get(world, realm_entity_id);
    assert_eq!(realm_wheat.balance, expected_wheat_balance, "wrong wheat balance");
    assert_eq!(realm_fish.balance, expected_fish_balance, "wrong wheat balance");

    army_coord = expected_explored_coord;
}


#[test]
#[should_panic(expected: ("max moves per tick exceeded", 'ENTRYPOINT_FAILED'))]
fn test_map_explore__ensure_explorer_cant_hex_travel_till_next_tick() {
    let (world, _, realm_army_unit_id, map_systems_dispatcher) = setup();

    starknet::testing::set_contract_address(contract_address_const::<'realm_owner'>());

    starknet::testing::set_transaction_hash('hellothash');

    let explore_tile_direction: Direction = Direction::West;

    map_systems_dispatcher.explore(realm_army_unit_id, explore_tile_direction);

    // deploy travel systems
    let travel_systems_address = deploy_system(world, travel_systems::TEST_CLASS_HASH);
    let travel_systems_dispatcher = ITravelSystemsDispatcher {
        contract_address: travel_systems_address
    };

    // ensure army cant travel in same tick
    travel_systems_dispatcher.travel_hex(realm_army_unit_id, array![Direction::West].span());
}
