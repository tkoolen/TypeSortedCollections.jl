__precompile__()

module TypeSortedCollections

export
    TypeSortedCollection

using Compat

const TupleOfVectors = Tuple{Vararg{Vector{T} where T}}

struct TypeSortedCollection{D<:TupleOfVectors, N}
    data::D
    indices::NTuple{N, Vector{Int}}

    function TypeSortedCollection{D}() where {D<:TupleOfVectors}
        eltypes = map(eltype, D.parameters)
        data = tuple((T[] for T in eltypes)...)
        indices = tuple((Int[] for i in eachindex(eltypes))...)
        N = length(indices)
        new{D, N}(data, indices)
    end

    function TypeSortedCollection{D}(A) where {D<:TupleOfVectors}
        append!(TypeSortedCollection{D}(), A)
    end
end

function TypeSortedCollection(A)
    types = unique(typeof.(A))
    D = Tuple{[Vector{T} for T in types]...}
    TypeSortedCollection{D}(A)
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

Base.isempty(x::TypeSortedCollection) = all(isempty, x.data)
Base.empty!(x::TypeSortedCollection) = foreach(empty!, x.data)
Base.length(x::TypeSortedCollection) = sum(length, x.data)

# Trick from StaticArrays:
@inline first_tsc(a1::TypeSortedCollection, as::Union{<:TypeSortedCollection, AbstractVector}...) = a1
@inline first_tsc(a1, as::Union{<:TypeSortedCollection, AbstractVector}...) = first_tsc(as...)

# inspired by Base.ith_all
@inline _getindex_all(::Val, j, vecindex) = ()
@inline _getindex_all(vali::Val{i}, j, vecindex, a1, as...) where {i} = (_getindex(vali, j, vecindex, a1), _getindex_all(vali, j, vecindex, as...)...)
@inline _getindex(::Val, j, vecindex, a::AbstractVector) = a[vecindex]
@inline _getindex(::Val{i}, j, vecindex, a::TypeSortedCollection) where {i} = a.data[i][j]
@inline _setindex!(::Val, j, vecindex, a::AbstractVector, val) = a[vecindex] = val
@inline _setindex!(::Val{i}, j, vecindex, a::TypeSortedCollection, val) where {i} = a.data[i][j] = val

@inline indices_match(::Val, indices::Vector{Int}, ::AbstractVector) = true
@inline function indices_match(::Val{i}, indices::Vector{Int}, tsc::TypeSortedCollection) where {i}
    tsc_indices = tsc.indices[i]
    length(indices) == length(tsc_indices) || return false
    @inbounds for j in eachindex(indices, tsc_indices)
        indices[j] == tsc_indices[j] || return false
    end
    true
end
@inline indices_match(vali::Val, indices::Vector{Int}, a1, as...) = indices_match(vali, indices, a1) && indices_match(vali, indices, as...)
@noinline indices_match_fail() = throw(ArgumentError("Indices of TypeSortedCollections do not match."))

@generated function Base.map!(f, As::Union{<:TypeSortedCollection{<:Any, N}, AbstractVector}...) where {N}
    expr = Expr(:block)
    push!(expr.args, :(leading_tsc = first_tsc(As...)))
    push!(expr.args, :(dest = As[1]))
    push!(expr.args, :(args = Base.tail(As)))
    for i = 1 : N
        vali = Val(i)
        push!(expr.args, quote
            let inds = leading_tsc.indices[$i]
                @boundscheck indices_match($vali, inds, As...) || indices_match_fail()
                for j in linearindices(inds)
                    vecindex = inds[j]
                    _setindex!($vali, j, vecindex, dest, f(_getindex_all($vali, j, vecindex, args...)...))
                end
            end
        end)
    end
    quote
        $expr
        nothing
    end
end

@generated function Base.foreach(f, As::Union{<:TypeSortedCollection{<:Any, N}, AbstractVector}...) where {N}
    expr = Expr(:block)
    push!(expr.args, :(leading_tsc = first_tsc(As...)))
    for i = 1 : N
        vali = Val(i)
        push!(expr.args, quote
            let inds = leading_tsc.indices[$i]
                @boundscheck indices_match($vali, inds, As...) || indices_match_fail()
                for j in linearindices(inds)
                    vecindex = inds[j]
                    f(_getindex_all($vali, j, vecindex, As...)...)
                end
            end
        end)
    end
    quote
        $expr
        nothing
    end
end

@generated function Base.mapreduce(f, op, v0, tsc::TypeSortedCollection{<:Any, N}) where {N}
    expr = Expr(:block)
    push!(expr.args, :(ret = Base.r_promote(op, v0)))
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

end # module
