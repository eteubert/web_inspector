defmodule WebInspector.Parser.OpenGraph do
  require Logger

  @doc """
  Parse Open Graph elements from HTML.

  ## Example

    iex> WebInspector.Parser.OpenGraph.parse(~S(
    ...>  <meta property="og:type" content="website" />
    ...>  <meta property="og:site_name" content="Freak Show" />
    ...>  <meta property="og:site_name" content="Freak Show 2" />
    ...> ), "https://example.com")
    {:open_graph, %{
      "type" => "website",
      "site_name" => "Freak Show"
    }}
  """
  @spec parse(binary(), binary()) :: {:open_graph, map()}
  def parse(html, _url) when is_binary(html) do
    Floki.parse_document(html)
    |> case do
      {:ok, document} ->
        prepare_return(_parse(document))

      other ->
        Logger.debug(other)
        prepare_return(%{})
    end
  end

  defp _parse(document) do
    Floki.find(document, "meta[property]")
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
          # [content | List.wrap(existing)]
          # ignore properties with more than one occurrence
          # if there are cases where multiple keys are allowed/wanted, a whitelist for these fields
          # should be made and those fields should then always return lists
          existing
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

  defp prepare_return(value) do
    {:open_graph, value}
  end
end
