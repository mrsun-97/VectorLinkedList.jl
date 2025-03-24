using Test
using VectorLinkedList

@testset "VectorLinkedList.jl" begin
    @testset "Basic Operations" begin
        # Test constructor
        list = MutableVecLinkedList{Int}()
        @test isempty(list)
        @test length(list) == 0
        
        # Test push! and pushfirst!
        push!(list, 1)
        @test length(list) == 1
        @test collect(list) == [1]
        
        pushfirst!(list, 2)
        @test length(list) == 2
        @test collect(list) == [2, 1]
        
        push!(list, 3)
        @test length(list) == 3
        @test collect(list) == [2, 1, 3]
        
        # Test getindex
        @test list[1] == 2
        @test list[2] == 1
        @test list[3] == 3
        
        # Test setindex!
        list[2] = 4
        @test list[2] == 4
        @test collect(list) == [2, 4, 3]
    end
    
    @testset "Insert and Delete" begin
        list = MutableVecLinkedList{Int}()
        push!(list, 1)
        push!(list, 2)
        push!(list, 3)
        
        # Test insert!
        insert!(list, 2, 4)
        @test collect(list) == [1, 4, 2, 3]
        
        # Test delete!
        delete!(list, 2)
        @test collect(list) == [1, 2, 3]
        
        # Test pop! and popfirst!
        @test pop!(list) == 3
        @test collect(list) == [1, 2]
        
        @test popfirst!(list) == 1
        @test collect(list) == [2]
        
        # Test empty!
        empty!(list)
        @test isempty(list)
    end
    
    @testset "Insert After and Before" begin
        list = MutableVecLinkedList{Int}()
        idx1 = push!(list, 1)
        idx2 = push!(list, 3)
        
        # Test insert_after!
        idx3 = insert_after!(list, idx1, 2)
        @test collect(list) == [1, 2, 3]
        
        # Test insert_before!
        idx4 = insert_before!(list, idx2, 2.5)
        @test collect(list) == [1, 2, 2.5, 3]
    end
    
    @testset "Indexed Iterator" begin
        list = MutableVecLinkedList{Int}()
        push!(list, 1)
        push!(list, 2)
        push!(list, 3)
        
        # Test indexed iterator
        indices_values = [(idx, val) for (idx, val) in indexed(list)]
        @test length(indices_values) == 3
        
        # Check that we can access elements by their indices
        for (idx, val) in indices_values
            @test list.elements[idx].data == val
        end
        
        # Test reverse indexed iterator
        rev_indices_values = [(idx, val) for (idx, val) in reverse(indexed(list))]
        @test length(rev_indices_values) == 3
        @test reverse([val for (_, val) in indices_values]) == [val for (_, val) in rev_indices_values]
    end
    
    @testset "Rust Example" begin
        # Recreate the Rust example in Julia
        list = MutableVecLinkedList{Int}()
        
        push!(list, 1)        # push_back(1)
        pushfirst!(list, 2)   # push_front(2)
        pushfirst!(list, 3)   # push_front(3)
        push!(list, 4)        # push_back(4)
        pushfirst!(list, 5)   # push_front(5)
        
        @test collect(list) == [5, 3, 2, 1, 4]
        
        # Test the indexed().rev() functionality
        for (idx, element) in reverse(indexed(list))
            @test element == list.elements[idx].data
        end
    end
    
    @testset "Edge Cases" begin
        # Test operations on empty list
        list = MutableVecLinkedList{Int}()
        
        # Push to empty list
        push!(list, 1)
        @test collect(list) == [1]
        empty!(list)
        
        # Pushfirst to empty list
        pushfirst!(list, 1)
        @test collect(list) == [1]
        empty!(list)
        
        # Test error cases
        @test_throws ArgumentError pop!(list)
        @test_throws ArgumentError popfirst!(list)
        @test_throws BoundsError list[1]
        
        # Test with deleted nodes
        list = MutableVecLinkedList{Int}()
        idx1 = push!(list, 1)
        idx2 = push!(list, 2)
        idx3 = push!(list, 3)
        
        delete!(list, idx2)
        push!(list, 4)  # Should reuse the deleted node
        @test collect(list) == [1, 3, 4]
        
        # Test that the free list is working
        @test list.free_index != 0
    end
end