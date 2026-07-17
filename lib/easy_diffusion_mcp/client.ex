defmodule EasyDiffusionMCP.Client do
  @moduledoc """
  HTTP client for a local Easy Diffusion server's `/render` API.

  Mirrors the request-shaping and model-name heuristics of the reference
  implementation (github.com/AvidGameFan/EDMCP, C#/.NET): per-model
  `clip_skip`, VAE/text-encoder overrides for flux/chroma, reduced step
  counts for flash/turbo/lightning variants, and the `anime`/`sdxl`/`sd`/
  `flux`/`chroma` model-name aliases.

  Easy Diffusion answers `/render` one of three ways, all handled here:
  a synchronous `"images"` array, a `"stream"` URL to poll for progress,
  or an `"output"` array (list of strings or `%{"data" => ...}` objects).
  """

  @poll_interval_ms 1_000
  @poll_max_attempts 300
  @poll_timeout_ms 300_000

  @doc "Base URL of the Easy Diffusion server, e.g. \"http://localhost:9000\"."
  def base_url do
    url = System.get_env("EASY_DIFFUSION_API_URL", "http://localhost:9000")
    if String.starts_with?(url, "http"), do: url, else: "http://" <> url
  end

  @doc """
  Generate images from `params` (a map with string keys matching the
  `generate_image` tool's arguments). Returns `{:ok, [base64_png, ...]}` or
  `{:error, reason}`.
  """
  def generate_images(params) do
    payload = build_payload(params)
    url = String.trim_trailing(base_url(), "/") <> "/render"

    case Req.post(url, json: payload, receive_timeout: @poll_timeout_ms) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        extract_images(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Easy Diffusion returned HTTP #{status}: #{inspect(body)}"}

      {:error, exception} ->
        {:error, "Easy Diffusion request failed: #{Exception.message(exception)}"}
    end
  end

  defp build_payload(params) do
    model = Map.get(params, "use_stable_diffusion_model", default_model())
    steps = Map.get(params, "num_inference_steps", 25)
    guidance = Map.get(params, "guidance_scale", 7.5)
    seed = Map.get(params, "seed", -1)

    negative_prompt =
      case Map.get(params, "negative_prompt") do
        nil -> "worst quality, low quality, low score"
        "" -> "worst quality, low quality, low score"
        "none" -> ""
        np -> np
      end

    %{
      "prompt" => Map.fetch!(params, "prompt"),
      "negative_prompt" => negative_prompt,
      "width" => Map.get(params, "width", 1280),
      "height" => Map.get(params, "height", 960),
      "num_outputs" => Map.get(params, "num_outputs", 1),
      "num_inference_steps" => steps,
      "guidance_scale" => min(guidance, 7.5),
      "seed" => if(seed == -1, do: 1, else: seed),
      "used_random_seed" => seed == -1,
      "sampler_name" => Map.get(params, "sampler_name", "deis"),
      "scheduler_name" => "simple",
      "use_stable_diffusion_model" => model,
      "use_vae_model" => "",
      "clip_skip" => false,
      "enable_vae_tiling" => true,
      "vram_usage_level" => "low",
      "output_format" => "png",
      "output_quality" => 75,
      "output_lossless" => false,
      "stream_progress_updates" => true,
      "stream_image_progress" => false,
      "show_only_filtered_image" => true,
      "block_nsfw" => false,
      "metadata_output_format" => "none",
      "session_id" => Integer.to_string(System.system_time(:millisecond))
    }
    |> apply_model_heuristics(model, steps)
    |> resolve_model_alias(model)
  end

  defp default_model, do: System.get_env("DEFAULT_MODEL", "animagineXL40_v4Opt")

  defp apply_model_heuristics(payload, model, steps) do
    model_lower = String.downcase(model)

    payload =
      if String.contains?(model_lower, "animaginexl") or String.contains?(model_lower, "pony") or
           String.contains?(model_lower, "illustrious") do
        Map.put(payload, "clip_skip", true)
      else
        payload
      end

    payload =
      if String.contains?(model_lower, "flash") or String.contains?(model_lower, "turbo") or
           String.contains?(model_lower, "schnell") or String.contains?(model_lower, "lightning") do
        Map.put(payload, "num_inference_steps", min(steps, 12))
      else
        payload
      end

    payload =
      if String.contains?(model_lower, "flux") do
        payload
        |> Map.put("use_vae_model", "ae")
        |> Map.put("guidance_scale", 1)
        |> Map.put("use_text_encoder_model", ["clip_l", "t5xxl_fp16"])
      else
        payload
      end

    if String.contains?(model_lower, "chroma") do
      guidance = if String.contains?(model_lower, "flash"), do: 1, else: 4

      payload
      |> Map.put("use_vae_model", "ae")
      |> Map.put("guidance_scale", guidance)
      |> Map.put("use_text_encoder_model", "t5xxl_fp16")
    else
      payload
    end
  end

  @model_aliases %{
    "anime" => "animagineXL_v4Opt",
    "sdxl" => "sd_xl_base_1.0_0.9vae",
    "sd" => "sd-v1-5",
    "flux" => "flux1-dev-bnb-nf4-v2",
    "chroma" => "Chroma1-HD-Q6_K"
  }

  defp resolve_model_alias(payload, model) do
    case Map.get(@model_aliases, String.downcase(model)) do
      nil -> payload
      resolved -> Map.put(payload, "use_stable_diffusion_model", resolved)
    end
  end

  defp extract_images(%{"images" => images}) when is_list(images), do: {:ok, images}

  defp extract_images(%{"stream" => stream_url}) when is_binary(stream_url) do
    url =
      if String.starts_with?(stream_url, "/"),
        do: String.trim_trailing(base_url(), "/") <> stream_url,
        else: stream_url

    poll_stream(url, 0, System.monotonic_time(:millisecond))
  end

  defp extract_images(%{"output" => output}) when is_list(output) do
    {:ok, Enum.map(output, &output_item_to_image/1)}
  end

  defp extract_images(body), do: {:error, "No images in Easy Diffusion response: #{inspect(body)}"}

  defp output_item_to_image(%{"data" => data}), do: data
  defp output_item_to_image(item) when is_binary(item), do: item

  defp poll_stream(_url, attempts, _start) when attempts >= @poll_max_attempts do
    {:error, "Maximum polling attempts reached (#{@poll_max_attempts})"}
  end

  defp poll_stream(url, attempts, start) do
    if System.monotonic_time(:millisecond) - start > @poll_timeout_ms do
      {:error, "Generation timed out after #{@poll_timeout_ms}ms"}
    else
      case Req.get(url) do
        {:ok, %Req.Response{body: body}} ->
          handle_poll_body(body, url, attempts, start)

        {:error, _exception} ->
          Process.sleep(@poll_interval_ms)
          poll_stream(url, attempts + 1, start)
      end
    end
  end

  defp handle_poll_body(body, url, attempts, start) do
    case parse_poll_status(body) do
      {:succeeded, payload} ->
        extract_images(payload)

      {:failed, reason} ->
        {:error, "Generation failed: #{reason}"}

      :pending ->
        Process.sleep(@poll_interval_ms)
        poll_stream(url, attempts + 1, start)
    end
  end

  # Easy Diffusion streams newline-delimited JSON; only the last well-formed
  # line reflects the current status.
  defp parse_poll_status(body) when is_map(body) do
    case Map.get(body, "status") do
      "succeeded" -> {:succeeded, body}
      "failed" -> {:failed, Map.get(body, "detail", "Unknown error")}
      _ -> :pending
    end
  end

  defp parse_poll_status(body) when is_binary(body) do
    body
    |> String.trim()
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(:pending, fn line ->
      case Jason.decode(line) do
        {:ok, decoded} ->
          case parse_poll_status(decoded) do
            :pending -> nil
            result -> result
          end

        {:error, _} ->
          nil
      end
    end)
  end

  defp parse_poll_status(_body), do: :pending
end
