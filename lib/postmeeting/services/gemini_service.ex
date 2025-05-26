defmodule Postmeeting.Services.GeminiService do
  alias Tesla
  alias Jason

  @gemini_api_key Application.compile_env(:postmeeting, [:api_keys, :gemini])
  @gemini_base_url "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash"

  @doc """
  Generates a social media post based on the provided meeting transcript using the Gemini API.
  Uses Tesla with Hackney adapter.
  """
  def generate_post_from_transcript(transcript_text) do
    prompt =
      "Generate a concise and engaging social media post summarizing the key points of the following meeting transcript:

#{transcript_text}"

    generate_content(prompt)
  end

  @doc """
  Generates content based on the provided prompt using the Gemini API.
  Uses Tesla with Hackney adapter.
  """
  def generate_content(prompt) do
    body = %{
      "contents" => [
        %{
          "parts" => [
            %{"text" => prompt}
          ]
        }
      ]
    }

    middleware = [
      {Tesla.Middleware.BaseUrl, @gemini_base_url},
      Tesla.Middleware.JSON
    ]

    client =
      Tesla.client(
        middleware,
        {Tesla.Adapter.Hackney, [recv_timeout: 30_000, connect_timeout: 15_000]}
      )

    case Tesla.post(client, ":generateContent?key=#{@gemini_api_key}", body) do
      {:ok, %Tesla.Env{status: 200, body: resp_body}} ->
        # resp_body is already decoded by Tesla.Middleware.JSON
        handle_successful_response(resp_body)

      {:ok, %Tesla.Env{status: status_code, body: error_body}} ->
        {:error, "Gemini API request failed with status #{status_code}: #{inspect(error_body)}"}

      {:error, reason} ->
        {:error, "HTTP request to Gemini API failed: #{inspect(reason)}"}
    end
  end

  defp handle_successful_response(parsed_resp) when is_map(parsed_resp) do
    # Extract text from candidates -> content -> parts -> text
    # Structure: %{"candidates" => [%{"content" => %{"parts" => [%{"text" => "..."}]}}]}
    text =
      parsed_resp
      |> get_in(["candidates", Access.at(0), "content", "parts", Access.at(0), "text"])

    if text do
      {:ok, text}
    else
      {:error, "Failed to extract text from Gemini response: #{inspect(parsed_resp)}"}
    end
  end

  defp handle_successful_response(_other_body) do
    {:error, "Gemini API response body was not a map."}
  end
end
