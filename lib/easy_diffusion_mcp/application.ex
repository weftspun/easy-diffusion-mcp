defmodule EasyDiffusionMCP.Application do
  @moduledoc """
  OTP application: starts a Cowboy endpoint serving the Easy Diffusion MCP
  server over HTTP.

  Runtime env:

    * `PORT` — listen port (default `5242`, matching the reference EDMCP server).
    * `EASY_DIFFUSION_API_URL` — Easy Diffusion server address (default `http://localhost:9000`).
    * `DEFAULT_MODEL` — default `use_stable_diffusion_model` when the tool call omits one.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT", "5242"))

    Logger.info(
      "easy-diffusion-mcp listening on 0.0.0.0:#{port}, backend #{EasyDiffusionMCP.Client.base_url()}"
    )

    children = [
      {Plug.Cowboy,
       scheme: :http,
       plug: EasyDiffusionMCP.Router,
       options: [port: port, ip: {0, 0, 0, 0}]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EasyDiffusionMCP.Supervisor)
  end
end
