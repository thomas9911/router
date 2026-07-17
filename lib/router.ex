defmodule Router do
  defstruct data: %{}, templates: [], ptemplates: []

  def new(), do: %__MODULE__{}

  def route(
        %__MODULE__{data: data, templates: templates, ptemplates: ptemplates} = router,
        path,
        value
      ) do
    template = parse(path)
    ptemplate = process_template(template, [])

    %{
      router
      | templates: [template | templates],
        ptemplates: [ptemplate | ptemplates],
        data: Map.put(data, ptemplate, value)
    }
  end

  def parse(path) do
    do_parse(path, [])
  end

  defp do_parse("", [{:text, ""} | rest]) do
    rest |> Enum.reverse()
  end

  defp do_parse("", acc) do
    acc |> Enum.reverse()
  end

  defp do_parse(<<f, rest::bytes>>, []) do
    cond do
      f == ?{ -> do_parse(rest, [{:var, ""}])
      f == ?} -> raise "invalid end"
      true -> do_parse(rest, [{:text, <<f>>}])
    end
  end

  defp do_parse(<<f, rest::bytes>>, [{:text, first} | xd]) do
    cond do
      f == ?{ -> do_parse(rest, [{:var, ""}, {:text, <<first::bytes>>} | xd])
      f == ?} -> raise "invalid end"
      true -> do_parse(rest, [{:text, <<first::bytes, f>>} | xd])
    end
  end

  defp do_parse(<<f, rest::bytes>>, [{:var, first} | xd]) do
    cond do
      f == ?{ -> raise "invalid start"
      f == ?} -> do_parse(rest, [{:text, ""}, {:var, <<first::bytes>>} | xd])
      true -> do_parse(rest, [{:var, <<first::bytes, f>>} | xd])
    end
  end

  def match(%__MODULE__{data: data, ptemplates: ptemplates}, path) do
    parsed = String.graphemes(path)

    ptemplates
    |> Enum.reduce_while({:error, :no_match}, fn template, _ ->
      parsed
      |> Enum.reduce_while(%{template: template, vars: %{}}, fn x,
                                                                %{
                                                                  template: [y | rest],
                                                                  vars: vars
                                                                } ->
        case y do
          {_, ^x} ->
            {:cont, %{template: Enum.drop(rest, 1), vars: vars}}

          {var_name, _} ->
            data = Map.get(vars, var_name, "")

            {:cont,
             %{template: [y | rest], vars: Map.put(vars, var_name, <<data::bytes, x::bytes>>)}}

          ^x ->
            {:cont, %{template: rest, vars: vars}}

          _ ->
            {:halt, :no_match}
        end
      end)
      |> case do
        :no_match -> {:cont, {:error, :no_match}}
        %{vars: vars} -> {:halt, {:ok, vars, Map.get(data, template)}}
      end
    end)
  end

  def process_template([], acc) do
    Enum.reverse(acc)
  end

  def process_template([{:text, start} | rest], acc) do
    chars = String.graphemes(start) |> Enum.reverse()
    process_template(rest, chars ++ acc)
  end

  def process_template([{:var, var}, {:text, next} | rest], acc) do
    if next == "" do
      raise "invalid template, variables cannot be after each other"
    end

    <<first, _::bytes>> = next

    process_template([{:text, next} | rest], [{var, <<first>>} | acc])
  end

  def process_template([{:var, var}], acc) do
    process_template([], [{var, ""} | acc])
  end
end
