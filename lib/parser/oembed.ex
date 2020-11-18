defmodule WebInspector.Parser.OEmbed do
  require Logger

  @doc """
  Detect and parse oEmbed data.

  Finds all "application/json+oembed" links, fetches them all and returns
  the first valid result.
  """
  @spec parse(binary(), binary()) :: map()
  def parse(html, _url) when is_binary(html) do
    Floki.parse_document(html)
    |> case do
      {:ok, document} ->
        _parse(document)

      other ->
        Logger.debug(other)
        %{}
    end
  end

  defp _parse(document) do
    Floki.find(document, "link[type=\"application/json+oembed\"]")
    |> List.wrap()
    |> Enum.map(fn node -> with [href] <- Floki.attribute(node, "href"), do: href end)
    |> Enum.map(fn url ->
      Task.async(fn -> fetch(url) end)
    end)
    |> Task.yield_many()
    |> Enum.reduce(nil, fn
      {_task, {:ok, {:ok, {:ok, oembed}}}}, _acc ->
        oembed
        # filter out items with empty values
        |> Enum.filter(fn
          {_k, v} when is_binary(v) -> v |> String.trim() |> String.length() > 0
          _ -> true
        end)
        |> Enum.into(%{})

      _, _ ->
        nil
    end)
    |> case do
      oembed when is_map(oembed) -> oembed
      _ -> %{}
    end
  end

  defp fetch(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: json}} ->
        {:ok, Jason.decode(json)}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, :unexpected_status, status}

      _ ->
        {:error, :invalid_response}
    end
  end
end
