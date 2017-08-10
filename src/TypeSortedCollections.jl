module TypeSortedCollections

export
    TypeSortedCollection

const TupleOfVectors = Tuple{Vararg{Vector{T} where T}}

struct TypeSortedCollection{D<:TupleOfVectors}
    data::D
    indices::Tuple{Vector{Int}}

    function TypeSortedCollection{D}() where {D<:TupleOfVectors}
        eltypes = eltype.([D.parameters...])
        data = tuple((T[] for T in eltypes)...)
        indices = tuple((Int[] for i in eachindex(eltypes))...)
        new{D}(data, indices)
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

# not type stable
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

# type stable
Base.length(x::TypeSortedCollection) = sum(length, x.data)

# type stable
@generated function Base.map!(f, dest::AbstractVector, tsc::TypeSortedCollection{D}, As::AbstractVector...) where {D}
    expr = Expr(:block)
    push!(expr.args, :(Base.@_inline_meta))
    for i = 1 : nfields(D)
        push!(expr.args, quote
            let vec = tsc.data[$i], inds = tsc.indices[$i]
                for j in eachindex(vec)
                    element = vec[j]
                    index = inds[j]
                    dest[index] = f(element, getindex.(As, index)...)
                end
            end
        end)
    end
    push!(expr.args, :(return nothing))
    expr
end

# type stable
@generated function Base.foreach(f, tsc::TypeSortedCollection{D}, As::AbstractVector...) where {D}
    expr = Expr(:block)
    push!(expr.args, :(Base.@_inline_meta))
    for i = 1 : nfields(D)
        push!(expr.args, quote
            let vec = tsc.data[$i], inds = tsc.indices[$i]
                for j in eachindex(vec)
                    element = vec[j]
                    index = inds[j]
                    f(element, getindex.(As, index)...)
                end
            end
        end)
    end
    push!(expr.args, :(return nothing))
    expr
end

end # module
