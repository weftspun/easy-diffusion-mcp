defmodule EasyDiffusionMCP.Router do
  @moduledoc """
  HTTP surface for the Easy Diffusion MCP server:

    * `GET /health` — liveness check.
    * `POST /mcp` — the MCP endpoint (JSON-RPC), unauthenticated by design
      (intended for use on a trusted local network, same as the reference
      EDMCP server it mirrors).

  JSON-RPC dispatch is done here directly against the ex_mcp DSL-generated
  callbacks (`handle_list_tools/2`, `handle_call_tool/3`) rather than through
  `ExMCP.HttpPlug`: every process-based dispatch mode in ex_mcp (hex 0.12.0
  AND git main, `message_processor/method_handlers.ex`) wraps tool calls in a
  `GenServer.call(..., 10_000)`, and real Stable Diffusion renders routinely
  exceed 10 seconds. Calling the handler in-process has no artificial cap.
  """

  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  @version Mix.Project.config()[:version]
  @protocol_version "2025-03-26"

  get "/health" do
    send_json(conn, 200, %{"status" => "ok", "version" => @version})
  end

  options "/mcp" do
    conn
    |> put_cors_headers()
    |> send_resp(204, "")
  end

  post "/mcp" do
    {:ok, body, conn} = read_body(conn, length: 10_000_000)

    case Jason.decode(body) do
      {:ok, request} ->
        case handle_rpc(request) do
          :notification -> conn |> put_cors_headers() |> send_resp(202, "")
          response -> conn |> put_cors_headers() |> send_json(200, response)
        end

      {:error, _} ->
        send_json(conn, 400, rpc_error(nil, -32700, "Parse error"))
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  # ── JSON-RPC dispatch ──────────────────────────────────────────────────────

  defp handle_rpc(%{"method" => "initialize", "id" => id}) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => %{
        "protocolVersion" => @protocol_version,
        "capabilities" => %{"tools" => %{"listChanged" => false}},
        "serverInfo" => %{"name" => "easy-diffusion-mcp", "version" => @version}
      }
    }
  end

  defp handle_rpc(%{"method" => "tools/list", "id" => id}) do
    {:ok, tools, _cursor, _state} = EasyDiffusionMCP.Server.handle_list_tools(nil, %{})
    %{"jsonrpc" => "2.0", "id" => id, "result" => %{"tools" => tools}}
  end

  defp handle_rpc(%{"method" => "tools/call", "id" => id, "params" => params}) do
    name = Map.get(params, "name")
    arguments = Map.get(params, "arguments", %{})

    # The DSL-generated handle_call_tool/3 normalizes every outcome (including
    # handler errors) into {:ok, result, state} — errors arrive as a result
    # map with isError: true, so a single clause covers both.
    {:ok, result, _state} = EasyDiffusionMCP.Server.handle_call_tool(name, arguments, %{})
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  defp handle_rpc(%{"method" => "ping", "id" => id}) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => %{}}
  end

  # Notifications (no id) get no response body.
  defp handle_rpc(%{"method" => _method} = request) when not is_map_key(request, "id") do
    :notification
  end

  defp handle_rpc(%{"method" => method, "id" => id}) do
    rpc_error(id, -32601, "Method not found: #{method}")
  end

  defp handle_rpc(_), do: rpc_error(nil, -32600, "Invalid Request")

  defp rpc_error(id, code, message) do
    %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}}
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  defp put_cors_headers(conn) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type, accept, mcp-session-id")
  end

  defp send_json(conn, status, map) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(map))
  end
end
