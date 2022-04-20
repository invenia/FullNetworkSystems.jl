@testset "system.jl" begin
    datetimes = DateTime(2017, 12, 15):Hour(1):DateTime(2017, 12, 15, 23)
    gen_ids = collect(111:1:120)
    l = length(gen_ids)
    fake_gen_ts = KeyedArray(rand(10, 24); ids=gen_ids, datetimes=datetimes)
    fake_offer_ts = KeyedArray(
        repeat([[(1.0, 100.0)]], inner=(1, 24), outer=(10, 1));
        ids=gen_ids, datetimes=datetimes
    )
    fake_bool_ts = KeyedArray(rand(Bool, 10, 24); ids=gen_ids, datetimes=datetimes)

    bus_nums = [111, 222, 333]
    branch_names = string.([1, 2, 3])
    bus_names = ["A", "B", "C"]

    @testset "System" begin
        sts = ServicesTimeSeries(fake_gen_ts, fake_gen_ts, fake_gen_ts, fake_gen_ts)
        @test sts isa ServicesTimeSeries

        zone1 = Zone(1, 1.0, 1.0, 1.0, 1.0)
        zone2 = Zone(1, 4.0, 2.0, 4.0, 2.0)
        zone_market = Zone(-9999, 3.0, 3.0, 3.0, 3.0)
        @testset "Zone" begin
            @test zone1 isa Zone
        end

        gens = Generators(
            gen_ids,
            fill(zone1.number, l), # zone
            fill(0.0, l), # start_up_cost
            fill(1.0, l), # shut_down_cost
            fill(1.0, l), # no_load_cost
            fill(24.0, l), # time_at_status
            fill(24.0, l), # min_uptime
            fill(24.0, l), # min_downtime
            fill(2.0, l), # ramp_up
            fill(2.0, l), # ramp_down
            fill(100.0, l), # initial_gen
            fill(:tech, l)
        )
        expected_gens_zones = Dict(1 => gen_ids)
        @testset "Generators" begin
            @test gens isa Generators
            @test length(gens) == l
            @test gens_per_zone(gens) == expected_gens_zones
        end

        buses = Buses(bus_names, rand(length(bus_names)))
        @testset "Buses" begin
            @test buses isa Buses
            @test length(buses) == length(bus_names)
        end

        branches = Branches(
            branch_names,
            bus_names,
            reverse(bus_names),
            rand(3),
            rand(3),
            [true, true, false],
            [(100.0, 102.0), (100.0,), ()],
            [(5.0, 6.0), (5.0,), ()]
        )
        @testset "Branches" begin
            @test branches isa Branches
            @test length(branches) == length(branch_names)

            zero_bp, one_bp, two_bp = branches_by_breakpoints(branches)
            @test zero_bp == String[] # unmonitored
            @test one_bp == ["2"]
            @test two_bp == ["1"]
        end

        gens_per_bus = Dict(b => rand(gen_ids, 3) for b in bus_nums)
        incs_per_bus = Dict(b => string.(rand('A':'Z', 3)) for b in bus_nums)
        decs_per_bus = Dict(b => string.(rand('A':'Z', 3)) for b in bus_nums)
        psds_per_bus = Dict(b => string.(rand('A':'Z', 3)) for b in bus_nums)
        loads_per_bus = Dict(b => string.(rand('A':'Z', 3)) for b in bus_nums)

        LODF = Dict(
            "CONTIN_1" => KeyedArray(rand(3, 1);
            buses=bus_names, branch=[first(branch_names)])
        )
        PTDF = KeyedArray(rand(3, 3); row=bus_names, col=bus_names)

        da_system = SystemDA(
            gens_per_bus,
            incs_per_bus,
            decs_per_bus,
            psds_per_bus,
            loads_per_bus,
            [zone1, zone2, zone_market],
            buses,
            gens,
            branches,
            LODF,
            PTDF,
            fake_offer_ts,
            fake_bool_ts,
            fake_bool_ts,
            fake_gen_ts,
            fake_gen_ts,
            fake_gen_ts,
            fake_gen_ts,
            sts,
            fake_gen_ts,
            fake_offer_ts,
            fake_offer_ts,
            fake_offer_ts
        )

        @test da_system isa SystemDA
        @test get_datetimes(da_system) == datetimes

        rt_system = SystemRT(
            gens_per_bus,
            loads_per_bus,
            [zone1, zone2, zone_market],
            buses,
            gens,
            branches,
            LODF,
            PTDF,
            fake_offer_ts,
            fake_bool_ts,
            fake_bool_ts,
            fake_gen_ts,
            fake_gen_ts,
            fake_gen_ts,
            fake_gen_ts,
            sts,
            fake_gen_ts
        )

        @test rt_system isa SystemRT
        @test get_datetimes(rt_system) == datetimes
    end
end
