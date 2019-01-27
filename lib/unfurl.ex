defmodule Unfurl do
  @moduledoc """
  Documentation for Unfurl.
  """

  alias Unfurl.Parser.{Misc, OEmbed, OpenGraph, Twitter}

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
        {:error, :unhandled_url_response}
    end
  end

  @spec location_header(list()) :: binary() | nil
  defp location_header([{"location", location} | _]), do: location
  defp location_header([{"Location", location} | _]), do: location
  defp location_header([_ | headers]), do: location_header(headers)
  defp location_header([]), do: nil

  defp parse(url, html, opts) do
    tasks = [
      Task.async(OpenGraph, :parse, [html]),
      Task.async(Twitter, :parse, [html]),
      Task.async(Misc, :parse, [html]),
      Task.async(OEmbed, :parse, [html])
    ]

    with [open_graph, twitter, misc, oembed] <- Task.yield_many(tasks),
         {_, {:ok, open_graph}} <- open_graph,
         {_, {:ok, twitter}} <- twitter,
         {_, {:ok, misc}} <- misc,
         {_, {:ok, oembed}} <- oembed do
      result =
        %{providers: %{}}
        |> put_in([:providers, :open_graph], open_graph)
        |> put_in([:providers, :twitter], twitter)
        |> put_in([:providers, :misc], misc)
        |> put_in([:providers, :oembed], oembed)
        |> generate_porcelain(url, opts)

      {:ok, result}
    end
  end

  defp generate_porcelain(
         data = %{
           providers: %{open_graph: open_graph, twitter: twitter, misc: misc, oembed: oembed}
         },
         url,
         opts
       ) do
    icon =
      case Map.get(misc, "icons") do
        [icon | _tail] -> icon
        _ -> nil
      end

    canonical_url =
      Map.get(misc, "canonical_url") || Map.get(oembed, "url") || Map.get(open_graph, "url") ||
        Map.get(twitter, "url") ||
        url

    data
    |> Map.put(:title, Map.get(open_graph, "title") || Map.get(twitter, "title"))
    |> Map.put(
      :url,
      canonical_url
    )
    |> Map.put(:original_url, hd(Map.get(opts, :locations)))
    |> Map.put(
      :description,
      Map.get(open_graph, "description") || Map.get(twitter, "description")
    )
    |> Map.put(
      :site_name,
      Map.get(oembed, "provider_name") || Map.get(open_graph, "site_name") ||
        Map.get(oembed, "author_name")
    )
    |> Map.put(
      :site_url,
      Map.get(oembed, "provider_url") || Map.get(oembed, "author_url") ||
        short_domain(canonical_url)
    )
    |> Map.put(:embed, Map.get(oembed, "html"))
    |> Map.put(:locations, Map.get(opts, :locations))
    |> Map.put(:icon, icon)
  end

  def short_domain(url) do
    URI.parse(url).host |> String.replace("www.", "")
  end
end
