defmodule WebInspector.Adapter.ScrapingAnt do
  alias WebInspector.Adapter

  @api_base_uri URI.parse("https://api.scrapingant.com/v1/general")

  def call(url, headers, options) do
    config = Application.get_env(:web_inspector, __MODULE__)

    if config[:enabled] do
      call_api(url, headers, options, config)
    else
      Adapter.Plain.call(url, headers, options)
    end
  end

  defp call_api(url, headers, options, config) do
    url =
      @api_base_uri
      |> URI.append_query("url=" <> URI.encode_www_form(url))
      |> URI.append_query("proxy_country=" <> config[:proxy_country])
      |> URI.append_query("browser=false")
      |> URI.to_string()

    headers = [{"x-api-key", config[:api_key]} | headers]

    Adapter.Plain.call(url, headers, options)
  end
end
