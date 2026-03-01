# VectorLinkedList.jl

[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

A Julia implementation of Rust's [array-linked-list](https://docs.rs/array-linked-list/latest/array_linked_list/index.html) library.

Array-backed doubly-linked list with O(1) insertions, removals, and iteration.
Freed slots are recycled via an internal free list, so **slot indices remain
stable** until explicitly reused — enabling direct O(1) access without a
separate search.

## Features

- Array-backed linked list for cache-local storage (nodes stored inline, not on the heap)
- `isbitstype`-preserving node layout — important for bits-type elements like simulation structs
- Slot indices are stable: `push!` / `pushfirst!` return the slot index for later O(1) removal
- Forward and reverse iteration via Julia's standard `Iterators.Reverse` protocol
- Indexed iteration — `indexed(l)` yields `(slot_index, value)` pairs
- Free-slot detection: `l[idx]` returns `nothing` for freed slots

## Quick Start

```julia
using VectorLinkedList

# Create a list
l = MutableVecLinkedList{Int}()

# push!/pushfirst! return the slot index of the new element
i1 = pushfirst!(l, 10)          # l = [10],       i1 = 1
i2 = push!(l, 30)               # l = [10, 30],   i2 = 2
i3 = insert_after!(l, i1, 20)  # l = [10, 20, 30], i3 = 3

# Slot-based access (O(1))
l[i1]        # => 10
l[i1] = 11  # update in place

# Remove by slot index (O(1)); slot is recycled on next insert
val = remove!(l, i3)  # returns 20, l = [11, 30]
l[i3]                 # => nothing (freed slot)

# Standard iteration
collect(l)                        # => [11, 30]
collect(Iterators.reverse(l))     # => [30, 11]

# Indexed iteration — yields (slot_index, value)
for (idx, v) in indexed(l)
    println("slot $idx => $v")
end

# Reverse indexed iteration
for (idx, v) in reverse(indexed(l))
    println("slot $idx => $v")
end

# Search
findfirst(x -> x > 15, l)  # => slot index of first match, or nothing
20 in l                     # => false (we removed it)

# Concatenation
append!(l, MutableVecLinkedList{Int}(100, 200))
```

## API Summary

| Function | Description |
|---|---|
| `MutableVecLinkedList{T}()` | Empty list |
| `with_capacity(T, n)` | Empty list with pre-reserved storage for `n` elements |
| `push!(l, v) -> Int` | Append to back; returns slot index |
| `pushfirst!(l, v) -> Int` | Prepend to front; returns slot index |
| `insert_after!(l, idx, v) -> Int` | Insert after slot `idx`; returns new slot index |
| `insert_before!(l, idx, v) -> Int` | Insert before slot `idx`; returns new slot index |
| `remove!(l, idx) -> T` | Remove slot `idx`; returns its value |
| `pop!(l) -> T` | Remove and return last element |
| `popfirst!(l) -> T` | Remove and return first element |
| `delete!(l, idx) -> l` | Alias for `remove!`; returns the list |
| `l[idx]` | `T` if slot is live, `nothing` if freed |
| `l[idx] = v` | Overwrite a live slot in place |
| `first(l)` / `last(l)` | Peek at front / back element |
| `front_index(l)` / `back_index(l)` | Slot index of front / back, or `nothing` |
| `length(l)` / `isempty(l)` | Live element count |
| `capacity(l)` | Total allocated slots (live + freed) |
| `indexed(l)` | Iterator of `(slot_index, value)` pairs |
| `reverse(indexed(l))` | Same, in reverse order |
| `findfirst(pred, l)` | Slot index of first match, or `nothing` |
| `in(v, l)` | Membership test |
| `append!(l1, l2)` | Push all of `l2` onto back of `l1` |
| `prepend!(l1, l2)` | Insert all of `l2` at front of `l1` |
| `copy(l)` | Independent copy (preserves slot layout) |
| `empty!(l)` | Reset to empty, free all storage |

## Implementation Notes

Nodes are stored as an immutable `struct LinkedListNode{T}` with an `occupied::Bool`
field to distinguish live from freed slots.  For bits-type `T` (e.g. a struct of
`Float64`, `Int64`, `Bool`), `isbitstype(LinkedListNode{T}) == true`, so
`Vector{LinkedListNode{T}}` stores all nodes contiguously with no heap indirection.

Freed nodes are linked into a singly-linked free list and recycled by the next
insertion, keeping slot indices stable for the lifetime of a slot.

## Contributing

If you are interested in contributing, please feel free to fork the repository,
make your changes, and submit a pull request.
