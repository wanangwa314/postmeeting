defmodule Postmeeting.Workers.CalendarSyncWorker do
  use Oban.Worker, queue: :calendar
  require Logger
  alias Postmeeting.{Repo, Calendar, Accounts}
  alias Postmeeting.Meetings.Meeting

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    with user when not is_nil(user) <- Accounts.get_user!(user_id),
         {:ok, events} <- Calendar.list_events_with_zoom(user) do
      dbg(events)

      Enum.each(events, fn event ->
        # Extract meeting details - using string keys
        start_time = parse_event_time(event["start"])

        zoom_link =
          Calendar.extract_zoom_link(event["description"]) ||
            Calendar.extract_zoom_link(event["location"])

        # If no zoom link is found, skip this event
        if zoom_link do
          meeting_params = %{
            # Store original event summary as name
            name: event["summary"],
            start_time: start_time,
            status: "scheduled",
            user_id: user_id,
            # Use zoom_link as the meeting_link
            meeting_link: zoom_link
          }

          # Check if a meeting with this link already exists
          case Repo.get_by(Meeting, meeting_link: zoom_link) do
            nil ->
              # Create new meeting
              case Meeting.changeset(%Meeting{}, meeting_params) |> Repo.insert() do
                {:ok, meeting} ->
                  Logger.info("Created new meeting: #{meeting.id} with link #{zoom_link}")
                  # Schedule bot creation
                  schedule_bot_creation(meeting)

                {:error, changeset} ->
                  Logger.error(
                    "Failed to create meeting: #{inspect(changeset.errors)} for event: #{event["summary"]}"
                  )
              end

            existing ->
              Logger.info("Meeting with link #{zoom_link} already exists: #{existing.id}")
          end
        else
          Logger.info("Skipping event without a Zoom link: #{event["summary"]}")
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

  # Updated to handle string keys from Google Calendar API
  defp parse_event_time(%{"dateTime" => datetime}) when not is_nil(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, dt, _offset} -> dt
      _error -> nil
    end
  end

  defp parse_event_time(%{"date" => date}) when not is_nil(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _error -> nil
    end
  end

  defp parse_event_time(_), do: nil
end
