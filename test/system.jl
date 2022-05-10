@testset "system.jl" begin
    datetimes = DateTime(2017, 12, 15):Hour(1):DateTime(2017, 12, 15, 23)
    gen_ids = collect(111:1:120)
    l = length(gen_ids)
    fake_vec_ts = KeyedArray(rand(10); ids=gen_ids)
    fake_gen_ts = KeyedArray(rand(10, 24); ids=gen_ids, datetimes=datetimes)
    fake_offer_ts = KeyedArray(
        repeat([[(1.0, 100.0)]], inner=(1, 24), outer=(10, 1));
        ids=gen_ids, datetimes=datetimes
    )
    fake_bool_ts = KeyedArray(rand(Bool, 10, 24); ids=gen_ids, datetimes=datetimes)
    fake_services_ts = KeyedArray(
        vcat(rand(9, 24), fill(missing, 24)');
        ids=gen_ids, datetimes=datetimes
    )

    branch_names = string.([1, 2, 3])
    bus_names = ["A", "B", "C"]

    @testset "Zone" begin
        zone1 = Zone(1, 1.0, 1.0, 1.0)
        @test zone1 isa Zone
    end

    @testset "Generator" begin
        gen1 = Generator(111, 1, 0.0, 1.0, 1.0, 24.0, 24.0, 2.0, 2.0, :tech)
        @test gen1 isa Generator
    end

    @testset "Bus" begin
        bus1 = Bus("A", 100.0)
        @test bus1 isa Bus
    end

    @testset "Branch" begin
        branch1 = Branch("1", "A", "C", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0))
        @test branch1 isa Branch
    end

    @testset "System" begin
        zone1 = Zone(1, 1.0, 1.0, 1.0)
        zone2 = Zone(2, 4.0, 2.0, 4.0)
        zone_market = Zone(-9999, 3.0, 3.0, 3.0)
        zones = Dictionary([1, 2, -9999], [zone1, zone2, zone_market])

        gen_types = map(gen_ids) do id
            Generator(id, zone1.number, 0.0, 1.0, 1.0, 24.0, 24.0, 2.0, 2.0, :tech)
        end
        gens = Dictionary(gen_ids, gen_types)

        bus_types = map(bus_names) do name
            Bus(name, 100.0)
        end
        buses = Dictionary(bus_names, bus_types)

        branches = Dictionary(
            branch_names,
            [
                Branch("1", "A", "B", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0)),
                Branch("2", "B", "C", 10.0, 10.0, false, (100.0, 0.0), (5.0, 0.0)),
                Branch("3", "C", "A", 10.0, 10.0, true, (0.0, 0.0), (0.0, 0.0)),
            ]
        )

        gens_per_bus = Dictionary(bus_names, rand(gen_ids, 3) for _ in bus_names)
        incs_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        decs_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        psds_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        loads_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)

        lodf = Dictionary(
            ["CONTIN_1"],
            [KeyedArray(rand(3, 1); branches=branch_names, branch=[first(branch_names)])]
        )
        ptdf = KeyedArray(rand(3, 3); row=branch_names, col=bus_names)

        generator_time_series = GeneratorTimeSeries(
            fake_vec_ts,
            fake_offer_ts,
            fake_gen_ts,
            fake_gen_ts,
            fake_gen_ts,
            fake_gen_ts,
            fake_services_ts,
            fake_services_ts,
            fake_services_ts,
            fake_services_ts
        )
        da_gen_status = GeneratorStatusDA(fake_vec_ts, fake_bool_ts, fake_bool_ts)
        da_system = SystemDA(
            gens_per_bus,
            incs_per_bus,
            decs_per_bus,
            psds_per_bus,
            loads_per_bus,
            zones,
            buses,
            gens,
            branches,
            lodf,
            ptdf,
            generator_time_series,
            da_gen_status,
            fake_gen_ts,
            fake_offer_ts,
            fake_offer_ts,
            fake_offer_ts
        )
        @test da_system isa SystemDA

        rt_gen_status = GeneratorStatusRT(fake_bool_ts, fake_bool_ts)
        rt_system = SystemRT(
            gens_per_bus,
            loads_per_bus,
            zones,
            buses,
            gens,
            branches,
            lodf,
            ptdf,
            generator_time_series,
            rt_gen_status,
            fake_gen_ts
        )
        @test rt_system isa SystemRT

        @testset "System accessor functions" begin
            @testset "Common accessors $T" for (system, T) in (
                (da_system, SystemDA), (rt_system, SystemRT)
            )
                @test get_datetimes(system) == datetimes
                @test get_zones(system) == zones
                @test get_regulation_requirements(system) == Dictionary([1, 2, -9999], [1.0, 4.0, 3.0])
                @test get_operating_reserve_requirements(system) == Dictionary([1, 2, -9999], [1.0, 2.0, 3.0])
                @test get_good_utility_requirements(system) == Dictionary([1, 2, -9999], [1.0, 4.0, 3.0])
                @test get_buses(system) == buses
                @test get_generators(system) == gens
                @test get_branches(system) == branches

                @test get_gens_per_bus(system) == gens_per_bus
                @test get_loads_per_bus(system) == loads_per_bus

                @test get_ptdf(system) == ptdf
                @test get_lodf(system) == lodf

                @test get_initial_generation(system) == fake_vec_ts
                @test get_load(system) == fake_gen_ts
                @test get_offer_curve(system) == fake_offer_ts
                @test get_pmin(system) == fake_gen_ts
                @test get_pmax(system) == fake_gen_ts
                @test get_regmin(system) == fake_gen_ts
                @test get_regmax(system) == fake_gen_ts

                @test skipmissing(get_regulation(system)) == skipmissing(fake_services_ts)
                @test skipmissing(get_spinning(system)) == skipmissing(fake_services_ts)
                @test skipmissing(get_supplemental_on(system)) == skipmissing(fake_services_ts)
                @test skipmissing(get_supplemental_off(system)) == skipmissing(fake_services_ts)

                gens_by_zone = gens_per_zone(da_system)
                @test issetequal(keys(gens_by_zone), [1, FullNetworkSystems.MARKET_WIDE_ZONE])
                for (_, v) in gens_by_zone
                    @test v == gen_ids
                end

                zero_bp, one_bp, two_bp = branches_by_breakpoints(da_system)
                @test zero_bp == ["3"]
                @test one_bp == String[] #unmonitored
                @test two_bp == ["1"]
            end

            @testset "SystemDA only accessors" begin
                @test get_initial_commitment(da_system) isa KeyedArray{Bool, 1}
                @test get_incs_per_bus(da_system) == incs_per_bus
                @test get_decs_per_bus(da_system) == decs_per_bus
                @test get_psds_per_bus(da_system) == psds_per_bus

                @test get_bids(da_system, :increment) == fake_offer_ts
                @test get_bids(da_system, :decrement) == fake_offer_ts
                @test get_bids(da_system, :price_sensitive_demand) == fake_offer_ts

                @test get_availability(da_system) == fake_bool_ts
                @test get_must_run(da_system) == fake_bool_ts
            end

            @testset "SystemRT only accessors" begin
                @test get_commitment(rt_system) == fake_bool_ts
                @test get_regulation_commitment(rt_system) == fake_bool_ts
            end
        end
    end
end
