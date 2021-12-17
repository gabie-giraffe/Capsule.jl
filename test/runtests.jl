push!(LOAD_PATH, @__DIR__)
using Capsule, Test, TestModule

TestModule.@testmodule myTest "valueA" "valueB"

@testset "Instance registration" begin
    @test myTest.ts.fieldA == "valueA"
    @test myTest.ts.fieldB == "valueB"
end
instance = myTest.ts

@testset "function and arguments" begin
    @test myTest.noArg() == :noArg
    @test myTest.customArgumentsAreSupported("hello", "world") == (:a => "hello", :b => "world")
    @test myTest.keywordArgumentsAreSupported(; a = "hello", b = "world") == (:a => "hello", :b => "world")
    @test myTest.keywordArgumentsAreSupported("hello", "world"; c = "mundo", d = "monde") == (:a => "hello", :b => "world", :c => "mundo", :d => "monde")
end

@testset "instance auto-wireing" begin
    @test myTest.instanceArgIsAutowired() == (:ts => instance)
    @test myTest.instanceArgIsAutowired("hello", "world") == (:ts => instance, :a => "hello", :b => "world")
    @test myTest.instanceArgIsAutowired("hello"; b = "world") == (:ts => instance, :a => "hello", :b => "world")
    # @test myTest.instanceArgIsAutowired("hello") == (:ts => instance, :a => "hello")
end

@testset "scoping" begin
    @test :privateMethodIsNotAvailable ∉ names(myTest; all=true)
end
