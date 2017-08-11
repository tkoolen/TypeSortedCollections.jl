__precompile__()

module TypeSortedCollections

export
    TypeSortedCollection

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


@inline num_types(::Type{TypeSortedCollection{D, N}}) where {D, N} = Val{N}()
@inline num_types(tsc::TypeSortedCollection) = num_types(typeof(tsc))

val(::Val{T}) where {T} = T

# Trick from StaticArrays:
@inline first_tsc(a1::TypeSortedCollection, as...) = a1
@inline first_tsc(a1, as...) = first_tsc(as...)
@inline first_tsc() = throw(ArgumentError("No TypeSortedCollection found in argument list"))

@inline function same_num_types(as...)
    n = num_types(first_tsc(as...))
    _num_types_match(n, as...) || _throw_num_types_mismatch(as...)
    n
end
@inline _num_types_match(n::Val, a1::AbstractVector, as...) = _num_types_match(n, as...)
@inline _num_types_match(n::Val, a1::TypeSortedCollection, as...) = ((n == num_types(a1)) ? _num_types_match(n, as...) : false)
@inline _num_types_match(n::Val) = true

@noinline function _throw_num_types_mismatch(as...)
    throw(DimensionMismatch()) # TODO: better error message
end

# inspired by Base.ith_all
@inline _getindex_all(::Val, j, vecindex, ::Tuple{}) = ()
@inline _getindex_all(vali::Val{i}, j, vecindex, as) where {i} = (_getindex(vali, j, vecindex, as[1]), _getindex_all(vali, j, vecindex, Base.tail(as))...)
@inline _getindex(::Val, j, vecindex, a::AbstractVector) = a[vecindex]
@inline _getindex(::Val{i}, j, vecindex, a::TypeSortedCollection) where {i} = a.data[i][j]
@inline _setindex!(::Val, j, vecindex, a::AbstractVector, val) = a[vecindex] = val
@inline _setindex!(::Val{i}, j, vecindex, a::TypeSortedCollection, val) where {i} = a.data[i][j] = val

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

@inline Base.isempty(x::TypeSortedCollection) = all(isempty, x.data)
@inline Base.empty!(x::TypeSortedCollection) = foreach(empty!, x.data)
@inline Base.length(x::TypeSortedCollection) = sum(length, x.data)

function Base.map!(f, As::Union{T, AbstractVector}...) where {T<:TypeSortedCollection}
    N = same_num_types(As...)
    _map!(f, N, As...)
end

@generated function _map!(f, ::Val{N}, dest, args...) where {N}
    expr = Expr(:block)
    push!(expr.args, :(leading_tsc = first_tsc(dest, args...)))
    for i = 1 : N
        push!(expr.args, quote
            # TODO: check that indices match
            let inds = leading_tsc.indices[$i], vali = Val($i)
                for j in linearindices(inds)
                    vecindex = inds[j]
                    _setindex!(vali, j, vecindex, dest, f(_getindex_all(vali, j, vecindex, args)...))
                end
            end
        end)
    end
    push!(expr.args, :(return nothing))
    expr
end

function Base.foreach(f, As::Union{T, AbstractVector}...) where {T<:TypeSortedCollection}
    N = same_num_types(As...)
    _foreach(f, N, As...)
end

@generated function _foreach(f, ::Val{N}, As...) where {N}
    expr = Expr(:block)
    push!(expr.args, :(leading_tsc = first_tsc(As...)))
    for i = 1 : N
        push!(expr.args, quote
            # TODO: check that indices match
            let inds = leading_tsc.indices[$i], vali = Val($i)
                for j in linearindices(inds)
                    vecindex = inds[j]
                    f(_getindex_all(vali, j, vecindex, As)...)
                end
            end
        end)
    end
    push!(expr.args, :(return nothing))
    expr
end

@generated function Base.mapreduce(f, op, v0, tsc::TypeSortedCollection)
    expr = Expr(:block)
    push!(expr.args, :(ret = Base.r_promote(op, v0)))
    for i = 1 : val(num_types(tsc))
        push!(expr.args, quote
            let vec = tsc.data[$i]
                ret = mapreduce(f, op, ret, vec)
            end
        end)
    end
    push!(expr.args, :(return ret))
    expr
end

end # module
