defmodule MiscTest do
  use ExUnit.Case
  doctest WebInspector.Parser.Misc

  @url "https://example.com"

  test "finds apple touch icons" do
    icon =
      ~S(<link rel="apple-touch-icon" href="https://abs.twimg.com/icons/apple-touch-icon-192x192.png" sizes="192x192">)

    {:misc, result} = WebInspector.Parser.Misc.parse(icon, @url)
    icons = Map.get(result, "icons")

    assert is_list(icons)
    assert length(icons) == 1

    assert hd(icons) == %{
             type: "icon",
             width: "192",
             height: "192",
             url: "https://abs.twimg.com/icons/apple-touch-icon-192x192.png"
           }
  end
end
