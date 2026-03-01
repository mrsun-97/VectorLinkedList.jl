# ============================================================
#  Internal node type
# ============================================================

"""
    LinkedListNode{T}

Immutable node stored inline inside `MutableVecLinkedList{T}`.

Using an immutable struct (rather than `mutable struct`) ensures
`isbitstype(LinkedListNode{T})` is true for bits-type `T` (e.g. SpinCut),
so that `Vector{LinkedListNode{T}}` stores nodes contiguously in memory
rather than as a vector of heap pointers.

Fields:
- `data`     : the stored value; stale but harmless for freed nodes
- `prev`     : index of previous live node (0 = none / head sentinel)
- `next`     : index of next live node OR next free slot (0 = none)
- `occupied` : `true` for a live node, `false` for a freed/recycled slot
"""
struct LinkedListNode{T}
    data::T
    prev::Int
    next::Int
    occupied::Bool
end

# ============================================================
#  List type
# ============================================================

"""
    MutableVecLinkedList{T}

Array-backed doubly-linked list.  All operations that do not trigger
a reallocation run in O(1):

- `pushfirst!` / `push!`
- `popfirst!`  / `pop!`
- `insert_after!` / `insert_before!`
- `remove!`
- `length` / `isempty` / `first` / `last`

Indices are 1-based (Julia convention).  Index 0 is the null sentinel.

Deleted slots are recycled via a singly-linked free list so that slot
indices remain stable until explicitly reused.  `getindex(l, idx)` returns
`nothing` for freed slots, enabling validity checks.
"""
mutable struct MutableVecLinkedList{T}
    count::Int
    head_index::Int      # index of first live node; 0 = empty
    tail_index::Int      # index of last  live node; 0 = empty
    free_index::Int      # head of the free list;    0 = no free slots
    elements::Vector{LinkedListNode{T}}

    function MutableVecLinkedList{T}() where {T}
        new{T}(0, 0, 0, 0, LinkedListNode{T}[])
    end
end

MutableVecLinkedList() = error("Type parameter required: use MutableVecLinkedList{T}()")

"""
    MutableVecLinkedList{T}(elts...)

Construct a list from zero or more elements, pushed in order to the back.
"""
function MutableVecLinkedList{T}(elts...) where {T}
    l = MutableVecLinkedList{T}()
    for e in elts
        push!(l, e)
    end
    return l
end

"""
    with_capacity(T, n)

Return an empty `MutableVecLinkedList{T}` with the underlying vector
pre-reserved for `n` elements (no reallocation for the first `n` pushes).
"""
function with_capacity(::Type{T}, n::Integer) where {T}
    l = MutableVecLinkedList{T}()
    sizehint!(l.elements, n)
    return l
end

# ============================================================
#  Internal helpers
# ============================================================

@inline function _set_next!(l::MutableVecLinkedList{T}, i::Int, v::Int) where {T}
    n = l.elements[i]
    l.elements[i] = LinkedListNode{T}(n.data, n.prev, v, n.occupied)
end

@inline function _set_prev!(l::MutableVecLinkedList{T}, i::Int, v::Int) where {T}
    n = l.elements[i]
    l.elements[i] = LinkedListNode{T}(n.data, v, n.next, n.occupied)
end

# Update the `next` field of the node BEFORE `prev_idx` in the live list,
# or update `head_index` when prev_idx == 0 (inserting before the head).
@inline function _next_of_prev!(l::MutableVecLinkedList, prev_idx::Int, val::Int)
    if prev_idx > 0
        _set_next!(l, prev_idx, val)
    else
        l.head_index = val
    end
end

# Update the `prev` field of the node AFTER `next_idx` in the live list,
# or update `tail_index` when next_idx == 0 (inserting after the tail).
@inline function _prev_of_next!(l::MutableVecLinkedList, next_idx::Int, val::Int)
    if next_idx > 0
        _set_prev!(l, next_idx, val)
    else
        l.tail_index = val
    end
end

# Patch both neighbours of a gap in the live list (after removing a node).
@inline function _connect_live!(l::MutableVecLinkedList, prev_idx::Int, next_idx::Int)
    _prev_of_next!(l, next_idx, prev_idx)
    _next_of_prev!(l, prev_idx, next_idx)
