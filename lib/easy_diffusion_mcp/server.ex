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

    param(:use_vae_model, :string,
      required: false,
      description: "VAE model override (e.g. pig_flux_vae_fp32-f16); defaults follow the model heuristics"
    )

    param(:use_text_encoder_model, :string,
      required: false,
      description: "Text encoder override, comma-separated for multiple (e.g. qwen3_4b_f32-q8_0)"
    )

    param(:output_format, :string,
      required: false,
      description: "Image format: png (default), webp, or jpeg"
    )

    param(:save_to_disk_path, :string,
      required: false,
      description: "If set, Easy Diffusion also saves the renders to this directory on the server host"
    )

    run(fn args, state ->
      params = args |> Map.new(fn {k, v} -> {to_string(k), v} end)

      case EasyDiffusionMCP.Client.generate_images(params) do
        {:ok, [_ | _] = images} ->
          content =
            Enum.map(images, fn image ->
              data = strip_data_url(image)
              ExMCP.Content.image(data, detect_mime(data))
            end)

          {:ok, %{content: content}, state}

        {:ok, []} ->
          {:ok, "No images generated", state}

        {:error, reason} ->
          {:error, "Image generation failed: #{reason}", state}
      end
    end)
  end

  # Easy Diffusion's data-URL header does not always match the actual bytes
  # (e.g. "data:image/webp" wrapping a PNG), so sniff the base64 magic instead.
  defp detect_mime("iVBOR" <> _), do: "image/png"
  defp detect_mime("UklGR" <> _), do: "image/webp"
  defp detect_mime("/9j/" <> _), do: "image/jpeg"
  defp detect_mime(_), do: "image/png"

  # Easy Diffusion may return either raw base64 or a "data:image/png;base64,..." URL.
  defp strip_data_url("data:" <> rest) do
    case String.split(rest, ",", parts: 2) do
      [_header, data] -> data
      _ -> rest
    end
  end

  defp strip_data_url(data), do: data
end
