defmodule WebInspector.Parser.Puppeteer do
  require Logger

  def fetch_and_parse(url) when is_binary(url) do
    if Application.get_env(:web_inspector, :puppeteer_enabled) do
      do_fetch_and_parse(url)
    else
      %{}
    end
  end

  def fetch_screenshot(url) do
    headers = []

    options = [recv_timeout: 30_000]

    host = Application.get_env(:web_inspector, :puppeteer_host)
    request_url = host <> "/screenshot/?" <> URI.encode_query(%{"url" => url})

    case HTTPoison.get(
           request_url,
           headers,
           options
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: jpeg}} ->
        jpeg

      _ ->
        ""
    end
  end

  defp do_fetch_and_parse(url) do
    headers = []

    options = [recv_timeout: 30_000]

    host = Application.get_env(:web_inspector, :puppeteer_host)

    request_url = host <> "/?" <> URI.encode_query(%{"url" => url})

    case HTTPoison.get(
           request_url,
           headers,
           options
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: json}} ->
        Jason.decode!(json)

      _ ->
        %{}
    end
  end
end
