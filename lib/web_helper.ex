defmodule WebInspector.WebHelper do
  @doc """
  Makes given relative URL absolute to the provided site_url.

  ## Examples

      iex> WebInspector.WebHelper.ensure_absolute_url("/icon.png", "https://example.com")
      "https://example.com/icon.png"

      iex> WebInspector.WebHelper.ensure_absolute_url("css/img/icon-webclip-iphone.png", "https://help.apple.com/itc/podcasts_connect/#/itcb54353390")
      "https://help.apple.com/css/img/icon-webclip-iphone.png"

  """
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
    parsed_url = URI.parse(url)

    parsed_url
    |> Map.put(:authority, site_url.authority)
    |> Map.put(:host, site_url.host)
    |> Map.put(:scheme, site_url.scheme)
    |> Map.put(:port, site_url.port)
    |> Map.put(:path, prefix_with_slash(parsed_url.path))
    |> URI.to_string()
  end

  defp prefix_with_slash(<<"/", _rest::binary>> = string) do
    string
  end

  defp prefix_with_slash(string) do
    "/" <> string
  end
end
