module TypeSortedCollections

export
    TypeSortedCollection

using Compat

const TupleOfVectors = Tuple{Vararg{Vector{T} where T}}

struct TypeSortedCollection{D<:TupleOfVectors, N}
    data::D
    indices::NTuple{N, Vector{Int}}

    function TypeSortedCollection{D}() where {D<:TupleOfVectors}
        eltypes = eltype.([D.parameters...])
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
    type_to_tuple_index = Dict(T => i for (i, T) in enumerate(eltype.(dest.data)))
    index = length(dest)
    for x in A
        T = typeof(x)
        i = type_to_tuple_index[T]
        push!(dest.data[i], x)
        push!(dest.indices[i], (index += 1))
    end
    dest
end

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

end # module
