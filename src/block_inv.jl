# Used to compute PTDF, but it generic code for inverting a large matrix
# Could/should be open sourced. See:
# https://github.com/JuliaLinearAlgebra/GenericLinearAlgebra.jl/pull/46

function _block_inv(
    A::AbstractMatrix,
    B::AbstractMatrix,
    C::AbstractMatrix,
    D_inv::AbstractMatrix,
)
    B_D_inv = B * D_inv
    # Compute -B_D_inv * C + A and store it in A
    BLAS.gemm!('N', 'N', -1.0, B_D_inv, C, 1.0, A)
    A = inv(A)
    B = A * B_D_inv
    D_inv_C = D_inv * C
    # Compute -D_inv_C * A and store it in C
    mul!(C, -D_inv_C, A)
    # Compute D_inv_C * B + D_inv and store it in D_inv
    BLAS.gemm!('N', 'N', 1.0, D_inv_C, B, 1.0, D_inv)
    return A, -B, C, D_inv
end

@views function _partition_big_mat(mat::AbstractMatrix; block_size::Int=13_000)
    A = mat[1:block_size, 1:block_size]
    B = mat[1:block_size, (block_size + 1):end]
    C = mat[(block_size + 1):end, 1:block_size]
    D = mat[(block_size + 1):end, (block_size + 1):end]
    return A, B, C, D
end

function _blocks_big_mat(
    mat::T; block_size::Int=13_000
) where T<:AbstractMatrix{F} where F

    # SubMat is the type that `_partition_big_mat` returns
    SubMat = SubArray{F, 2, T, Tuple{UnitRange{Int}, UnitRange{Int}}, false}
    mat_blocks = Tuple{SubMat, SubMat, SubMat, SubMat}[]
    D = mat

    while true
        A, B, C, D = _partition_big_mat(D; block_size=block_size)
        pushfirst!(mat_blocks, (A, B, C, D))
        size(D, 1) <= block_size && break
    end

    return mat_blocks
end

"""
    big_mat_inv(mat::AbstractMatrix; block_size::Int=13_000) -> AbstractMatrix

Receives a matrix that is supposed to be inverted. If the size of the matrix is larger than
the defined `block_size`, it first partitions the matrix into smaller blocks until the
matrices that are supposed to be inverted have size less than `block_size`.
The partitioned matrix would look like: `mat = [A B; C D]` where the size of A is guaranteed
to be smaller than the `block_size`. If matrix D is larger than `block_size`, it
gets partitioned `D = [A1 B1;C1 D1]` and this process continues until all Ais and Dis are
smaller than `block_size`.

The default `block_size` is set to be `13_000` as we have empirically observed that, for
matrices smaller than this size, the built-in `inv` can efficiently handle the inversion.
This was set when doing the calculation of admittance matrix inverse in MISO and depending
on the application, this number can be adjusted.


Staring from the right bottom corner of the partitioned matrix, we use block inversion
matrix lemma (https://en.wikipedia.org/wiki/Block_matrix) iteratively until the full matrix
inversion is computed.
"""
function big_mat_inv(mat::AbstractMatrix; block_size::Int=13_000)
    # If the matrix is smaller than the specified block size, just do regular inversion
    size(mat, 1) <= block_size && return inv(mat)
    # partition the matrix into smaller blocks.
    blocks = _blocks_big_mat(mat, block_size=block_size)
    # iteratively calculating the matrix inversion of each block
    A, B, C, D = popfirst!(blocks)
    A, B, C, D = _block_inv(A, B, C, inv(D))
    num_blocks = length(blocks)
    for bl_ in 1:num_blocks
        inverted_mat = [A B; C D]
        A, B, C, D = popfirst!(blocks)
        A, B, C, D = _block_inv(A, B, C, inverted_mat)
    end
    return [A B; C D]
end
