defmodule RouterTest do
  use ExUnit.Case

  describe "parse/1" do
    test "parses plain text with no variables" do
      assert Router.parse("static/only") == [text: "static/only"]
    end

    test "parses a single variable" do
      assert Router.parse("hallo/{app_id}") == [text: "hallo/", var: "app_id"]
    end

    test "parses multiple variables separated by text" do
      assert Router.parse("hallo/{a}/{b}") ==
               [text: "hallo/", var: "a", text: "/", var: "b"]
    end

    test "parses a variable in the middle of text" do
      assert Router.parse("a{x}b") == [text: "a", var: "x", text: "b"]
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
      assert Router.parse("{a}") == [var: "a"]
    end

    test "raises on a stray closing brace as the very first character" do
      assert_raise RuntimeError, "invalid end", fn ->
        Router.parse("}a")
      end
    end
  end

  describe "route/3 and match/2" do
    test "matches a static route" do
      router = Router.new() |> Router.route("hallo/xd", 3)

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
      router = Router.new() |> Router.route("{id}/edit", :edit)

      assert Router.match(router, "42/edit") == {:ok, %{"id" => "42"}, :edit}
    end

    test "captures a variable embedded between static text" do
      router = Router.new() |> Router.route("a{x}b", :mid)

      assert Router.match(router, "aFOOb") == {:ok, %{"x" => "FOO"}, :mid}
    end

    test "returns an error tuple when nothing matches" do
      router = Router.new() |> Router.route("hallo/xd", 3)

      assert Router.match(router, "nope") == {:error, :no_match}
    end

    test "returns an error tuple for an empty router" do
      assert Router.match(Router.new(), "anything") == {:error, :no_match}
    end

    test "prefers the most recently added route when templates overlap" do
      router =
        Router.new()
        |> Router.route("a/{x}", :first)
        |> Router.route("a/{x}", :second)

      assert Router.match(router, "a/foo") == {:ok, %{"x" => "foo"}, :second}
    end

    test "raises when two variables are adjacent with no text between them" do
      assert_raise RuntimeError, "invalid template, variables cannot be after each other", fn ->
        Router.new() |> Router.route("a{b}{c}/d", 1)
      end
    end
  end
end