end

# Insert `element` into a free slot (recycling if available) and return its index.
@inline function _insert_free_element!(l::MutableVecLinkedList{T}, element::LinkedListNode{T}) where {T}
    if l.free_index == 0
        push!(l.elements, element)
        return length(l.elements)
    else
        idx = l.free_index
        l.free_index = l.elements[idx].next   # advance free list
        l.elements[idx] = element
        return idx
    end
end

# Insert `value` between the nodes at `prev_idx` and `next_idx` (either may be 0).
# Returns the new node's 1-based index.
@inline function _insert_between!(
        l::MutableVecLinkedList{T}, prev_idx::Int, next_idx::Int, value::T
) where {T}
    element = LinkedListNode{T}(value, prev_idx, next_idx, true)
    new_idx = _insert_free_element!(l, element)
    _next_of_prev!(l, prev_idx, new_idx)
    _prev_of_next!(l, next_idx, new_idx)
    l.count += 1
    return new_idx
end

# ============================================================
#  Insertion
# ============================================================

"""
    pushfirst!(l::MutableVecLinkedList, value) -> Int

Insert `value` at the front of `l`.  Returns the 1-based slot index.
"""
function Base.pushfirst!(l::MutableVecLinkedList{T}, value::T) where {T}
    return _insert_between!(l, 0, l.head_index, value)
end

"""
    push!(l::MutableVecLinkedList, value) -> Int

Insert `value` at the back of `l`.  Returns the 1-based slot index.
"""
function Base.push!(l::MutableVecLinkedList{T}, value::T) where {T}
    return _insert_between!(l, l.tail_index, 0, value)
end

"""
    insert_after!(l, prev_idx, value) -> Int

Insert `value` immediately after the element at `prev_idx`.
Returns the 1-based slot index of the new element.
"""
function insert_after!(l::MutableVecLinkedList{T}, prev_idx::Int, value::T) where {T}
    return _insert_between!(l, prev_idx, l.elements[prev_idx].next, value)
end

"""
    insert_before!(l, next_idx, value) -> Int

Insert `value` immediately before the element at `next_idx`.
Returns the 1-based slot index of the new element.
"""
function insert_before!(l::MutableVecLinkedList{T}, next_idx::Int, value::T) where {T}
    return _insert_between!(l, l.elements[next_idx].prev, next_idx, value)
end

# ============================================================
#  Removal
# ============================================================

"""
    remove!(l, idx) -> T

Remove the element at slot `idx` and return its value.
The slot is prepended to the free list for future reuse.

The caller is responsible for only removing live (occupied) slots.
"""
function remove!(l::MutableVecLinkedList{T}, idx::Int) where {T}
    node = l.elements[idx]
    _connect_live!(l, node.prev, node.next)
    l.elements[idx] = LinkedListNode{T}(node.data, 0, l.free_index, false)
    l.free_index = idx
    l.count -= 1
    return node.data
end

"""
    popfirst!(l) -> T

Remove and return the first element.  Throws `ArgumentError` if empty.
"""
function Base.popfirst!(l::MutableVecLinkedList)
    isempty(l) && throw(ArgumentError("List is empty"))
    return remove!(l, l.head_index)
end

"""
    pop!(l) -> T

Remove and return the last element.  Throws `ArgumentError` if empty.
"""
function Base.pop!(l::MutableVecLinkedList)
    isempty(l) && throw(ArgumentError("List is empty"))
    return remove!(l, l.tail_index)
end

# ============================================================
#  Accessors
# ============================================================

"""
    first(l) -> T

Return the first element without removing it.  Throws if empty.
"""
function Base.first(l::MutableVecLinkedList)
    isempty(l) && throw(ArgumentError("List is empty"))
    return l.elements[l.head_index].data
end

"""
    last(l) -> T

Return the last element without removing it.  Throws if empty.
"""
function Base.last(l::MutableVecLinkedList)
    isempty(l) && throw(ArgumentError("List is empty"))
    return l.elements[l.tail_index].data
end

"""
    front_index(l) -> Union{Int, Nothing}

Return the 1-based index of the first element, or `nothing` if empty.
"""
front_index(l::MutableVecLinkedList) = l.head_index > 0 ? l.head_index : nothing

