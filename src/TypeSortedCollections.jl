module TypeSortedCollections

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
