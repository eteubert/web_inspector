defmodule WebInspector do
  @moduledoc """
  Documentation for WebInspector.
  """

  require Logger

  alias WebInspector.Parser.{Misc, OEmbed, OpenGraph, Twitter}

  @spec unfurl(binary()) :: {:ok, map()} | {:error, atom()}
  def unfurl(url) do
    unfurl(url, [])
  end

  def unfurl(url, visited_locations) when length(visited_locations) < 10 do
    headers = []
    options = []

    case HTTPoison.get(url, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: html}} ->
        parse(url, html, %{locations: Enum.reverse([url | visited_locations])})

      # HTTP 301 Moved Permanently
      {:ok, %HTTPoison.Response{status_code: 301, headers: headers}} ->
        unfurl(location_header(headers), [url | visited_locations])

      # HTTP 302 Found
      {:ok, %HTTPoison.Response{status_code: 302, headers: headers}} ->
        location = location_header(headers)

        # if location has no scheme, it's relative and I need to build the fully qualified URI
        next_url =
          location
          |> URI.parse()
          |> Map.get(:scheme)
          |> case do
            nil -> URI.parse(url) |> Map.put(:path, location) |> URI.to_string()
            url -> url
          end

        unfurl(next_url, [url | visited_locations])

      # HTTP 307 Temporary Redirect
      {:ok, %HTTPoison.Response{status_code: 307, headers: headers}} ->
        unfurl(location_header(headers), [url | visited_locations])

      {:ok, %HTTPoison.Response{status_code: 403}} ->
        {:error, :forbidden}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      other ->
        Logger.error(inspect(other))
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

    # todo: after timeout, collect completed values; shutdown and discard others
    with [open_graph, twitter, misc, oembed] <- Task.yield_many(tasks, 30_000),
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
    else
      _ -> {:error, :parsing_failed}
    end
  end

  defp generate_porcelain(
         data = %{
           providers: %{open_graph: open_graph, twitter: twitter, misc: misc, oembed: oembed}
         },
         url,
         opts
       ) do
    canonical_url =
      Map.get(misc, "canonical_url") || Map.get(oembed, "url") || Map.get(open_graph, "url") ||
        Map.get(twitter, "url") ||
        url

    site_url =
      Map.get(oembed, "provider_url") || Map.get(oembed, "author_url") ||
        fallback_site_url(canonical_url) || fallback_site_url(Map.get(open_graph, "url")) ||
        fallback_site_url(url)

    icon =
      case Map.get(misc, "icons") do
        [icon | _tail] ->
          %{icon | url: ensure_absolute_url(icon.url, site_url)}

        _ ->
          nil
      end

    title = Map.get(open_graph, "title") || Map.get(twitter, "title") || Map.get(misc, "title")

    data
    |> Map.put(:title, title)
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
        Map.get(oembed, "author_name") || short_domain(url)
    )
    |> Map.put(
      :site_url,
      site_url
    )
    |> Map.put(:embed, Map.get(oembed, "html"))
    |> Map.put(:locations, Map.get(opts, :locations))
    |> Map.put(:icon, icon)
  end

  def short_domain(url) do
    URI.parse(url).host |> String.replace("www.", "")
  end

  @doc """
  Extract site URL from url.

      iex> WebInspector.fallback_site_url("https://www.amazon.de/acme")
      "https://www.amazon.de"
  """
  def fallback_site_url(url) do
    u = URI.parse(url)

    if is_binary(u.scheme) && is_binary(u.host) do
      u.scheme <> "://" <> u.host
    else
      nil
    end
  end

  def ensure_absolute_url(icon_url, site_url) do
    icon = URI.parse(icon_url)
    site = URI.parse(site_url)

    case icon.host do
      nil ->
        site
        |> Map.put(:path, icon_url)
        |> URI.to_string()

      _ ->
        icon_url
    end
  end
end
