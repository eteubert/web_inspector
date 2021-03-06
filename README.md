# WebInspector

Elixir web inspector to unfurl URLs.

## Installation

The package can be installed by adding `web_inspector` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:web_inspector, git: "https://github.com/eteubert/web_inspector.git"}
  ]
end
```

## Usage

```elixir
WebInspector.unfurl("https://podlove.org")
{:ok,
 %{
   description: nil,
   embed: nil,
   icon: %{
     height: "32",
     type: "icon",
     url: "https://podlove.org/files/2014/06/cropped-podlove-avatar-bkd-1024-32x32.png",
     width: "32"
   },
   locations: ["https://podlove.org"],
   original_url: "https://podlove.org",
   providers: %{
     misc: %{
       "canonical_url" => nil,
       "icons" => [
         %{
           height: "32",
           type: "icon",
           url: "https://podlove.org/files/2014/06/cropped-podlove-avatar-bkd-1024-32x32.png",
           width: "32"
         },
         %{
           height: "192",
           type: "icon",
           url: "https://podlove.org/files/2014/06/cropped-podlove-avatar-bkd-1024-192x192.png",
           width: "192"
         }
       ],
       "title" => "Podlove | Personal Media Development"
     },
     oembed: %{},
     open_graph: %{},
     twitter: %{}
   },
   site_name: "podlove.org",
   site_url: "https://podlove.org",
   title: "Podlove | Personal Media Development",
   url: "https://podlove.org"
 }}
```
