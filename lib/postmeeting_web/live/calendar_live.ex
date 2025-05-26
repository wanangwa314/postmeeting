defmodule PostmeetingWeb.CalendarLive do
  use PostmeetingWeb, :live_view

  alias Postmeeting.Meetings

  on_mount {PostmeetingWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    meetings = Meetings.list_user_meetings(socket.assigns.current_user.id)

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       completed_meetings: meetings.completed_with_transcripts
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <!-- Dashboard Header -->
      <div class="border-b border-gray-200 pb-5">
        <h1 class="text-3xl font-bold leading-9 text-gray-900">Admin Dashboard</h1>
        <p class="mt-2 max-w-4xl text-sm text-gray-500">
          Manage and review your completed meetings and transcripts.
        </p>
      </div>
      
    <!-- Stats Cards -->
      <div class="mt-8">
        <dl class="grid grid-cols-1 gap-5 sm:grid-cols-3">
          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">Total Meetings</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
              {length(@completed_meetings)}
            </dd>
          </div>
          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">With Transcripts</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
              {length(@completed_meetings)}
            </dd>
          </div>
          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">This Month</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
              {count_meetings_this_month(@completed_meetings)}
            </dd>
          </div>
        </dl>
      </div>
      
    <!-- Past Meetings Table -->
      <div class="mt-12">
        <div class="sm:flex sm:items-center">
          <div class="sm:flex-auto">
            <h2 class="text-xl font-semibold leading-6 text-gray-900">Past Meetings</h2>
            <p class="mt-2 text-sm text-gray-700">
              A list of all completed meetings with transcripts and details.
            </p>
          </div>
        </div>

        <div class="mt-8 flow-root">
          <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
            <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
              <%= if Enum.empty?(@completed_meetings) do %>
                <div class="text-center py-12">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8 7V3a4 4 0 118 0v4m-4 9v2m-6-3h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-semibold text-gray-900">No meetings found</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Get started by connecting your calendar and attending some meetings.
                  </p>
                </div>
              <% else %>
                <.table id="meetings" rows={@completed_meetings}>
                  <:col :let={meeting} label="Meeting Name">
                    <div class="flex items-center">
                      <div class="flex-shrink-0 mr-3">
                        <%= case meeting.platform_type do %>
                          <% "MEET" -> %>
                            <img src="https://fonts.gstatic.com/s/i/productlogos/meet_2020q4/v6/web-64dp/logo_meet_2020q4_color_1x_web_64dp.png" alt="Google Meet" class="h-8 w-8">
                          <% "TEAMS" -> %>
                            <img src="https://upload.wikimedia.org/wikipedia/commons/c/c9/Microsoft_Office_Teams_%282018%E2%80%93present%29.svg" alt="Microsoft Teams" class="h-8 w-8">
                          <% "ZOOM" -> %>
                            <img src="https://upload.wikimedia.org/wikipedia/commons/7/7b/Zoom_Communications_Logo.svg" alt="Zoom" class="h-8 w-8">
                        <% end %>
                      </div>
                      <div>
                        <div class="text-sm font-medium text-gray-900">{meeting.name}</div>
                        <div class="text-sm text-gray-500">
                          {format_platform(meeting.platform_type)}
                        </div>
                      </div>
                    </div>
                  </:col>
                  <:col :let={meeting} label="Date">
                    <div class="text-sm text-gray-900">{format_date(meeting.start_time)}</div>
                    <div class="text-sm text-gray-500">{format_time(meeting.start_time)}</div>
                  </:col>
                  <:col :let={_meeting} label="Duration">
                    <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800">
                      Completed
                    </span>
                  </:col>
                  <:col :let={meeting} label="Attendees">
                    <div class="text-sm text-gray-900">
                      <%= if meeting.attendees && length(meeting.attendees) > 0 do %>
                        {length(meeting.attendees)} participants
                      <% else %>
                        No attendee data
                      <% end %>
                    </div>
                  </:col>
                  <:col :let={meeting} label="Transcript">
                    <%= if meeting.transcript do %>
                      <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                        Available
                      </span>
                    <% else %>
                      <span class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800">
                        Not Available
                      </span>
                    <% end %>
                  </:col>
                  <:action :let={meeting}>
                    <button
                      type="button"
                      phx-click="view_details"
                      phx-value-id={meeting.id}
                      class="text-indigo-600 hover:text-indigo-900 text-sm font-medium"
                    >
                      View
                    </button>
                  </:action>
                </.table>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("view_details", %{"id" => meeting_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/meetings/#{meeting_id}")}
  end

  # Helper functions for formatting
  defp format_date(datetime) when is_struct(datetime, DateTime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_string()
  end

  defp format_date(_), do: "Unknown"

  defp format_time(datetime) when is_struct(datetime, DateTime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    # Show HH:MM only
    |> String.slice(0..4)
  end

  defp format_time(_), do: "Unknown"

  defp format_platform("MEET"), do: "Google Meet"
  defp format_platform("ZOOM"), do: "Zoom"
  defp format_platform("TEAMS"), do: "Microsoft Teams"
  defp format_platform(platform) when is_binary(platform), do: platform
  defp format_platform(_), do: "Unknown"

  defp count_meetings_this_month(meetings) do
    current_month = Date.utc_today().month
    current_year = Date.utc_today().year

    Enum.count(meetings, fn meeting ->
      case meeting.start_time do
        %DateTime{} = dt ->
          date = DateTime.to_date(dt)
          date.month == current_month && date.year == current_year

        _ ->
          false
      end
    end)
  end
end
