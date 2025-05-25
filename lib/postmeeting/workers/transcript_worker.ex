defmodule Postmeeting.Workers.TranscriptWorker do
  use Oban.Worker, queue: :transcripts, max_attempts: 20

  require Logger
  alias Postmeeting.Repo
  alias Postmeeting.Meetings.Meeting
  alias Postmeeting.Recall

  # Maximum time to wait for transcript (2 hours)
  @max_wait_time 2 * 60 * 60
  # Initial retry interval (30 seconds)
  @initial_retry_interval 30
  # Maximum retry interval (5 minutes)
  @max_retry_interval 300

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"meeting_id" => meeting_id}} = job) do
    meeting = Repo.get!(Meeting, meeting_id)

    case meeting.bot_id do
      nil ->
        Logger.error("No bot ID found for meeting #{meeting_id}")
        {:error, "No bot ID found for meeting"}

      bot_id ->
        # Check if we've been waiting too long
        if exceeded_max_wait_time?(meeting) do
          Logger.warning(
            "Max wait time exceeded for meeting #{meeting_id}, marking as completed without transcript"
          )

          meeting
          |> Meeting.changeset(%{status: "completed"})
          |> Repo.update()

          {:ok, :timeout}
        else
          fetch_and_process_transcript(meeting, bot_id, job)
        end
    end
  end

  defp fetch_and_process_transcript(meeting, bot_id, job) do
    case Recall.get_transcript(bot_id) do
      {:ok, %{"transcript" => transcript}} when is_list(transcript) and length(transcript) > 0 ->
        # We have a non-empty transcript
        Logger.info(
          "Transcript received for meeting #{meeting.id}, #{length(transcript)} segments"
        )

        meeting
        |> Meeting.changeset(%{
          transcript: Jason.encode!(transcript),
          status: "completed"
        })
        |> Repo.update()

        {:ok, :completed}

      {:ok, %{"transcript" => []}} ->
        # Empty transcript - reschedule
        Logger.info("Empty transcript for meeting #{meeting.id}, rescheduling check")
        reschedule_transcript_check(meeting.id, job)

      {:ok, %{"transcript" => nil}} ->
        # Null transcript - reschedule
        Logger.info("Null transcript for meeting #{meeting.id}, rescheduling check")
        reschedule_transcript_check(meeting.id, job)

      {:ok, response} ->
        # Unexpected response format - reschedule
        Logger.warning(
          "Unexpected transcript response for meeting #{meeting.id}: #{inspect(response)}, rescheduling"
        )

        reschedule_transcript_check(meeting.id, job)

      {:error, %{status: 404}} ->
        # Bot not found or transcript not available yet - reschedule
        Logger.info("Transcript not available yet for meeting #{meeting.id} (404), rescheduling")
        reschedule_transcript_check(meeting.id, job)

      {:error, %{status: status}} when status in [429, 500, 502, 503, 504] ->
        # Temporary API errors - reschedule with backoff
        Logger.warning("Temporary API error #{status} for meeting #{meeting.id}, rescheduling")
        reschedule_transcript_check(meeting.id, job)

      {:error, error} ->
        # Other errors - log and reschedule
        Logger.error(
          "Error fetching transcript for meeting #{meeting.id}: #{inspect(error)}, rescheduling"
        )

        reschedule_transcript_check(meeting.id, job)
    end
  end

  defp reschedule_transcript_check(meeting_id, job) do
    retry_interval = calculate_retry_interval(job.attempt)

    Logger.info(
      "Rescheduling transcript check for meeting #{meeting_id} in #{retry_interval} seconds (attempt #{job.attempt})"
    )

    %{meeting_id: meeting_id}
    |> __MODULE__.new(schedule_in: retry_interval)
    |> Oban.insert()

    {:ok, :rescheduled}
  end

  defp calculate_retry_interval(attempt) do
    # Exponential backoff with jitter, capped at max interval
    base_interval = @initial_retry_interval * :math.pow(1.5, attempt - 1)
    # Random jitter of -5 to +5 seconds
    jitter = :rand.uniform(10) - 5

    min(@max_retry_interval, round(base_interval) + jitter)
  end

  defp exceeded_max_wait_time?(meeting) do
    # Calculate time since meeting started
    now = DateTime.utc_now()
    meeting_start = meeting.start_time
    time_since_start = DateTime.diff(now, meeting_start, :second)

    time_since_start > @max_wait_time
  end
end
