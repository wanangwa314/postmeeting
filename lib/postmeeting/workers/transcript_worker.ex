defmodule Postmeeting.Workers.TranscriptWorker do
  use Oban.Worker, queue: :transcripts

  require Logger
  alias Postmeeting.Repo
  alias Postmeeting.Meetings.Meeting
  alias Postmeeting.Recall

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"meeting_id" => meeting_id}}) do
    meeting = Repo.get!(Meeting, meeting_id)

    case meeting.bot_id do
      nil ->
        {:error, "No bot ID found for meeting"}

      bot_id ->
        case Recall.get_transcript(bot_id) do
          {:ok, %{"transcript" => transcript}} when not is_nil(transcript) ->
            # Update meeting with transcript and mark as completed
            meeting
            |> Meeting.changeset(%{transcript: Jason.encode!(transcript), status: "completed"})
            |> Repo.update()

          {:ok, _} ->
            # Transcript not ready yet, retry in 30 seconds
            %{meeting_id: meeting_id}
            |> new(schedule_in: 30)
            |> Oban.insert()

            {:ok, :retry}

          {:error, error} ->
            Logger.error(
              "Failed to fetch transcript for meeting #{meeting_id}: #{inspect(error)}"
            )

            {:error, "Failed to fetch transcript"}
        end
    end
  end
end
