module TestModule

using Capsule

struct TestStuct
    fieldA::String
    fieldB::String
end

function noArg()
    return :noArg
end

customArgumentsAreSupported(a::String, b::String) = (:a => a, :b => b)
keywordArgumentsAreSupported(;a::String, b::String) = (:a => a, :b => b)
keywordArgumentsAreSupported(a::String, b::String; c::String, d::String) = (:a => a, :b => b, :c => c, :d => d)

instanceArgIsAutowired(ts::TestStuct) = (:ts => ts)

instanceArgIsAutowired(ts::TestStuct, a::String, b::String) = (
    :ts => ts,
    :a => a,
    :b => b
)

instanceArgIsAutowired(ts::TestStuct, a::String; b::String) = (
    :ts => ts,
    :a => a,
    :b => b
)

privateMethodIsNotAvailable() = :NotAvailable

macro testmodule(instance_name::Symbol, fieldA::String, fieldB::String)
    Capsule.make(
        instance_name, 
        TestModule,
        [Capsule.Instance(:ts, TestStuct(fieldA, fieldB))],
        [privateMethodIsNotAvailable]
    )
end
    
end
