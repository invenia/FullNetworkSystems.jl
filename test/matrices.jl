function _to_branch(nt)
    return Branch(;
        nt...,
        tap=missing,
        angle=missing,
        # fill unused fields with zeroes
        rate_a=0,
        rate_b=0,
        is_monitored=false,
        break_points=(0,0),
        penalties=(0,0),
    )
end

branch_nt = NamedTuple{(:name, :to_bus, :from_bus, :resistance, :reactance)}.([
    ("branch_1", "bus_2", "bus_1", 0.01938, 0.05917),
    ("branch_2", "bus_5", "bus_1", 0.05403, 0.22304),
    ("branch_3", "bus_3", "bus_2", 0.04699, 0.19797),
    ("branch_4", "bus_4", "bus_2", 0.05811, 0.17632),
    ("branch_5", "bus_5", "bus_2", 0.05695, 0.17388),
    ("branch_6", "bus_4", "bus_3", 0.06701, 0.17103),
    ("branch_7", "bus_5", "bus_4", 0.01335, 0.04211),
    ("branch_8", "bus_7", "bus_4", 0.0, 0.20912),
    ("branch_9", "bus_9", "bus_4", 0.0, 0.55618),
    ("branch_10", "bus_6", "bus_5", 0.0, 0.25202),
    ("branch_11", "bus_11", "bus_6", 0.09498, 0.1989),
    ("branch_12", "bus_12", "bus_6", 0.12291, 0.25581),
    ("branch_13", "bus_13", "bus_6", 0.06615, 0.13027),
    ("branch_14", "bus_8", "bus_7", 0.0, 0.17615),
    ("branch_15", "bus_9", "bus_7", 0.0, 0.11001),
    ("branch_16", "bus_10", "bus_9", 0.03181, 0.0845),
    ("branch_17", "bus_14", "bus_9", 0.12711, 0.27038),
    ("branch_18", "bus_11", "bus_10", 0.08205, 0.19207),
    ("branch_19", "bus_13", "bus_12", 0.22092, 0.19988),
    ("branch_20", "bus_14", "bus_13", 0.17093, 0.34802),
])

branches = index(b -> getfield(b, :name), _to_branch.(branch_nt))
branch_names = collect(keys(branches))

bus_names = string.("bus_", collect(1:14))
buses = Buses(bus_names, Bus.(bus_names, 1))

function _to_transformer(br)
    return Branch(
        name=string(br.name, "_T"),
        to_bus=br.to_bus,
        from_bus=br.from_bus,
        rate_a=br.rate_a,
        rate_b=br.rate_b,
        is_monitored=br.is_monitored,
        break_points=br.break_points,
        penalties=br.penalties,
        resistance=br.resistance,
        reactance=br.reactance,
        tap=1,
        angle=1,
    )
end

