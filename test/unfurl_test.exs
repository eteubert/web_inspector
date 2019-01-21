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

  test "extracts open graph data", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, &respond_with_freakshow_episode/1)

    {:ok, result} = unfurl(url)

    og = get_in(result, [:providers, :open_graph])

    assert is_map(og)
    assert Map.get(og, "type") == "website"
    assert Map.get(og, "site_name") == "Freak Show"
    assert Map.get(og, "url") == "https://freakshow.fm/fs229-telefonischturm"
    assert Map.get(og, "image") == "https://meta.metaebene.me/media/mm/freakshow-logo-1.0.jpg"

    assert is_list(Map.get(og, "audio"))
  end

  test "extracts Twitter data", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, &respond_with_freakshow_episode/1)

    {:ok, result} = unfurl(url)

    twitter = get_in(result, [:providers, :twitter])

    assert is_map(twitter)

    assert Map.get(twitter, "card") == "summary"

    assert Map.get(twitter, "image") ==
             "https://meta.metaebene.me/media/mm/freakshow-logo-1.0.jpg"
  end
end
