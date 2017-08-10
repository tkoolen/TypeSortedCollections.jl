using TypeSortedCollections
using Base.Test

module M
f(x::Int64) = 3 * x
f(x::Float64) = round(Int64, x / 2)

g(x::Int64, y1::Float64, y2::Int64) = x * y1 * y2
g(x::Float64, y1::Float64, y2::Int64) = x + y1 + y2
end

@testset "length" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    @test length(sortedx) == length(x)
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
    allocations = @allocated map!(M.g, results, sortedx, y1, y2)
    @test allocations == 0
    for (index, element) in enumerate(x)
        @test results[index] == M.g(element, y1[index], y2[index])
    end
end

@testset "foreach" begin
    x = Number[4.; 5; 3.; Float32(6)]
    sortedx = TypeSortedCollection(x)
    @test length(sortedx.data) == 3
    results = []
    foreach(sortedx) do x
        push!(results, x * 4.)
    end
    for (index, element) in enumerate(x)
        @test element * 4. in results
    end
end

@testset "append!" begin
    x = Number[4.; 5; 3.]
    sortedx = TypeSortedCollection(x)
    @test_throws ArgumentError append!(sortedx, [Float32(6)])
end
