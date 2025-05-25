defmodule Postmeeting.Workers.MeetingBotWorker do
  use Oban.Worker, queue: :meetings

  require Logger
  alias Postmeeting.Repo
  alias Postmeeting.Meetings.Meeting
  alias Postmeeting.Recall

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"meeting_id" => meeting_id}}) do
    meeting = Repo.get!(Meeting, meeting_id)

    # Only create bot for meetings that are about to start and don't have a bot yet
    if should_create_bot?(meeting) do
      case Recall.create_bot(meeting.meeting_link, meeting.name) do
        {:ok, %{"id" => bot_id}} ->
          meeting
          |> Meeting.changeset(%{bot_id: bot_id, status: "in_progress"})
          |> Repo.update()

          # Schedule transcript check after some time
          %{meeting_id: meeting_id}
          |> Postmeeting.Workers.TranscriptWorker.new(schedule_in: 30)
          |> Oban.insert()

          :ok

        {:error, error} ->
          Logger.error("Failed to create bot for meeting #{meeting_id}: #{inspect(error)}")
          {:error, "Failed to create bot"}
      end
    else
      :ok
    end
  end

  defp should_create_bot?(
         %Meeting{bot_id: nil, status: "scheduled", meeting_link: meeting_link} = meeting
       )
       when not is_nil(meeting_link) do
    # Check if meeting is starting within the next 5 minutes
    start_time = DateTime.to_unix(meeting.start_time)
    now = DateTime.to_unix(DateTime.utc_now())
    start_time - now <= 300 && start_time - now > 0
  end

  defp should_create_bot?(_), do: false
end
