defmodule WebInspector do
  @moduledoc """
  Documentation for WebInspector.
  """

  # pretend to be a Firefox but add Unfurl component for semi-good citizenship
  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:73.0) Gecko/20100101 Firefox/73.0 Unfurl/1.0"

  require Logger

  alias WebInspector.Parser.{Misc, OEmbed, OpenGraph, Twitter, Puppeteer}
  alias WebInspector.WebHelper

  @spec unfurl(binary()) :: {:ok, map()} | {:error, atom()}
  def unfurl(url) do
    with {:ok, sanitized_url} <- sanitize_url(url),
         true <- String.length(sanitized_url) > 0 do
      unfurl(sanitized_url, [])
    else
      _ -> {:error, :invalid_url}
    end
  end

  def maybe_use_scrapingant(url, headers) do
    config = Application.get_env(:web_inspector, :scrapingant)

    if config[:enabled] do
      use_scrapingant(url, headers, config)
    else
      {url, headers}
    end
  end

  # TODO: extract scrapingant logic into module
  # rename config to config :web_inspector, ScrapingAnt, ...
  @scrapingant_base_uri URI.parse("https://api.scrapingant.com/v1/general")

  def use_scrapingant(url, headers, config) do
    url =
      @scrapingant_base_uri
      |> URI.append_query("url=" <> URI.encode_www_form(url))
      |> URI.append_query("proxy_country=" <> config[:proxy_country])
      |> URI.append_query("browser=false")
      |> URI.to_string()

    headers = [{"x-api-key", config[:api_key]} | headers]

    {url, headers}
  end

  def unfurl(url, visited_locations) when length(visited_locations) < 10 do
    headers = [
      {"User-agent", @user_agent}
    ]

    options = [
      ssl: [{:versions, [:"tlsv1.2"]}],
      recv_timeout: 15_000
    ]

    {url, headers} = maybe_use_scrapingant(url, headers)

    Logger.debug(url)

    try do
      case HTTPoison.get(url, headers, options) do
        {:ok, %HTTPoison.Response{status_code: 200, body: html, headers: headers}} ->
          compression = find_header(headers, "content-encoding")
          # contentType = find_header(headers, "content-type")
          # Logger.debug("contentType: " <> contentType)
          html = decompress_body(compression, html)
          parse(url, html, %{locations: Enum.reverse([url | visited_locations])})

        # HTTP 301 Moved Permanently
        {:ok, %HTTPoison.Response{status_code: 301, headers: headers}} ->
          unfurl(next_url(url, headers), [url | visited_locations])

        # HTTP 302 Found
        {:ok, %HTTPoison.Response{status_code: 302, headers: headers}} ->
          unfurl(next_url(url, headers), [url | visited_locations])

        # HTTP 303 See Other
        {:ok, %HTTPoison.Response{status_code: 303, headers: headers}} ->
          unfurl(next_url(url, headers), [url | visited_locations])

        # HTTP 307 Temporary Redirect
        {:ok, %HTTPoison.Response{status_code: 307, headers: headers}} ->
          unfurl(next_url(url, headers), [url | visited_locations])

        {:ok, %HTTPoison.Response{status_code: 403, body: body}} ->
          if String.contains?(body, "cf-captcha-container") do
            {:error, :forbidden_cloudflare_captcha}
          else
            {:error, :forbidden}
          end

        {:ok, %HTTPoison.Response{status_code: 423}} ->
          {:error, :scrapingant_blocked_by_bot_detection}

        {:error, %HTTPoison.Error{reason: :nxdomain}} ->
          {:error, :nxdomain}

        {:ok, %HTTPoison.Response{status_code: 404}} ->
          {:error, :not_found}

        {:ok, %HTTPoison.Response{status_code: 429}} ->
          {:error, :http_429_too_many_requests}

        {:ok, %HTTPoison.Response{status_code: 502}} ->
          {:error, :http_bad_gateway}

        {:error, %HTTPoison.Error{reason: {:tls_alert, tls_alert}}} ->
          Logger.error(inspect(tls_alert))
          {:error, :tls_alert}

        other ->
          Logger.error(inspect(other))
          {:error, :unhandled_url_response}
      end
    catch
      :exit, thrown_value ->
        Logger.error("HTTPoison: exit thrown: #{inspect(thrown_value)}")
        {:error, :http_client_exception}
    end
  end

  def unfurl(_url, _visited_locations) do
    {:error, :too_many_redirects}
  end

  # determine next url to request based on location header
  # - follow location header if it is a fully qualified URL
  # - if location header is relative, build fully qualified URL
  defp next_url(request_url, headers) do
    headers
    |> location_header()
    |> WebHelper.ensure_absolute_url(request_url)
  end

  @spec location_header(list()) :: binary() | nil
  defp location_header([{"location", location} | _]), do: location
  defp location_header([{"Location", location} | _]), do: location
  defp location_header([_ | headers]), do: location_header(headers)
  defp location_header([]), do: nil

  defp find_header(headers, header_name) do
    Enum.find_value(
      headers,
      fn {name, value} ->
        name =~ ~r/#{header_name}/i && String.downcase(value)
      end
    )
  end

  defp decompress_body(nil, body), do: body
  defp decompress_body("identity", body), do: body
  defp decompress_body("gzip", <<31, 139, 8, _::binary>> = body), do: :zlib.gunzip(body)
  defp decompress_body("gzip", body), do: body
  defp decompress_body("x-gzip", <<31, 139, 8, _::binary>> = body), do: :zlib.gunzip(body)
  defp decompress_body("x-gzip", body), do: body
  defp decompress_body("deflate", body), do: :zlib.unzip(body)

  defp decompress_body(other, body) do
    Logger.error("No support for decompression of body using '#{other}' algorithm.")
    body
  end

  defp parse(url, html, opts) do
    original_url = hd(Map.get(opts, :locations))

    tasks = [
      Task.async(Puppeteer, :fetch_and_parse, [original_url]),
      Task.async(OpenGraph, :parse, [html, url]),
      Task.async(Twitter, :parse, [html, url]),
      Task.async(Misc, :parse, [html, url]),
      Task.async(OEmbed, :parse, [html, url])
    ]

    tasks_with_results = Task.yield_many(tasks, 60_000)

    task_results =
      Enum.map(tasks_with_results, fn {task, res} ->
        # Shut down the tasks that did not reply nor exit
        res || Task.shutdown(task, :brutal_kill)
      end)

    # only take the completed tasks, ignore the others
    result =
      Enum.reduce(task_results, %{providers: %{}}, fn
        {:ok, {provider_name, value}}, acc -> put_in(acc, [:providers, provider_name], value)
        _, acc -> acc
      end)

    {:ok, generate_porcelain(result, url, opts)}
  end

  defp generate_porcelain(data, url, opts) do
    open_graph = get_in(data, [:providers, :open_graph]) || %{}
    twitter = get_in(data, [:providers, :twitter]) || %{}
    misc = get_in(data, [:providers, :misc]) || %{}
    oembed = get_in(data, [:providers, :oembed]) || %{}
    puppeteer = get_in(data, [:providers, :puppeteer]) || %{}

    canonical_url =
      Map.get(puppeteer, "url") || Map.get(misc, "canonical_url") || Map.get(oembed, "url") ||
        Map.get(open_graph, "url") ||
        Map.get(twitter, "url") ||
        url

    site_url =
      Map.get(oembed, "provider_url") || Map.get(oembed, "author_url") ||
        fallback_site_url(canonical_url) || fallback_site_url(Map.get(open_graph, "url")) ||
        fallback_site_url(url)

    icon =
      case Map.get(misc, "icons") do
        [icon | _tail] when is_map(icon) ->
          %{icon | url: WebHelper.ensure_absolute_url(icon.url, site_url)}

        _ ->
          nil
      end

    title =
      Map.get(puppeteer, "title") || Map.get(open_graph, "title") || Map.get(twitter, "title") ||
        Map.get(misc, "title")

    image =
      (Map.get(puppeteer, "image") || Map.get(open_graph, "image") ||
         Map.get(twitter, "image:src"))
      |> WebHelper.ensure_absolute_url(site_url)

    data
    |> Map.put(:title, title)
    |> Map.put(
      :url,
      canonical_url
    )
    |> Map.put(:original_url, hd(Map.get(opts, :locations)))
    |> Map.put(
      :description,
      Map.get(puppeteer, "description") || Map.get(open_graph, "description") ||
        Map.get(twitter, "description")
    )
    |> Map.put(
      :site_name,
      Map.get(puppeteer, "site_name") || Map.get(oembed, "provider_name") ||
        Map.get(open_graph, "site_name") || short_domain(url)
    )
    |> Map.put(
      :site_url,
      site_url
    )
    |> Map.put(:embed, Map.get(oembed, "html"))
    |> Map.put(:locations, Map.get(opts, :locations))
    |> Map.put(:icon, icon)
    |> Map.put(:image, image)
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

  @doc """
  Sanitize url

  ## Examples

      iex> WebInspector.sanitize_url("http://example.com")
      {:ok, "http://example.com"}

      iex> WebInspector.sanitize_url("ukw.fm")
      {:ok, "https://ukw.fm"}

      iex> WebInspector.sanitize_url("https:///ukw.fm")
      {:ok, "https://ukw.fm"}
  """
  def sanitize_url(url) do
    parsed_url = url |> String.trim() |> String.replace(":///", "://") |> URI.parse()

    parsed_url =
      if is_nil(parsed_url.scheme) && is_nil(parsed_url.host) && !is_nil(parsed_url.path) do
        %URI{
          host: parsed_url.path,
          authority: parsed_url.path,
          scheme: "https",
          port: 443
        }
      else
        parsed_url
      end

    result = to_string(parsed_url)

    if result == "https://" do
      {:error, :invalid_url}
    else
      {:ok, result}
    end
  end
end
