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


Routes can also be tagged and matched with the same tag:

```elixir
router =
  Router.new()
  |> Router.route({:get, "users/{id:int}"}, :get_user)
  |> Router.route({:get, "users"}, :list_users)
  |> Router.route({:post, "users"}, :create_user)

Router.match(router, {:get, "users/42"})
#=> {:ok, %{"id" => 42}, :get_user}
```

Variables can optionally declare filters with `{name:filter}`. Supported
filters are validated when the route is parsed and normalized to atoms
internally. The built-in `int` filter only matches segments that parse as
integers, and successful matches are returned as integers.
The `hex` filter matches non-empty segments containing only `0-9`, `a-f`, or
`A-F`, and successful matches are returned as strings.
A fixed length can be specified, for example `{token:hex(8)}`.

## DSL

`Router.Macro` builds the router for you via `use`, letting you define tagged
routes as functions instead of building the router by hand:

```elixir
defmodule MyRouter do
  use Router.Macro, macro_name: :get, match_name: :call, no_match: {:error, :not_found}

  get :show_user, "users/{id:int}" do
    "user #{id}"
  end
end

MyRouter.call({:show_user, "users/42"})
#=> "user 42"
```

Route captures are bound as variables in the block, and an optional
`context` argument (default `%{}`) is available too. See `Router.Macro` for
details.

## Tip

Consider building your router as a module attribute (`@router = ...`) when you know the paths upfront, rather than in a function.
This will build it once at compile time instead of rebuilding it on every call. Or use the `Router.Macro` DSL this will do it for you.

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
