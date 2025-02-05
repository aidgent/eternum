use core::array::{ArrayTrait, SpanTrait};
use core::traits::Into;

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use eternum::constants::DONKEY_ENTITY_TYPE;

use eternum::constants::ResourceTypes;
use eternum::models::movable::{Movable, ArrivalTime};
use eternum::models::owner::Owner;
use eternum::models::position::{Position};
use eternum::models::resources::Resource;

use eternum::models::trade::{Trade, Status, TradeStatus};
use eternum::models::weight::Weight;

use eternum::systems::config::contracts::{
    config_systems, ITransportConfigDispatcher, ITransportConfigDispatcherTrait,
    IWeightConfigDispatcher, IWeightConfigDispatcherTrait, ICapacityConfigDispatcher,
    ICapacityConfigDispatcherTrait
};

use eternum::systems::realm::contracts::{
    realm_systems, IRealmSystemsDispatcher, IRealmSystemsDispatcherTrait
};

use eternum::systems::trade::contracts::trade_systems::{
    trade_systems, ITradeSystemsDispatcher, ITradeSystemsDispatcherTrait
};

use eternum::utils::testing::{spawn_eternum, deploy_system};

use starknet::contract_address_const;


fn setup() -> (IWorldDispatcher, u128, u128, u128, ITradeSystemsDispatcher) {
    let world = spawn_eternum();

    let config_systems_address = deploy_system(world, config_systems::TEST_CLASS_HASH);

    // set speed configuration 
    ITransportConfigDispatcher { contract_address: config_systems_address }
        .set_speed_config(DONKEY_ENTITY_TYPE, 10); // 10km per sec

    // set weight configuration for stone
    IWeightConfigDispatcher { contract_address: config_systems_address }
        .set_weight_config(ResourceTypes::STONE.into(), 200);

    // set weight configuration for gold
    IWeightConfigDispatcher { contract_address: config_systems_address }
        .set_weight_config(ResourceTypes::GOLD.into(), 200);

    // set weight configuration for wood
    IWeightConfigDispatcher { contract_address: config_systems_address }
        .set_weight_config(ResourceTypes::WOOD.into(), 200);

    // set weight configuration for silver
    IWeightConfigDispatcher { contract_address: config_systems_address }
        .set_weight_config(ResourceTypes::SILVER.into(), 200);

    let realm_systems_address = deploy_system(world, realm_systems::TEST_CLASS_HASH);
    let realm_systems_dispatcher = IRealmSystemsDispatcher {
        contract_address: realm_systems_address
    };

    // maker and taker are at the same location
    // so they can trade without transport
    let maker_position = Position { x: 100000, y: 1000000, entity_id: 1_u128 };
    let taker_position = Position { x: 100000, y: 1000000, entity_id: 1_u128 };

    let realm_id = 1;
    let resource_types_packed = 1;
    let resource_types_count = 1;
    let cities = 6;
    let harbors = 5;
    let rivers = 5;
    let regions = 5;
    let wonder = 1;
    let order = 1;

    // create maker's realm
    let maker_realm_entity_id = realm_systems_dispatcher
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
            maker_position.clone(),
        );
    // create taker's realm
    let taker_realm_entity_id = realm_systems_dispatcher
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
            taker_position.clone(),
        );

    let maker_id = maker_realm_entity_id;
    let taker_id = taker_realm_entity_id;

    set!(world, (Owner { entity_id: maker_id, address: contract_address_const::<'maker'>() }));
    set!(world, (Owner { entity_id: taker_id, address: contract_address_const::<'taker'>() }));

    set!(
        world, (Resource { entity_id: maker_id, resource_type: ResourceTypes::STONE, balance: 100 })
    );
    set!(
        world, (Resource { entity_id: maker_id, resource_type: ResourceTypes::GOLD, balance: 100 })
    );

    set!(
        world, (Resource { entity_id: taker_id, resource_type: ResourceTypes::WOOD, balance: 500 })
    );
    set!(
        world,
        (Resource { entity_id: taker_id, resource_type: ResourceTypes::SILVER, balance: 500 })
    );

    starknet::testing::set_contract_address(contract_address_const::<'maker'>());

    let trade_systems_address = deploy_system(world, trade_systems::TEST_CLASS_HASH);
    let trade_systems_dispatcher = ITradeSystemsDispatcher {
        contract_address: trade_systems_address
    };

    // create order
    starknet::testing::set_contract_address(contract_address_const::<'maker'>());

    // trade 100 stone and 100 gold for 200 wood and 200 silver
    let trade_id = trade_systems_dispatcher
        .create_order(
            maker_id,
            array![(ResourceTypes::STONE, 100), (ResourceTypes::GOLD, 100),].span(),
            taker_id,
            array![(ResourceTypes::WOOD, 200), (ResourceTypes::SILVER, 200),].span(),
            100
        );

    (world, trade_id, maker_id, taker_id, trade_systems_dispatcher)
}


#[test]
#[available_gas(3000000000000)]
fn test_cancel() {
    let (world, trade_id, maker_id, _, trade_systems_dispatcher) = setup();

    let _trade = get!(world, trade_id, Trade);

    // cancel order 
    starknet::testing::set_contract_address(contract_address_const::<'maker'>());
    trade_systems_dispatcher
        .cancel_order(
            trade_id, array![(ResourceTypes::STONE, 100), (ResourceTypes::GOLD, 100),].span()
        );

    // check that maker balance is correct
    let maker_stone_resource = get!(world, (maker_id, ResourceTypes::STONE), Resource);
    assert(maker_stone_resource.balance == 100, 'wrong maker balance');

    let maker_gold_resource = get!(world, (maker_id, ResourceTypes::GOLD), Resource);
    assert(maker_gold_resource.balance == 100, 'wrong maker balance');

    // check that trade status is cancelled
    let trade_status = get!(world, trade_id, Status);
    assert(trade_status.value == TradeStatus::CANCELLED, 'wrong trade status');
}


#[test]
#[available_gas(3000000000000)]
#[should_panic(expected: ('trade must be open', 'ENTRYPOINT_FAILED'))]
fn test_cancel_after_acceptance() {
    let (world, trade_id, _, _, trade_systems_dispatcher) = setup();

    // accept order 

    set!(world, (Status { trade_id, value: TradeStatus::ACCEPTED, }),);

    // cancel order 
    starknet::testing::set_contract_address(contract_address_const::<'maker'>());
    trade_systems_dispatcher
        .cancel_order(
            trade_id, array![(ResourceTypes::STONE, 100), (ResourceTypes::GOLD, 100),].span()
        );
}


#[test]
#[available_gas(3000000000000)]
#[should_panic(expected: ('caller must be trade maker', 'ENTRYPOINT_FAILED'))]
fn test_cancel_caller_not_maker() {
    let (_, trade_id, _, _, trade_systems_dispatcher) = setup();

    // set caller to an unknown address
    starknet::testing::set_contract_address(contract_address_const::<'unknown'>());

    // cancel order 
    trade_systems_dispatcher
        .cancel_order(
            trade_id, array![(ResourceTypes::STONE, 100), (ResourceTypes::GOLD, 100),].span()
        );
}
