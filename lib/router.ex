defmodule Router do
  @moduledoc """
  A minimal path router with `{variable}` placeholders.

  Register routes with `route/3` using a path template such as
  `"users/{id}/posts/{post_id}"`, then look up an incoming path with
  `match/2` to get back the captured variables and the value that was
  routed to.

      iex> router = Router.new() |> Router.route("users/{id}", :show_user)
      iex> Router.match(router, "users/42")
      {:ok, %{"id" => "42"}, :show_user}

  If two registered templates overlap, `match/2` prefers the one most
  recently added via `route/3`.
  """

  defstruct data: %{}, compiled_templates: []

  @type token :: {:text, String.t()} | {:var, String.t()}
  @type compiled_template :: [String.t() | {String.t(), String.t()}]
  @type t :: %__MODULE__{
          data: %{optional(compiled_template()) => any()},
          compiled_templates: [compiled_template()]
        }

  @doc "Builds an empty router."
  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @doc """
  Registers `value` under `path`, a template that may contain
  `{variable_name}` placeholders.
  """
  @spec route(t(), String.t(), any()) :: t()
  def route(%__MODULE__{data: data, compiled_templates: compiled_templates} = router, path, value) do
    compiled = path |> parse() |> compile_template()

    %{
      router
      | compiled_templates: [compiled | compiled_templates],
        data: Map.put(data, compiled, value)
    }
  end

  @doc """
  Tokenizes a path template into `{:text, _}` and `{:var, _}` parts.

  Raises if braces are unbalanced or two variables appear with nothing
  between them (e.g. `"{a}{b}"`).
  """
  @spec parse(String.t()) :: [token()]
  def parse(path) do
    do_parse(path, [])
  end

  @doc """
  Matches `path` against every registered route, most-recently-registered
  first, and returns the first hit.
  """
  @spec match(t(), String.t()) :: {:ok, %{String.t() => String.t()}, any()} | {:error, :no_match}
  def match(%__MODULE__{data: data, compiled_templates: compiled_templates}, path) do
    chars = String.graphemes(path)

    compiled_templates
    |> Enum.reduce_while({:error, :no_match}, fn compiled, _ ->
      case match_template(compiled, chars) do
        {:ok, vars} -> {:halt, {:ok, vars, Map.get(data, compiled)}}
        :no_match -> {:cont, {:error, :no_match}}
      end
    end)
  end

  defp do_parse("", [{:text, ""} | rest]), do: Enum.reverse(rest)
  defp do_parse("", acc), do: Enum.reverse(acc)

  defp do_parse(<<char, rest::bytes>>, []) do
    cond do
      char == ?{ -> do_parse(rest, [{:var, ""}])
      char == ?} -> raise "invalid end"
      true -> do_parse(rest, [{:text, <<char>>}])
    end
  end

  defp do_parse(<<char, rest::bytes>>, [{:text, text} | acc]) do
    cond do
      char == ?{ -> do_parse(rest, [{:var, ""}, {:text, text} | acc])
      char == ?} -> raise "invalid end"
      true -> do_parse(rest, [{:text, <<text::bytes, char>>} | acc])
    end
  end

  defp do_parse(<<char, rest::bytes>>, [{:var, name} | acc]) do
    cond do
      char == ?{ -> raise "invalid start"
      char == ?} -> do_parse(rest, [{:text, ""}, {:var, name} | acc])
      true -> do_parse(rest, [{:var, <<name::bytes, char>>} | acc])
    end
  end

  # Flattens parsed tokens into the structure `match_template/2` walks
  # character by character: literal text becomes individual grapheme
  # strings, and each variable becomes a `{name, boundary_char}` marker,
  # where `boundary_char` is the first character of the literal text that
  # follows it (or "" when the variable is the last thing in the
  # template). That invariant is what lets `match_char/2` recognize the
  # end of a capture without look-ahead.
  @spec compile_template([token()]) :: compiled_template()
  defp compile_template(tokens), do: compile_template(tokens, [])

  defp compile_template([], acc), do: Enum.reverse(acc)

  defp compile_template([{:text, text} | rest], acc) do
    chars = text |> String.graphemes() |> Enum.reverse()
    compile_template(rest, chars ++ acc)
  end

  defp compile_template([{:var, name}, {:text, next} | rest], acc) do
    if next == "" do
      raise "invalid template, variables cannot be after each other"
    end

    <<boundary, _::bytes>> = next
    compile_template([{:text, next} | rest], [{name, <<boundary>>} | acc])
  end

  defp compile_template([{:var, name}], acc) do
    compile_template([], [{name, ""} | acc])
  end

  defp match_template(compiled, chars) do
    chars
    |> Enum.reduce_while(%{template: compiled, vars: %{}}, &match_char/2)
    |> case do
      %{template: [], vars: vars} -> {:ok, vars}
      # a trailing variable's boundary marker is left over on purpose: it
      # swallows the rest of the path, including zero characters.
      %{template: [{_var, ""}], vars: vars} -> {:ok, vars}
      _ -> :no_match
    end
  end

  # the path has more characters than the template does; no candidate
  # template can grow to accept them.
  defp match_char(_char, %{template: []}), do: {:halt, :no_match}

  defp match_char(char, %{template: [token | rest], vars: vars}) do
    case token do
      {_var, ^char} ->
        # `char` both closes the capture and is the literal character that
        # follows it in the template, so this step satisfies both and
        # drops that literal from `rest` too.
        {:cont, %{template: Enum.drop(rest, 1), vars: vars}}

      {var_name, _boundary} ->
        captured = Map.get(vars, var_name, "")
        {:cont, %{template: [token | rest], vars: Map.put(vars, var_name, captured <> char)}}

      ^char ->
        {:cont, %{template: rest, vars: vars}}

      _ ->
        {:halt, :no_match}
    end
  end
end
