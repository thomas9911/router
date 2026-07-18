defmodule Router.Macro do
  @moduledoc false

  @doc false
  defmacro __using__(args) do
    macro_name = Access.get(args, :macro_name, :route)
    macro_module = create_macro_module(macro_name, __CALLER__)

    quote do
      import unquote(macro_module), only: [{unquote(macro_name), 3}]

      @current_router Router.new()

      @before_compile Router.Macro
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def match(path) do
        case Router.match(@current_router, path) do
          {:ok, args, func} -> apply(__MODULE__, func, [args])
          _ -> nil
        end
      end
    end
  end

  @doc false
  def expand_route(tag, route, block) do
    function_name = String.to_atom("#{tag}_#{route}")
    variables = route |> Router.Parser.parse() |> variable_names()
    bindings = Enum.map(variables, &variable_binding/1)

    quote do
      def unquote(function_name)(args) do
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
