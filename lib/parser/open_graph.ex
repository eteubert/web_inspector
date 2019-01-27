defmodule WebInspector.Parser.OpenGraph do
  @doc """
  Parse Open Graph elements from HTML.

  ## Example

    iex> WebInspector.Parser.OpenGraph.parse(~S(
    ...>  <meta property="og:type" content="website" />
    ...>  <meta property="og:site_name" content="Freak Show" />
    ...> ))
    %{
      "type" => "website",
      "site_name" => "Freak Show"
    }
  """
  @spec parse(binary()) :: map()
  def parse(html) when is_binary(html) do
    Floki.find(html, "meta[property]")
    |> List.wrap()
    |> filter()
    |> aggregate()
  end

  defp aggregate(nodes) when is_list(nodes) do
    nodes
    |> Enum.reduce(%{}, fn node, agg ->
      with [content] <- Floki.attribute(node, "content"),
           [<<"og:", property::binary>>] <- Floki.attribute(node, "property") do
        Map.update(agg, property, content, fn existing ->
          [content | List.wrap(existing)]
        end)
      end
    end)
  end

  defp filter(nodes) do
    nodes
    |> Enum.filter(fn node ->
      Floki.attribute(node, "property")
      |> case do
        [<<"og:", _::binary>>] -> true
        _ -> false
      end
    end)
  end
end
