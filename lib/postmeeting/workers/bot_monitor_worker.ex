defmodule Postmeeting.Workers.BotMonitorWorker do
  use Oban.Worker, queue: :monitoring, max_attempts: 5

  require Logger
  alias Postmeeting.Repo
  alias Postmeeting.Meetings.Meeting
  alias Postmeeting.Recall

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"meeting_id" => meeting_id}}) do
    meeting = Repo.get!(Meeting, meeting_id)

    case meeting.bot_id do
      nil ->
        Logger.info("No bot to monitor for meeting #{meeting_id}")
        :ok

      bot_id ->
        case Recall.get_bot(bot_id) do
          {:ok, %{"status" => "ACTIVE"}} ->
            Logger.info("Bot #{bot_id} is active for meeting #{meeting_id}")

            # Schedule next check in 2 minutes
            %{meeting_id: meeting_id}
            |> __MODULE__.new(schedule_in: 120)
            |> Oban.insert()

            :ok

          {:ok, %{"status" => "DONE"}} ->
            Logger.info("Bot #{bot_id} has finished for meeting #{meeting_id}")

            # Bot is done, start transcript checking immediately
            %{meeting_id: meeting_id}
            |> Postmeeting.Workers.TranscriptWorker.new(schedule_in: 5)
            |> Oban.insert()

            :ok

          {:ok, %{"status" => status}} when status in ["FAILED", "CANCELLED"] ->
            Logger.warning(
              "Bot #{bot_id} failed or was cancelled for meeting #{meeting_id}, status: #{status}"
            )

            # Mark meeting as completed without transcript
            meeting
            |> Meeting.changeset(%{status: "completed"})
            |> Repo.update()

            :ok

          {:ok, %{"status" => status}} ->
            Logger.info(
              "Bot #{bot_id} status: #{status} for meeting #{meeting_id}, continuing to monitor"
            )

            # Continue monitoring
            %{meeting_id: meeting_id}
            |> __MODULE__.new(schedule_in: 120)
            |> Oban.insert()

            :ok

          {:error, %{status: 404}} ->
            Logger.warning(
              "Bot #{bot_id} not found for meeting #{meeting_id}, may have been deleted"
            )

            # Mark meeting as completed without transcript
            meeting
            |> Meeting.changeset(%{status: "completed"})
            |> Repo.update()

            :ok

          {:error, error} ->
            Logger.error("Error checking bot status for meeting #{meeting_id}: #{inspect(error)}")

            # Retry monitoring in 5 minutes
            %{meeting_id: meeting_id}
            |> __MODULE__.new(schedule_in: 300)
            |> Oban.insert()

            {:error, "Failed to check bot status"}
        end
    end
  end
end
