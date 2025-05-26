defmodule Postmeeting.Calendar do
  @moduledoc """
  The Calendar context.
  """

  alias Postmeeting.Accounts

  @doc """
  Lists calendar events with meeting links for a user.
  Fetches events from the past week up to 1 month in the future.
  Returns raw Google Calendar events for backward compatibility.
  """
  def list_events_with_meeting_links(user) do
    google_accounts = get_google_accounts(user)

    all_events = Enum.reduce(google_accounts, [], fn account, acc ->
      case fetch_events(account.access_token) do
        {:ok, %{"items" => items}} when is_list(items) -> acc ++ items
        _ -> acc
      end
    end)

    case all_events do
      [] -> {:error, :no_events}
      events -> {:ok, filter_meeting_events(events)}
    end
  end

  @doc """
  Lists calendar events with meeting links for a user, returning structured data.
  Fetches events from the past week up to 1 month in the future.
  """
  def list_structured_events_with_meeting_links(user) do
    google_accounts = get_google_accounts(user)

    all_events = Enum.reduce(google_accounts, [], fn account, acc ->
      case fetch_events(account.access_token) do
        {:ok, %{"items" => items}} when is_list(items) -> acc ++ items
        _ -> acc
      end
    end)

    case all_events do
      [] -> {:error, :no_events}
      events ->
        structured_events =
          events
          |> filter_meeting_events()
          |> Enum.map(&extract_event_info/1)
        {:ok, structured_events}
    end
  end

  # Keep the old function for backward compatibility
  def list_events_with_zoom(user) do
    list_events_with_meeting_links(user)
  end

  @doc """
  Extracts comprehensive event information including attendees, meeting link, and platform
  """
  def extract_event_info(event) do
    %{
      id: Map.get(event, "id"),
      summary: Map.get(event, "summary"),
      description: Map.get(event, "description"),
      start_time: get_event_start_time(event),
      end_time: get_event_end_time(event),
      attendees: extract_attendees(event),
      organizer: extract_organizer(event),
      meeting_link: extract_comprehensive_meeting_link(event),
      platform_type: determine_platform_type(event),
      location: Map.get(event, "location"),
      status: Map.get(event, "status"),
      html_link: Map.get(event, "htmlLink")
    }
  end

  @doc """
  Extracts attendees from an event
  """
  def extract_attendees(event) do
    case Map.get(event, "attendees") do
      nil ->
        []

      attendees when is_list(attendees) ->
        Enum.map(attendees, fn attendee ->
          %{
            email: Map.get(attendee, "email"),
            name: Map.get(attendee, "displayName"),
            response_status: Map.get(attendee, "responseStatus"),
            organizer: Map.get(attendee, "organizer", false),
            self: Map.get(attendee, "self", false)
          }
        end)

      _ ->
        []
    end
  end

  @doc """
  Extracts organizer information from an event
  """
  def extract_organizer(event) do
    case Map.get(event, "organizer") do
      nil ->
        nil

      organizer ->
        %{
          email: Map.get(organizer, "email"),
          name: Map.get(organizer, "displayName"),
          self: Map.get(organizer, "self", false)
        }
    end
  end

  @doc """
  Comprehensively extracts meeting link from all possible locations in the event
  """
  def extract_comprehensive_meeting_link(event) do
    # Try different sources in order of preference
    extract_from_hangout_link(event) ||
      extract_from_conference_data(event) ||
      extract_from_location(event) ||
      extract_from_description(event)
  end

  @doc """
  Determines the platform type based on the event data
  """
  def determine_platform_type(event) do
    cond do
      # Check for Google Meet indicators
      has_google_meet_indicators?(event) -> "MEET"
      # Check for Zoom indicators
      has_zoom_indicators?(event) -> "ZOOM"
      # Check for Teams indicators
      has_teams_indicators?(event) -> "TEAMS"
      # Fallback to link-based detection
      true -> determine_platform_from_link(extract_comprehensive_meeting_link(event))
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
  Extracts meeting link from an event using comprehensive detection.
  Works with raw Google Calendar event data (string keys).
  Returns the meeting link or nil if not found.
  """
  def extract_event_meeting_link(event) when is_map(event) do
    extract_from_hangout_link(event) ||
      extract_from_conference_data(event) ||
      extract_from_location(event) ||
      extract_from_description(event)
  end

  @doc """
  Extracts meeting link and platform from an event using comprehensive detection.
  Works with raw Google Calendar event data (string keys).
  Returns {meeting_link, platform_type} or nil if not found.
  """
  def extract_event_meeting_link_with_platform(event) when is_map(event) do
    case extract_event_meeting_link(event) do
      nil -> nil
      link -> {link, determine_platform_from_link(link)}
    end
  end

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

  defp get_google_accounts(user) do
    Accounts.list_google_accounts(user)
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
    # Return raw events for backward compatibility
    # Use extract_event_info/1 separately if you need structured data
    Enum.filter(items, &has_meeting_link?/1)
  end

  defp filter_meeting_events(_), do: []

  # Enhanced meeting link detection
  defp has_meeting_link?(event) do
    has_hangout_link?(event) ||
      has_conference_data?(event) ||
      has_meeting_link_in_location?(event) ||
      has_meeting_link_in_description?(event) ||
      has_zoom_extended_properties?(event)
  end

  # Check for Google Meet hangout link
  defp has_hangout_link?(event) do
    case Map.get(event, "hangoutLink") do
      nil -> false
      link when is_binary(link) -> String.contains?(link, "meet.google.com")
      _ -> false
    end
  end

  # Check for conference data (Google Meet)
  defp has_conference_data?(event) do
    case get_in(event, ["conferenceData", "entryPoints"]) do
      nil ->
        false

      entry_points when is_list(entry_points) ->
        Enum.any?(entry_points, fn entry_point ->
          case Map.get(entry_point, "uri") do
            nil -> false
            uri -> String.contains?(uri, ["meet.google.com", "zoom.us", "teams.microsoft.com"])
          end
        end)

      _ ->
        false
    end
  end

  # Check for Zoom extended properties
  defp has_zoom_extended_properties?(event) do
    case get_in(event, ["extendedProperties", "shared", "zmMeetingNum"]) do
      nil -> false
      _ -> true
    end
  end

  defp has_meeting_link_in_location?(event) do
    case Map.get(event, "location") do
      nil -> false
      location -> has_meeting_link_in_text?(location)
    end
  end

  defp has_meeting_link_in_description?(event) do
    case Map.get(event, "description") do
      nil -> false
      description -> has_meeting_link_in_text?(description)
    end
  end

  # Helper function to check if text contains any meeting platform link
  defp has_meeting_link_in_text?(text) when is_binary(text) do
    String.match?(text, ~r/zoom\.us\/[jw]\/\d+/i) ||
      String.match?(text, ~r/teams\.microsoft\.com\/l\/meetup-join/i) ||
      String.match?(text, ~r/meet\.google\.com\/[a-z\-]+/i)
  end

  defp has_meeting_link_in_text?(_), do: false

  # Comprehensive link extraction functions

  defp extract_from_hangout_link(event) do
    Map.get(event, "hangoutLink")
  end

  defp extract_from_conference_data(event) do
    case get_in(event, ["conferenceData", "entryPoints"]) do
      nil ->
        nil

      entry_points when is_list(entry_points) ->
        entry_points
        |> Enum.find_value(fn entry_point ->
          case Map.get(entry_point, "uri") do
            nil ->
              nil

            uri ->
              if String.contains?(uri, ["meet.google.com", "zoom.us", "teams.microsoft.com"]) do
                uri
              else
                nil
              end
          end
        end)

      _ ->
        nil
    end
  end

  defp extract_from_location(event) do
    case Map.get(event, "location") do
      nil -> nil
      location -> extract_meeting_link(location)
    end
  end

  defp extract_from_description(event) do
    case Map.get(event, "description") do
      nil -> nil
      description -> extract_meeting_link(description)
    end
  end

  # Platform detection helpers

  defp has_google_meet_indicators?(event) do
    Map.has_key?(event, "hangoutLink") ||
      get_in(event, ["conferenceData", "conferenceSolution", "key", "type"]) == "hangoutsMeet"
  end

  defp has_zoom_indicators?(event) do
    Map.has_key?(event, ["extendedProperties", "shared", "zmMeetingNum"]) ||
      (Map.get(event, "location") && String.contains?(Map.get(event, "location"), "zoom.us"))
  end

  defp has_teams_indicators?(event) do
    description = Map.get(event, "description", "")
    location = Map.get(event, "location", "")

    String.contains?(description <> location, "teams.microsoft.com")
  end

  defp determine_platform_from_link(nil), do: nil

  defp determine_platform_from_link(link) when is_binary(link) do
    cond do
      String.contains?(link, "zoom.us") -> "ZOOM"
      String.contains?(link, "meet.google.com") -> "MEET"
      String.contains?(link, "teams.microsoft.com") -> "TEAMS"
      true -> "UNKNOWN"
    end
  end

  # Helper functions for extracting start and end times
  defp get_event_start_time(event) do
    case Map.get(event, "start") do
      %{"dateTime" => date_time} -> date_time
      %{"date" => date} -> date
      _ -> nil
    end
  end

  defp get_event_end_time(event) do
    case Map.get(event, "end") do
      %{"dateTime" => date_time} -> date_time
      %{"date" => date} -> date
      _ -> nil
    end
  end
end
