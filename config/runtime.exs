import Config

Dotenvy.source!([".env", System.get_env()])

if Mix.env() != :test do
  config :web_inspector, WebInspector.Adapter.ScrapingAnt,
    enabled: Dotenvy.env!("SCRAPINGANT_ENABLED", :string, false),
    api_key: Dotenvy.env!("SCRAPINGANT_API_KEY", :string)

  config :web_inspector, WebInspector.Adapter.Youtube,
    enabled: Dotenvy.env!("YOUTUBE_ENABLED", :string, false),
    api_key: Dotenvy.env!("YOUTUBE_API_KEY", :string)
end
