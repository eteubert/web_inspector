defmodule Unfurl do
  @moduledoc """
  Documentation for Unfurl.
  """

  alias Unfurl.Parser.{OpenGraph, Twitter}

  def unfurl(url) do
    {:ok, response} = HTTPoison.get(url)
    %HTTPoison.Response{status_code: 200, headers: _headers, body: html} = response

    tasks = [
      Task.async(OpenGraph, :parse, [html]),
      Task.async(Twitter, :parse, [html])
    ]

    with [open_graph, twitter] <- Task.yield_many(tasks),
         {_, {:ok, open_graph}} <- open_graph,
         {_, {:ok, twitter}} <- twitter do
      result =
        %{providers: %{}}
        |> put_in([:providers, :open_graph], open_graph)
        |> put_in([:providers, :twitter], twitter)
        |> Map.put(:title, Map.get(open_graph, "title"))

      {:ok, result}
    end
  end
end
