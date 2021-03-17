defmodule WebInspector.WebHelper do
  def ensure_absolute_url(url, site_url) when is_binary(url) do
    url
    |> URI.parse()
    |> Map.get(:scheme)
    |> case do
      nil -> make_absolute_url(url, site_url)
      _url -> url
    end
  end

  def ensure_absolute_url(url, _), do: url

  defp make_absolute_url(url, site_url) do
    site_url = URI.parse(site_url)

    URI.parse(url)
    |> Map.put(:authority, site_url.authority)
    |> Map.put(:host, site_url.host)
    |> Map.put(:scheme, site_url.scheme)
    |> Map.put(:port, site_url.port)
    |> URI.to_string()
  end
end
