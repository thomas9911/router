defmodule Router do
  @moduledoc """
  A minimal path router with `{variable}` placeholders, backed by a trie.

  Register routes with `route/3` using a path template such as
  `"users/{id}/posts/{post_id}"`, then look up an incoming path with
  `match/2` to get back the captured variables and the value that was
  routed to.

  ```elixir
      iex> router = Router.new() |> Router.route("users/{id}", :show_user)
      iex> Router.match(router, "users/42")
      {:ok, %{"id" => "42"}, :show_user}
  ```

  ```elixir
      iex> router = Router.new() |> Router.route("users/{id:int}", :show_user)
      iex> Router.match(router, "users/42")
      {:ok, %{"id" => 42}, :show_user}
  ```

  ```elixir
      iex> router = Router.new()
      ...>          |> Router.route("users/{id}", fn arguments -> "fetch user with " <> inspect(arguments) end)
      ...>          |> Router.route("posts/{id}", fn arguments -> "fetch post with " <> inspect(arguments) end)
      iex> {:ok, data, func} = Router.match(router, "users/42")
      iex> func.(data)
      ~s|fetch user with %{"id" => "42"}|
  ```

  Routes are matched via a trie built from the registered templates'
  shared prefixes, rather than by retrying every template from scratch.
  At any point where a template continues with literal text and another
  continues with a `{variable}`, the literal (static) branch is always
  tried first, regardless of which route was registered first. Only
  between two equally dynamic overlapping routes (e.g. the same template
  registered twice) does registration order act as the tie-break: the
  one registered first wins.

  Variables may also declare a filter via `{name:filter}`. Supported
  filters are normalized to atoms internally. The built-in `int` filter
  only matches segments that parse as integers and returns them as
  integers in the match result.
  """

  defstruct root: %{literal: %{}, vars: [], accept: :none}

  @type filter :: :int
  @type var_token :: %{name: String.t(), filter: filter() | nil}
  @type token :: {:text, String.t()} | {:var, var_token()}
  @type capture_value :: String.t() | integer()
  @type trie_node :: %{
          literal: %{String.t() => trie_node()},
          vars: [
            %{
              name: String.t(),
              filter: filter() | nil,
              boundary: String.t() | nil,
              node: trie_node()
            }
          ],
          accept: :none | {:value, any()}
        }
  @type t :: %__MODULE__{root: trie_node()}

  @doc "Builds an empty router."
  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @doc """
  Registers `value` under `path`, a template that may contain
  `{variable_name}` placeholders, with optional `{variable_name:filter}`
  filters.
  """
  @spec route(t(), String.t(), any()) :: t()
  def route(%__MODULE__{root: root} = router, path, value) do
    %{router | root: insert(root, parse(path), value)}
  end

  @doc """
  Tokenizes a path template into `{:text, _}` and `{:var, _}` parts.

  Raises if braces are unbalanced, a variable is malformed, an unknown
  filter is used, or two variables appear with nothing between them
  (e.g. `"{a}{b}"`).
  """
  @spec parse(String.t()) :: [token()]
  def parse(path) do
    do_parse(path, [])
  end

  @doc """
  Matches `path` against the registered routes and returns the first hit.
  """
  @spec match(t(), String.t()) ::
          {:ok, %{String.t() => capture_value()}, any()} | {:error, :no_match}
  def match(%__MODULE__{root: root}, path) do
    case match_node(root, String.graphemes(path)) do
      {:ok, vars, value} -> {:ok, vars, value}
      :no_match -> {:error, :no_match}
    end
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
      char == ?} -> do_parse(rest, [{:text, ""}, {:var, parse_var(name)} | acc])
      true -> do_parse(rest, [{:var, <<name::bytes, char>>} | acc])
    end
  end

  defp empty_node, do: %{literal: %{}, vars: [], accept: :none}

  defp insert(node, [], value) do
    case node.accept do
      :none -> %{node | accept: {:value, value}}
      _ -> node
    end
  end

  defp insert(node, [{:text, text} | rest], value) do
    insert_chars(node, String.graphemes(text), rest, value)
  end

  defp insert(_node, [{:var, _var}, {:text, ""} | _rest], _value) do
    raise "invalid template, variables cannot be after each other"
  end

  defp insert(node, [{:var, %{name: name, filter: filter}}, {:text, next} | rest], value) do
    boundary = String.first(next)
    target = insert(empty_node(), [{:text, next} | rest], value)
    %{node | vars: node.vars ++ [%{name: name, filter: filter, boundary: boundary, node: target}]}
  end

  defp insert(node, [{:var, %{name: name, filter: filter}}], value) do
    target = insert(empty_node(), [], value)
    %{node | vars: node.vars ++ [%{name: name, filter: filter, boundary: nil, node: target}]}
  end

  defp insert_chars(node, [], remaining_tokens, value), do: insert(node, remaining_tokens, value)

  defp insert_chars(node, [char | chars], remaining_tokens, value) do
    child = Map.get(node.literal, char, empty_node())
    updated_child = insert_chars(child, chars, remaining_tokens, value)
    %{node | literal: Map.put(node.literal, char, updated_child)}
  end

  defp match_node(node, []) do
    case node.accept do
      {:value, value} -> {:ok, %{}, value}
      :none -> match_var_edges(node.vars, [])
    end
  end

  defp match_node(node, [char | rest] = chars) do
    case Map.fetch(node.literal, char) do
      {:ok, child} ->
        case match_node(child, rest) do
          {:ok, _vars, _value} = success -> success
          :no_match -> match_var_edges(node.vars, chars)
        end

      :error ->
        match_var_edges(node.vars, chars)
    end
  end

  defp match_var_edges([], _chars), do: :no_match

  defp match_var_edges(
         [%{name: name, filter: filter, boundary: boundary, node: target} | rest_edges],
         chars
       ) do
    case consume_var(chars, boundary) do
      {:ok, captured, remaining} ->
        case cast_capture(captured, filter) do
          {:ok, cast_value} ->
            case match_node(target, remaining) do
              {:ok, vars, value} ->
                vars = if captured == "", do: vars, else: Map.put(vars, name, cast_value)
                {:ok, vars, value}

              :no_match ->
                match_var_edges(rest_edges, chars)
            end

          :no_match ->
            match_var_edges(rest_edges, chars)
        end

      :no_match ->
        match_var_edges(rest_edges, chars)
    end
  end

  defp consume_var(chars, nil), do: {:ok, Enum.join(chars), []}
  defp consume_var(chars, boundary), do: consume_var(chars, boundary, [])

  defp consume_var([], _boundary, _acc), do: :no_match

  defp consume_var([char | rest], boundary, acc) when char == boundary do
    {:ok, acc |> Enum.reverse() |> Enum.join(), [char | rest]}
  end

  defp consume_var([char | rest], boundary, acc), do: consume_var(rest, boundary, [char | acc])

  defp parse_var(raw) do
    case String.split(raw, ":", parts: 2) do
      [name] when name != "" ->
        %{name: name, filter: nil}

      [name, filter] when name != "" and filter != "" ->
        %{name: name, filter: parse_filter(filter)}

      _ ->
        raise "invalid variable"
    end
  end

  defp parse_filter("int"), do: :int
  defp parse_filter(_filter), do: raise("unknown filter")

  defp cast_capture(captured, nil), do: {:ok, captured}

  defp cast_capture(captured, :int) do
    case Integer.parse(captured) do
      {value, ""} -> {:ok, value}
      _ -> :no_match
    end
  end
end
