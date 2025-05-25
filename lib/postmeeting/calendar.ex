defmodule Postmeeting.Calendar do
  @moduledoc """
  The Calendar context.
  """

  alias Postmeeting.Accounts
  alias GoogleApi.Calendar.V3.Api.Events
  alias GoogleApi.Calendar.V3.Connection

  @doc """
  Lists calendar events with Zoom links for a user.
  Fetches events from the past week up to 1 month in the future.
  """
  def list_events_with_zoom(user) do
    with {:ok, google_account} <- get_google_account(user),
         {:ok, connection} <- get_connection(google_account),
         {:ok, events} <- fetch_events(connection) do
      {:ok, filter_zoom_events(events)}
    end
  end

  defp get_google_account(user) do
    case Accounts.get_google_account(user) do
      nil -> {:error, :no_google_account}
      account -> {:ok, account}
    end
  end

  defp get_connection(google_account) do
    connection = Connection.new()

    token = %{
      "access_token" => google_account.access_token,
      "refresh_token" => google_account.refresh_token,
      "token_type" => "Bearer",
      "expires_at" => DateTime.to_unix(google_account.expires_at)
    }

    {:ok, Connection.set_token(connection, token)}
  end

  defp fetch_events(conn) do
    now = DateTime.utc_now()
    past = DateTime.add(now, -7, :day)
    future = DateTime.add(now, 30, :day)

    Events.calendar_events_list(
      conn,
      "primary",
      timeMin: DateTime.to_iso8601(past),
      timeMax: DateTime.to_iso8601(future),
      singleEvents: true,
      orderBy: "startTime"
    )
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
