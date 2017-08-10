using TypeSortedCollections
using Base.Test

@testset "length" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    @test length(sortedx) == length(x)
end

@testset "map! no args" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    @test length(sortedx.data) == 2
    f(x::Int64) = 3 * x
    f(x::Float64) = round(Int64, x / 2)
    results = similar(x, Int64)
    map!(f, results, sortedx)
    for (index, element) in enumerate(x)
        @test results[index] == f(element)
    end
end

@testset "map! with args" begin
    x = Number[3.; 4; 5]
    sortedx = TypeSortedCollection(x)
    y1 = rand(length(x))
    y2 = rand(Int, length(x))
    f(x::Int64, y1::Float64, y2::Int64) = x * y1 * y2
    f(x::Float64, y1::Float64, y2::Int64) = x + y1 + y2
    results = similar(x, Float64)
    map!(f, results, sortedx, y1, y2)
    for (index, element) in enumerate(x)
        @test results[index] == f(element, y1[index], y2[index])
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
        @test results[index] isa Float64
        @test element * 4. in results
    end
end
