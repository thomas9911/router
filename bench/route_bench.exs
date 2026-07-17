defmodule RouteBench do
  @iterations 5_000
  @sizes [10, 100, 500, 1_000, 2_000, 4_000]

  def run do
    IO.puts("iterations per measurement: #{@iterations}\n")

    header =
      [
        String.pad_trailing("routes", 8),
        String.pad_trailing("match last-registered (µs/call)", 34),
        String.pad_trailing("match first-registered (µs/call)", 34),
        "no match at all (µs/call)"
      ]
      |> Enum.join("")

    IO.puts(header)
    IO.puts(String.duplicate("-", String.length(header)))

    Enum.each(@sizes, &bench_size/1)
  end

  defp bench_size(n) do
    routes = for i <- 1..n, do: {"resource-#{i}/items/{id}", i}

    router =
      Enum.reduce(routes, Router.new(), fn {path, value}, acc ->
        Router.route(acc, path, value)
      end)

    {first_path, _} = List.first(routes)
    {last_path, _} = List.last(routes)

    hit_last = String.replace(last_path, "{id}", "42")
    hit_first = String.replace(first_path, "{id}", "42")
    miss = "no-such-resource/items/42"

    last_us = time_per_call(fn -> Router.match(router, hit_last) end)
    first_us = time_per_call(fn -> Router.match(router, hit_first) end)
    miss_us = time_per_call(fn -> Router.match(router, miss) end)

    IO.puts(
      String.pad_trailing(Integer.to_string(n), 8) <>
        String.pad_trailing(:erlang.float_to_binary(last_us, decimals: 3), 34) <>
        String.pad_trailing(:erlang.float_to_binary(first_us, decimals: 3), 34) <>
        :erlang.float_to_binary(miss_us, decimals: 3)
    )
  end

  defp time_per_call(fun) do
    {time, _} =
      :timer.tc(fn ->
        for _ <- 1..@iterations, do: fun.()
      end)

    time / @iterations
  end
end

RouteBench.run()
