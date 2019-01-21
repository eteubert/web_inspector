defmodule Unfurl do
  @moduledoc """
  Documentation for Unfurl.
  """

  alias Unfurl.Parser.OpenGraph

  def unfurl(url) do
    {:ok, response} = HTTPoison.get(url)
    %HTTPoison.Response{status_code: 200, headers: _headers, body: html} = response

    open_graph = OpenGraph.parse(html)

    result =
      %{providers: %{}}
      |> put_in([:providers, :open_graph], open_graph)
      |> Map.put(:title, Map.get(open_graph, "title"))

    {:ok, result}
  end
end
