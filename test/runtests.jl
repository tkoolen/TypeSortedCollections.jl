using Test
using TypeSortedCollections

using TypeSortedCollections: indices

module M
f(x::Int64) = 3 * x
f(x::Float64) = round(Int64, x / 2)

g(x::Int64, y1::Float64, y2::Int64) = x * y1 * y2
g(x::Float64, y1::Float64, y2::Int64) = x + y1 + y2
g(x::Int64, y1::Float64, y2::Float64) = x * y1 - y2
g(x::Float64, y1::Float64, y2::Float64) = x + y1 - y2
g(x::Int64, y1::Int64, y2::Float64) = x - y1 * y2

h(x::Int64) = x > 4
h(x::Float64) = x <= 4

struct Foo end
end

macro test_noalloc(expr)
    quote
        $expr
        allocs = @allocated $expr
        @test allocs == 0
    end |> esc
end

@testset "ambiguities" begin
    @test isempty(detect_ambiguities(Base, Core, TypeSortedCollections))
end

@testset "general collection interface" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    @test length(sortedx) == length(x)
    @test !isempty(sortedx)
    @test @allocated(length(sortedx)) == 0

    empty!(sortedx)
    @test length(sortedx) == 0
    @test isempty(sortedx)
end

@testset "empty input" begin
    @test isempty(TypeSortedCollection(Number[]))
    @test isempty(TypeSortedCollection(Float64[], ()))
end

@testset "map! no args" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    @test length(sortedx.data) == 2

    results = similar(x, Int64)
    map!(M.f, results, sortedx)
    allocations = @allocated map!(M.f, results, sortedx)
    @test allocations == 0
    for (index, element) in enumerate(x)
        @test results[index] == M.f(element)
    end
end

@testset "map! with args" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = rand(length(x))
    y2 = rand(Int, length(x))
    results = similar(x, Float64)
    map!(M.g, results, sortedx, y1, y2)
    for (index, element) in enumerate(x)
        @test results[index] == M.g(element, y1[index], y2[index])
    end
    @test_noalloc map!(M.g, results, sortedx, y1, y2)

    y2 = Number[7.; 8; 9]
    sortedy2 = TypeSortedCollection(y2)
    map!(M.g, results, sortedx, y1, sortedy2)
    for (index, element) in enumerate(x)
        @test results[index] == M.g(element, y1[index], y2[index])
    end
    @test_noalloc map!(M.g, results, sortedx, y1, sortedy2)
end

@testset "map! indices mismatch" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = rand(length(x))
    y2 = Number[8; 9; Float32(7)]
    sortedy2 = TypeSortedCollection(y2)
    results = similar(x, Float64)
    @test_throws ArgumentError map!(M.g, results, sortedx, y1, sortedy2)
end

@testset "map! length mismatch" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = rand(length(x) + 1)
    y2 = rand(length(x))
    results = similar(x, Float64)
    @test_throws DimensionMismatch map!(M.g, results, sortedx, y1, y2)
end

@testset "foreach" begin
    x = Number[4.; 5; 3.]
    sortedx = TypeSortedCollection(x)
    @test length(sortedx.data) == 2
    results = []
    foreach(sortedx) do x
        push!(results, x * 4.)
    end
    for (index, element) in enumerate(x)
        @test element * 4. in results
    end

    y1 = rand(length(x))
    y2 = Number[7.; 8; 9.]
    sortedy2 = TypeSortedCollection(y2)
    foreach(M.g, sortedx, y1, sortedy2)
    @test_noalloc foreach(M.g, sortedx, y1, sortedy2)
end

@testset "append!" begin
    x = Number[4.; 5; 3.]
    sortedx = TypeSortedCollection(x)
    @test_throws ArgumentError append!(sortedx, [Float32(6)])
    append!(sortedx, x)
    @test length(sortedx) == 2 * length(x)
end

@testset "mapreduce" begin
    x = Number[4.; 5; 3.]
    let sortedx = TypeSortedCollection(x), v0 = 2. # required to achieve zero allocations.
        result = mapreduce(M.f, +, x, init=v0)
        @test isapprox(result, mapreduce(M.f, +, sortedx, init=v0); atol = 1e-18)
        @test_noalloc mapreduce(M.f, +, sortedx, init=v0)
    end
end

@testset "any/all" begin
    x = Number[4.; 5; 3.]
    y = [missing, true, false]
    z = []
    let sortedx = TypeSortedCollection(x), sortedy = TypeSortedCollection(y), sortedz = TypeSortedCollection(z)
        @test any(M.h, x) == any(M.h, sortedx) && all(M.h, x) == all(M.h, sortedx)
        @test any(y) == any(sortedy) && all(y) == all(sortedy)
        @test any(z) == any(sortedz) && all(z) == all(sortedz)
        @test_noalloc any(M.h, sortedx)
        @test_noalloc all(M.h, sortedx)
        @test_noalloc any(sortedy)
        @test_noalloc all(sortedy)
        @test_noalloc any(sortedz)
        @test_noalloc all(sortedz)
    end
