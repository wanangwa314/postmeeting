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
          # Update meeting with bot_id and status
          case meeting
               |> Meeting.changeset(%{bot_id: bot_id, status: "in_progress"})
               |> Repo.update() do
            {:ok, updated_meeting} ->
              Logger.info("Bot created successfully for meeting #{meeting_id}, bot_id: #{bot_id}")

              # Schedule transcript check - start checking after 1 minute to allow bot to join
              %{meeting_id: updated_meeting.id}
              |> Postmeeting.Workers.TranscriptWorker.new(schedule_in: 60)
              |> Oban.insert()

              # Also start monitoring the bot status
              %{meeting_id: updated_meeting.id}
              |> Postmeeting.Workers.BotMonitorWorker.new(schedule_in: 30)
              |> Oban.insert()

              :ok

            {:error, changeset} ->
              Logger.error("Failed to update meeting with bot_id: #{inspect(changeset.errors)}")
              {:error, "Failed to update meeting"}
          end

        {:error, error} ->
          Logger.error("Failed to create bot for meeting #{meeting_id}: #{inspect(error)}")

          # Retry bot creation in 2 minutes if it failed
          %{meeting_id: meeting_id}
          |> __MODULE__.new(schedule_in: 120)
          |> Oban.insert()

          {:error, "Failed to create bot"}
      end
    else
      Logger.info("Meeting #{meeting_id} doesn't need bot creation at this time")
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