"""
    back_index(l) -> Union{Int, Nothing}

Return the 1-based index of the last element, or `nothing` if empty.
"""
back_index(l::MutableVecLinkedList) = l.tail_index > 0 ? l.tail_index : nothing

"""
    l[idx] -> Union{T, Nothing}

Return the data at slot `idx`, or `nothing` if the slot has been freed.
"""
function Base.getindex(l::MutableVecLinkedList, idx::Int)
    node = l.elements[idx]
    return node.occupied ? node.data : nothing
end

"""
    l[idx] = value

Overwrite the data of the live node at slot `idx`.
The node's position in the list is unchanged.
"""
function Base.setindex!(l::MutableVecLinkedList{T}, value::T, idx::Int) where {T}
    n = l.elements[idx]
    l.elements[idx] = LinkedListNode{T}(value, n.prev, n.next, n.occupied)
    return value
end

"""
    length(l) -> Int

Return the number of live elements.
"""
Base.length(l::MutableVecLinkedList) = l.count

"""
    isempty(l) -> Bool
"""
Base.isempty(l::MutableVecLinkedList) = l.count == 0

"""
    capacity(l) -> Int

Return the number of allocated slots (live + freed).
Slot indices in `1:capacity(l)` are valid for `getindex`.
"""
capacity(l::MutableVecLinkedList) = length(l.elements)

Base.eltype(::Type{<:MutableVecLinkedList{T}}) where {T} = T

Base.IteratorSize(::Type{<:MutableVecLinkedList}) = Base.HasLength()

# ============================================================
#  Mutation utilities
# ============================================================

"""
    empty!(l)

Remove all elements and reset the list.  Frees the underlying storage.
"""
function Base.empty!(l::MutableVecLinkedList)
    l.count = 0
    l.head_index = 0
    l.tail_index = 0
    l.free_index = 0
    empty!(l.elements)
    return l
end

Base.collect(l::MutableVecLinkedList{T}) where {T} = T[x for x in l]

# ============================================================
#  Display
# ============================================================

function Base.show(io::IO, l::MutableVecLinkedList{T}) where {T}
    print(io, "MutableVecLinkedList{", T, "}[")
    first_item = true
    for v in l
        first_item || print(io, ", ")
        show(io, v)
        first_item = false
    end
    print(io, "]")
end

# ============================================================
#  Copy
# ============================================================

"""
    copy(l::MutableVecLinkedList{T}) -> MutableVecLinkedList{T}

Return a shallow copy of `l` with an independent `elements` vector.
Modifications to the copy (insertions, removals) do not affect the original.

For element types containing mutable heap objects, use `deepcopy` to also
copy the element values themselves.
"""
function Base.copy(l::MutableVecLinkedList{T}) where {T}
    c = MutableVecLinkedList{T}()
    c.count       = l.count
    c.head_index  = l.head_index
    c.tail_index  = l.tail_index
    c.free_index  = l.free_index
    c.elements    = copy(l.elements)   # new Vector, same immutable node values
    return c
end

# ============================================================
#  Equality
# ============================================================

Base.:(==)(::MutableVecLinkedList, ::MutableVecLinkedList) = false

function Base.:(==)(l1::MutableVecLinkedList{T}, l2::MutableVecLinkedList{T}) where {T}
    length(l1) == length(l2) || return false
    for (a, b) in zip(l1, l2)
        a == b || return false
    end
    return true
end

# ============================================================
#  Iteration
# ============================================================

# Forward iteration.
# State = index of the NEXT node to yield; 0 means exhausted.
function Base.iterate(l::MutableVecLinkedList)
    l.count == 0 && return nothing
    node = l.elements[l.head_index]
    return (node.data, node.next)
end

function Base.iterate(l::MutableVecLinkedList, state::Int)
    state == 0 && return nothing
    node = l.elements[state]
    return (node.data, node.next)
end

# Reverse iteration via Iterators.Reverse.
# State = index of the NEXT node to yield going backwards; 0 means exhausted.
function Base.iterate(iter::Iterators.Reverse{<:MutableVecLinkedList})
    l = iter.itr
    l.count == 0 && return nothing
    node = l.elements[l.tail_index]
    return (node.data, node.prev)
