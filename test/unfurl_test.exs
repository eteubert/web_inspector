defmodule UnfurlTest do
  use ExUnit.Case
  # doctest Unfurl

  import Unfurl, only: [unfurl: 1]

  test "extracts page title" do
    {:ok, result} = Unfurl.unfurl("https://freakshow.fm/fs229-telefonischturm")

    assert result.title == "FS229 Telefonischturm"
  end
end
