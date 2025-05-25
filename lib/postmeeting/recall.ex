defmodule Postmeeting.Recall do
  @moduledoc """
  Module for interacting with the Recall.ai API
  """

  use Tesla

  @base_url "https://api.recall.ai/api/v1"

  # Tesla middleware setup
  plug Tesla.Middleware.BaseUrl, @base_url

  plug Tesla.Middleware.Headers, [
    {"authorization", "Token " <> (Application.get_env(:postmeeting, :recall)[:api_key] || "")}
  ]

  plug Tesla.Middleware.JSON

  @doc """
  Creates a new bot for a video call.

  ## Parameters
  - meeting_url: The URL of the meeting to join
  - title: Optional title for the bot

  ## Examples
      iex> create_bot("https://zoom.us/j/123456789", "My Meeting")
      {:ok, %{"id" => "bot_123", "status" => "WAITING"}}
  """
  def create_bot(meeting_url, title \\ nil) do
    post("/bot", %{
      "meeting_url" => meeting_url,
      "bot_name" => title || "Meeting Notetaker",
      "transcription_options" => %{"provider" => "meeting_captions"}
    })
    |> handle_response()
  end

  @doc """
  Gets the status of a bot by its ID.

  ## Examples
      iex> get_bot("bot_123")
      {:ok, %{"id" => "bot_123", "status" => "ACTIVE"}}
  """
  def get_bot(bot_id) do
    get("/bot/#{bot_id}")
    |> handle_response()
  end

  @doc """
  Lists all bots with optional filtering.

  ## Parameters
  - status: Optional filter by bot status ("active", "done", etc.)
  - limit: Optional limit for number of results (default 100)
  - offset: Optional offset for pagination

  ## Examples
      iex> list_bots(status: "active", limit: 10)
      {:ok, [%{"id" => "bot_123", "status" => "ACTIVE"}]}
  """
  def list_bots(opts \\ []) do
    get("/bot", query: opts)
    |> handle_response()
  end

  @doc """
  Deletes a bot by its ID.

  ## Examples
      iex> delete_bot("bot_123")
      {:ok, %{}}
  """
  def delete_bot(bot_id) do
    delete("/bot/#{bot_id}")
    |> handle_response()
  end

  @doc """
  Gets the transcript of a bot recording.

  ## Examples
      iex> get_transcript("bot_123")
      {:ok, %{"transcript" => [%{"text" => "Hello", "timestamp" => 0.0}]}}
  """
  def get_transcript(bot_id) do
    get("/bot/#{bot_id}/transcript")
    |> handle_response()
  end

  # Private helper to handle Tesla responses
  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, _reason} = error) do
    error
  end
end
