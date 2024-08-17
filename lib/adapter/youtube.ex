defmodule WebInspector.Adapter.Youtube do
  @doc """
  TODO: Is this the right namespace? Or should I distinguish adapters by
  purpose? Behavior?
  """

  @user_agent "Podlove Unfurl/1.0"

  @api_base_uri URI.parse("https://www.googleapis.com/youtube/v3/videos")

  def unfurl(url) do
    config = Application.get_env(:web_inspector, __MODULE__)

    if config[:enabled] do
      call_api(url, config)
    end
  end

  @doc """
  Is this adapter enabled?
  """
  def enabled? do
    Application.get_env(:web_inspector, __MODULE__)[:enabled]
  end

  @doc """
  Does this adapter apply to the given URL?
  """
  def applies?(url) do
    uri = URI.parse(url)
    host = String.trim_leading(uri.host, "www.")

    host == "youtube.com" && video_id_from_url(url) != nil
  end

  defp call_api(url, config) do
    video_id = video_id_from_url(url)

    yt_api_url =
      @api_base_uri
      |> URI.append_query("part=snippet")
      |> URI.append_query("id=" <> video_id)
      |> URI.append_query("key=" <> config[:api_key])
      |> URI.to_string()

    {:ok, response} = HTTPoison.get(yt_api_url, [{"User-agent", @user_agent}], [])
    {:ok, %{"items" => [%{"snippet" => video}]}} = response.body |> Jason.decode()

    {:ok,
     %{
       title: video["title"],
       url: "https://www.youtube.com/watch?v=" <> video_id,
       description: video["description"],
       site_name: "YouTube",
       image: video["thumbnails"]["standard"]["url"],
       site_url: "https://www.youtube.com",
       icon: %{url: "https://www.youtube.com/s/desktop/103479f3/img/favicon_144x144.png"}
     }}
  end

  defp video_id_from_url(url) do
    case URI.parse(url) |> Map.get(:query) do
      nil ->
        nil

      query ->
        query
        |> URI.decode_query()
        |> Map.get("v")
    end
  end
end
