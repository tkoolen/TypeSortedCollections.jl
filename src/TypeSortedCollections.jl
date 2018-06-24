__precompile__()

module TypeSortedCollections

export
    TypeSortedCollection,
    num_types,
    eltypes,
    vectortypes

using Compat

const TupleOfVectors = Tuple{Vararg{Vector{T} where T}}

struct TypeSortedCollection{D<:TupleOfVectors, N}
    data::D
    indices::NTuple{N, Vector{Int}}

    function TypeSortedCollection{D, N}(data::D, indices::NTuple{N, Vector{Int}}) where {D<:TupleOfVectors, N}
        fieldcount(D) == N || error()
        l = mapreduce(length, +, 0, data)
        l == mapreduce(length, +, 0, indices) || error()
        if N > 0
            allindices = Base.Iterators.flatten(indices)
            allunique(allindices) || error()
            isempty(allindices) || extrema(allindices) == (1, l) || error()
        end
        new{D, N}(data, indices)
    end

    function TypeSortedCollection{D, N}(indices::NTuple{N, Vector{Int}}) where {D<:TupleOfVectors, N}
        lengths = map(length, indices)
        data = ntuple(i -> D.parameters[i](undef, lengths[i]), N)
        TypeSortedCollection{D, N}(data, indices)
    end

    function TypeSortedCollection{D, N}() where {D<:TupleOfVectors, N}
        indices = ntuple(_ -> Int[], N)
        TypeSortedCollection{D, N}(indices)
    end

    TypeSortedCollection{D}() where {D<:TupleOfVectors} = TypeSortedCollection{D, length(D.parameters)}()
    TypeSortedCollection{D, N}(A) where {D<:TupleOfVectors, N} = append!(TypeSortedCollection{D, N}(), A)
    TypeSortedCollection{D}(A) where {D<:TupleOfVectors} = append!(TypeSortedCollection{D}(), A)
end

function TypeSortedCollection(data::D, indices::NTuple{N, Vector{Int}}) where {D<:TupleOfVectors, N}
    TypeSortedCollection{D, N}(data, indices)
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
    @assert length(A) == mapreduce(length, +, 0, indices)
    data = []
    for indicesvec in indices
        T = length(indicesvec) > 0 ? typeof(A[indicesvec[1]]) : Nothing
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

@inline Base.eltype(A::TypeSortedCollection) = Union{map(eltype, A.data)...}

eltypes(::Type{TypeSortedCollection{D, N}}) where {D, N} = eltypes(D)
function eltypes(::Type{T}) where {T <: TupleOfVectors}
    Base.tuple_type_cons(eltype(Base.tuple_type_head(T)), eltypes(Base.tuple_type_tail(T)))
end
eltypes(::Type{Tuple{}}) = Tuple{}

function vectortypes(::Type{T}) where {T <: Tuple}
    Base.tuple_type_cons(Vector{Base.tuple_type_head(T)}, vectortypes(Base.tuple_type_tail(T)))
end
vectortypes(::Type{Tuple{}}) = Tuple{}

@generated function Base.push!(dest::TypeSortedCollection{D}, x::X) where {D, X}
    i = 0
    for j = 1 : length(D.parameters)
        Vector{X} == D.parameters[j] && (i = j; break)
    end
    i == 0 && return :(throw(ArgumentError("Destination cannot store arguments of type $(typeof(x)).")))
    quote
        Base.@_inline_meta
        index = length(dest) + 1
        push!(dest.data[$i], x)
        push!(dest.indices[$i], index)
        return dest
    end
end

function Base.append!(dest::TypeSortedCollection, A)
    # TODO: consider resizing first
    for x in A
        push!(dest, x)
    end
    dest
end

num_types(::Type{<:TypeSortedCollection{<:Any, N}}) where {N} = N
num_types(x::TypeSortedCollection) = num_types(typeof(x))

const TSCOrAbstractVector{N} = Union{<:TypeSortedCollection{<:Any, N}, AbstractVector}

Base.isempty(x::TypeSortedCollection) = all(isempty, x.data)
Base.empty!(x::TypeSortedCollection) = foreach(empty!, x.data)
@inline Base.length(x::TypeSortedCollection) = mapreduce(length, +, 0, x.data)
Base.indices(x::TypeSortedCollection) = x.indices # semantics are a little different from Array, but OK

