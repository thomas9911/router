defmodule Router.MacroTest do
  use ExUnit.Case, async: true

  doctest Router.Macro

  defmodule CustomRouter do
    use Router.Macro, macro_name: :handle, match_name: :dispatch

    handle :get, "users/{id:int}" do
      {:user, id, context}
    end
  end

  defmodule NoMatchRouter do
    use Router.Macro, no_match: {:error, :not_found}

    route :get, "users" do
      :users
    end
  end

  defmodule TestRouter do
    use Router.Macro

    route :get, "users/{id:int}" do
      {:user, id, context}
    end

    route :get, "users" do
      :users
    end
  end

  test "supports custom route and match macro names" do
    assert CustomRouter.dispatch({:get, "users/42"}, %{"name" => "testing"}) ==
             {:user, 42, %{"name" => "testing"}}
  end

  test "supports a custom no-match result" do
    assert NoMatchRouter.match({:get, "missing"}) == {:error, :not_found}
  end

  test "exposes matched variables in the route block" do
    assert TestRouter.match({:get, "users/42"}) == {:user, 42, %{}}

    assert TestRouter.match({:get, "users/42"}, %{name: "testing"}) ==
             {:user, 42, %{name: "testing"}}
  end

  test "keeps routes without variables working" do
    assert TestRouter.match({:get, "users"}) == :users
  end

  test "returns nil when no route matches" do
    assert TestRouter.match({:get, "missing"}) == nil
  end
end
