defmodule RealworldTest do
  use ExUnit.Case
  # doctest Unfurl

  import Unfurl, only: [unfurl: 1]

  setup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"

    {:ok, bypass: bypass, url: url}
  end

  def respond_with_spon_article(conn) do
    html =
      [__DIR__ | ~w(.. fixtures websites spon-article.html)]
      |> Path.join()
      |> File.read!()

    Plug.Conn.resp(conn, 200, html)
  end

  test "can handle spon article", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, &respond_with_spon_article/1)

    {:ok, result} = unfurl(url)

    assert result.title ==
             ~S(Frankreich: Proteste gegen "Gelbwesten" angekündigt - SPIEGEL ONLINE - Politik)
  end
end
