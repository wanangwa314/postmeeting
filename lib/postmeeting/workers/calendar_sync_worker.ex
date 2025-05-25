defmodule Postmeeting.Workers.CalendarSyncWorker do
  use Oban.Worker, queue: :calendar

  require Logger
  alias Postmeeting.{Repo, Calendar, Accounts}
  alias Postmeeting.Meetings.Meeting

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    with user when not is_nil(user) <- Accounts.get_user!(user_id),
         {:ok, events} <- Calendar.list_events_with_zoom(user) do
      Enum.each(events, fn event ->
        # Extract meeting details
        start_time = parse_event_time(event.start)

        # Create or update meeting
        meeting_params = %{
          name:
            event.summary <>
              " - " <> (Calendar.extract_zoom_link(event.description) || "No Zoom link"),
          start_time: start_time,
          status: "scheduled",
          user_id: user_id
        }

        case Repo.get_by(Meeting, name: event.summary, start_time: start_time, user_id: user_id) do
          nil ->
            # Create new meeting
            {:ok, meeting} = Meeting.changeset(%Meeting{}, meeting_params) |> Repo.insert()
            Logger.info("Created new meeting: #{meeting.id}")

            # Schedule bot creation
            schedule_bot_creation(meeting)

          existing ->
            Logger.info("Meeting already exists: #{existing.id}")
        end
      end)

      :ok
    else
      nil ->
        Logger.error("User #{user_id} not found")
        {:error, :user_not_found}

      {:error, reason} ->
        Logger.error("Failed to fetch calendar events: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Schedule bot creation job to run 5 minutes before meeting start
  defp schedule_bot_creation(meeting) do
    now = DateTime.utc_now()
    start_time = meeting.start_time

    # Schedule 5 minutes before meeting
    schedule_time = DateTime.add(start_time, -5 * 60, :second)

    if DateTime.compare(schedule_time, now) == :gt do
      %{meeting_id: meeting.id}
      |> Postmeeting.Workers.MeetingBotWorker.new(
        schedule_in: DateTime.diff(schedule_time, now, :second)
      )
      |> Oban.insert()
    end
  end

  defp parse_event_time(%{dateTime: datetime}) when not is_nil(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, dt, _offset} -> dt
      _error -> nil
    end
  end

  defp parse_event_time(%{date: date}) when not is_nil(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _error -> nil
    end
  end

  defp parse_event_time(_), do: nil
end