@testset "matrices" begin
    @testset "PTDF and incidence" begin
        incidence = FullNetworkSystems._incidence(buses, branches)

        @test size(incidence) == (20, 14)
        @test incidence isa SparseMatrixCSC

        @testset "no transformers" begin
            ptdf_all_lines = compute_ptdf(buses, branches)

            # PTDF should be a branches x buses KeyedArray
            @test size(ptdf_all_lines) == (20, 14)
            @test ptdf_all_lines isa KeyedArray
            # Test if axes and lookup are correct
            @test axiskeys(ptdf_all_lines) == (branch_names, bus_names)

            @testset "reference_bus" begin
                @test all(≈(0.0; atol=1e-3), ptdf_all_lines(:, "bus_1"))
                @test any(>(0.0 + 1e-3), ptdf_all_lines(:, "bus_5"))

                ptdf_bus_5 = compute_ptdf(buses, branches, reference_bus="bus_5")
                @test all(≈(0.0; atol=1e-3), ptdf_bus_5(:, "bus_5"))
                @test any(>(0.0 + 1e-3), ptdf_bus_5(:, "bus_1"))

                @test_throws(
                    ArgumentError("Reference bus 'not_here' not found."),
                    compute_ptdf(buses, branches, reference_bus="not_here"),
                )
            end

            # The tests based on "Direct Calculation of Line Outage Distribution Factors" by
            # Guo et al. involve a PTDF multiplied by an incidence matrix, so we multiply the
            # PTDF by the incidence and then test for the specific elements that are shown in
            # the paper.
            ptdf_paper = ptdf_all_lines * incidence'
            @test ptdf_paper[2, 2] ≈ 0.3894 atol = 1e-3
            @test ptdf_paper[2, 6] ≈ 0.0790 atol = 1e-3
            @test ptdf_paper[2, 11] ≈ -0.0092 atol = 1e-3
            @test ptdf_paper[6, 2] ≈ 0.1031 atol = 1e-3
            @test ptdf_paper[6, 6] ≈ 0.6193 atol = 1e-3
            @test ptdf_paper[6, 11] ≈ 0.0078 atol = 1e-3
            @test ptdf_paper[11, 2] ≈ -0.0103 atol = 1e-3
            @test ptdf_paper[11, 6] ≈ 0.0067 atol = 1e-3
            @test ptdf_paper[11, 11] ≈ 0.7407 atol = 1e-3
        end

        @testset "with_transformers" begin
            new_branches = _to_branch.(branch_nt)
            new_branches[1] = _to_transformer(new_branches[1])
            new_branches[2] = _to_transformer(new_branches[2])

            branches_with_transformers = index(b -> getfield(b, :name), new_branches)

            incid_w_tr = FullNetworkSystems._incidence(buses, branches_with_transformers)
            @test incid_w_tr == incidence

            ptdf_w_tr = compute_ptdf(buses, branches_with_transformers)
            bt_names = collect(keys(branches_with_transformers))
            @test axiskeys(ptdf_w_tr) == (bt_names, bus_names)

            ptdf_paper = ptdf_w_tr * incid_w_tr'
            # Transformer branches are calculated differently
            @test ptdf_paper[2, 2] ≈ 0.3399 atol = 1e-3
            # Lines remain the same
            @test ptdf_paper[11, 11] ≈ 0.7407 atol = 1e-3
        end
    end

    @testset "LODF" begin
        ptdf_mat = FullNetworkSystems.compute_ptdf(buses, branches)
        branch_names_out = ["branch_2", "branch_6", "branch_11"]

        lodf_mat = compute_lodf(buses, branches, ptdf_mat, branch_names_out)
        @test axiskeys(lodf_mat) == (branch_names, branch_names_out)

        # Based on "Direct Calculation of Line Outage Distribution Factors" by Guo et al.
        @test lodf_mat[5, 1] ≈ 0.5551 atol = 1e-3
        @test lodf_mat[5, 2] ≈ 0.4511 atol = 1e-3
        @test lodf_mat[5, 3] ≈ -0.0637 atol = 1e-3
        @test lodf_mat[13, 1] ≈ -0.0120 atol = 1e-3
        @test lodf_mat[13, 2] ≈ 0.0121 atol = 1e-3
        @test lodf_mat[13, 3] ≈ 0.3159 atol = 1e-3

        @testset "LODF values when a monitored line goes out" begin
            # Lines 2, 6, and 11 are going out, but are also monitored. Check if their
            # post-contingency flow will be set to zero considering an arbitrary `pnet`.
            pnet = KeyedArray([fill(1.0, 7); fill(-1.0, 7)], bus_names)

            fl = KeyedArray(
                [sum(ptdf_mat(m, n) * pnet(n) for n in bus_names) for m in branch_names],
                branch_names
            )
            flc = KeyedArray(
                [
                    fl(m) + sum(lodf_mat(m, l) * fl(l) for l in branch_names_out)
                        for m in branch_names
                ],
                branch_names
            )
            @test all(==(0), flc(branch_names_out))
            @test all(!=(0), flc(setdiff(branch_names, branch_names_out)))
        end
        @testset "LODF is consistent for different input orders" begin
            lodf1 = compute_lodf(buses, branches, ptdf_mat, ["branch_2", "branch_6"])
            lodf2 = compute_lodf(buses, branches, ptdf_mat, ["branch_6", "branch_2"])
            for i in axiskeys(ptdf_mat, 1), j in ["branch_2", "branch_6"]
                @test lodf1(i, j) == lodf2(i, j)
            end
        end
    end

    @testset "From system" begin
        empty_float_matrix = KeyedArray(fill(0.0, 0, 0), (String[], String[]))
        empty_missing_float_matrix = KeyedArray(
            reshape(Union{Float64, Missing}[], 0, 0),
            (String[], String[]),
        )

        sys = SystemRT(
            buses=buses,
            branches=branches,
            ptdf=missing,
            lodfs=Dictionary(),
            # Fill in the rest with nonsense (unused)
            gens_per_bus=Dictionary(),
            loads_per_bus=Dictionary(),
            zones=Zones(),
            generators=Generators(),
            generator_time_series=GeneratorTimeSeries(
                initial_generation=KeyedArray(Float64[], String[]),
                offer_curve= KeyedArray(fill([(1.0, 1.0)], 0,0), (String[], String[])),
                regulation_min=empty_float_matrix,
                regulation_max=empty_float_matrix,
                pmin=empty_float_matrix,
                pmax=empty_float_matrix,
                regulation_offers=empty_missing_float_matrix,
                spinning_offers=empty_missing_float_matrix,
                on_supplemental_offers=empty_missing_float_matrix,
                off_supplemental_offers=empty_missing_float_matrix,
            ),
            generator_status=GeneratorStatusRT(
                commitment=KeyedArray(falses(0, 0), (String[], String[])),
                regulation_commitment=KeyedArray(falses(0, 0), (String[], String[])),
            ),
            loads=empty_float_matrix,
        )

        @test get_ptdf(sys) === missing
        @test get_lodfs(sys) == Dictionary()

        @test compute_ptdf(sys) == compute_ptdf(buses, branches) == retrieve_ptdf(sys)
        # Double check nothing has set the system PTDF
        @test get_ptdf(sys) === missing

        @test_throws(
            ArgumentError("System PTDF is missing."),
            compute_lodf(sys, ["branch_2", "branch_6", "branch_11"])
        )

        ptdf_sys = compute_ptdf(sys)

        lodf_df = compute_lodf(
            buses,
            branches,
            ptdf_sys,
            ["branch_2", "branch_6", "branch_11"],
        )
        lodf_input_mat = compute_lodf(sys, ptdf_sys, ["branch_2", "branch_6", "branch_11"])

        # Add PTDF to system
        sys.ptdf = ptdf_sys
        lodf_sys = compute_lodf(sys, ["branch_2", "branch_6", "branch_11"])

        @test lodf_sys == lodf_input_mat == lodf_df
    end
end
