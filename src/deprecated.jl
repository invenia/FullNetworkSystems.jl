# v1 deprecations, to be removed in v2

@deprecate get_lodf(system::System) get_lodfs(system)

@deprecate get_regmin(system::System) get_regulation_min(system)
@deprecate get_regmax(system::System) get_regulation_max(system)

@deprecate get_load(system::System) get_loads(system)

@deprecate get_regulation(system::System) get_regulation_offers(system)
@deprecate get_spinning(system::System) get_spinning_offers(system)
@deprecate get_supplemental_on(system::System) get_on_supplemental_offers(system)
@deprecate get_supplemental_off(system::System) get_off_supplemental_offers(system)
