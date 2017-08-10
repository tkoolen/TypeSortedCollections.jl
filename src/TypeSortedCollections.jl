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

@inline Base.isempty(x::TypeSortedCollection) = all(isempty, x.data)
@inline Base.empty!(x::TypeSortedCollection) = foreach(empty!, x.data)
@inline Base.length(x::TypeSortedCollection) = sum(length, x.data)

@generated function Base.map!(f, dest::AbstractVector, tsc::TypeSortedCollection{D}, As::AbstractVector...) where {D}
    expr = Expr(:block)
    for i = 1 : fieldcount(D)
        push!(expr.args, quote
            let vec = tsc.data[$i], inds = tsc.indices[$i]
                for j in linearindices(vec)
                    element = vec[j]
                    index = inds[j]
                    dest[index] = f(element, Base.ith_all(index, As)...)
                end
            end
        end)
    end
    push!(expr.args, :(return nothing))
    expr
end

@generated function Base.foreach(f, tsc::TypeSortedCollection{D}, As::AbstractVector...) where {D}
    expr = Expr(:block)
    for i = 1 : fieldcount(D)
        push!(expr.args, quote
            let vec = tsc.data[$i], inds = tsc.indices[$i]
                for j in linearindices(vec)
                    element = vec[j]
                    index = inds[j]
                    f(element, Base.ith_all(index, As)...)
                end
            end
        end)
    end
    push!(expr.args, :(return nothing))
    expr
end

@generated function Base.mapreduce(f, op, v0, tsc::TypeSortedCollection{D}) where {D}
    expr = Expr(:block)
    push!(expr.args, :(ret = Base.r_promote(op, v0)))
    for i = 1 : fieldcount(D)
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
