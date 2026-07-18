defmodule RouterTest do
  use ExUnit.Case

  doctest Router

  describe "parse/1" do
    test "parses plain text with no variables" do
      assert Router.parse("static/only") == [text: "static/only"]
    end

    test "parses a single variable" do
      assert Router.parse("hallo/{app_id}") == [
               text: "hallo/",
               var: %{name: "app_id", filter: nil}
             ]
    end

    test "parses multiple variables separated by text" do
      assert Router.parse("hallo/{a}/{b}") ==
               [
                 text: "hallo/",
                 var: %{name: "a", filter: nil},
                 text: "/",
                 var: %{name: "b", filter: nil}
               ]
    end

    test "parses a variable in the middle of text" do
      assert Router.parse("a{x}b") == [text: "a", var: %{name: "x", filter: nil}, text: "b"]
    end

    test "parses a variable filter as an atom" do
      assert Router.parse("user/{id:int}/") ==
               [text: "user/", var: %{name: "id", filter: :int}, text: "/"]
    end

    test "parses a hex variable filter as an atom" do
      assert Router.parse("user/{id:hex}/") ==
               [text: "user/", var: %{name: "id", filter: :hex}, text: "/"]
    end

    test "raises on a stray closing brace with no open variable" do
      assert_raise RuntimeError, "invalid end", fn ->
        Router.parse("a}")
      end
    end

    test "raises on a nested opening brace" do
      assert_raise RuntimeError, "invalid start", fn ->
        Router.parse("a{b{c}")
      end
    end

    test "parses a variable that starts the template" do
      assert Router.parse("{a}") == [var: %{name: "a", filter: nil}]
    end

    test "raises on a stray closing brace as the very first character" do
      assert_raise RuntimeError, "invalid end", fn ->
        Router.parse("}a")
      end
    end

    test "raises on an invalid filtered variable" do
      assert_raise RuntimeError, "invalid variable", fn ->
        Router.parse("{id:}")
      end
    end

    test "raises on an unknown filter" do
      assert_raise RuntimeError, "unknown filter", fn ->
        Router.parse("{id:uuid}")
      end
    end
  end

  describe "route/3 and match/2" do
    test "matches a static route" do
      router = Router.route(Router.new(), "hallo/xd", 3)

      assert Router.match(router, "hallo/xd") == {:ok, %{}, 3}
    end

    test "matches a route with variables and extracts their values" do
      router =
        Router.new()
        |> Router.route("hallo/doei/{app_id}/{mooi}", 1)
        |> Router.route("hallo/xd", 3)

      assert Router.match(router, "hallo/doei/1234/28123") ==
               {:ok, %{"app_id" => "1234", "mooi" => "28123"}, 1}
    end

    test "matches a route whose template starts with a variable" do
      router = Router.route(Router.new(), "{id}/edit", :edit)

      assert Router.match(router, "42/edit") == {:ok, %{"id" => "42"}, :edit}
    end

    test "captures a variable embedded between static text" do
      router = Router.route(Router.new(), "a{x}b", :mid)

      assert Router.match(router, "aFOOb") == {:ok, %{"x" => "FOO"}, :mid}
    end

    test "matches an integer-filtered variable and casts it to an integer" do
      router = Router.route(Router.new(), "user/{id:int}/", :user)

      assert Router.match(router, "user/42/") == {:ok, %{"id" => 42}, :user}
    end

    test "rejects a non-integer for an integer-filtered variable" do
      router = Router.route(Router.new(), "user/{id:int}/", :user)

      assert Router.match(router, "user/abc/") == {:error, :no_match}
    end

    test "rejects an empty integer-filtered trailing variable" do
      router = Router.route(Router.new(), "user/{id:int}", :user)

      assert Router.match(router, "user/") == {:error, :no_match}
    end

    test "matches a hexadecimal-filtered variable" do
      router = Router.route(Router.new(), "user/{id:hex}/", :user)

      assert Router.match(router, "user/0aF9/") ==
               {:ok, %{"id" => "0aF9"}, :user}
    end

    test "rejects non-hexadecimal characters" do
      router = Router.route(Router.new(), "user/{id:hex}/", :user)

      assert Router.match(router, "user/0aG9/") == {:error, :no_match}
    end

    test "rejects an empty hexadecimal-filtered trailing variable" do
      router = Router.route(Router.new(), "user/{id:hex}", :user)

      assert Router.match(router, "user/") == {:error, :no_match}
    end

    test "raises while routing with an unknown filter" do
      assert_raise RuntimeError, "unknown filter", fn ->
        Router.route(Router.new(), "user/{id:uuid}", :user)
      end
    end

    test "returns an error tuple when nothing matches" do
      router = Router.route(Router.new(), "hallo/xd", 3)

      assert Router.match(router, "nope") == {:error, :no_match}
    end

    test "returns an error tuple for an empty router" do
      assert Router.match(Router.new(), "anything") == {:error, :no_match}
    end

    test "prefers the first added route when templates overlap" do
      router =
        Router.new()
        |> Router.route("a/{x}", :first)
        |> Router.route("a/{x}", :second)

      assert Router.match(router, "a/foo") == {:ok, %{"x" => "foo"}, :first}
    end

    test "raises when two variables are adjacent with no text between them" do
      assert_raise RuntimeError, "invalid template, variables cannot be after each other", fn ->
        Router.route(Router.new(), "a{b}{c}/d", 1)
      end
    end

    test "does not match a path longer than the template" do
      router = Router.route(Router.new(), "a", 1)

      assert Router.match(router, "ab") == {:error, :no_match}
    end

    test "does not match a path shorter than the template" do
      router = Router.route(Router.new(), "ab", 1)

      assert Router.match(router, "a") == {:error, :no_match}
    end

    test "does not match when a variable never reaches its trailing literal text" do
      router = Router.route(Router.new(), "a{x}b", :mid)

      assert Router.match(router, "aFOO") == {:error, :no_match}
    end

    test "matches an empty capture for a variable that trails the template" do
      router = Router.route(Router.new(), "hallo/{x}", 2)

      assert Router.match(router, "hallo/") == {:ok, %{}, 2}
    end

    test "a more specific route registered before an overlapping general one wins" do
      router =
        Router.new()
        |> Router.route("test/hello/bye/{rest}", :specific)
        |> Router.route("test/hello/{rest}", :general)

      assert Router.match(router, "test/hello/bye/foo") ==
               {:ok, %{"rest" => "foo"}, :specific}

      assert Router.match(router, "test/hello/other") ==
               {:ok, %{"rest" => "other"}, :general}
    end

    test "a more specific route wins over an overlapping general one regardless of registration order" do
      router =
        Router.new()
        |> Router.route("test/hello/{rest}", :general)
        |> Router.route("test/hello/bye/{rest}", :specific)

      assert Router.match(router, "test/hello/bye/foo") ==
               {:ok, %{"rest" => "foo"}, :specific}
    end

    test "matches a multi-byte UTF-8 boundary character correctly" do
      router = Router.route(Router.new(), "a{x}é", :accented)

      assert Router.match(router, "aFOOé") == {:ok, %{"x" => "FOO"}, :accented}
    end
  end
end
