defmodule RouterTest do
  use ExUnit.Case

  test "do it" do
    router =
      Router.new()
      |> Router.route("hallo/doei/{app_id}/{mooi}", 1)
      # |> Router.route("hallo/doei/{app_id}", 3)
      |> Router.route("hallo/xd", 3)

    assert {:ok, %{"app_id" => "1234", "mooi" => "28123"}, 1} ==
             router |> Router.match("hallo/doei/1234/28123")
  end

  # test "parse" do
  #   assert :ok == Router.parse("hallo/doei/{app_id}/{mooi}")
  # end
end
