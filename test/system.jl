@testset "system.jl" begin

    @testset "Zone" begin
        zone1 = Zone(number=1, regulation=1.0, operating_reserve=1.0, good_utility=1.0)
        @test zone1 isa Zone
    end

    @testset "Generator" begin
        gen1 = Generator(
            unit_code=111,
            zone=1,
            startup_cost=0.0,
            shutdown_cost=1.0,
            no_load_cost=1.0,
            min_uptime=24.0,
            min_downtime=24.0,
            ramp_up=2.0,
            ramp_down=2.0,
            technology=:tech
        )
        @test gen1 isa Generator
    end

    @testset "Bus" begin
        bus1 = Bus(name="A", base_voltage=100.0)
        @test bus1 isa Bus
    end

    @testset "Branch" begin
        branch1 = Branch(
            name="1",
            to_bus="A",
            from_bus="C",
            rate_a=10.0,
            rate_b=10.0,
            is_monitored=true,
            break_points=(100.0, 102.0),
            penalties=(5.0, 6.0),
            resistance=1.0,
            reactance=1.0
        )
        @test branch1 isa Branch
        @test !branch1.is_transformer

        branch2 = Branch(
            "2",
            "A",
            "C",
            10.0,
            10.0,
            true,
            (100.0, 102.0),
            (5.0, 6.0)
        )
        @test branch2 isa Branch
        @test !branch2.is_transformer

        transformer1 = Branch(
            name="1",
            to_bus="A",
            from_bus="C",
            rate_a=10.0,
            rate_b=10.0,
            is_monitored=true,
            break_points=(100.0, 102.0),
            penalties=(5.0, 6.0),
            resistance=1.0,
            reactance=1.0,
            tap=0.5,
            angle=30.0
        )
        @test transformer1 isa Branch
    end

    @testset "System" begin
        zone1 = Zone(1, 1.0, 1.0, 1.0)
        zone2 = Zone(2, 4.0, 2.0, 4.0)
        zone_market = Zone(-9999, 3.0, 3.0, 3.0)
        zones = Dictionary([1, 2, -9999], [zone1, zone2, zone_market])

        gen_ids = collect(111:1:120)
        gen_types = map(gen_ids) do id
            Generator(id, zone1.number, 0.0, 1.0, 1.0, 24.0, 24.0, 2.0, 2.0, :tech)
        end
        generators = Dictionary(gen_ids, gen_types)

        bus_names = ["A", "B", "C"]
        bus_types = map(bus_names) do name
            Bus(name, 100.0)
        end
        buses = Dictionary(bus_names, bus_types)

        branch_names = string.([1,2,3,4])
        branches = Dictionary(
            branch_names,
            [
                Branch("1", "A", "B", 10.0, 10.0, true,  (100.0, 102.0), (5.0, 6.0), 1.0, 1.0),
                Branch("2", "B", "C", 10.0, 10.0, false, (100.0,   0.0), (5.0, 0.0), 1.0, 1.0),
                Branch("3", "C", "A", 10.0, 10.0, true,  (0.0,     0.0), (0.0, 0.0), 1.0, 1.0),
                Branch("4", "A", "C", 10.0, 10.0, true,  (100.0, 102.0), (5.0, 6.0), 1.0, 1.0, 0.5, 30.0,
                )
            ]
        )

        gens_per_bus = Dictionary(bus_names, rand(gen_ids, 3) for _ in bus_names)
        incs_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        decs_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        psls_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        loads_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)

        lodfs = Dictionary(
            ["CONTIN_1"],
            [KeyedArray(rand(4, 1); branches=branch_names, branch=[first(branch_names)])]
        )
        ptdf = KeyedArray(rand(4, 3); row=branch_names, col=bus_names)

        ids = gen_ids
        datetimes = DateTime(2017, 12, 15):Hour(1):DateTime(2017, 12, 15, 23)
        time_series(T=Float64) = KeyedArray(rand(T, length(ids), length(datetimes)); ids, datetimes)
        services_time_series() = KeyedArray(vcat(rand(length(ids) - 1, length(datetimes)), fill(missing, 1, length(datetimes))); ids, datetimes)
        offer_time_series() = KeyedArray(fill([(1.0, 100.0)], length(ids), length(datetimes)); ids, datetimes)

        initial_generation = KeyedArray([rand(length(ids) - 2); fill(0.0, 2)]; ids)
        offer_curve = offer_time_series()
        regulation_min = time_series()
        regulation_max = time_series()
        pmin = time_series()
        pmax = time_series()
        pmin = time_series()
        pmax = time_series()
        regulation_offers = services_time_series()
        spinning_offers = services_time_series()
        on_supplemental_offers = services_time_series()
        off_supplemental_offers = services_time_series()

        generator_time_series = GeneratorTimeSeries(;
            initial_generation,
            offer_curve,
            regulation_min,
            regulation_max,
            pmin,
            pmax,
            regulation_offers,
            spinning_offers,
            on_supplemental_offers,
            off_supplemental_offers,
        )

        hours_at_status = KeyedArray(rand(length(ids)); ids)
        availability = time_series(Bool)
        must_run = time_series(Bool)
        da_generator_status = GeneratorStatusDA(; hours_at_status, availability, must_run)

        loads = time_series()
        increments = offer_time_series()
        decrements = offer_time_series()
        price_sensitive_loads = offer_time_series()
        da_system = SystemDA(;
            gens_per_bus,
            incs_per_bus,
            decs_per_bus,
            psls_per_bus,
            loads_per_bus,
            zones,
            buses,
            generators,
            branches,
            lodfs,
            ptdf,
            generator_time_series,
            generator_status=da_generator_status,
            loads,
            increments,
            decrements,
            price_sensitive_loads,
        )
        @test da_system isa SystemDA

        commitment = time_series(Bool)
        regulation_commitment= time_series(Bool)
        rt_generator_status = GeneratorStatusRT(; commitment, regulation_commitment)

        rt_system = SystemRT(;
            gens_per_bus,
            loads_per_bus,
            zones,
            buses,
            generators,
            branches,
            lodfs,
            ptdf,
            generator_time_series,
            generator_status=rt_generator_status,
            loads,
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
                @test get_generators(system) == generators
                @test get_branches(system) == branches
                @test get_lines(system) == Dictionary(
                    ["1", "2", "3"], [branches["1"], branches["2"], branches["3"]]
                )
                @test get_transformers(system) == Dictionary(["4"], [branches["4"]])

                @test get_gens_per_bus(system) == gens_per_bus
                @test get_loads_per_bus(system) == loads_per_bus

                @test get_ptdf(system) == ptdf
                @test get_lodfs(system) == lodfs

                @test get_initial_generation(system) == initial_generation
                @test get_loads(system) == loads
                @test get_offer_curve(system) == offer_curve
                @test get_pmin(system) == pmin
                @test get_pmax(system) == pmax
                @test get_regulation_min(system) == regulation_min
                @test get_regulation_max(system) == regulation_max

                @test skipmissing(get_regulation_offers(system)) == skipmissing(regulation_offers)
                @test skipmissing(get_spinning_offers(system)) == skipmissing(spinning_offers)
                @test skipmissing(get_on_supplemental_offers(system)) == skipmissing(on_supplemental_offers)
                @test skipmissing(get_off_supplemental_offers(system)) == skipmissing(off_supplemental_offers)

                gens_by_zone = gens_per_zone(system)
                @test issetequal(keys(gens_by_zone), [1, FullNetworkSystems.MARKET_WIDE_ZONE])
                for (_, v) in gens_by_zone
                    @test v == gen_ids
                end

                zero_bp, one_bp, two_bp = branches_by_breakpoints(system)
                @test zero_bp == ["3"]
                @test one_bp == [] # unmonitored
                @test two_bp == ["1", "4"]
                @test eltype(zero_bp) == eltype(one_bp) == eltype(two_bp) == FullNetworkSystems.BranchName

                # Also test on a system with a 1-breakpoint branch
                da_system.branches = Dictionary(
                    branch_names,
                    [
                        Branch("1", "A", "B", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0), 1.0, 1.0),
                        Branch("2", "B", "C", 10.0, 10.0, true, (100.0,   0.0), (5.0, 0.0), 1.0, 1.0),
                        Branch("3", "C", "A", 10.0, 10.0, true, (0.0,     0.0), (5.0, 6.0), 1.0, 1.0),
                        Branch("4", "A", "C", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0), 1.0, 1.0),
                    ]
                )
                zero_bp, one_bp, two_bp = branches_by_breakpoints(da_system)
                @test zero_bp == ["3"]
                @test one_bp == ["2"]
                @test two_bp == ["1", "4"]
                da_system.branches = branches  # reset

                # Check that we can remove the PTDF
                system.ptdf = missing
                @test system.ptdf === missing

                @testset "deprecated" begin
                    @test (@test_deprecated get_lodf(system)) == lodfs

                    @test (@test_deprecated get_regmin(system)) == regulation_min
                    @test (@test_deprecated get_regmax(system)) == regulation_max

                    @test (@test_deprecated get_load(system)) == loads

                    @test (@test_deprecated skipmissing(get_regulation(system))) == skipmissing(regulation_offers)
                    @test (@test_deprecated skipmissing(get_spinning(system))) == skipmissing(spinning_offers)
                    @test (@test_deprecated skipmissing(get_supplemental_on(system))) == skipmissing(on_supplemental_offers)
                    @test (@test_deprecated skipmissing(get_supplemental_off(system))) == skipmissing(off_supplemental_offers)
                end
            end

            @testset "SystemDA only accessors" begin
                @test get_initial_commitment(da_system) == [trues(length(ids) - 2); falses(2)]

                @test get_initial_uptime(da_system) == [hours_at_status[1:end-2]..., 0, 0]
                @test get_initial_downtime(da_system) == [zeros(length(ids)-2); hours_at_status[end-1:end]...]

                @test get_incs_per_bus(da_system) == incs_per_bus
                @test get_decs_per_bus(da_system) == decs_per_bus
                @test get_psls_per_bus(da_system) == psls_per_bus

                @test get_increments(da_system) == increments
                @test get_decrements(da_system) == decrements
                @test get_price_sensitive_loads(da_system) == price_sensitive_loads

                @test get_availability(da_system) == availability
                @test get_must_run(da_system) == must_run

                @testset "deprecated" begin
                    @test (@test_deprecated get_bids(da_system, :increment)) == increments
                    @test (@test_deprecated get_bids(da_system, :decrement)) == decrements
                    @test (@test_deprecated get_bids(da_system, :price_sensitive_demand)) == price_sensitive_loads
                    @test (@test_deprecated get_psds_per_bus(da_system)) == psls_per_bus
                end
            end

            @testset "SystemRT only accessors" begin
                @test get_commitment(rt_system) == commitment
                @test get_regulation_commitment(rt_system) == regulation_commitment
            end
        end
    end
end
