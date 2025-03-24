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
        push!(l.elements, element)
        length(l.elements)
    else
        free_index = l.free_index
        recycle_element = l.elements[free_index]
        l.free_index = recycle_element.next
        l.elements[free_index] = element
        free_index
    end
    return new_index
end

function Base.pushfirst!(l::MutableVecLinkedList{T}, value::T) where {T}
    element = _head(value, l.head_index)
    current_index = _insert_free_element!(l, element)
    if l.head_index != 0
        l.elements[l.head_index].prev = current_index
    else
        # If the list was empty, set the tail_index as well
        l.tail_index = current_index
    end
    l.head_index = current_index
    l.count += 1
    return current_index
end

function Base.push!(l::MutableVecLinkedList{T}, value::T) where {T}
    element = _tail(value, l.tail_index)
    current_index = _insert_free_element!(l, element)
    if l.tail_index != 0
        l.elements[l.tail_index].next = current_index
    else
        # If the list was empty, set the head_index as well
        l.head_index = current_index
    end
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

function Base.empty!(l::MutableVecLinkedList{T}) where {T}
    if isempty(l)
        return l
    end
    
    # Reset all elements to be in the free list
    for i in 1:length(l.elements)
        if i < length(l.elements)
            l.elements[i] = _deleted(T, i + 1)
        else
            l.elements[i] = _deleted(T, 0)
        end
    end
    
    # Reset list properties
    l.count = 0
    l.head_index = 0
    l.tail_index = 0
    l.free_index = 1
    
    return l
end

function Base.getindex(l::MutableVecLinkedList, index::Int)
    if index <= 0 || index > l.count
        throw(BoundsError(l, index))
    end
    
    # Traverse the list to find the element at the given index
    current_index = l.head_index
    for _ in 1:(index-1)
        current_index = l.elements[current_index].next
    end
    
    return l.elements[current_index].data
end

function Base.setindex!(l::MutableVecLinkedList{T}, value::T, index::Int) where {T}
    if index <= 0 || index > l.count
        throw(BoundsError(l, index))
    end
    
    # Traverse the list to find the element at the given index
    current_index = l.head_index
    for _ in 1:(index-1)
        current_index = l.elements[current_index].next
    end
    
    l.elements[current_index].data = value
    return l
end

function Base.insert!(l::MutableVecLinkedList{T}, index::Int, value::T) where {T}
    if index <= 0 || index > l.count + 1
        throw(BoundsError(l, index))
    end
    
    if index == 1
        return pushfirst!(l, value)
    elseif index == l.count + 1
        return push!(l, value)
    end
    
    # Traverse the list to find the element at the given index
    current_index = l.head_index
    for _ in 1:(index-2)
        current_index = l.elements[current_index].next
    end
    
    next_index = l.elements[current_index].next
    
    # Create a new element
    element = LinkedListNode{T}(value, current_index, next_index)
    new_index = _insert_free_element!(l, element)
    
    # Update the surrounding elements
    l.elements[current_index].next = new_index
    l.elements[next_index].prev = new_index
    
    l.count += 1
    return new_index
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

function Base.delete!(l::MutableVecLinkedList, index::Int)
    if index <= 0 || index > length(l.elements) || l.elements[index].data === nothing
        throw(ArgumentError("Invalid index or node already deleted"))
    end
    
    prev_index = l.elements[index].prev
    next_index = l.elements[index].next
    
    # Update the previous node's next pointer
    if prev_index != 0
        l.elements[prev_index].next = next_index
    else
        # If we're deleting the head, update the head_index
        l.head_index = next_index
    end
    
    # Update the next node's previous pointer
    if next_index != 0
        l.elements[next_index].prev = prev_index
    else
        # If we're deleting the tail, update the tail_index
        l.tail_index = prev_index
    end
    
    # Add the deleted node to the free list
    l.elements[index] = _deleted(eltype(l), l.free_index)
    l.free_index = index
    
    # Decrement the count
    l.count -= 1
    
    return l
end

function Base.popfirst!(l::MutableVecLinkedList)
    isempty(l) && throw(ArgumentError("List is empty"))
    head_index = l.head_index
    value = l.elements[head_index].data
    delete!(l, head_index)
    return value
end

function Base.pop!(l::MutableVecLinkedList)
    isempty(l) && throw(ArgumentError("List is empty"))
    tail_index = l.tail_index
    value = l.elements[tail_index].data
    delete!(l, tail_index)
    return value
end

function Base.in(value::T, l::MutableVecLinkedList{T}) where {T}
    for item in l
        if item == value
            return true
        end
    end
    return false
end

function Base.findfirst(predicate::Function, l::MutableVecLinkedList)
    index = 1
    current_index = l.head_index
    while current_index != 0
        if predicate(l.elements[current_index].data)
            return index
        end
        current_index = l.elements[current_index].next
        index += 1
    end
    return nothing
end

function Base.findfirst(value::T, l::MutableVecLinkedList{T}) where {T}
    return findfirst(x -> x == value, l)
end