end

@testset "matching indices" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = [7.; 8.; 9.]
    sortedy1 = TypeSortedCollection(y1, indices(sortedx))
    @test length(sortedy1.data) == length(sortedx.data)
    y2 = rand(Int, length(x))
    foreach(M.g, sortedx, sortedy1, y2)
end

@testset "matching indices, empty index vector" begin
    x = [3., 4.]
    sortedx = TypeSortedCollection(x, ([1, 2], Int[]))
    results = similar(x)
    map!(identity, results, sortedx)
    @test results == x
end

@testset "preserve order" begin
    x = Number[3.; 4; 5; 6.]
    sortedx1 = TypeSortedCollection(x)
    sortedx2 = TypeSortedCollection(x, true)
    @test num_types(sortedx1) == 2
    @test num_types(sortedx2) == 3
    results = Number[]
    foreach(x -> push!(results, x), sortedx2)
    @test all(x .== results)
end

@testset "broadcast! consecutive TypeSortedCollections" begin
    # strangely, having this test set appear later in the code results in different behavior
    # see https://github.com/JuliaLang/julia/pull/23800
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y = [7.; 8.; 9.]
    sortedy = TypeSortedCollection(y, indices(sortedx))
    z = 3
    results = similar(y, Float64)
    broadcast!(M.g, results, sortedx, sortedy, z)
    @test all(results .== M.g.(x, y, z))
    @test_noalloc broadcast!(M.g, results, sortedx, sortedy, z)
end

@testset "broadcast! TSC Vec Number" begin
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
    let results = results # needed on 0.7 for some reason; TODO: investigate more
        @test_noalloc broadcast!(M.g, results, sortedx, y1, y2)
    end
end

@testset "broadcast! with scalars and TSC as second arg" begin
    x = 3
    y = Number[3.; 4; 5]
    z = 5.
    sortedy = TypeSortedCollection(y)
    results = similar(y, Float64)
    results .= M.g.(x, sortedy, z)
    @test all(results .== M.g.(x, y, z))
    @test_noalloc broadcast!(M.g, results, x, sortedy, z)
end

@testset "broadcast! consecutive scalars" begin
    x = 3
    y = 4.
    z = Number[3.; 4; 5.]
    sortedz = TypeSortedCollection(z)
    results = similar(z, Float64)
    results .= M.g.(x, y, sortedz)
    @test all(results .== M.g.(x, y, z))
    @test_noalloc broadcast!(M.g, results, x, y, sortedz)
end

@testset "broadcast! Array first" begin
    x = rand(Int, 3)
    y = Number[3.; 4; 5.]
    z = rand()
    sortedy = TypeSortedCollection(y)
    results = similar(y, Float64)
    results .= M.g.(x, sortedy, z)
    @test all(results .== M.g.(x, y, z))
    @test_noalloc broadcast!(M.g, results, x, sortedy, z)
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
    @test_noalloc broadcast!(M.g, results, sortedx, y1, sortedy2)
end

@testset "broadcast! TSC destination" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    results = typeof(sortedx)(indices(sortedx))
    results .= 3 .* sortedx
    @test results.data[1][1] === 3 * 3.
    @test results.data[2][1] === 3 * 4
    @test results.data[2][2] === 3 * 5
end

@testset "eltype" begin
    x = [4.; 5; 3.; Int32(2); Int16(1); "foo"]
    let sortedx = TypeSortedCollection(x)
        @test eltype(sortedx) == Union{Float64, Int64, Int32, Int16, String}
        @test_noalloc eltype(sortedx)
    end
end

@testset "push!" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    @test length(sortedx) == 3
    @test_throws ArgumentError push!(sortedx, "foo")
    push!(sortedx, 8)
    @test length(sortedx) == 4
    @test mapreduce(x -> x == 8, (a, b) -> a || b, sortedx, init=false)
    results = similar(x, length(sortedx))
    map!(identity, results, sortedx)
    @test last(results) == 8
    @test @inferred(push!(sortedx, 1)) isa typeof(sortedx)
end

@testset "eltypes/vectortypes" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    let T = typeof(sortedx)
        @test @inferred eltypes(T) == Tuple{Float64, Int}
        elt = eltypes(T)
        @test @inferred vectortypes(elt) == Tuple{Vector{Float64}, Vector{Int}}
        @test typeof(sortedx.data) == vectortypes(elt)
    end
end

@testset "broadcast with user types" begin
    x = fill(M.Foo(), 3)
    sortedx = TypeSortedCollection(x)
    sortedx .= Ref(M.Foo())
end
