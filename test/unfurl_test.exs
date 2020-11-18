defmodule WebInspectorTest do
  use ExUnit.Case
  doctest WebInspector

  import WebInspector, only: [unfurl: 1]

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

  test "extracts misc data", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, &respond_with_freakshow_episode/1)

    {:ok, result} = unfurl(url)

    misc = get_in(result, [:providers, :misc])
    assert is_map(misc)

    assert Map.get(misc, "title") == "FS229 Telefonischturm | Freak Show"
    assert Map.get(misc, "canonical_url") == "https://freakshow.fm/fs229-telefonischturm"

    assert Map.get(misc, "icons") == [
             %{
               type: "icon",
               width: "32",
               height: "32",
               url: "#{url}/files/2013/07/cropped-freakshow-logo-600x600-32x32.jpg"
             },
             %{
               type: "icon",
               width: "192",
               height: "192",
               url: "#{url}/files/2013/07/cropped-freakshow-logo-600x600-192x192.jpg"
             }
           ]

    assert get_in(result, [:icon, :url]) ==
             "#{url}/files/2013/07/cropped-freakshow-logo-600x600-32x32.jpg"
  end

  @tag external: true
  test "redirects are followed" do
    url = "https://t.co/VbTTH3ltoQ"

    {:ok, result} = unfurl(url)

    assert result.site_name == "Nomad List"
    assert result.url == "https://nomadlist.com/"
  end
end
