defmodule EasyDiffusionMCP.Router do
  @moduledoc """
  HTTP surface for the Easy Diffusion MCP server:

    * `GET /health` — liveness check.
    * `/mcp` (any sub-path) — the MCP endpoint (`ExMCP.HttpPlug`), unauthenticated
      by design (intended for use on a trusted local network, same as the
      reference EDMCP server it mirrors).
  """

  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  @version Mix.Project.config()[:version]

  @mcp_init [
    handler: EasyDiffusionMCP.Server,
    server_info: %{name: "easy-diffusion-mcp", version: @version},
    tools: [],
    sse_enabled: true,
    cors_enabled: true,
    allowed_origins: :any,
    validate_origin: false
  ]

  get "/health" do
    send_json(conn, 200, %{"status" => "ok", "version" => @version})
  end

  forward("/mcp", to: ExMCP.HttpPlug, init_opts: @mcp_init)

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp send_json(conn, status, map) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(map))
  end
end
