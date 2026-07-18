# Router

A minimal path router with `{variable}` placeholders, backed by a trie for
fast matching.

```elixir
router =
  Router.new()
  |> Router.route("users/{id}", :show_user)
  |> Router.route("users/{id:int}/posts", :user_posts)

Router.match(router, "users/42")
#=> {:ok, %{"id" => "42"}, :show_user}

Router.match(router, "users/42/posts")
#=> {:ok, %{"id" => 42}, :user_posts}

Router.match(router, "users/abc/posts")
#=> {:error, :no_match}
```

Variables can optionally declare filters with `{name:filter}`. Supported
filters are validated when the route is parsed and normalized to atoms
internally. The built-in `int` filter only matches segments that parse as
integers, and successful matches are returned as integers.
The `hex` filter matches non-empty segments containing only `0-9`, `a-f`, or
`A-F`, and successful matches are returned as strings.

## Tip

Consider building your router as a module attribute (`@router = ...`) when you know the paths upfront, rather than in a function.
This will build it once at compile time instead of rebuilding it on every call.

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
