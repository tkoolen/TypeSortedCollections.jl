module TypeSortedCollections

export
    TypeSortedCollection,
    num_types

const TupleOfVectors = Tuple{Vararg{Vector{T} where T}}

struct TypeSortedCollection{D<:TupleOfVectors, N}
    data::D
    indices::NTuple{N, Vector{Int}}

    function TypeSortedCollection{D, N}() where {D<:TupleOfVectors, N}
        fieldcount(D) == N || error()
        data = tuple((T[] for T in D.parameters)...)
        indices = tuple((Int[] for i in eachindex(data))...)
        new{D, N}(data, indices)
    end

    TypeSortedCollection{D}() where {D<:TupleOfVectors} = TypeSortedCollection{D, length(D.parameters)}()
    TypeSortedCollection{D, N}(A) where {D<:TupleOfVectors, N} = append!(TypeSortedCollection{D, N}(), A)
    TypeSortedCollection{D}(A) where {D<:TupleOfVectors} = append!(TypeSortedCollection{D}(), A)

    function TypeSortedCollection(data::D, indices::NTuple{N, Vector{Int}}) where {D<:TupleOfVectors, N}
        fieldcount(D) == N || error()
        l = mapreduce(length, +, 0, data)
        l == mapreduce(length, +, 0, indices) || error()
        allindices = Base.Iterators.flatten(indices)
        allunique(allindices) || error()
        extrema(allindices) == (1, l) || error()
        new{D, N}(data, indices)
    end
end

function TypeSortedCollection(A, preserve_order::Bool = false)
    if preserve_order
        data = Vector[]
        indices = Vector{Vector{Int}}()
        for (i, x) in enumerate(A)
            T = typeof(x)
            if isempty(data) || T != eltype(last(data))
                push!(data, T[])
                push!(indices, Int[])
            end
            push!(last(data), x)
            push!(last(indices), i)
        end
        TypeSortedCollection(tuple(data...), tuple(indices...))
    else
        types = unique(typeof.(A))
        D = Tuple{[Vector{T} for T in types]...}
        TypeSortedCollection{D}(A)
    end
end

function TypeSortedCollection(A, indices::NTuple{N, Vector{Int}} where {N})
    @assert length(A) == sum(length, indices)
    data = []
    for indicesvec in indices
        @assert length(indicesvec) > 0
        T = typeof(A[indicesvec[1]])
        Tdata = Vector{T}()
        sizehint!(Tdata, length(indicesvec))
        push!(data, Tdata)
        for i in indicesvec
            A[i]::T
            push!(Tdata, A[i])
        end
    end
    TypeSortedCollection(tuple(data...), indices)
end

function Base.append!(dest::TypeSortedCollection, A)
    eltypes = map(eltype, dest.data)
    type_to_tuple_index = Dict(T => i for (i, T) in enumerate(eltypes))
    index = length(dest)
    for x in A
        T = typeof(x)
        haskey(type_to_tuple_index, T) || throw(ArgumentError("Cannot store elements of type $T; must be one of $eltypes."))
        i = type_to_tuple_index[T]
        push!(dest.data[i], x)
        push!(dest.indices[i], (index += 1))
    end
    dest
end

Base.@pure num_types(::Type{<:TypeSortedCollection{<:Any, N}}) where {N} = N
num_types(x::TypeSortedCollection) = num_types(typeof(x))

const TSCOrAbstractVector{N} = Union{<:TypeSortedCollection{<:Any, N}, AbstractVector}

Base.isempty(x::TypeSortedCollection) = all(isempty, x.data)
Base.empty!(x::TypeSortedCollection) = foreach(empty!, x.data)
Base.length(x::TypeSortedCollection) = mapreduce(length, +, 0, x.data)
Base.indices(x::TypeSortedCollection) = x.indices # semantics are a little different from Array, but OK


## broadcast!
Base.Broadcast._containertype(::Type{<:TypeSortedCollection}) = TypeSortedCollection
Base.Broadcast.promote_containertype(::Type{TypeSortedCollection}, _) = TypeSortedCollection
Base.Broadcast.promote_containertype(_, ::Type{TypeSortedCollection}) = TypeSortedCollection
Base.Broadcast.promote_containertype(::Type{TypeSortedCollection}, ::Type{Array}) = TypeSortedCollection # handle ambiguities with `Array`
Base.Broadcast.promote_containertype(::Type{Array}, ::Type{TypeSortedCollection}) = TypeSortedCollection # handle ambiguities with `Array`

@generated function Base.Broadcast.broadcast_c!(f, ::Type, ::Type{TypeSortedCollection}, dest::AbstractVector, A, Bs...)
    :(throw(DimensionMismatch()))
end

end # module
