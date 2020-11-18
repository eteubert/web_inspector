defmodule WebInspector.Parser.Misc do
  alias WebInspector.WebHelper

  require Logger

  @doc """
  Parse miscellaneous elements from HTML.

  ## Example

    iex> WebInspector.Parser.Misc.parse(~S(
    ...>  <title>Foo<title>
    ...>  <link rel="canonical" href="https://example.com" />
    ...>  <link rel="icon" href="https://freakshow.fm/files/2013/07/cropped-freakshow-logo-600x600-32x32.jpg" sizes="32x32" />
    ...>  <link rel="icon" href="https://freakshow.fm/files/2013/07/cropped-freakshow-logo-600x600-16x16.jpg" />
    ...> ), "https://example.com")
    %{
      "title" => "Foo",
      "canonical_url" => "https://example.com",
      "icons" =>
        [
          %{
            type: "icon",
            width: "32",
            height: "32",
            url: "https://freakshow.fm/files/2013/07/cropped-freakshow-logo-600x600-32x32.jpg"
          },
          %{
            type: "icon",
            url: "https://freakshow.fm/files/2013/07/cropped-freakshow-logo-600x600-16x16.jpg"
          }
        ]
    }
  """
  @spec parse(binary(), binary()) :: map()
  def parse(html, site_url) when is_binary(html) do
    Floki.parse_document(html)
    |> case do
      {:ok, document} ->
        _parse(document, site_url)

      other ->
        Logger.debug(other)
        %{}
    end
  end

  defp _parse(document, site_url) do
    title =
      Floki.find(document, "title")
      |> case do
        [node | _] -> Floki.text(node)
        _ -> nil
      end

    canonical_url =
      Floki.find(document, "link[rel=canonical]")
      |> case do
        [node | _] ->
          hd(Floki.attribute(node, "href")) |> WebHelper.ensure_absolute_url(site_url)

        _ ->
          nil
      end

    icons =
      Floki.find(document, "link[rel]")
      |> List.wrap()
      |> filter_icons()
      |> aggregate_icons(site_url)
      |> Enum.filter(&is_map/1)

    %{
      "title" => title,
      "canonical_url" => canonical_url,
      "icons" => icons
    }
  end

  defp aggregate_icons(nodes, site_url) when is_list(nodes) do
    nodes
    |> Enum.map(fn node ->
      with [href] <- Floki.attribute(node, "href") do
        build_icon(WebHelper.ensure_absolute_url(href, site_url), Floki.attribute(node, "sizes"))
      else
        _ -> nil
      end
    end)
  end

  @spec build_icon(binary(), list()) :: map()
  def build_icon(href, sizes) do
    case sizes do
      [] ->
        %{type: "icon", url: href}

      [sizes] ->
        case String.split(sizes, ["x", "X"]) do
          [w, h] ->
            %{type: "icon", width: w, height: h, url: href}

          _ ->
            %{type: "icon", url: href}
        end
    end
  end

  defp filter_icons(nodes) do
    nodes
    |> Enum.filter(fn node ->
      Floki.attribute(node, "rel")
      |> case do
        ["icon"] -> true
        ["apple-touch-icon"] -> true
        _ -> false
      end
    end)
  end
end
