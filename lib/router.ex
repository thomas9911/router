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

  Variables may declare filters via `{name:filter}`. Supported filters are
  normalized to atoms internally. `int` validates and casts integers, while
  `hex` validates non-empty hexadecimal segments and returns them as strings.
  """

  defstruct root: Router.Trie.new()

  @type capture_value :: Router.Trie.capture_value()
  @type trie_node :: Router.Trie.trie_node()
  @type t :: %__MODULE__{root: trie_node()}

  @doc "Builds an empty router."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Registers `value` under a path template."
  @spec route(t(), String.t(), any()) :: t()
  def route(%__MODULE__{root: root} = router, path, value) do
    %{router | root: Router.Trie.insert(root, Router.Parser.parse(path), value)}
  end

  @doc "Matches a path against the registered routes and returns the first hit."
  @spec match(t(), String.t()) ::
          {:ok, %{String.t() => capture_value()}, any()} | {:error, :no_match}
  def match(%__MODULE__{root: root}, path) do
    case Router.Trie.match(root, String.graphemes(path)) do
      {:ok, vars, value} -> {:ok, vars, value}
      :no_match -> {:error, :no_match}
    end
  end
end
