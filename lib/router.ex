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

  ```elixir
      iex> router = Router.new()
      ...>          |> Router.route({:get, "users/{id:int}"}, :get_user)
      ...>          |> Router.route({:get, "users"}, :list_users)
      ...>          |> Router.route({:post, "users"}, :create_user)
      ...>          |> Router.route({:put, "users/{id:int}"}, :update_user)
      iex> Router.match(router, {:get, "users/42"})
      {:ok, %{"id" => 42}, :get_user}
  ```

  Variables may declare filters via `{name:filter}`. Supported filters are
  normalized to atoms internally. `int` validates and casts integers, while
  `hex` validates non-empty hexadecimal segments and returns them as strings.
  A fixed length can be specified with `hex(8)`.

  Routes may optionally be tagged, for example `{:get, "users/{id}"}`.
  Tagged routes are matched with `{:get, "users/42"}`; untagged routes
  continue to be matched with a path string.

  For the compile-time routing DSL, see `Router.Macro`.
  """

  defstruct root: Router.Trie.new(), tagged: %{}

  @type tag :: atom()
  @type filter :: :int | :hex | {:hex, pos_integer()}
  @type var_token :: %{name: String.t(), filter: filter() | nil}
  @type token :: {:text, String.t()} | {:var, var_token()}
  @type capture_value :: String.t() | integer()
  @type trie_node :: %{
          literal: %{String.t() => trie_node()},
          vars: [trie_var_edge()],
          accept: :none | {:value, any()}
        }
  @type trie_var_edge :: %{
          name: String.t(),
          filter: filter() | nil,
          boundary: String.t() | nil,
          node: trie_node()
        }
  @type t :: %__MODULE__{root: trie_node(), tagged: %{tag() => trie_node()}}

  @doc "Builds an empty router."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Registers `value` under a path template, optionally tagged as `{tag, path}`."
  @spec route(t(), String.t() | {tag(), String.t()}, any()) :: t()
  def route(%__MODULE__{tagged: tagged} = router, {tag, path}, value)
      when is_atom(tag) and is_binary(path) do
    register_route({tag, path}, fn ->
      root = Map.get(tagged, tag, Router.Trie.new())
      tagged = Map.put(tagged, tag, Router.Trie.insert(root, Router.Parser.parse(path), value))
      %{router | tagged: tagged}
    end)
  end

  def route(%__MODULE__{root: root} = router, path, value) when is_binary(path) do
    register_route(path, fn ->
      %{router | root: Router.Trie.insert(root, Router.Parser.parse(path), value)}
    end)
  end

  @doc "Matches a path, optionally tagged as `{tag, path}`, against the registered routes."
  @spec match(t(), String.t() | {tag(), String.t()}) ::
          {:ok, %{String.t() => capture_value()}, any()} | {:error, :no_match}
  def match(%__MODULE__{tagged: tagged}, {tag, path}) when is_atom(tag) and is_binary(path) do
    case Map.fetch(tagged, tag) do
      {:ok, root} -> match_root(root, path)
      :error -> {:error, :no_match}
    end
  end

  def match(%__MODULE__{root: root}, path) when is_binary(path), do: match_root(root, path)

  defp register_route(pattern, fun) do
    fun.()
  rescue
    error in RuntimeError ->
      reraise RuntimeError,
              [message: "could not register route '#{pattern}': #{error.message}"],
              __STACKTRACE__
  end

  defp match_root(root, path) do
    case Router.Trie.match(root, String.graphemes(path)) do
      {:ok, vars, value} -> {:ok, vars, value}
      :no_match -> {:error, :no_match}
    end
  end
end
