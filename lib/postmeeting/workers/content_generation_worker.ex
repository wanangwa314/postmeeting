defmodule Postmeeting.Workers.ContentGenerationWorker do
  use Oban.Worker, queue: :content_generation, max_attempts: 3

  require Logger
  alias Postmeeting.Repo
  alias Postmeeting.Meetings.Meeting
  alias Postmeeting.ContentSettings
  alias Postmeeting.Services.GeminiService

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"meeting_id" => meeting_id}}) do
    meeting = Repo.get!(Meeting, meeting_id)

    case meeting.transcript do
      nil ->
        Logger.warning(
          "No transcript available for meeting #{meeting_id}, skipping content generation"
        )

        :ok

      transcript when is_binary(transcript) or is_map(transcript) ->
        Logger.info("Starting content generation for meeting #{meeting_id}")

        # Get the meeting owner's content settings
        user_id = meeting.user_id
        generation_settings = ContentSettings.list_user_generation_settings(user_id)

        # Generate content for each configured platform
        results =
          generation_settings
          |> Enum.map(&generate_content_for_platform(meeting, &1))
          |> Enum.filter(fn {_platform, result} -> result != :skip end)

        # Update the meeting with generated content
        if Enum.any?(results, fn {_platform, result} -> match?({:ok, _}, result) end) do
          update_meeting_with_content(meeting, results)
        else
          Logger.warning("No content was successfully generated for meeting #{meeting_id}")
          :ok
        end

      _ ->
        Logger.error("Invalid transcript format for meeting #{meeting_id}")
        {:error, "Invalid transcript format"}
    end
  end

  defp generate_content_for_platform(meeting, generation_setting) do
    platform = generation_setting.platform

    Logger.info(
      "Generating #{platform} content for meeting #{meeting.id} using setting '#{generation_setting.name}'"
    )

    # Convert transcript to string if it's a map
    transcript_text = extract_transcript_text(meeting.transcript)

    # Build prompt from generation setting's description and example
    prompt = """
    Task: Generate content for #{platform} based on the following requirements:

    #{generation_setting.description}

    Example format:
    #{generation_setting.example}

    Meeting Details:
    - Name: #{meeting.name}
    - Date: #{meeting.start_time}

    Meeting Transcript:
    #{transcript_text}

    Please generate content that follows the description and example format provided above.
    """

    case GeminiService.generate_content(prompt) |> dbg() do
      {:ok, generated_content} ->
        Logger.info("Successfully generated #{platform} content for meeting #{meeting.id}")
        {platform, {:ok, generated_content}}

      {:error, error} ->
        Logger.error(
          "Failed to generate #{platform} content for meeting #{meeting.id}: #{inspect(error)}"
        )

        {platform, {:error, error}}
    end
  end

  defp extract_transcript_text(transcript) when is_binary(transcript), do: transcript

  defp extract_transcript_text(transcript) when is_map(transcript) do
    cond do
      # If it's a map with a "text" key
      Map.has_key?(transcript, "text") ->
        transcript["text"]

      # If it's a map with string content directly
      is_binary(transcript["content"]) ->
        transcript["content"]

      # If it's a map with segments/entries, concatenate them
      is_list(transcript["segments"]) ->
        transcript["segments"]
        |> Enum.map(fn segment -> segment["text"] || "" end)
        |> Enum.join(" ")

      # Try to convert the whole map to string as fallback
      true ->
        inspect(transcript)
    end
  end

  defp extract_transcript_text(_), do: ""

  defp update_meeting_with_content(meeting, results) do
    # Build update attributes from successful generations
    update_attrs =
      results
      |> Enum.reduce(%{}, fn
        {platform, {:ok, content}}, acc ->
          case String.downcase(platform) do
            "email" -> Map.put(acc, :email, content)
            "facebook" -> Map.put(acc, :facebook_post, content)
            "linkedin" -> Map.put(acc, :linkedin_post, content)
            _ -> acc
          end

        {_platform, {:error, _}}, acc ->
          acc
      end)

    # Always set status to completed, regardless of content generation success
    update_attrs = Map.put(update_attrs, :status, "completed")

    case meeting
         |> Meeting.changeset(update_attrs)
         |> Repo.update() do
      {:ok, _updated_meeting} ->
        content_keys = Map.keys(update_attrs) -- [:status]

        if length(content_keys) > 0 do
          Logger.info(
            "Successfully updated meeting #{meeting.id} with generated content: #{Enum.join(content_keys, ", ")} and marked as completed"
          )
        else
          Logger.info("Meeting #{meeting.id} marked as completed with no additional content")
        end

        :ok

      {:error, changeset} ->
        Logger.error("Failed to update meeting #{meeting.id}: #{inspect(changeset.errors)}")
        {:error, "Failed to update meeting"}
    end
  end
end
