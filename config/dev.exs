import Config

config :web_inspector, puppeteer_enabled: false

config :web_inspector, WebInspector.Adapter.ScrapingAnt,
  enabled: true,
  proxy_country: "DE"