end

function Base.iterate(iter::Iterators.Reverse{<:MutableVecLinkedList}, state::Int)
    state == 0 && return nothing
    l = iter.itr
    node = l.elements[state]
    return (node.data, node.prev)
end

# ============================================================
#  Indexed iteration
# ============================================================

"""
    IndexedIterator{T}

Iterator yielding `(slot_index::Int, value::T)` pairs in forward list order.
Obtain via `indexed(l)`.  Knowing the slot index during iteration allows O(1)
operations like `remove!` without a separate search.
"""
struct IndexedIterator{T}
    list::MutableVecLinkedList{T}
end

"""
    indexed(l) -> IndexedIterator

Return an iterator over `(slot_index, value)` pairs in list order.
"""
indexed(l::MutableVecLinkedList{T}) where {T} = IndexedIterator{T}(l)

function Base.iterate(it::IndexedIterator{T}) where {T}
    isempty(it.list) && return nothing
    idx = it.list.head_index
    return ((idx, it.list.elements[idx].data), it.list.elements[idx].next)
end

function Base.iterate(it::IndexedIterator{T}, state::Int) where {T}
    state == 0 && return nothing
    return ((state, it.list.elements[state].data), it.list.elements[state].next)
end

Base.length(it::IndexedIterator) = length(it.list)
Base.eltype(::Type{IndexedIterator{T}}) where {T} = Tuple{Int, T}

"""
    ReverseIndexedIterator{T}

Like `IndexedIterator` but traverses in reverse order.
Obtain via `reverse(indexed(l))`.
"""
struct ReverseIndexedIterator{T}
    list::MutableVecLinkedList{T}
end

Base.reverse(it::IndexedIterator{T}) where {T} = ReverseIndexedIterator{T}(it.list)

function Base.iterate(it::ReverseIndexedIterator{T}) where {T}
    isempty(it.list) && return nothing
    idx = it.list.tail_index
    return ((idx, it.list.elements[idx].data), it.list.elements[idx].prev)
end

function Base.iterate(it::ReverseIndexedIterator{T}, state::Int) where {T}
    state == 0 && return nothing
    return ((state, it.list.elements[state].data), it.list.elements[state].prev)
end

Base.length(it::ReverseIndexedIterator) = length(it.list)
Base.eltype(::Type{ReverseIndexedIterator{T}}) where {T} = Tuple{Int, T}

# ============================================================
#  Search and membership
# ============================================================

Base.in(value::T, l::MutableVecLinkedList{T}) where {T} = any(x -> x == value, l)

"""
    findfirst(predicate, l) -> Union{Int, Nothing}
    findfirst(value, l)     -> Union{Int, Nothing}

Return the slot index of the first element satisfying `predicate` (or equal
to `value`), or `nothing` if not found.
"""
function Base.findfirst(predicate::Function, l::MutableVecLinkedList)
    for (idx, val) in indexed(l)
        predicate(val) && return idx
    end
    return nothing
end

Base.findfirst(value::T, l::MutableVecLinkedList{T}) where {T} =
    findfirst(x -> x == value, l)

# ============================================================
#  Concatenation
# ============================================================

"""
    append!(l1, l2) -> l1

Push every element of `l2` onto the back of `l1`.
"""
function Base.append!(l1::MutableVecLinkedList{T}, l2::MutableVecLinkedList{T}) where {T}
    for v in l2; push!(l1, v); end
    return l1
end

"""
    prepend!(l1, l2) -> l1

Insert every element of `l2` at the front of `l1`, preserving `l2`'s order.
"""
function Base.prepend!(l1::MutableVecLinkedList{T}, l2::MutableVecLinkedList{T}) where {T}
    for v in Iterators.reverse(l2); pushfirst!(l1, v); end
    return l1
end

# ============================================================
#  Base.delete! alias
# ============================================================

"""
    delete!(l, idx) -> l

Remove the element at slot `idx` and return the list.
Alias for `remove!` that follows the `Base.delete!` convention.
"""
Base.delete!(l::MutableVecLinkedList, idx::Int) = (remove!(l, idx); l)