# Trick from StaticArrays:
@inline first_tsc(a1::TypeSortedCollection, as...) = a1
@inline first_tsc(a1, as...) = first_tsc(as...)

@inline first_tsc_type(a1::Type{<:TypeSortedCollection}, as::Type...) = a1
@inline first_tsc_type(a1::Type, as::Type...) = first_tsc_type(as...)

# inspired by Base.ith_all
@inline _getindex_all(::Val, j, vecindex) = ()
Base.@propagate_inbounds @inline _getindex_all(vali::Val{i}, j, vecindex, a1, as...) where {i} = (_getindex(vali, j, vecindex, a1), _getindex_all(vali, j, vecindex, as...)...)
@inline _getindex(::Val, j, vecindex, a) = a # for anything that's not an AbstractVector or TypeSortedCollection, don't index (for use in broadcast!)
@inline _getindex(::Val, j, vecindex, a::AbstractVector) = a[vecindex]
@inline _getindex(::Val, j, vecindex, a::Ref) = a[]
@inline _getindex(::Val{i}, j, vecindex, a::TypeSortedCollection) where {i} = a.data[i][j]
@inline _setindex!(::Val, j, vecindex, a::AbstractVector, val) = a[vecindex] = val
@inline _setindex!(::Val{i}, j, vecindex, a::TypeSortedCollection, val) where {i} = a.data[i][j] = val

@inline lengths_match(a1) = true
@inline lengths_match(a1::TSCOrAbstractVector, a2::TSCOrAbstractVector, as...) = length(a1) == length(a2) && lengths_match(a2, as...)
@inline lengths_match(a1::TSCOrAbstractVector, a2, as...) = lengths_match(a1, as...) # case: a2 is not indexable: skip it
@noinline lengths_match_fail() = throw(DimensionMismatch("Lengths of input collections do not match."))

@inline indices_match(::Val, indices::Vector{Int}, ::Any) = true
@inline function indices_match(::Val{i}, indices::Vector{Int}, tsc::TypeSortedCollection) where {i}
    tsc_indices = tsc.indices[i]
    length(indices) == length(tsc_indices) || return false
    @inbounds for j in eachindex(indices)
        indices[j] == tsc_indices[j] || return false
    end
    true
end
@inline indices_match(vali::Val, indices::Vector{Int}, a1, as...) = indices_match(vali, indices, a1) && indices_match(vali, indices, as...)
@noinline indices_match_fail() = throw(ArgumentError("Indices of TypeSortedCollections do not match."))

@generated function Base.map!(f::Tf, dest::TSCOrAbstractVector{N}, src1::TypeSortedCollection{<:Any, N}, srcs::TSCOrAbstractVector{N}...) where {Tf, N}
    expr = Expr(:block)
    push!(expr.args, :(Base.@_inline_meta))
    push!(expr.args, :(leading_tsc = first_tsc(dest, src1, srcs...)))
    push!(expr.args, :(@boundscheck lengths_match(dest, src1, srcs...) || lengths_match_fail()))
    for i = 1 : N
        vali = Val(i)
        push!(expr.args, quote
            let inds = leading_tsc.indices[$i]
                @boundscheck indices_match($vali, inds, dest, src1, srcs...) || indices_match_fail()
                @inbounds for j in LinearIndices(inds)
                    vecindex = inds[j]
                    _setindex!($vali, j, vecindex, dest, f(_getindex_all($vali, j, vecindex, src1, srcs...)...))
                end
            end
        end)
    end
    quote
        $expr
        dest
    end
end

@generated function Base.foreach(f::Tf, A1::TypeSortedCollection{<:Any, N}, As::TSCOrAbstractVector{N}...) where {Tf, N}
    expr = Expr(:block)
    push!(expr.args, :(Base.@_inline_meta))
    push!(expr.args, :(leading_tsc = first_tsc(A1, As...)))
    push!(expr.args, :(@boundscheck lengths_match(A1, As...) || lengths_match_fail()))
    for i = 1 : N
        vali = Val(i)
        push!(expr.args, quote
            let inds = leading_tsc.indices[$i]
                @boundscheck indices_match($vali, inds, A1, As...) || indices_match_fail()
                @inbounds for j in LinearIndices(inds)
                    vecindex = inds[j]
                    f(_getindex_all($vali, j, vecindex, A1, As...)...)
                end
            end
        end)
    end
    quote
        $expr
        nothing
    end
