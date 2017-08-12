# TypeSortedCollections

[![Build Status](https://travis-ci.org/tkoolen/TypeSortedCollections.jl.svg?branch=master)](https://travis-ci.org/tkoolen/TypeSortedCollections.jl)
[![codecov.io](http://codecov.io/github/tkoolen/TypeSortedCollections.jl/coverage.svg?branch=master)](http://codecov.io/github/tkoolen/TypeSortedCollections.jl?branch=master)

TypeSortedCollections provides the `TypeSortedCollection` type, which can be used to store type-heterogeneous data in a way that allows operations on the data to be performed in a type-stable manner. It does so by sorting a type-heterogeneous input collection by type upon construction, and storing these elements in a `Tuple` of concretely typed `Vector`s, one for each type. TypeSortedCollections provides type stable methods for `map!`, `foreach`, and `mapreduce` that take at least one `TypeSortedCollection`.

An example:
```julia
julia> using TypeSortedCollections

julia> f(x::Int64, y::Float64) = x * y
f (generic function with 2 methods)

julia> f(x::Float64, y::Float64) = round(Int64, -x * y)
f (generic function with 2 methods)

julia> xs = Number[1.; 2; 3];

julia> sortedxs = TypeSortedCollection(xs);

julia> ys = [1.; 2.; 3.];

julia> results = Vector{Int64}(length(xs));

julia> map!(f, results, sortedxs, ys)
3-element Array{Int64,1}:
 -1
  4
  9

julia> @allocated map!(f, results, sortedxs, ys)
0
```

`TypeSortedCollection`s are appropriate when the number of different types in a heterogeneous collection is (much) smaller than the number of elements of the collection. If the number of types is approximately the same as the number of elements, a plain `Tuple` may be a better choice.

Note that construction of a `TypeSortedCollection` is of course not type stable, so the intended usage is not to construct `TypeSortedCollection`s in tight loops.

By default, `TypeSortedCollection`s do not preserve order, in the sense that the order in which elements are processed in `map!`, `foreach`, and `mapreduce` will not be the same as if these functions were called on the original type-heterogeneous vector:
```julia
julia> xs = Number[1.; 2; 3.];

julia> sortedxs = TypeSortedCollection(xs);

julia> foreach(println, sortedxs)
1.0
3.0
2
```

If this is not desired, a `TypeSortedCollection` that does preserve order can be constructed by passing in an additional constructor argument:
```julia
julia> xs = Number[1.; 2; 3.];

julia> sortedxs = TypeSortedCollection(xs, true);

julia> foreach(println, sortedxs)
1.0
2
3.0
```
The cost of preserving order is that the number of `Vector`s stored in the `TypeSortedCollection` is equal to the number of contiguous subsequences of the input collection that have the same type, as opposed to simply the number of different types in the input collection. Note that calls to `map!` and `foreach` with both `TypeSortedCollection` and `AbstractVector` arguments are correctly indexed, regardless of whether order is preserved:

```julia
julia> xs = Number[1.; 2; 3.];

julia> sortedxs = TypeSortedCollection(xs); # doesn't preserve order

julia> results = similar(xs);

julia> map!(identity, results, sortedxs) # results of applying `identity` end up in the right location
3-element Array{Number,1}:
 1.0
 2  
 3.0
```
