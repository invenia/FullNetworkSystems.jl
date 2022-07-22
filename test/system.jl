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
        psds_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)
        loads_per_bus = Dictionary(bus_names, string.(rand('A':'Z', 3)) for _ in bus_names)

        lodf = Dictionary(
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
        asm_regulation = services_time_series()
        asm_spin = services_time_series()
        asm_sup_on = services_time_series()
        asm_sup_off = services_time_series()

        generator_time_series = GeneratorTimeSeries(;
            initial_generation,
            offer_curve,
            regulation_min,
            regulation_max,
            pmin,
            pmax,
            asm_regulation,
            asm_spin,
            asm_sup_on,
            asm_sup_off,
        )

        hours_at_status = KeyedArray(rand(length(ids)); ids)
        availability = time_series(Bool)
        must_run = time_series(Bool)
        da_generator_status = GeneratorStatusDA(; hours_at_status, availability, must_run)

        loads = time_series()
        increment = offer_time_series()
        decrement = offer_time_series()
        price_sensitive_demand = offer_time_series()
        da_system = SystemDA(;
            gens_per_bus,
            incs_per_bus,
            decs_per_bus,
            psds_per_bus,
            loads_per_bus,
            zones,
            buses,
            generators,
            branches,
            lodf,
            ptdf,
            generator_time_series,
            generator_status=da_generator_status,
            loads,
            increment,
            decrement,
            price_sensitive_demand,
        )
        @test da_system isa SystemDA

        status = time_series(Bool)
        status_regulation = time_series(Bool)
        rt_generator_status = GeneratorStatusRT(; status, status_regulation)

        rt_system = SystemRT(;
            gens_per_bus,
            loads_per_bus,
            zones,
            buses,
            generators,
            branches,
            lodf,
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
                @test get_lodf(system) == lodf

                @test get_initial_generation(system) == initial_generation
                @test get_load(system) == loads
                @test get_offer_curve(system) == offer_curve
                @test get_pmin(system) == pmin
                @test get_pmax(system) == pmax
                @test get_regmin(system) == regulation_min
                @test get_regmax(system) == regulation_max

                @test skipmissing(get_regulation(system)) == skipmissing(asm_regulation)
                @test skipmissing(get_spinning(system)) == skipmissing(asm_spin)
                @test skipmissing(get_supplemental_on(system)) == skipmissing(asm_sup_on)
                @test skipmissing(get_supplemental_off(system)) == skipmissing(asm_sup_off)

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
            end

            @testset "SystemDA only accessors" begin
                @test get_initial_commitment(da_system) isa KeyedArray{Bool, 1}
                @test get_initial_commitment(da_system) == [trues(length(ids) - 2); falses(2)]
                @test get_incs_per_bus(da_system) == incs_per_bus
                @test get_decs_per_bus(da_system) == decs_per_bus
                @test get_psds_per_bus(da_system) == psds_per_bus

                @test get_bids(da_system, :increment) == increment
                @test get_bids(da_system, :decrement) == decrement
                @test get_bids(da_system, :price_sensitive_demand) == price_sensitive_demand

                @test get_availability(da_system) == availability
                @test get_must_run(da_system) == must_run
            end

            @testset "SystemRT only accessors" begin
                @test get_commitment(rt_system) == status
                @test get_regulation_commitment(rt_system) == status_regulation
            end
        end
    end
end
