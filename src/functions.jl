mutable struct LinkedListNode{T}
    data::Union{T, Nothing}
    prev::Int
    next::Int
    function LinkedListNode{T}(data::T, prev::Int, next::Int) where {T}
        return new(data, prev, next)
    end
    function LinkedListNode{T}(prev::Int, next::Int) where {T}
        return new(nothing, prev, next)
    end
end

mutable struct MutableVecLinkedList{T}
    count::Int
    head_index::Int
    tail_index::Int
    free_index::Int
    capacity::Int
    elements::Vector{LinkedListNode{T}}
    function MutableVecLinkedList{T}() where {T}
        l = new{T}()
        l.count = 0
        l.head_index = 0
        l.tail_index = 0
        l.free_index = 0
        l.capacity = 0
        l.elements = LinkedListNode{T}[]
        return l
    end
end

MutableVecLinkedList() = error("use MutableVecLinkedList{T}()")

function MutableVecLinkedList{T}(elts...) where {T}
    l = MutableVecLinkedList{T}()
    for elt in elts
        push!(l, elt)
    end
    return l
end

function _head(data::T, head_index::Int) where {T}
    return LinkedListNode{T}(data, 0, head_index)
end

function _tail(data::T, tail_index::Int) where {T}
    return LinkedListNode{T}(data, tail_index, 0)
end

function _deleted(::Type{T}, free_index::Int) where {T}
    return LinkedListNode{T}(0, free_index)
end

# change this function
function fill_elements!(l::MutableVecLinkedList{T}, capacity::Integer) where {T}
    if capacity == 0
        return l
    end
    if isempty(l.elements)
        l.elements = Vector{LinkedListNode{T}}(undef, capacity)
    end
    for i in 1:(capacity - 1)
        l.elements[i] = _deleted(T, i + 1)
    end
    l.elements[end] = _deleted(T, 0)
    l.free_index = 1
    l.capacity = capacity
    return l
end

function with_capacity(::Type{T}, capacity::Integer) where {T}
    l = MutableVecLinkedList{T}()
    if capacity == 0
        return l
    end
    l.elements = Vector{LinkedListNode{T}}(undef, capacity)
    for i in 1:(capacity - 1)
        l.elements[i] = _deleted(T, i + 1)
    end
    l.elements[end] = _deleted(T, 0)
    l.free_index = 1
    l.capacity = capacity

    return l
end

"""
    function insert_free_element!(
        l::MutableVecLinkedList{T}, element::LinkedListNode{T}
    ) where {T}

Insert data to a possibly free node. Return the inserted data index.
"""
function _insert_free_element!(
        l::MutableVecLinkedList{T}, element::LinkedListNode{T}
) where {T}
    new_index = if l.free_index == 0
        l.elements.push(element)
        length(l.elements)
    else
        free_index = l.free_index
        recycle_element = l.elements[free_index]
        l.free_index = recycle_element.next_index
        l.elements[free_index] = element
        free_index
    end
    return new_index
end

function Base.pushfirst!(l::MutableVecLinkedList, value::T) where {T}
    element = _head(value, l.head_index)
    current_index = _insert_free_element!(l, element)
    l.elements[l.head_index].prev_index = current_index
    l.head_index = current_index
    l.count += 1
    return current_index
end

function Base.push!(l::MutableVecLinkedList, value::T) where {T}
    element = _tail(value, l.tail_index)
    current_index = _insert_free_element!(l, element)
    l.elements[l.tail_index].next_index = current_index
    l.tail_index = current_index
    l.count += 1
    return current_index
end

function Base.iterate(l::MutableVecLinkedList)
    l.count == 0 ? nothing :
    (l.elements[l.head_index].data, l.elements[l.head_index].next)
end

function Base.iterate(l::MutableVecLinkedList, n::Int)
    n == 0 ? nothing : (l.elements[n].data, l.elements[n].next)
end

Base.isempty(l::MutableVecLinkedList) = l.count == 0
Base.length(l::MutableVecLinkedList) = l.count
Base.collect(l::MutableVecLinkedList{T}) where {T} = T[x for x in l]
Base.eltype(::Type{<:MutableVecLinkedList{T}}) where {T} = T
capacity(l::MutableVecLinkedList) = length(l.elements)

function Base.first(l::MutableVecLinkedList)
    isempty(l) && throw(ArgumentError("List is empty"))
    return l.elements[l.head_index]
end

function Base.last(l::MutableVecLinkedList)
    isempty(l) && throw(ArgumentError("List is empty"))
    return l.elements[l.tail_index]
end

Base.:(==)(l1::MutableVecLinkedList{T}, l2::MutableVecLinkedList{S}) where {T, S} = false

# copied from Datastructures.jl
function Base.:(==)(l1::MutableVecLinkedList{T}, l2::MutableVecLinkedList{T}) where {T}
    length(l1) == length(l2) || return false
    for (i, j) in zip(l1, l2)
        i == j || return false
    end
    return true
end

# TODO
function Base.delete!(l::MutableVecLinkedList, index::Int)
    prev_index = l.elements[index].prev_index
    next_index = l.elements[index].next_index
end
