defmodule Unfurl do
  @moduledoc """
  Documentation for Unfurl.
  """

  def unfurl(url) do
    {:ok, response} = HTTPoison.get(url)
    %HTTPoison.Response{status_code: 200, headers: _headers, body: html} = response

    title =
      Floki.find(html, "meta[property=\"og:title\"")
      |> Floki.attribute("content")
      |> hd

    result = %{title: title}
    {:ok, result}
  end
end
