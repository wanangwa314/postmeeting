defmodule Postmeeting.Calendar do
  @moduledoc """
  The Calendar context.
  """

  alias Postmeeting.Accounts

  @doc """
  Lists calendar events with Zoom links for a user.
  Fetches events from the past week up to 1 month in the future.
  """
  def list_events_with_zoom(user) do
    with {:ok, google_account} <- get_google_account(user),
         {:ok, events} <- fetch_events(google_account.access_token) do
      {:ok, filter_zoom_events(events)}
    end
  end

  @doc """
  Formats a timestamp relative to now, like "2 hours ago" or "3 days ago"
  """
  def format_relative_time(datetime) when is_struct(datetime, NaiveDateTime) do
    # Convert NaiveDateTime to DateTime in UTC
    {:ok, datetime_utc} = DateTime.from_naive(datetime, "Etc/UTC")
    format_relative_time(datetime_utc)
  end

  def format_relative_time(datetime) when is_struct(datetime, DateTime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 2_592_000 -> "#{div(diff, 86400)} days ago"
      diff < 31_536_000 -> "#{div(diff, 2_592_000)} months ago"
      true -> "#{div(diff, 31_536_000)} years ago"
    end
  end

  @doc """
  Formats event start and end times in a user-friendly way
  """
  def format_event_time(%{dateTime: start_time}, %{dateTime: end_time}) do
    {:ok, start_dt, _} = DateTime.from_iso8601(start_time)
    {:ok, end_dt, _} = DateTime.from_iso8601(end_time)

    date_str = Calendar.strftime(start_dt, "%B %d, %Y")
    start_str = Calendar.strftime(start_dt, "%I:%M %p")
    end_str = Calendar.strftime(end_dt, "%I:%M %p")

    "#{date_str} · #{start_str} - #{end_str}"
  end

  def format_event_time(%{date: date}, %{date: date}) do
    {:ok, date_dt} = Date.from_iso8601(date)
    Calendar.strftime(date_dt, "%B %d, %Y")
  end

  def format_event_time(_, _), do: "Time not specified"

  @doc """
  Extracts the first Zoom meeting link from text
  """
  def extract_zoom_link(nil), do: nil

  def extract_zoom_link(text) when is_binary(text) do
    case Regex.run(~r/https:\/\/[^\/\s]*zoom\.us\/[jw]\/\d+[^\s<]*/, text) do
      [url | _] -> url
      nil -> nil
    end
  end

  # Private functions

  defp get_google_account(user) do
    case Accounts.get_google_account_by_user(user) do
      nil -> {:error, :no_google_account}
      account -> {:ok, account}
    end
  end

  defp fetch_events(access_token) do
    now = DateTime.utc_now()
    past = DateTime.add(now, -7, :day)
    future = DateTime.add(now, 30, :day)

    client =
      Tesla.client([
        {Tesla.Middleware.BaseUrl, "https://www.googleapis.com/calendar/v3"},
        {Tesla.Middleware.Headers, [{"authorization", "Bearer #{access_token}"}]},
        Tesla.Middleware.JSON
      ])

    params = [
      timeMin: DateTime.to_iso8601(past),
      timeMax: DateTime.to_iso8601(future),
      singleEvents: true,
      orderBy: "startTime"
    ]

    case Tesla.get(client, "/calendars/primary/events", query: params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp filter_zoom_events(%{items: items}) when is_list(items) do
    Enum.filter(items, &has_zoom_link?/1)
  end

  defp filter_zoom_events(_), do: []

  defp has_zoom_link?(%{description: description}) when is_binary(description) do
    String.match?(description, ~r/zoom\.us\/[jw]\/\d+/i)
  end

  defp has_zoom_link?(_), do: false
end
