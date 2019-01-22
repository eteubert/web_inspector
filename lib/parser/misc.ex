defmodule Unfurl.Parser.Misc do
  @doc """
  Parse miscellaneous elements from HTML.

  ## Example

    iex> Unfurl.Parser.Misc.parse(~S(
    ...>  <link rel="icon" href="https://freakshow.fm/files/2013/07/cropped-freakshow-logo-600x600-32x32.jpg" sizes="32x32" />
    ...>  <link rel="icon" href="https://freakshow.fm/files/2013/07/cropped-freakshow-logo-600x600-16x16.jpg" />
    ...> ))
    %{"icons" =>
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
  @spec parse(binary()) :: map()
  def parse(html) when is_binary(html) do
    icons =
      Floki.find(html, "link[rel]")
      |> List.wrap()
      |> filter_icons()
      |> aggregate_icons()

    %{
      "icons" => icons
    }
  end

  defp aggregate_icons(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(fn node ->
      with [href] <- Floki.attribute(node, "href") do
        build_icon(href, Floki.attribute(node, "sizes"))
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
        _ -> false
      end
    end)
  end
end
