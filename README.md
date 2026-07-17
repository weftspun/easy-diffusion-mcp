# easy-diffusion-mcp

MCP server for [Easy Diffusion](https://github.com/easydiffusion/easydiffusion), in Elixir.

Exposes one tool, `generate_image`, over the MCP HTTP transport (JSON-RPC +
SSE, via [`ex_mcp`](https://hex.pm/packages/ex_mcp)). It proxies to a running
Easy Diffusion server's `/render` API, matching the request shape, model-name
heuristics (`anime`/`sdxl`/`sd`/`flux`/`chroma` aliases, per-model
`clip_skip`/VAE/step-count adjustments), and streamed-result polling of the
reference implementation, [AvidGameFan/EDMCP](https://github.com/AvidGameFan/EDMCP)
(C#/.NET).

No authentication — this is meant for a trusted local network, same as the
reference server.

## Running

```sh
mix deps.get
EASY_DIFFUSION_API_URL=http://localhost:9000 mix run --no-halt
```

The server listens on `:5242` by default (`PORT` to override) and serves the
MCP endpoint at `/mcp`.

## Configuring an MCP client

```json
{
  "mcpServers": {
    "easy-diffusion-mcp": {
      "url": "http://localhost:5242/mcp"
    }
  }
}
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `5242` | HTTP listen port |
| `EASY_DIFFUSION_API_URL` | `http://localhost:9000` | Easy Diffusion server address |
| `DEFAULT_MODEL` | `animagineXL40_v4Opt` | Default `use_stable_diffusion_model` |

See https://github.com/taskweft/taskweft for the sibling MCP-over-Elixir HTN
planner project this server's structure follows.
