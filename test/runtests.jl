using Test
using VectorLinkedList

# Defined at module level so Julia doesn't warn about type redefinition
# when tests are re-run in the same session.
struct SpinCutTest
    position::Float64
    spin::Int64
    marked::Bool
end

# ============================================================
#  NOTE ON INDEX CONVENTION
#  Rust returns 0-based indices; Julia returns 1-based indices.
#  All index assertions below are shifted by +1 vs. the Rust doctests.
# ============================================================

# ============================================================
#  Module-level doctest 1 (Rust lines 48-58)
#  Indices are always assigned in raising order regardless of
#  whether elements are pushed front or back.
# ============================================================
@testset "index ordering: push_front / push_back return consecutive indices" begin
    l = MutableVecLinkedList{Int}()
    @test pushfirst!(l, 1) == 1
    @test push!(l, 2)      == 2
    @test pushfirst!(l, 3) == 3
    @test pushfirst!(l, 4) == 4
    @test push!(l, 5)      == 5
end

# ============================================================
#  Module-level doctest 2 (Rust lines 64-76)
#  push_front elements: reverse iteration aligns with getindex.
# ============================================================
@testset "push_front order: reverse iteration consistent with getindex" begin
    l = MutableVecLinkedList{Int}()
    pushfirst!(l, 1)
    pushfirst!(l, 2)
    pushfirst!(l, 3)
    # List order: [3, 2, 1]
    # Slot assignments: l[1]=1, l[2]=2, l[3]=3
    for (i, v) in enumerate(Iterators.reverse(l))
        @test v == l[i]
    end
end

# ============================================================
#  Module-level doctest 3 (Rust lines 78-90)
#  push_back elements: forward iteration aligns with getindex.
# ============================================================
@testset "push_back order: forward iteration consistent with getindex" begin
    l = MutableVecLinkedList{Int}()
    push!(l, 1)
    push!(l, 2)
    push!(l, 3)
    # List order: [1, 2, 3]
    # Slot assignments: l[1]=1, l[2]=2, l[3]=3
    for (i, v) in enumerate(l)
        @test v == l[i]
    end
end

# ============================================================
#  Module-level doctest 4 (Rust lines 97-111)
#  Mixed pushes: getindex still reflects the value placed at each slot.
#  (Rust used indexed().rev(); we verify slot-to-value consistency directly.)
# ============================================================
@testset "mixed push: getindex consistent with insertion values" begin
    l = MutableVecLinkedList{Int}()
    i1 = push!(l, 1)      # 1
    i2 = pushfirst!(l, 2) # 2
    i3 = pushfirst!(l, 3) # 3
    i4 = push!(l, 4)      # 4
    i5 = pushfirst!(l, 5) # 5

    @test l[i1] == 1
    @test l[i2] == 2
    @test l[i3] == 3
    @test l[i4] == 4
    @test l[i5] == 5
    # List order follows linked order: 5 → 3 → 2 → 1 → 4
    @test collect(l) == [5, 3, 2, 1, 4]
    # Reverse
    @test collect(Iterators.reverse(l)) == [4, 1, 2, 3, 5]
end

# ============================================================
#  push_front doctest (Rust lines 237-247)
# ============================================================
@testset "pushfirst!: sequential indices, new element becomes front" begin
    l = MutableVecLinkedList{Int}()
    @test pushfirst!(l, 2) == 1
    @test first(l) == 2

    @test pushfirst!(l, 1) == 2
    @test first(l) == 1
end

# ============================================================
#  push_back doctest (Rust lines 269-277)
# ============================================================
@testset "push!: sequential indices, new element becomes back" begin
    l = MutableVecLinkedList{Int}()
    @test push!(l, 1) == 1
    @test push!(l, 3) == 2
    @test last(l) == 3
end

# ============================================================
#  insert_after doctest (Rust lines 313-329)
# ============================================================
@testset "insert_after!: correct position and pop_front order" begin
    l = MutableVecLinkedList{Int}()
    _first  = push!(l, 1)
    second  = push!(l, 2)
    _third  = push!(l, 3)

    insert_after!(l, second, 100)

    @test popfirst!(l) == 1
    @test popfirst!(l) == 2
    @test popfirst!(l) == 100
    @test popfirst!(l) == 3
    @test_throws ArgumentError popfirst!(l)
end

