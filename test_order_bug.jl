module A

export
    TypeSortedCollection

const TupleOfVectors = Tuple{Vararg{Vector{T} where T}}

struct TypeSortedCollection{D<:TupleOfVectors, N}
    TypeSortedCollection{D}() where {D} = new{D, length(D.parameters)}()
end

function TypeSortedCollection(A)
   types = unique(typeof.(A))
   D = Tuple{[Vector{T} for T in types]...}
   TypeSortedCollection{D}()
end

Base.Broadcast._containertype(::Type{<:TypeSortedCollection}) = TypeSortedCollection
Base.Broadcast.promote_containertype(::Type{TypeSortedCollection}, _) = TypeSortedCollection
Base.Broadcast.promote_containertype(_, ::Type{TypeSortedCollection}) = TypeSortedCollection
Base.Broadcast.promote_containertype(::Type{TypeSortedCollection}, ::Type{Array}) = TypeSortedCollection
Base.Broadcast.promote_containertype(::Type{Array}, ::Type{TypeSortedCollection}) = TypeSortedCollection

function Base.Broadcast.broadcast_c!(f, ::Type, ::Type{TypeSortedCollection}, dest::AbstractVector, A, Bs...)
    throw(DimensionMismatch())
end

end # module

function g end

using Base.Test
@testset "broadcast! length mismatch" begin
    x = Number[3.; 4; 5]
    sortedx = A.TypeSortedCollection(x)
    results = rand(length(x) + 1)
    y1 = rand()
    y2 = rand(Int)
    @test_throws DimensionMismatch results .= g.(sortedx, y1, y2)
end

@testset "broadcast! matching indices" begin
    x = Number[3.; 4; 5]
    sortedx = A.TypeSortedCollection(x)
    y1 = rand()
    y2 = [7.; 8.; 9.]
    sortedy2 = A.TypeSortedCollection(y2)
    results = similar(x, Float64)
    broadcast!(g, results, sortedx, y1, sortedy2)
    @allocated broadcast!(g, results, sortedx, y1, sortedy2)
end

