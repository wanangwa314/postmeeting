defmodule Postmeeting.Calendar do
  @moduledoc """
  The Calendar context.
  """

  alias Postmeeting.Accounts

  @doc """
  Lists calendar events with meeting links for a user.
  Fetches events from the past week up to 1 month in the future.
  """
  def list_events_with_meeting_links(user) do
    with {:ok, google_account} <- get_google_account(user),
         {:ok, events} <- fetch_events(google_account.access_token) do
      dbg(events)
      {:ok, filter_meeting_events(events)}
    end
  end

  # Keep the old function for backward compatibility
  def list_events_with_zoom(user) do
    list_events_with_meeting_links(user)
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
      diff < -31_536_000 -> "in #{div(-diff, 31_536_000)} years"
      diff < -2_592_000 -> "in #{div(-diff, 2_592_000)} months"
      diff < -86400 -> "in #{div(-diff, 86400)} days"
      diff < -3600 -> "in #{div(-diff, 3600)} hours"
      diff < -60 -> "in #{div(-diff, 60)} minutes"
      diff < 0 -> "in less than a minute"
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
  Extracts meeting link and determines platform type from text
  Returns {meeting_link, platform_type} or nil if no meeting link found
  """
  def extract_meeting_link_with_platform(nil), do: nil

  def extract_meeting_link_with_platform(text) when is_binary(text) do
    cond do
      # Check for Zoom links
      match = Regex.run(~r/https:\/\/[^\/\s]*zoom\.us\/[jw]\/\d+[^\s<]*/, text) ->
        {List.first(match), "ZOOM"}

      # Check for Teams links
      match = Regex.run(~r/https:\/\/teams\.microsoft\.com\/l\/meetup-join\/[^\s<]*/, text) ->
        {List.first(match), "TEAMS"}

      # Check for Google Meet links
      match = Regex.run(~r/https:\/\/meet\.google\.com\/[a-z\-]+/, text) ->
        {List.first(match), "MEET"}

      true ->
        nil
    end
  end

  @doc """
  Extracts the first meeting link from text (backward compatibility)
  """
  def extract_meeting_link(nil), do: nil

  def extract_meeting_link(text) when is_binary(text) do
    case extract_meeting_link_with_platform(text) do
      {link, _platform} -> link
      nil -> nil
    end
  end

  # Keep old zoom-specific function for backward compatibility
  def extract_zoom_link(text), do: extract_meeting_link(text)

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

  defp filter_meeting_events(%{"items" => items}) when is_list(items) do
    Enum.filter(items, &has_meeting_link?/1)
  end

  defp filter_meeting_events(_), do: []

  # Updated to detect Zoom, Teams, and Google Meet links
  defp has_meeting_link?(%{"description" => description, "location" => location}) do
    has_meeting_link_in_text?(description) || has_meeting_link_in_text?(location)
  end

  defp has_meeting_link?(%{"description" => description}) when is_binary(description) do
    has_meeting_link_in_text?(description)
  end

  defp has_meeting_link?(%{"location" => location}) when is_binary(location) do
    has_meeting_link_in_text?(location)
  end

  defp has_meeting_link?(_), do: false

  # Helper function to check if text contains any meeting platform link
  defp has_meeting_link_in_text?(text) when is_binary(text) do
    String.match?(text, ~r/zoom\.us\/[jw]\/\d+/i) ||
      String.match?(text, ~r/teams\.microsoft\.com\/l\/meetup-join/i) ||
      String.match?(text, ~r/meet\.google\.com\/[a-z\-]+/i)
  end

  defp has_meeting_link_in_text?(_), do: false
end
