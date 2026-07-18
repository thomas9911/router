defmodule Router.MacroTest do
  use ExUnit.Case, async: true

  defmodule CustomRouter do
    use Router.Macro, macro_name: :handle

    handle :get, "users/{id:int}" do
      {:user, id}
    end
  end

  defmodule TestRouter do
    use Router.Macro

    route :get, "users/{id:int}" do
      {:user, id}
    end

    route :get, "users" do
      :users
    end
  end

  test "supports a custom route macro name" do
    assert CustomRouter.match({:get, "users/42"}) == {:user, 42}
  end

  test "exposes matched variables in the route block" do
    assert TestRouter.match({:get, "users/42"}) == {:user, 42}
  end

  test "keeps routes without variables working" do
    assert TestRouter.match({:get, "users"}) == :users
  end

  test "returns nil when no route matches" do
    assert TestRouter.match({:get, "missing"}) == nil
  end
end
