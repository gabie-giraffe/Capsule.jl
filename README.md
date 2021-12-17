# Capsule.jl

Capsule.jl allows one to create macros that 'encapsulate' functions defined within a module along with a given state in a new module behaves similarly to a class instance in Object-Oriented Programing. This can be used to create shorthands in scenarios where a set of functions are made to operate from one or more `struct` that acts as configuration or state holder.

An example of that is building an API client, where a struct is used to keep the base url to the API service as well as other information like the authentication header.

**Module and macro definition**
```julia
module MyApi

using HTTP, JSON
using Capsule

mutable struct ApiContext
    baseurl::String
    auth_token::String

    function ApiContext(baseurl::String)
        ctx = new()
        ctx.baseurl = baseurl
        return ctx
    end
end

function authenticate(ctx::ApiContext; username::String, password::String)
    # ...
end

function get_resoure(ctx::ApiContext, id::String)
    # ...
end

macro make(instance_name::Symbol, baseurl::String)
    Capsule.make(
        instance_name, 
        MyApi, 
        [Capsule.Instance(:ctx, ApiContext(baseurl))]
    )
end

end
```

**Usage**
```julia
using MyApi

MyApi.@make ma "https://my.service.io"

ma.authenticate(; username="giraffe", password="super-secret")
ma.get_resoure(7)
```

## Defining the macro
At the very lease, the instantiation macro needs to call the `Capsule.make` function and provide it with the name of the instance module and the target module that contains the function declarations. In most cases (to provide an object-like behaviour), you will also provide a `Capsule.Instance` that will carry the state of your instance.

Usually, the macro that you declare will take a `Symbol` as parameter that will allow the consumer to choose the name of the instance module. Assitional parameters are often used to help creating the state that is injected in the instance module.

**Example**
```julia
macro make(instance_name::Symbol, baseurl::String)
    Capsule.make(
        instance_name, 
        MyApi, 
        [Capsule.Instance(:ctx, ApiContext(baseurl))]
    )
end
```

`Capsule.Instance` defines the instance and the name of the target argument to substitute in the functions of `MyApi`. In the example above, an `ApiContext` is mapped to the symbol `:ctx`. This will cause `Capsule.make` to auto-wire arguments that match the signature `ctx::ApiContext` in all functions that are declared in the module `MyApi`. The functions generated in the instance module will be callable without needing to specify that argument. The target argument `ctx` can hold any position in the functions, as long as it matches that name and the type. One caveat is that `ctx` cannot be passed as a keyword argument.

In many cases a single `Capsule.Instance` suffice, but it is possible to specify multiple mappings.

## Scope management
Sometimes, a module contains utility functions that do not need to be exposed in the encapsulation. Keeping these functions hidden is a good strategy to manage the complexity of your modules and avoid muddying your interface/contract. This can be acheived in `Capsule` by providing a list of "private" functions. This essentially informs `Capsule` to skip any functions matching those names.

**Example**
```julia
macro make(instance_name::Symbol, baseurl::String)
    Capsule.make(
        instance_name, 
        MyApi, 
        [Capsule.Instance(:ctx, ApiContext(baseurl))],
        [MyApi.my_util_fn]
    )
end
```