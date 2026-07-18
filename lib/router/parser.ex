defmodule Router.Parser do
  @moduledoc false

  @type filter :: :int | :hex | {:hex, pos_integer()}
  @type var_token :: %{name: String.t(), filter: filter() | nil}
  @type token :: {:text, String.t()} | {:var, var_token()}

  @spec parse(String.t()) :: [token()]
  def parse(path), do: do_parse(path, [])

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

  defp parse_var(raw) do
    case String.split(raw, ":", parts: 2) do
      [name] ->
        name = String.trim(name)

        if name == "", do: raise("invalid variable")
        %{name: name, filter: nil}

      [name, filter] ->
        name = String.trim(name)
        filter = String.trim(filter)

        if name == "" or filter == "", do: raise("invalid variable")
        %{name: name, filter: parse_filter(filter)}
    end
  end

  defp parse_filter("int"), do: :int
  defp parse_filter("hex"), do: :hex

  defp parse_filter(<<"hex(", rest::binary>>) do
    case Integer.parse(rest) do
      {length, ")"} when length > 0 -> {:hex, length}
      _ -> raise "invalid filter"
    end
  end

  defp parse_filter(_filter), do: raise("unknown filter")
end