# ============================================================
#  insert_before doctest (Rust lines 352-368)
# ============================================================
@testset "insert_before!: correct position and pop_front order" begin
    l = MutableVecLinkedList{Int}()
    _first  = push!(l, 1)
    second  = push!(l, 2)
    _third  = push!(l, 3)

    insert_before!(l, second, 100)

    @test popfirst!(l) == 1
    @test popfirst!(l) == 100
    @test popfirst!(l) == 2
    @test popfirst!(l) == 3
    @test_throws ArgumentError popfirst!(l)
end

# ============================================================
#  remove doctest (Rust lines 425-448)
#  Note: double-removal is not supported in this Julia implementation
#  (caller's responsibility); that branch of the Rust test is omitted.
# ============================================================
@testset "remove!: returns value, marks slot as nothing, updates length" begin
    l = MutableVecLinkedList{Int}()
    first  = pushfirst!(l, 1)   # idx 1
    second = push!(l, 2)        # idx 2
    third  = pushfirst!(l, 3)   # idx 3

    @test length(l) == 3

    @test remove!(l, second) == 2
    @test l[second] === nothing   # freed slot returns nothing
    @test length(l) == 2

    @test remove!(l, first) == 1
    @test length(l) == 1

    @test remove!(l, third) == 3
    @test length(l) == 0
    @test isempty(l)
end

# replace_front / replace_back are not implemented in this translation.

# ============================================================
#  pop_front doctest (Rust lines 601-609)
# ============================================================
@testset "popfirst!: throws on empty, removes and returns front" begin
    l = MutableVecLinkedList{Int}()
    @test_throws ArgumentError popfirst!(l)
    push!(l, 1)
    push!(l, 3)
    @test popfirst!(l) == 1
end

# ============================================================
#  pop_back doctest (Rust lines 639-647)
# ============================================================
@testset "pop!: throws on empty, removes and returns back" begin
    l = MutableVecLinkedList{Int}()
    @test_throws ArgumentError pop!(l)
    push!(l, 1)
    push!(l, 3)
    @test pop!(l) == 3
end

# ============================================================
#  Julia-specific tests
# ============================================================

@testset "slot reuse: freed slot is recycled by subsequent push" begin
    l = MutableVecLinkedList{Int}()
    i1 = push!(l, 10)   # 1
    i2 = push!(l, 20)   # 2
    i3 = push!(l, 30)   # 3

    remove!(l, i2)              # free slot 2
    @test l[i2] === nothing

    i4 = push!(l, 99)           # should reuse slot 2
    @test i4 == i2
    @test l[i4] == 99
    @test collect(l) == [10, 30, 99]
end

@testset "reverse iteration" begin
    l = MutableVecLinkedList{Int}()
    push!(l, 1); push!(l, 2); push!(l, 3)
    @test collect(Iterators.reverse(l)) == [3, 2, 1]
end

@testset "front_index / back_index" begin
    l = MutableVecLinkedList{Int}()
    @test front_index(l) === nothing
    @test back_index(l)  === nothing

    i1 = push!(l, 10)
    i2 = push!(l, 20)
    @test front_index(l) == i1
    @test back_index(l)  == i2
end

@testset "first / last throw on empty" begin
    l = MutableVecLinkedList{Int}()
    @test_throws ArgumentError first(l)
    @test_throws ArgumentError last(l)
end

@testset "setindex!: updates data in place, preserves list structure" begin
    l = MutableVecLinkedList{Int}()
    push!(l, 1); push!(l, 2); push!(l, 3)
    idx = front_index(l)
    l[idx] = 99
    @test first(l) == 99
    @test collect(l) == [99, 2, 3]
end

@testset "empty!: resets list, frees all storage" begin
    l = MutableVecLinkedList{Int}()
    push!(l, 1); push!(l, 2); push!(l, 3)
    empty!(l)
    @test isempty(l)
    @test length(l) == 0
    @test capacity(l) == 0
    @test front_index(l) === nothing
end

@testset "capacity: tracks allocated slots (live + freed)" begin
    l = MutableVecLinkedList{Int}()
    push!(l, 1); push!(l, 2); push!(l, 3)
    @test capacity(l) == 3

    i2 = front_index(l)
    popfirst!(l)
    @test capacity(l) == 3   # freed slot still counted
    @test length(l) == 2

    push!(l, 99)             # recycles freed slot
    @test capacity(l) == 3   # no new slot allocated
end

