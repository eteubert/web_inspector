import Config
import Dotenvy

Dotenvy.source([".env", System.get_env()])

config :web_inspector, WebInspector.Adapter.ScrapingAnt,
  api_key: Dotenvy.env!("SCRAPINGANT_API_KEY", :string)
