module TypeSortedCollections

export
    TypeSortedCollection,
    indexfun # TODO: remove

const TupleOfVectors = Tuple{Vararg{Vector{T} where T}}

struct TypeSortedCollection{D<:TupleOfVectors, I}
    data::D
    indexfun::I

    function TypeSortedCollection(A, indexfun::I) where {I}
        types = unique(typeof.(A))
        D = Tuple{[Vector{T} for T in types]...}
        TypeSortedCollection{D, I}(A, indexfun)
    end

    function TypeSortedCollection{D}(indexfun::I) where {D<:TupleOfVectors, I}
        eltypes = eltype.([D.parameters...])
        data = tuple((T[] for T in eltypes)...)
        new{D, I}(data, indexfun)
    end

    function TypeSortedCollection{D, I}(A, indexfun::I) where {D<:TupleOfVectors, I}
        append!(TypeSortedCollection{D}(indexfun), A)
    end
end

function Base.append!(dest::TypeSortedCollection, A)
    data = dest.data
    type_to_index = Dict(T => i for (i, T) in enumerate(eltype.(data)))
    for x in A
        T = typeof(x)
        push!(data[type_to_index[T]], x)
    end
    dest
end

Base.length(x::TypeSortedCollection) = sum(length, x.data)
indexfun(x::TypeSortedCollection) = x.indexfun

@generated function Base.map!(f, dest::AbstractVector, tsc::TypeSortedCollection{D}, As::AbstractVector...) where {D}
    expr = Expr(:block)
    push!(expr.args, :(Base.@_inline_meta))
    for i = 1 : nfields(D)
        push!(expr.args, quote
            let vec = tsc.data[$i]
                for j in eachindex(vec)
                    element = vec[j]
                    index = tsc.indexfun(element)
                    dest[index] = f(element, getindex.(As, index)...)
                end
            end
        end)
    end
    push!(expr.args, :(return nothing))
    expr
end

@generated function Base.foreach(f, tsc::TypeSortedCollection{D}, As::AbstractVector...) where {D}
    expr = Expr(:block)
    push!(expr.args, :(Base.@_inline_meta))
    for i = 1 : nfields(D)
        push!(expr.args, quote
            let vec = tsc.data[$i]
                for j in eachindex(vec)
                    element = vec[j]
                    index = tsc.indexfun(element)
                    f(element, getindex.(As, index)...)
                end
            end
        end)
    end
    push!(expr.args, :(return nothing))
    expr
end

end # module
