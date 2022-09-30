defmodule WebInspector.Adapter.Plain do
  def call(url, headers, options) do
    HTTPoison.get(url, headers, options)
  end
end
