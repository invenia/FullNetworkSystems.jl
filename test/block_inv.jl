# This file contains tests related to the matrix block inversion procedure

@testset "Block matrix inversion" begin
    big_mat_inv = FullNetworkSystems.big_mat_inv
    @testset "fallback to `inv`" begin
        n = 1000
        M = randn(n, n)
        # default block size should be >1000, so should fallback to `inv` here
        @test big_mat_inv(M) == inv(M)
    end

    @testset "use block algorithm" begin
        n = 1000
        for _ in 1:3
            M = randn(n, n)
            @test inv(M) ≈ big_mat_inv(M; block_size=500) rtol=1e-3
        end

        n = 2000
        for _ in 1:3
            M = randn(n, n)
            @test inv(M) ≈ big_mat_inv(M; block_size=1800) rtol=1e-3
        end
    end
end
