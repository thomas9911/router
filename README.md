# Router

A minimal path router with `{variable}` placeholders, backed by a trie for
fast matching.

```elixir
router =
  Router.new()
  |> Router.route("users/{id}", :show_user)

Router.match(router, "users/42")
#=> {:ok, %{"id" => "42"}, :show_user}

Router.match(router, "nope")
#=> {:error, :no_match}
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `router` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:router, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/router>.
