defmodule WebInspector.Parser.Twitter do
  require Logger

  @doc """
  Parse Twitter elements from HTML.

  ## Example

    iex> WebInspector.Parser.Twitter.parse(~S(
    ...>  <meta name="twitter:card" content="summary" />
    ...>  <meta name="twitter:url" content="https://freakshow.fm/fs229-telefonischturm" />
    ...> ), "https://example.com")
    {:twitter, %{
      "card" => "summary",
      "url" => "https://freakshow.fm/fs229-telefonischturm"
    }}
  """
  @spec parse(binary(), binary()) :: {:twitter, map()}
  def parse(html, _url) when is_binary(html) do
    Floki.parse_document(html)
    |> case do
      {:ok, document} ->
        Floki.find(document, "meta[name]")
        |> List.wrap()
        |> filter()
        |> aggregate()
        |> prepare_return()

      other ->
        Logger.debug(other)
        prepare_return(%{})
    end
  end

  defp aggregate(nodes) when is_list(nodes) do
    nodes
    |> Enum.reduce(%{}, fn node, agg ->
      with [content] <- Floki.attribute(node, "content"),
           [<<"twitter:", property::binary>>] <- Floki.attribute(node, "name") do
        Map.update(agg, property, content, fn existing ->
          [content | List.wrap(existing)]
        end)
      else
        _ -> agg
      end
    end)
  end

  defp filter(nodes) do
    nodes
    |> Enum.filter(fn node ->
      Floki.attribute(node, "name")
      |> case do
        [<<"twitter:", _::binary>>] -> true
        _ -> false
      end
    end)
  end

  defp prepare_return(value) do
    {:twitter, value}
  end
end
