module Capsule

export make

struct Instance{T}
    name::Symbol
    value::T
end

function make(
    instance_name::Symbol, 
    target::Module, 
    instances::Vector{Instance{T}} where T, 
    privates::Vector{T} where T <: Function = Vector{Function}()
)
    module_block = quote
        # target_symbol = Symbol($target)
        # quote 
        #     using $target_symbol
        # end |> eval

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
