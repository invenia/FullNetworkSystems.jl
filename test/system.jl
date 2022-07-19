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
        branch1 = Branch("1", "A", "C", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0), 1.0, 1.0)
        @test branch1 isa Branch
        @test !branch1.is_transformer

        branch2 = Branch("2", "A", "C", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0))
        @test branch2 isa Branch
        @test !branch2.is_transformer

        transformer1 = Branch(
            "1", "A", "C", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0), 1.0, 1.0, 0.5, 30.0
        )
        @test transformer1 isa Branch
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

        bus_names = ["A", "B", "C"]
        bus_types = map(bus_names) do name
            Bus(name, 100.0)
        end
        buses = Dictionary(bus_names, bus_types)

        branch_names = string.([1,2,3,4])
        branches = Dictionary(
            branch_names,
            [
                Branch("1", "A", "B", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0), 1.0, 1.0),
                Branch("2", "B", "C", 10.0, 10.0, false, (100.0, 0.0), (5.0, 0.0), 1.0, 1.0),
                Branch("3", "C", "A", 10.0, 10.0, true, (0.0, 0.0), (0.0, 0.0), 1.0, 1.0),
                Branch(
                    "4", "A", "C", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0), 1.0, 1.0, 0.5, 30.0
                )
            ]
        )

        gens_per_bus = Dictionary(bus_names, rand(gen_ids, 3) for _ in bus_names)
        incs_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        decs_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        psds_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        loads_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)

        lodf = Dictionary(
            ["CONTIN_1"],
            [KeyedArray(rand(4, 1); branches=branch_names, branch=[first(branch_names)])]
        )
        ptdf = KeyedArray(rand(4, 3); row=branch_names, col=bus_names)

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


        @testset "Constructors using keywords" begin
            zone_kws = Zone(
                number=1, regulation=10.0, operating_reserve=20.0, good_utility=5.0
            )
            @test zone_kws isa Zone
            @test zone_kws.regulation == 10.0

            generator_kws = Generator(
                unit_code=1,
                zone=1,
                startup_cost=10.0,
                shutdown_cost=5.0,
                no_load_cost=1.0,
                min_uptime=2.0,
                min_downtime=1.0,
                ramp_up=0.2,
                ramp_down=0.4,
                technology=:foo
            )
            @test generator_kws isa Generator
            @test generator_kws.technology == :foo

            bus_kws = Bus(name="foo", base_voltage=69.0)
            @test bus_kws isa Bus
            @test bus_kws.base_voltage == 69.0

            branch_kws = Branch(
                name="moo",
                to_bus="foo1",
                from_bus="foo2",
                rate_a=50.0,
                rate_b=55.0,
                is_monitored=true,
                is_transformer=false,
                break_points=(1.0, 2.0),
                penalties=(3.0, 4.0),
                resistance=1.0,
                reactance=1.0
            )
            @test branch_kws isa Branch
            @test branch_kws.is_monitored

            gen_ts_kws = GeneratorTimeSeries(
                initial_generation=fake_vec_ts,
                offer_curve=fake_offer_ts,
                regulation_min=fake_gen_ts,
                regulation_max=fake_gen_ts,
                pmin=fake_gen_ts,
                pmax=fake_gen_ts,
                asm_regulation=fake_services_ts,
                asm_spin=fake_services_ts,
                asm_sup_on=fake_services_ts,
                asm_sup_off=fake_services_ts
            )
            @test gen_ts_kws isa GeneratorTimeSeries
            @test gen_ts_kws.pmin == fake_gen_ts

            da_gen_status_kws = GeneratorStatusDA(
                hours_at_status=fake_vec_ts,
                availability=fake_bool_ts,
                must_run=fake_bool_ts
            )
            @test da_gen_status_kws isa GeneratorStatusDA
            @test da_gen_status_kws.must_run == fake_bool_ts

            rt_gen_status_kws = GeneratorStatusRT(
                status=fake_bool_ts,
                status_regulation=fake_bool_ts
            )
            @test rt_gen_status_kws isa GeneratorStatusRT
            @test rt_gen_status_kws.status == fake_bool_ts

            da_system_kws = SystemDA(
                buses=buses,
                generators=gens,
                loads=fake_gen_ts,
                branches=branches,
                zones=zones,
                generator_time_series=generator_time_series,
                generator_status=da_gen_status,
                increment=fake_offer_ts,
                decrement=fake_offer_ts,
                price_sensitive_demand=fake_offer_ts,
                gens_per_bus=gens_per_bus,
                incs_per_bus=incs_per_bus,
                decs_per_bus=decs_per_bus,
                psds_per_bus=psds_per_bus,
                loads_per_bus=loads_per_bus,
                lodf=lodf,
                ptdf=ptdf,
            )
            @test da_system_kws isa SystemDA
            @test da_system_kws.ptdf == ptdf

            rt_system_kws = SystemRT(
                gens_per_bus=gens_per_bus,
                loads_per_bus=loads_per_bus,
                zones=zones,
                buses=buses,
                generators=gens,
                branches=branches,
                lodf=lodf,
                ptdf=ptdf,
                generator_time_series=generator_time_series,
                generator_status=rt_gen_status,
                loads=fake_gen_ts
            )
            @test rt_system_kws isa SystemRT
            @test rt_system_kws.lodf == lodf
        end

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
                @test get_lines(system) == Dictionary(
                    ["1", "2", "3"], [branches["1"], branches["2"], branches["3"]]
                )
                @test get_transformers(system) == Dictionary(["4"], [branches["4"]])

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
                @test two_bp == ["1", "4"]

                # Check that we can remove the PTDF
                system.ptdf = missing
                @test system.ptdf === missing
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
