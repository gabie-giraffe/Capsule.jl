module Capsule

export make

"""
    Instance(name, value)

Declares a value auto-wireing for the functions of the encapsulated module.
"""
struct Instance{T}
    name::Symbol
    value::T
end

"""
    make(instance_name, target, instances, [privates])

For use inside of `macro`, generate an instance module named `instance_name` with proxies for all 
functions defined within a `target` module. Functions that defines arguments that match the `instances` 
provided are auto-wired and removed from the arguments in the instance module.

Optionally, a list of `privates` functions from the `target` module can be specified. These functions
will not have proxy generated for them. They will effectively be unaccessible from the instance module.

# Examples
```julia
module MyApi
macro make(instance_name::Symbol, baseurl::String)
    Capsule.make(
        instance_name, 
        MyApi, 
        [Capsule.Instance(:ctx, ApiContext(baseurl))],
        [MyApi.my_util_fn]
    )
end
end
...

MyApi.@make ma "https://my.service.io"
ma.get_resource(7)
```
"""
function make(
    instance_name::Symbol, 
    target::Module, 
    instances::Vector{Instance{T}} where T, 
    privates::Vector{T} where T <: Function = Vector{Function}()
)
    module_block = quote
        target_name = nameof($target) |> Symbol
        quote
            using $target_name
        end |> eval

        # Setup instance parameters.
        for i ∈ $instances
            quote
                $(i.name) = $(i.value)
            end |> eval
        end

        $import_methods($target, $instances, $privates) |> eval
    end

    return Expr(:toplevel, Expr(:module, true, esc(instance_name), esc(module_block)))
end

function import_methods(
    target::Module, 
    instances::Vector{Instance{T}} where T, 
    privates::Vector{T} where T <: Function = []
)
    instance_filter = instances .|> pw -> (string(pw.name), string(typeof(pw.value)))

    quote 
        target = $target

        for symbol ∈ names(target; all=true)
            if match(r"^[a-z]\w+$", string(symbol)) !== nothing
                for method ∈ eval(Meta.parse("$target.$symbol")) |> methods
                    decl_parts = Base.arg_decl_parts(method)[2]
                    m_name = Symbol(decl_parts[1][2])

                    # We do not import these methods.
                    if m_name ∈ [:eval, :include] ∪ nameof.($privates)
                        continue
                    end

                    # Regular arguments assignment.
                    m_args = decl_parts[2:end] |> 
                        argdef_list -> filter(arg -> arg ∉ $instance_filter, argdef_list) .|> 
                        argdef -> argdef[2] === "" ? Symbol(argdef[1]) : Meta.parse("$(argdef[1])::$(argdef[2])")
                    m_args_fwd = decl_parts[2:end] .|> p -> Symbol(p[1])

                    # Key-word argument assignment.
                    m_has_kwargs = length(Base.kwarg_decl(method)) > 0
                    m_kwargs = Base.kwarg_decl(method)
                    m_kwargs_fwd = Base.kwarg_decl(method) .|> kw -> Meta.parse("$kw = $kw")

                    # Generating the signature.
                    signature = m_has_kwargs ? quote # With kwargs
                        $m_name($(m_args...); $(m_kwargs...)) = $target.$m_name($(m_args_fwd...); $(m_kwargs_fwd...))
                    end : quote  # Without kwargs
                        $m_name($(m_args...)) = $target.$m_name($(m_args_fwd...))
                    end

                    # Add it to the module.
                    eval(signature)
                end
            end
        end
    end
end

end
