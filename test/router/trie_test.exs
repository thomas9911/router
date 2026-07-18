defmodule Router.TrieTest do
  use ExUnit.Case, async: true

  alias Router.Trie

  describe "insert/3 and match/2" do
    test "matches a static route" do
      trie = Trie.insert(Trie.new(), [text: "users"], :users)

      assert Trie.match(trie, String.graphemes("users")) == {:ok, %{}, :users}
      assert Trie.match(trie, String.graphemes("posts")) == :no_match
    end

    test "captures a variable at the end of a route" do
      tokens = [text: "users/", var: %{name: "id", filter: nil}]
      trie = Trie.insert(Trie.new(), tokens, :user)

      assert Trie.match(trie, String.graphemes("users/42")) ==
               {:ok, %{"id" => "42"}, :user}
    end

    test "captures a variable up to its literal boundary" do
      tokens = [text: "users/", var: %{name: "id", filter: nil}, text: "/posts"]
      trie = Trie.insert(Trie.new(), tokens, :posts)

      assert Trie.match(trie, String.graphemes("users/42/posts")) ==
               {:ok, %{"id" => "42"}, :posts}
    end

    test "prefers a literal branch over a variable branch" do
      trie =
        Trie.new()
        |> Trie.insert([text: "users/me"], :current_user)
        |> Trie.insert([text: "users/", var: %{name: "id", filter: nil}], :user)

      assert Trie.match(trie, String.graphemes("users/me")) ==
               {:ok, %{}, :current_user}
    end

    test "backtracks when a filtered variable edge does not match" do
      trie =
        Trie.new()
        |> Trie.insert([text: "users/", var: %{name: "id", filter: :int}], :integer_user)
        |> Trie.insert([text: "users/", var: %{name: "id", filter: nil}], :any_user)

      assert Trie.match(trie, String.graphemes("users/alice")) ==
               {:ok, %{"id" => "alice"}, :any_user}
    end

    test "casts filtered captures" do
      trie = Trie.insert(Trie.new(), [text: "users/", var: %{name: "id", filter: :int}], :user)

      assert Trie.match(trie, String.graphemes("users/42")) ==
               {:ok, %{"id" => 42}, :user}

      assert Trie.match(trie, String.graphemes("users/nope")) == :no_match
    end
  end
end
