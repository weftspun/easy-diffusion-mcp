defmodule EasyDiffusionMCP.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :easy_diffusion_mcp,
      version: @version,
      elixir: "~> 1.18",
      deps: deps(),
      description: "MCP server exposing Easy Diffusion image generation as a generate_image tool",
      source_url: "https://github.com/weftspun/easy-diffusion-mcp"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {EasyDiffusionMCP.Application, []}
    ]
  end

  defp deps do
    [
      # Pinned to git main, not Hex: the published 0.12.0 hex release's HTTP
      # dispatch path (ExMCP.MessageProcessor.MethodHandlers) hardcodes a 10s
      # GenServer.call timeout on every tool call, too short for real SD
      # inference. Main branch's ExMCP.Server.Handler + ExMCP.Server.DSL
      # (tool/param/run) has no such cap — the same combination taskweft's own
      # MCP server (github.com/taskweft/taskweft) depends on for its
      # potentially-slow HTN planning tool calls.
      {:ex_mcp, github: "azmaveth/ex_mcp"},
      {:plug_cowboy, "~> 2.7"},
      {:req, "~> 0.6"},
      {:jason, "~> 1.4"}
    ]
  end
end
