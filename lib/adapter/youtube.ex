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

  def enabled? do
    Application.get_env(:web_inspector, __MODULE__)[:enabled]
  end

  defp call_api(url, config) do
    video_id =
      URI.parse(url)
      |> Map.get(:query)
      |> URI.decode_query()
      |> Map.get("v")

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
       image: video["thumbnails"]["standard"],
       site_url: "https://www.youtube.com",
       icon: "https://www.youtube.com/s/desktop/103479f3/img/favicon_144x144.png"
     }}
  end
end
