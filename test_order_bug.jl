using Base.Test
using TypeSortedCollections

module M
f(x::Int64) = 3 * x
f(x::Float64) = round(Int64, x / 2)

g(x::Int64, y1::Float64, y2::Int64) = x * y1 * y2
g(x::Float64, y1::Float64, y2::Int64) = x + y1 + y2
g(x::Int64, y1::Float64, y2::Float64) = x * y1 - y2
g(x::Float64, y1::Float64, y2::Float64) = x + y1 - y2
g(x::Int64, y1::Int64, y2::Float64) = x - y1 * y2
end

@testset "broadcast!" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = rand(length(x))
    y2 = rand(Int)
    results = similar(x, Float64)
    broadcast!(M.g, results, sortedx, y1, y2)
    @test all(results .== M.g.(x, y1, y2))

    results = similar(x, Float64)
    results .= M.g.(sortedx, y1, y2)
    @test all(results .== M.g.(x, y1, y2))

    @test (@allocated broadcast!(M.g, results, sortedx, y1, y2)) == 0
end

@testset "broadcast! with scalars and TSC as second arg" begin
    x = 3
    y = Number[3.; 4; 5]
    z = 5.
    sortedy = TypeSortedCollection(y)
    results = similar(y, Float64)
    results .= M.g.(x, sortedy, z)
    @test all(results .== M.g.(x, y, z))
    @test (@allocated results .= M.g.(x, sortedy, z)) == 0
end

@testset "broadcast! consecutive scalars" begin
    x = 3
    y = 4.
    z = Number[3.; 4; 5.]
    sortedz = TypeSortedCollection(z)
    results = similar(z, Float64)
    results .= M.g.(x, y, sortedz)
    @test all(results .== M.g.(x, y, z))
    @test (@allocated results .= M.g.(x, y, sortedz)) == 0
end

@testset "broadcast! Array first" begin
    x = rand(Int, 3)
    y = Number[3.; 4; 5.]
    z = rand()
    sortedy = TypeSortedCollection(y)
    results = similar(y, Float64)
    results .= M.g.(x, sortedy, z)
    @test all(results .== M.g.(x, y, z))
    @test (@allocated results .= M.g.(x, sortedy, z)) == 0
end

@testset "broadcast! indices mismatch" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = rand()
    y2 = Number[8; 9; Float32(7)]
    sortedy2 = TypeSortedCollection(y2)
    results = similar(x, Float64)
    @test_throws ArgumentError broadcast!(M.g, results, sortedx, y1, sortedy2)
end

@testset "broadcast! length mismatch" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = rand(length(x) + 1)
    y2 = rand(length(x))
    results = similar(x, Float64)
    @test_throws DimensionMismatch results .= M.g.(sortedx, y1, y2)

    y1 = rand()
    y2 = rand(length(x) + 1)
    @test_throws DimensionMismatch results .= M.g.(sortedx, y1, y2)

    results = rand(length(x) + 1)
    y1 = rand()
    y2 = rand(Int)
    @test_throws DimensionMismatch results .= M.g.(sortedx, y1, y2)
end

@testset "broadcast! matching indices" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = rand()
    y2 = [7.; 8.; 9.]
    sortedy2 = TypeSortedCollection(y2, indices(sortedx))
    results = similar(x, Float64)
    broadcast!(M.g, results, sortedx, y1, sortedy2)
    @test all(results .== M.g.(x, y1, y2))
    @test (@allocated broadcast!(M.g, results, sortedx, y1, sortedy2)) == 0
end
