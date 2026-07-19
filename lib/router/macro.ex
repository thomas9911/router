defmodule Router.Macro do
  @moduledoc """
  Generate a module similar to Plug.Router that has a function name to handle the dispatching to functions.

  For example:

  ```elixir
  iex> defmodule Implementation do
  ...>  use Router.Macro, macro_name: :patch, match_name: :execute, no_match: {:error, :no_match}
  ...>
  ...>   patch :replace, "users/{id}" do
  ...>     "user \#{id}"
  ...>   end
  ...>
  ...>   patch :add, "users" do
  ...>     "users \#{inspect(context)}"
  ...>   end
  ...>
  ...>   patch :add, "posts" do
  ...>     "posts \#{inspect(context)}"
  ...>   end
  ...> end
  iex> Implementation.execute({:replace, "users/1234"}, %{"name" => "testing"})
  "user 1234"
  iex> Implementation.execute({:add, "users"}, %{"name" => "testing"})
  ~s|users %{"name" => "testing"}|
  iex> Implementation.execute({:add, "posts"}, %{"name" => "testing"})
  ~s|posts %{"name" => "testing"}|
  iex> Implementation.execute({:remove, "users"}, %{"name" => "testing"})
  {:error, :no_match}
  ```

  """

  @doc false
  defmacro __using__(args) do
    macro_name = Access.get(args, :macro_name, :route)
    match_name = Access.get(args, :match_name, :match)
    no_match = Access.get(args, :no_match, nil)
    macro_module = create_macro_module(macro_name, __CALLER__)

    quote do
      import unquote(macro_module), only: [{unquote(macro_name), 3}]

      @router_match_name unquote(match_name)
      @router_no_match unquote(no_match)
      @current_router Router.new()

      @before_compile Router.Macro
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    match_name = Module.get_attribute(env.module, :router_match_name) || :match
    no_match = Module.get_attribute(env.module, :router_no_match)

    quote do
      def unquote(match_name)(path, context \\ %{}) do
        case Router.match(@current_router, path) do
          {:ok, args, func} -> apply(__MODULE__, func, [args, context])
          _ -> unquote(no_match)
        end
      end
    end
  end

  @doc false
  def expand_route(tag, route, block) do
    function_name = String.to_atom("#{tag}:#{route}")
    variables = route |> Router.Parser.parse() |> variable_names()
    bindings = Enum.map(variables, &variable_binding/1)
    context_variable = Macro.var(:context, nil)
    context_binding = quote do: _ = unquote(context_variable)

    quote do
      def unquote(function_name)(args, unquote(context_variable)) do
        unquote(context_binding)
        unquote_splicing(bindings)

        unquote(block)
      end

      Module.put_attribute(
        __MODULE__,
        :current_router,
        Router.route(@current_router, {unquote(tag), unquote(route)}, unquote(function_name))
      )
    end
  end

  defp create_macro_module(macro_name, caller) do
    module =
      Module.concat(
        Router.Macro.Generated,
        "#{macro_name}_#{:erlang.unique_integer([:positive])}"
      )

    body =
      quote do
        defmacro unquote(macro_name)(tag, route, do: block) do
          Router.Macro.expand_route(tag, route, block)
        end
      end

    {:module, ^module, _binary, _term} = Module.create(module, body, caller)
    module
  end

  defp variable_names(tokens) do
    tokens
    |> Enum.flat_map(fn
      {:var, %{name: name}} -> [name]
      _ -> []
    end)
    |> Enum.uniq()
  end

  defp variable_binding(name) do
    variable = Macro.var(String.to_atom(name), nil)

    quote do
      unquote(variable) = Map.get(args, unquote(name))
    end
  end
end
