defmodule PostmeetingWeb.CalendarLive do
  use PostmeetingWeb, :live_view

  alias Postmeeting.Meetings

  on_mount {PostmeetingWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    meetings = Meetings.list_user_meetings(socket.assigns.current_user.id)

    {:ok,
     assign(socket,
       page_title: "Calendar",
       upcoming_meetings: meetings.upcoming,
       ongoing_meetings: meetings.ongoing,
       completed_meetings: meetings.completed_with_transcripts
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12">
      <div class="mx-auto max-w-3xl">
        <h1 class="text-3xl font-bold text-gray-900">Calendar</h1>
        <%= if @current_user.email do %>
          <p class="mt-2 text-sm text-gray-600">Connected as {@current_user.email}</p>
        <% end %>
      </div>

      <div class="mt-12">
        <h2 class="text-2xl font-semibold text-gray-900">Ongoing Meetings</h2>
        <%= if Enum.empty?(@ongoing_meetings) do %>
          <p class="mt-2 text-sm text-gray-500">No ongoing meetings.</p>
        <% else %>
          <ul class="mt-4 space-y-4">
            <%= for meeting <- @ongoing_meetings do %>
              <li class="p-4 bg-white shadow sm:rounded-lg">
                <h3 class="text-lg font-medium text-gray-900">{meeting.name}</h3>
                <p class="text-sm text-gray-500">
                  Started at: {Timex.format!(
                    meeting.start_time,
                    "{YYYY}-{0M}-{0D} {h24}:{m}:{s}",
                    :local
                  )}
                </p>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>

      <div class="mt-12">
        <h2 class="text-2xl font-semibold text-gray-900">Upcoming Meetings</h2>
        <%= if Enum.empty?(@upcoming_meetings) do %>
          <p class="mt-2 text-sm text-gray-500">No upcoming meetings.</p>
        <% else %>
          <ul class="mt-4 space-y-4">
            <%= for meeting <- @upcoming_meetings do %>
              <li class="p-4 bg-white shadow sm:rounded-lg">
                <h3 class="text-lg font-medium text-gray-900">{meeting.name}</h3>
                <p class="text-sm text-gray-500">
                  Starts at: {Timex.format!(
                    meeting.start_time,
                    "{YYYY}-{0M}-{0D} {h24}:{m}:{s}",
                    :local
                  )}
                </p>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>

      <div class="mt-12">
        <h2 class="text-2xl font-semibold text-gray-900">Completed Meetings with Transcripts</h2>
        <%= if Enum.empty?(@completed_meetings) do %>
          <p class="mt-2 text-sm text-gray-500">No completed meetings with transcripts found.</p>
        <% else %>
          <ul class="mt-4 space-y-4">
            <%= for meeting <- @completed_meetings do %>
              <li class="p-4 bg-white shadow sm:rounded-lg">
                <h3 class="text-lg font-medium text-gray-900">{meeting.name}</h3>
                <p class="text-sm text-gray-500">
                  Completed at: {Timex.format!(
                    meeting.start_time,
                    "{YYYY}-{0M}-{0D} {h24}:{m}:{s}",
                    :local
                  )}
                </p>
                <div class="mt-2 p-2 bg-gray-50 rounded">
                  <h4 class="text-xs font-semibold text-gray-700">Transcript:</h4>
                  <p class="mt-1 text-xs text-gray-600 whitespace-pre-wrap">{meeting.transcript}</p>
                </div>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </div>
    """
  end
end
