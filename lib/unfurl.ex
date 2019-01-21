defmodule Unfurl do
  @moduledoc """
  Documentation for Unfurl.
  """

  alias Unfurl.Parser.{OpenGraph, Twitter}

  @spec unfurl(binary()) :: {:ok, map()} | {:error, atom()}
  def unfurl(url) do
    unfurl(url, [])
  end

  def unfurl(url, visited_locations) when length(visited_locations) < 10 do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: html}} ->
        parse(url, html, %{locations: Enum.reverse([url | visited_locations])})

      {:ok, %HTTPoison.Response{status_code: 301, headers: headers}} ->
        unfurl(location_header(headers), [url | visited_locations])

      {:ok, %HTTPoison.Response{status_code: 307, headers: headers}} ->
        unfurl(location_header(headers), [url | visited_locations])

      _ ->
        raise "Unhandled URL Response"
    end
  end

  @spec location_header(list()) :: binary() | nil
  defp location_header([{"location", location} | _]), do: location
  defp location_header([{"Location", location} | _]), do: location
  defp location_header([_ | headers]), do: location_header(headers)
  defp location_header([]), do: nil

  def parse(url, html, opts) do
    tasks = [
      Task.async(OpenGraph, :parse, [html]),
      Task.async(Twitter, :parse, [html])
    ]

    with [open_graph, twitter] <- Task.yield_many(tasks),
         {_, {:ok, open_graph}} <- open_graph,
         {_, {:ok, twitter}} <- twitter do
      result =
        %{providers: %{}}
        |> put_in([:providers, :open_graph], open_graph)
        |> put_in([:providers, :twitter], twitter)
        |> Map.put(:title, Map.get(open_graph, "title") || Map.get(twitter, "title"))
        |> Map.put(:url, Map.get(open_graph, "url") || Map.get(twitter, "url") || url)
        |> Map.put(:original_url, hd(Map.get(opts, :locations)))
        |> Map.put(
          :description,
          Map.get(open_graph, "description") || Map.get(twitter, "description")
        )
        |> Map.put(:site_name, Map.get(open_graph, "site_name"))
        |> Map.put(:locations, Map.get(opts, :locations))

      {:ok, result}
    end
  end
end
