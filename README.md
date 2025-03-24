# VectorLinkedList.jl

[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

A Julia implementation of Rust's [array-linked-list](https://docs.rs/array-linked-list/latest/array_linked_list/index.html) library.

This code aims to be a translation of Rust's [array-linked-list](https://docs.rs/array-linked-list/latest/array_linked_list/index.html) to Julia, providing a performant array-based alternative to traditional linked lists.

## Features

- Array-backed linked list implementation for better cache locality
- Efficient node reuse through a free list
- Standard linked list operations: push, pop, insert, delete
- Special iterators for accessing internal indices

## Quick Start

```julia
using VectorLinkedList

# Create a new list
list = MutableVecLinkedList{Int}()

# Add elements
push!(list, 1)        # Add to end
pushfirst!(list, 2)   # Add to beginning
push!(list, 3)        # Add to end

# Access elements
first_element = list[1]  # Access by position (2)
last_element = list[3]   # Access by position (3)

# Iterate through elements
for element in list
    println(element)  # Prints: 2, 1, 3
end

# Iterate with indices
for (idx, element) in indexed(list)
    println("Element $element is at internal index $idx")
end

# Reverse iteration with indices
for (idx, element) in reverse(indexed(list))
    println("Element $element is at internal index $idx")
end

# Insert and delete
insert!(list, 2, 4)      # Insert 4 at position 2
delete!(list, 2)         # Delete element at position 2

# Insert after/before specific nodes
idx = push!(list, 5)     # Returns the internal index
insert_after!(list, idx, 6)   # Insert 6 after 5
insert_before!(list, idx, 4)  # Insert 4 before 5
```

## Implementation Details

The `MutableVecLinkedList` uses an array to store linked list nodes, with each node containing:
- The data value
- A previous index pointer
- A next index pointer

This implementation maintains a free list of deleted nodes for efficient reuse, reducing memory allocations.

## Contributing

If you are interested in contributing, please feel free to fork the repository, make your changes, and submit a pull request.

Your feedback is important! Please teach me how to use Julia.