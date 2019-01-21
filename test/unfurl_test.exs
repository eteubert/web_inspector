defmodule UnfurlTest do
  use ExUnit.Case
  doctest Unfurl

  test "greets the world" do
    assert Unfurl.hello() == :world
  end
end
