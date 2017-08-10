using TypeSortedCollections
using Base.Test

x = Pair[3. => 1; 4 => 2; 5 => 3]
sortedx = TypeSortedCollection(x, last)
index = indexfun(sortedx)
@test index == last
@test length(sortedx) == length(x)

f(x::Pair{Int64, Int64}) = 3 * first(x)
f(x::Pair{Float64, Int64}) = round(Int64, first(x) / 2)

maptest(f, results, index, x) = begin
    for element in x
        results[index(element)] != f(element) && return false
    end
    true
end

results = Vector{Int64}(maximum(index.(x)))
map!(f, results, sortedx)
@test maptest(f, results, index, x)

y = Pair[1. => 4; 2. => 2; 3. => 3]
sortedy = typeof(sortedx)(y, index)
@test typeof(sortedy) == typeof(sortedx)

results = Vector{Int64}(maximum(index.(y)))
map!(f, results, sortedy)
@test maptest(f, results, index, y)
