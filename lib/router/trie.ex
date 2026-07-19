defmodule Router.Trie do
  @moduledoc false

  @spec new() :: Router.trie_node()
  def new, do: empty_node()

  @spec insert(Router.trie_node(), [Router.token()], Router.capture_value()) :: Router.trie_node()
  def insert(node, [], value) do
    case node.accept do
      :none -> %{node | accept: {:value, value}}
      _ -> node
    end
  end

  def insert(node, [{:text, text} | rest], value) do
    insert_chars(node, String.graphemes(text), rest, value)
  end

  def insert(_node, [{:var, _var}, {:text, ""} | _rest], _value) do
    raise "invalid route template: variables cannot be adjacent; add literal text between them"
  end

  def insert(node, [{:var, %{name: name, filter: filter}}, {:text, next} | rest], value) do
    boundary = String.first(next)
    target = insert(empty_node(), [{:text, next} | rest], value)
    %{node | vars: node.vars ++ [%{name: name, filter: filter, boundary: boundary, node: target}]}
  end

  def insert(node, [{:var, %{name: name, filter: filter}}], value) do
    target = insert(empty_node(), [], value)
    %{node | vars: node.vars ++ [%{name: name, filter: filter, boundary: nil, node: target}]}
  end

  @spec match(Router.trie_node(), [String.t()]) :: {:ok, map(), any()} | :no_match
  def match(node, chars), do: match_node(node, chars)

  defp empty_node, do: %{literal: %{}, vars: [], accept: :none}

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
    with {:ok, captured, remaining} <- consume_var(chars, boundary),
         {:ok, cast_value} <- cast_capture(captured, filter),
         {:ok, vars, value} <- match_node(target, remaining) do
      {:ok, put_capture(vars, name, captured, cast_value), value}
    else
      _ -> match_var_edges(rest_edges, chars)
    end
  end

  defp put_capture(vars, _name, "", _value), do: vars
  defp put_capture(vars, name, _captured, value), do: Map.put(vars, name, value)

  defp consume_var(chars, nil), do: {:ok, Enum.join(chars), []}
  defp consume_var(chars, boundary), do: consume_var(chars, boundary, [])

  defp consume_var([], _boundary, _acc), do: :no_match

  defp consume_var([char | rest], boundary, acc) when char == boundary do
    {:ok, acc |> Enum.reverse() |> Enum.join(), [char | rest]}
  end

  defp consume_var([char | rest], boundary, acc), do: consume_var(rest, boundary, [char | acc])

  defp cast_capture(captured, nil), do: {:ok, captured}

  defp cast_capture(captured, :int) do
    case Integer.parse(captured) do
      {value, ""} -> {:ok, value}
      _ -> :no_match
    end
  end

  defp cast_capture(captured, :hex), do: cast_hex(captured, nil)
  defp cast_capture(captured, {:hex, length}), do: cast_hex(captured, length)

  defp cast_hex(<<_::utf8, _::binary>> = captured, length) do
    valid_length? = is_nil(length) or String.length(captured) == length
    valid_digits? = captured |> String.to_charlist() |> Enum.all?(&hex_digit?/1)

    if valid_length? and valid_digits? do
      {:ok, captured}
    else
      :no_match
    end
  end

  defp cast_hex(_captured, _length), do: :no_match

  defp hex_digit?(char) when char in ?0..?9, do: true
  defp hex_digit?(char) when char in ?a..?f, do: true
  defp hex_digit?(char) when char in ?A..?F, do: true
  defp hex_digit?(_char), do: false
end