end

@generated function Base.mapreduce(f::Tf, op, v0, tsc::TypeSortedCollection{<:Any, N}) where {Tf, N}
    expr = Expr(:block)
    push!(expr.args, :(Base.@_inline_meta))
    push!(expr.args, :(ret = v0))
    for i = 1 : N
        push!(expr.args, quote
            let vec = tsc.data[$i]
                ret = mapreduce(f, op, ret, vec)
            end
        end)
    end
    quote
        $expr
        return ret
    end
end

## broadcast!
@generated function _broadcast!(f::Tf, dest, A, Bs...) where Tf
    T = first_tsc_type(dest, A, Bs...)
    N = num_types(T)
    expr = Expr(:block)
    push!(expr.args, :(Base.@_inline_meta)) # TODO: good idea?
    push!(expr.args, :(leading_tsc = first_tsc(dest, A, Bs...)))
    push!(expr.args, :(@boundscheck lengths_match(dest, A, Bs...) || lengths_match_fail()))
    for i = 1 : N
        vali = Val(i)
        push!(expr.args, quote
            let inds = leading_tsc.indices[$i]
                @boundscheck indices_match($vali, inds, A, Bs...) || indices_match_fail()
                @inbounds for j in LinearIndices(inds)
                    vecindex = inds[j]
                    _setindex!($vali, j, vecindex, dest, f(_getindex_all($vali, j, vecindex, A, Bs...)...))
                end
            end
        end)
    end
    quote
        Base.@_inline_meta
        $expr
        dest
    end
end

@static if VERSION >= v"0.7.0-DEV.5096"
    import Base.Broadcast: Broadcasted, BroadcastStyle, broadcastable, axes, instantiate

    struct TypeSortedStyle <: Broadcast.BroadcastStyle end
    BroadcastStyle(::Type{<:TypeSortedCollection}) = TypeSortedStyle()
    BroadcastStyle(::TypeSortedStyle, ::Broadcast.DefaultArrayStyle{1}) = TypeSortedStyle()
    BroadcastStyle(::TypeSortedStyle, ::Broadcast.DefaultArrayStyle{0}) = TypeSortedStyle()
    broadcastable(x::TypeSortedCollection) = x
    axes(tsc::TypeSortedCollection) = nothing
    instantiate(bc::Broadcasted{TypeSortedStyle}) = bc

    @inline Base.copyto!(dest::AbstractArray, bc::Broadcasted{TypeSortedStyle}) = _copy!(dest, bc)
    @inline Base.copyto!(dest::TypeSortedCollection, bc::Broadcasted) = _copy!(dest, bc)

    @inline function _copy!(dest, bc::Broadcasted)
        flat = Broadcast.flatten(bc)
        _broadcast!(flat.f, dest, flat.args...)
    end
else
    Base.Broadcast._containertype(::Type{<:TypeSortedCollection}) = TypeSortedCollection
    Base.Broadcast.promote_containertype(::Type{TypeSortedCollection}, _) = TypeSortedCollection
    Base.Broadcast.promote_containertype(_, ::Type{TypeSortedCollection}) = TypeSortedCollection
    Base.Broadcast.promote_containertype(::Type{TypeSortedCollection}, ::Type{TypeSortedCollection}) = TypeSortedCollection
    Base.Broadcast.promote_containertype(::Type{TypeSortedCollection}, ::Type{Array}) = TypeSortedCollection # handle ambiguities with `Array`
    Base.Broadcast.promote_containertype(::Type{Array}, ::Type{TypeSortedCollection}) = TypeSortedCollection # handle ambiguities with `Array`

    @inline function Base.Broadcast.broadcast_c!(f::Tf, ::Type, ::Type{TypeSortedCollection}, dest::AbstractVector, arghead, argtail::Vararg{Any, N}) where {Tf, N}
        _broadcast!(f, dest, arghead, argtail...)
        return dest
    end

    @inline Base.broadcast!(f::Tf, dest::TypeSortedCollection, args::Vararg{Any, N}) where {Tf, N} = _broadcast!(f, dest, args...)
end

end # module
