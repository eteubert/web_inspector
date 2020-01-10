defmodule OEmbedTest do
  use ExUnit.Case
  doctest WebInspector.Parser.OEmbed

  @url "https://example.com"

  setup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"

    {:ok, bypass: bypass, url: url}
  end

  def respond_with_oembed(conn) do
    response =
      [__DIR__ | ~w(.. fixtures websites twitter-oembed.json)]
      |> Path.join()
      |> File.read!()

    Plug.Conn.resp(conn, 200, response)
  end

  test "extracts oembed data", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, &respond_with_oembed/1)

    icon = ~s(<link rel="alternate" type="application/json+oembed" href="#{url}">)

    result = WebInspector.Parser.OEmbed.parse(icon, @url)

    assert is_map(result)
    assert Map.get(result, "author_name") == "Eric Teubert"
    assert Map.get(result, "author_url") == "https://twitter.com/ericteubert"
  end
end
