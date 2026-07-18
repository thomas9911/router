defmodule Router.ParserTest do
  use ExUnit.Case, async: true

  describe "parse/1" do
    test "parses plain text with no variables" do
      assert Router.Parser.parse("static/only") == [text: "static/only"]
    end

    test "parses a single variable" do
      assert Router.Parser.parse("hallo/{app_id}") == [
               text: "hallo/",
               var: %{name: "app_id", filter: nil}
             ]
    end

    test "parses multiple variables separated by text" do
      assert Router.Parser.parse("hallo/{a}/{b}") ==
               [
                 text: "hallo/",
                 var: %{name: "a", filter: nil},
                 text: "/",
                 var: %{name: "b", filter: nil}
               ]
    end

    test "parses a variable in the middle of text" do
      assert Router.Parser.parse("a{x}b") == [
               text: "a",
               var: %{name: "x", filter: nil},
               text: "b"
             ]
    end

    test "parses a variable filter as an atom" do
      assert Router.Parser.parse("user/{id:int}/") ==
               [text: "user/", var: %{name: "id", filter: :int}, text: "/"]
    end

    test "parses a hex variable filter as an atom" do
      assert Router.Parser.parse("user/{id:hex}/") ==
               [text: "user/", var: %{name: "id", filter: :hex}, text: "/"]
    end

    test "ignores whitespace around a variable filter" do
      assert Router.Parser.parse("user/{ id : int }/") ==
               [text: "user/", var: %{name: "id", filter: :int}, text: "/"]
    end

    test "raises on a stray closing brace with no open variable" do
      assert_raise RuntimeError, "invalid route template: unexpected closing brace", fn ->
        Router.Parser.parse("a}")
      end
    end

    test "raises on a nested opening brace" do
      assert_raise RuntimeError,
                   "invalid route template: unexpected opening brace inside a variable",
                   fn ->
                     Router.Parser.parse("a{b{c}")
                   end
    end

    test "parses a variable that starts the template" do
      assert Router.Parser.parse("{a}") == [var: %{name: "a", filter: nil}]
    end

    test "raises on a stray closing brace as the very first character" do
      assert_raise RuntimeError, "invalid route template: unexpected closing brace", fn ->
        Router.Parser.parse("}a")
      end
    end

    test "raises on an invalid filtered variable" do
      assert_raise RuntimeError, "invalid variable: filter is empty, remove the ':'", fn ->
        Router.Parser.parse("{id:}")
      end
    end

    test "raises on an unknown filter" do
      assert_raise RuntimeError,
                   "unknown filter: 'uuid'; supported filters: int, hex, hex(length)",
                   fn ->
                     Router.Parser.parse("{id:uuid}")
                   end
    end
  end
end
