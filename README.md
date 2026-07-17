# easy-diffusion-mcp

MCP server for [Easy Diffusion](https://github.com/easydiffusion/easydiffusion), in Elixir. Exposes one tool, `generate_image`, proxying to a local Easy Diffusion `/render` API. No authentication — trusted local network only.

```sh
mix deps.get
EASY_DIFFUSION_API_URL=http://localhost:9000 mix run --no-halt
```

MCP endpoint: `http://localhost:5242/mcp` (`PORT` to change). `DEFAULT_MODEL` sets the default `use_stable_diffusion_model`.
