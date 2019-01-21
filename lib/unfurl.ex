defmodule Unfurl do
  @moduledoc """
  Documentation for Unfurl.
  """

  def unfurl(url) do
    {:ok, response} = HTTPoison.get(url)
    %HTTPoison.Response{status_code: 200, headers: _headers, body: html} = response

    title =
      Floki.find(html, "meta[property=\"og:title\"")
      |> Floki.attribute("content")
      |> hd

    open_graph = parse_open_graph(html)

    result =
      %{title: title, providers: %{}}
      |> put_in([:providers, :open_graph], open_graph)

    {:ok, result}
  end

  def parse_open_graph(html) do
    Floki.find(html, "meta[property]")
    |> filter_open_graph_elements()
    |> aggregate_open_graph_elements()
    |> IO.inspect()
  end

  defp aggregate_open_graph_elements(nodes) when is_list(nodes) do
    nodes
    |> Enum.reduce(%{}, fn node, agg ->
      with [content] <- Floki.attribute(node, "content"),
           [<<"og:", property::binary>>] <- Floki.attribute(node, "property") do
        Map.update(agg, property, content, fn existing ->
          [content | List.wrap(existing)]
        end)
      end
    end)
  end

  defp filter_open_graph_elements(nodes) do
    nodes
    |> List.wrap()
    |> Enum.filter(fn node ->
      Floki.attribute(node, "property")
      |> case do
        [<<"og:", _::binary>>] -> true
        _ -> false
      end
    end)
  end
end
