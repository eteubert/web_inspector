defmodule Unfurl do
  @moduledoc """
  Documentation for Unfurl.
  """

  alias Unfurl.Parser.OpenGraph

  def unfurl(url) do
    {:ok, response} = HTTPoison.get(url)
    %HTTPoison.Response{status_code: 200, headers: _headers, body: html} = response

    title =
      Floki.find(html, "meta[property=\"og:title\"")
      |> Floki.attribute("content")
      |> hd

    open_graph = OpenGraph.parse(html)

    result =
      %{title: title, providers: %{}}
      |> put_in([:providers, :open_graph], open_graph)

    {:ok, result}
  end
end