function Base.delete!(l::MutableVecLinkedList{T}, value::T) where {T}
    index = findfirst(value, l)
    if index !== nothing
        current_index = l.head_index
        for _ in 1:(index-1)
            current_index = l.elements[current_index].next
        end
        delete!(l, current_index)
        return true
    end
    return false
end

function Base.copy(l::MutableVecLinkedList{T}) where {T}
    new_list = MutableVecLinkedList{T}()
    for item in l
        push!(new_list, item)
    end
    return new_list
end

function Base.append!(l1::MutableVecLinkedList{T}, l2::MutableVecLinkedList{T}) where {T}
    for item in l2
        push!(l1, item)
    end
    return l1
end

function Base.prepend!(l1::MutableVecLinkedList{T}, l2::MutableVecLinkedList{T}) where {T}
    for item in reverse(collect(l2))
        pushfirst!(l1, item)
    end
    return l1
end

# IndexedIterator for MutableVecLinkedList
struct IndexedIterator{T}
    list::MutableVecLinkedList{T}
end

# Return an iterator that yields tuples of (index, element)
function indexed(l::MutableVecLinkedList{T}) where {T}
    return IndexedIterator{T}(l)
end

function Base.iterate(it::IndexedIterator{T}) where {T}
    isempty(it.list) && return nothing
    current_index = it.list.head_index
    return ((current_index, it.list.elements[current_index].data), current_index)
end

function Base.iterate(it::IndexedIterator{T}, state::Int) where {T}
    state == 0 && return nothing
    next_index = it.list.elements[state].next
    next_index == 0 && return nothing
    return ((next_index, it.list.elements[next_index].data), next_index)
end

Base.length(it::IndexedIterator) = length(it.list)
Base.eltype(::Type{IndexedIterator{T}}) where {T} = Tuple{Int, T}

# Reverse iterator for MutableVecLinkedList
struct ReverseIterator{T}
    list::MutableVecLinkedList{T}
end

# Return a reverse iterator
function Base.reverse(l::MutableVecLinkedList{T}) where {T}
    return ReverseIterator{T}(l)
end

function Base.iterate(it::ReverseIterator{T}) where {T}
    isempty(it.list) && return nothing
    current_index = it.list.tail_index
    return (it.list.elements[current_index].data, current_index)
end

function Base.iterate(it::ReverseIterator{T}, state::Int) where {T}
    state == 0 && return nothing
    prev_index = it.list.elements[state].prev
    prev_index == 0 && return nothing
    return (it.list.elements[prev_index].data, prev_index)
end

Base.length(it::ReverseIterator) = length(it.list)
Base.eltype(::Type{ReverseIterator{T}}) where {T} = T

# Reverse indexed iterator
struct ReverseIndexedIterator{T}
    list::MutableVecLinkedList{T}
end

# Return a reverse indexed iterator
function Base.reverse(it::IndexedIterator{T}) where {T}
    return ReverseIndexedIterator{T}(it.list)
end

function Base.iterate(it::ReverseIndexedIterator{T}) where {T}
    isempty(it.list) && return nothing
    current_index = it.list.tail_index
    return ((current_index, it.list.elements[current_index].data), current_index)
end

function Base.iterate(it::ReverseIndexedIterator{T}, state::Int) where {T}
    state == 0 && return nothing
    prev_index = it.list.elements[state].prev
    prev_index == 0 && return nothing
    return ((prev_index, it.list.elements[prev_index].data), prev_index)
end

Base.length(it::ReverseIndexedIterator) = length(it.list)
Base.eltype(::Type{ReverseIndexedIterator{T}}) where {T} = Tuple{Int, T}

# Helper functions for insert_after and insert_before
function insert_after!(l::MutableVecLinkedList{T}, index::Int, value::T) where {T}
    if index <= 0 || index > length(l.elements) || l.elements[index].data === nothing
        throw(ArgumentError("Invalid index or node already deleted"))
    end
    
    next_index = l.elements[index].next
    
    # Create a new element
    element = LinkedListNode{T}(value, index, next_index)
    new_index = _insert_free_element!(l, element)
    
    # Update the surrounding elements
    l.elements[index].next = new_index
    
    if next_index != 0
        l.elements[next_index].prev = new_index
    else
        # If we're inserting after the tail, update the tail_index
        l.tail_index = new_index
    end
    
    l.count += 1
    return new_index
end

function insert_before!(l::MutableVecLinkedList{T}, index::Int, value::T) where {T}
    if index <= 0 || index > length(l.elements) || l.elements[index].data === nothing
        throw(ArgumentError("Invalid index or node already deleted"))
    end
    
    prev_index = l.elements[index].prev
    
    # Create a new element
    element = LinkedListNode{T}(value, prev_index, index)
    new_index = _insert_free_element!(l, element)
    
    # Update the surrounding elements
    l.elements[index].prev = new_index
    
    if prev_index != 0
        l.elements[prev_index].next = new_index
    else
        # If we're inserting before the head, update the head_index
        l.head_index = new_index
    end
    
    l.count += 1
    return new_index
end