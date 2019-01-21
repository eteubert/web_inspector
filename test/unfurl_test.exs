defmodule UnfurlTest do
  use ExUnit.Case
  # doctest Unfurl

  import Unfurl, only: [unfurl: 1]

  setup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"

    {:ok, bypass: bypass, url: url}
  end

  def respond_with_freakshow_episode(conn) do
    html =
      [__DIR__ | ~w(fixtures websites freakshow-episode.html)]
      |> Path.join()
      |> File.read!()

    Plug.Conn.resp(conn, 200, html)
  end

  test "extracts page title", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, &respond_with_freakshow_episode/1)

    {:ok, result} = unfurl(url)

    assert result.title == "FS229 Telefonischturm"
  end
end
