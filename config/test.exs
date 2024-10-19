import Config

config :web_inspector, puppeteer_enabled: false

config :web_inspector, WebInspector.Adapter.Youtube,
  enabled: true,
  api_key: ""