@testset "with_capacity: pre-reserves vector memory" begin
    l = with_capacity(Int, 10)
    @test isempty(l)
    @test capacity(l) == 0   # no slots allocated yet (sizehint!, not pre-filled)
    for i in 1:10
        push!(l, i)
    end
    @test length(l) == 10
    @test collect(l) == collect(1:10)
end

@testset "equality: same contents, different order => not equal" begin
    l1 = MutableVecLinkedList{Int}(1, 2, 3)
    l2 = MutableVecLinkedList{Int}(1, 2, 3)
    l3 = MutableVecLinkedList{Int}(3, 2, 1)
    @test l1 == l2
    @test l1 != l3

    # Different element types are never equal
    la = MutableVecLinkedList{Int}()
    lb = MutableVecLinkedList{Float64}()
    @test la != lb
end

@testset "variadic constructor" begin
    l = MutableVecLinkedList{Int}(10, 20, 30)
    @test length(l) == 3
    @test collect(l) == [10, 20, 30]
end

@testset "isbitstype: nodes stored inline for bits-type T" begin
    l = MutableVecLinkedList{SpinCutTest}()
    push!(l, SpinCutTest(0.5, 1, false))
    push!(l, SpinCutTest(1.5, -1, true))

    @test Base.isbitstype(eltype(l.elements))  # LinkedListNode{SpinCutTest} is isbitstype
    @test length(l) == 2
    @test first(l) == SpinCutTest(0.5, 1, false)
    @test last(l)  == SpinCutTest(1.5, -1, true)
end

@testset "insert_after! and insert_before! at head and tail" begin
    l = MutableVecLinkedList{Int}()
    ih = push!(l, 10)

    # Insert before the head = new head
    insert_before!(l, ih, 5)
    @test first(l) == 5
    @test collect(l) == [5, 10]

    # Insert after the tail = new tail
    it = back_index(l)
    insert_after!(l, it, 20)
    @test last(l) == 20
    @test collect(l) == [5, 10, 20]
end

@testset "getindex returns nothing for all freed slots" begin
    l = MutableVecLinkedList{Int}()
    indices = [push!(l, i) for i in 1:5]

    # Remove alternating elements
    remove!(l, indices[2])
    remove!(l, indices[4])

    @test l[indices[1]] == 1
    @test l[indices[2]] === nothing
    @test l[indices[3]] == 3
    @test l[indices[4]] === nothing
    @test l[indices[5]] == 5
    @test collect(l) == [1, 3, 5]
end

@testset "indexed: yields (slot_index, value) pairs" begin
    l = MutableVecLinkedList{Int}(10, 20, 30)
    pairs = collect(indexed(l))
    @test length(pairs) == 3
    @test all(p -> p[2] == l[p[1]], pairs)   # slot index is valid
    @test [p[2] for p in pairs] == [10, 20, 30]
end

@testset "reverse(indexed): reverse (slot_index, value) pairs" begin
    l = MutableVecLinkedList{Int}(10, 20, 30)
    pairs = collect(reverse(indexed(l)))
    @test [p[2] for p in pairs] == [30, 20, 10]
    @test all(p -> p[2] == l[p[1]], pairs)
end

@testset "in: membership test" begin
    l = MutableVecLinkedList{Int}(1, 2, 3)
    @test 2 in l
    @test !(4 in l)
end

@testset "findfirst: search by predicate and value" begin
    l = MutableVecLinkedList{Int}(10, 20, 30)
    idx = findfirst(x -> x == 20, l)
    @test idx !== nothing
    @test l[idx] == 20
    @test findfirst(x -> x > 100, l) === nothing
    @test findfirst(10, l) == findfirst(x -> x == 10, l)
end

@testset "append! and prepend!" begin
    a = MutableVecLinkedList{Int}(1, 2)
    b = MutableVecLinkedList{Int}(3, 4)
    append!(a, b)
    @test collect(a) == [1, 2, 3, 4]

    c = MutableVecLinkedList{Int}(3, 4)
    d = MutableVecLinkedList{Int}(1, 2)
    prepend!(c, d)
    @test collect(c) == [1, 2, 3, 4]
end

@testset "delete! alias for remove!" begin
    l = MutableVecLinkedList{Int}(1, 2, 3)
    idx = front_index(l)
    ret = delete!(l, idx)
    @test ret === l
    @test collect(l) == [2, 3]
end
