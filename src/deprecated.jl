# v1 deprecations, to be removed in v2

@deprecate get_lodf(system::System) get_lodfs(system)

@deprecate get_regmin(system::System) get_regulation_min(system)
@deprecate get_regmax(system::System) get_regulation_max(system)

@deprecate get_load(system::System) get_loads(system)

@deprecate get_regulation(system::System) get_regulation_offers(system)
@deprecate get_spinning(system::System) get_spinning_offers(system)
@deprecate get_supplemental_on(system::System) get_on_supplemental_offers(system)
@deprecate get_supplemental_off(system::System) get_off_supplemental_offers(system)

@deprecate get_psds_per_bus(system::System) get_psls_per_bus(system)

export get_bids
function get_bids(system::SystemDA, type_of_bid::Symbol)
    if type_of_bid === :increment
        Base.depwarn("`get_bids(system, :increment)` is deprecated, use `get_increments(system)` instead.", :get_bids)
        return get_increments(system)
    elseif type_of_bid === :decrement
        Base.depwarn("`get_bids(system, :decrement)` is deprecated, use `get_decrements(system)` instead.", :get_bids)
        return get_decrements(system)
    elseif type_of_bid === :price_sensitive_demand
        Base.depwarn("`get_bids(system, :price_sensitive_demand)` is deprecated, use `get_price_sensitive_loads(system)` instead.", :get_bids)
        return get_price_sensitive_loads(system)
    else
        Base.depwarn("`get_bids` is deprecated, use `get_increments` or `get_decrements` or `get_price_sensitive_loads`.", :get_bids)
        return getproperty(system, type_of_bid)
    end
end

@deprecate get_regulation_offers(system::System) get_regulation_offers(get_ancillary_services(system))
@deprecate get_spinning_offers(system::System) get_spinning_offers(get_ancillary_services(system))
@deprecate get_on_supplemental_offers(system::System) get_on_supplemental_offers(get_ancillary_services(system))
@deprecate get_off_supplemental_offers(system::System) get_off_supplemental_offers(get_ancillary_services(system))

@deprecate get_zones(system::System) get_requirements(system)
@deprecate get_regulation_requirements(system::System) get_regulation_requirements(get_requirements(system))
@deprecate get_operating_reserve_requirements(system::System) get_operating_reserve_requirements(get_requirements(system))
@deprecate get_good_utility_requirements(system::System) get_good_utility_requirements(get_requirements(system))
