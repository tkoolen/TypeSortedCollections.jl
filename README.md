# TypeSortedCollections

[![Build Status](https://travis-ci.org/tkoolen/TypeSortedCollections.jl.svg?branch=master)](https://travis-ci.org/tkoolen/TypeSortedCollections.jl)
[![codecov.io](http://codecov.io/github/tkoolen/TypeSortedCollections.jl/coverage.svg?branch=master)](http://codecov.io/github/tkoolen/TypeSortedCollections.jl?branch=master)

TypeSortedCollections provides the `TypeSortedCollection` type, which can be used to store type-heterogeneous data in a way that allows operations on the data to be performed in a type-stable manner. It does so by sorting a type-heterogeneous input collection by type upon construction, and storing these elements in a `Tuple` of concretely typed `Vector`s, one for each type. TypeSortedCollections provides type stable methods for `map!`, `foreach`, and `mapreduce` that take at least one `TypeSortedCollection`.

An example:
```julia
julia> f(x::Int64) = 3 * x
f (generic function with 2 methods)

julia> f(x::Float64) = round(Int64, -3 * x)
f (generic function with 2 methods)

julia> xs = Number[1.; 2; 3];

julia> sortedxs = TypeSortedCollection(xs);

julia> results = Vector{Int64}(length(xs));

julia> map!(f, results, sortedxs)
3-element Array{Int64,1}:
 -3
  6
  9

julia> @allocated map!(f, results, sortedxs)
0
```

`TypeSortedCollection`s are appropriate when the number of different types in a heterogeneous collection is (much) smaller than the number of elements of the collection. If the number of types is approximately the same as the number of elements, a plain `Tuple` may be a better choice.

Note that construction of a `TypeSortedCollection` is of course not type stable, so the intended usage is not to construct `TypeSortedCollection`s in tight loops.
