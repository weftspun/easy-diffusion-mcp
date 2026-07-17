defmodule EasyDiffusionMCP.Server do
  @moduledoc """
  MCP server exposing a single `generate_image` tool that proxies to a local
  Easy Diffusion server's `/render` API (default `http://localhost:9000`,
  override with `EASY_DIFFUSION_API_URL`).

  Mirrors the tool surface of the reference implementation
  (github.com/AvidGameFan/EDMCP): same parameters and defaults, so existing
  prompts/clients built against it work unchanged here.
  """

  use ExMCP.Server.Handler
  use ExMCP.Server.DSL, name: "easy-diffusion-mcp"

  tool "generate_image", "Generate an image using Easy Diffusion based on a text prompt" do
    param(:prompt, :string,
      required: true,
      description: "The text prompt describing the image to generate"
    )

    param(:negative_prompt, :string,
      required: false,
      description: "What to avoid in the generated image (optional)"
    )

    param(:width, :integer, required: false, description: "Image width in pixels")
    param(:height, :integer, required: false, description: "Image height in pixels")
    param(:num_outputs, :integer, required: false, description: "Number of images to generate")

    param(:num_inference_steps, :integer,
      required: false,
      description: "Number of inference steps"
    )

    param(:guidance_scale, :number,
      required: false,
      description: "Guidance scale for prompt adherence"
    )

    param(:seed, :integer, required: false, description: "Random seed (-1 for random)")
    param(:sampler_name, :string, required: false, description: "Sampler algorithm")

    param(:use_stable_diffusion_model, :string,
      required: false,
      description:
        "Model to use - specify type (such as SDXL or Flux) or specific model (such as animagineXL40_v4Opt)"
    )

    run(fn args, state ->
      params = args |> Map.new(fn {k, v} -> {to_string(k), v} end)

      case EasyDiffusionMCP.Client.generate_images(params) do
        {:ok, [first_image | _]} ->
          base64_data = strip_data_url(first_image)
          {:ok, %{content: [ExMCP.Content.image(base64_data, "image/png")]}, state}

        {:ok, []} ->
          {:ok, "No images generated", state}

        {:error, reason} ->
          {:error, "Image generation failed: #{reason}", state}
      end
    end)
  end

  # Easy Diffusion may return either raw base64 or a "data:image/png;base64,..." URL.
  defp strip_data_url("data:" <> rest) do
    case String.split(rest, ",", parts: 2) do
      [_header, data] -> data
      _ -> rest
    end
  end

  defp strip_data_url(data), do: data
end
