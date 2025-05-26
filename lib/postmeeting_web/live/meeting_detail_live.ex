defmodule PostmeetingWeb.MeetingDetailLive do
  use PostmeetingWeb, :live_view

  alias Postmeeting.Meetings
  alias Postmeeting.Accounts
  alias Postmeeting.Auth.Facebook
  alias Postmeeting.Auth.LinkedIn

  on_mount({PostmeetingWeb.UserAuth, :ensure_authenticated})

  @impl true
  def mount(%{"id" => meeting_id}, _session, socket) do
    meeting = Meetings.get_user_meeting(socket.assigns.current_user.id, meeting_id)

    case meeting do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Meeting not found")
         |> redirect(to: ~p"/calendar")}

      meeting ->
        # Get user's connected social media accounts
        facebook_account = Accounts.get_facebook_account_by_user(socket.assigns.current_user)
        linkedin_account = Accounts.get_linkedin_account_by_user(socket.assigns.current_user)

        {:ok,
         assign(socket,
           page_title: "Meeting Details - #{meeting.name}",
           meeting: meeting,
           copied_field: nil,
           facebook_account: facebook_account,
           linkedin_account: linkedin_account,
           posting_status: %{},
           show_transcript: false
         )}
    end
  end

  @impl true
  def handle_event("copy_text", %{"field" => field}, socket) do
    {:noreply, assign(socket, copied_field: field)}
  end

  @impl true
  def handle_event("toggle_transcript", _params, socket) do
    {:noreply, assign(socket, show_transcript: !socket.assigns.show_transcript)}
  end

  @impl true
  def handle_event("post_to_linkedin", _params, socket) do
    case socket.assigns.linkedin_account do
      nil ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "No LinkedIn account connected. Please connect your LinkedIn account first."
         )
         |> assign(posting_status: Map.put(socket.assigns.posting_status, :linkedin, :error))}

      linkedin_account ->
        # Set posting status to loading
        socket =
          assign(socket,
            posting_status: Map.put(socket.assigns.posting_status, :linkedin, :posting)
          )

        case LinkedIn.post_share(linkedin_account, socket.assigns.meeting.linkedin_post) do
          {:ok, _response} ->
            {:noreply,
             socket
             |> put_flash(:info, "Successfully posted to LinkedIn!")
             |> assign(
               posting_status: Map.put(socket.assigns.posting_status, :linkedin, :success)
             )}

          {:error, error} ->
            error_message =
              case error do
                %{"message" => msg} -> msg
                %{"error" => %{"message" => msg}} -> msg
                _ -> "Failed to post to LinkedIn. Please try again."
              end

            {:noreply,
             socket
             |> put_flash(:error, "LinkedIn posting failed: #{error_message}")
             |> assign(posting_status: Map.put(socket.assigns.posting_status, :linkedin, :error))}
        end
    end
  end

  @impl true
  def handle_event("post_to_facebook", _params, socket) do
    case socket.assigns.facebook_account do
      nil ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "No Facebook account connected. Please connect your Facebook account first."
         )
         |> assign(posting_status: Map.put(socket.assigns.posting_status, :facebook, :error))}

      facebook_account ->
        # Check if token is still valid (not expired)
        if token_expired?(facebook_account) do
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Facebook token has expired. Please reconnect your Facebook account."
           )
           |> assign(posting_status: Map.put(socket.assigns.posting_status, :facebook, :error))}
        else
          # Use share dialog approach instead of direct API posting
          if Facebook.has_posting_permissions?(facebook_account) do
            # Direct API posting (when you have approval)
            socket =
              assign(socket,
                posting_status: Map.put(socket.assigns.posting_status, :facebook, :posting)
              )

            case Facebook.post_to_feed(facebook_account, socket.assigns.meeting.facebook_post) do
              {:ok, _response} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Successfully posted to Facebook!")
                 |> assign(
                   posting_status: Map.put(socket.assigns.posting_status, :facebook, :success)
                 )}

              {:error, error} ->
                error_message =
                  case error do
                    %{"error" => %{"message" => msg}} -> msg
                    %{"message" => msg} -> msg
                    _ -> "Failed to post to Facebook. Please try again."
                  end

                {:noreply,
                 socket
                 |> put_flash(:error, "Facebook posting failed: #{error_message}")
                 |> assign(
                   posting_status: Map.put(socket.assigns.posting_status, :facebook, :error)
                 )}
            end
          else
            # Use Facebook Share Dialog approach
            meeting_link = build_meeting_share_link(socket.assigns.meeting)

            share_url =
              Facebook.generate_share_url_with_link(
                socket.assigns.meeting.facebook_post,
                meeting_link,
                "#PostMeeting"
              )

            {:noreply,
             socket
             |> put_flash(:info, "Opening Facebook to share your post...")
             |> redirect(external: share_url)}
          end
        end
    end
  end

  # Add this helper function to generate a shareable link for your meeting
  defp build_meeting_share_link(meeting) do
    # You can customize this to point to your app's meeting page or just your app homepage
    # For now, using a generic link - you might want to make this a public meeting link
    "https://yourapp.com/meetings/#{meeting.id}"
  end

  @impl true
  def handle_event("reset_posting_status", %{"platform" => platform}, socket) do
    platform_atom = String.to_existing_atom(platform)

    {:noreply,
     assign(socket, posting_status: Map.delete(socket.assigns.posting_status, platform_atom))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8"
      data-meeting="true"
      data-email-content={@meeting.email || ""}
      data-linkedin-content={@meeting.linkedin_post || ""}
      data-facebook-content={@meeting.facebook_post || ""}
      data-transcript-content={format_transcript_for_copy(@meeting.transcript)}
    >
      <!-- Header with back button -->
      <div class="border-b border-gray-200 pb-5 mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold leading-9 text-gray-900"><%= @meeting.name %></h1>
            <p class="mt-2 text-sm text-gray-500">
              Meeting Details and Generated Content
            </p>
          </div>
          <.link
            navigate={~p"/calendar"}
            class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
          >
            ← Back to Calendar
          </.link>
        </div>
      </div>

      <!-- Meeting Overview -->
      <div class="mb-8">
        <div class="overflow-hidden bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Meeting Overview</h3>
            <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2 lg:grid-cols-3">
              <div>
                <dt class="text-sm font-medium text-gray-500">Date & Time</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  <%= format_full_datetime(@meeting.start_time) %>
                </dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Platform</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  <div class="flex items-center">
                    <span class={[
                      "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                      platform_badge_color(@meeting.platform_type)
                    ]}>
                      <%= format_platform(@meeting.platform_type) %>
                    </span>
                  </div>
                </dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Duration</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  <%= calculate_duration(@meeting) %>
                </dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Attendees</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  <%= if @meeting.attendees && length(@meeting.attendees) > 0 do %>
                    <div class="flex flex-wrap gap-1">
                      <%= for {attendee, index} <- Enum.with_index(@meeting.attendees) do %>
                        <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800">
                          <%= attendee %>
                        </span>
                        <%= if index < length(@meeting.attendees) - 1 and index < 2 do %>
                        <% end %>
                        <%= if index == 2 and length(@meeting.attendees) > 3 do %>
                          <span class="text-xs text-gray-500">+<%= length(@meeting.attendees) - 3 %> more</span>
                        <% end %>
                      <% end %>
                    </div>
                  <% else %>
                    <span class="text-gray-400">No attendee data</span>
                  <% end %>
                </dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Status</dt>
                <dd class="mt-1">
                  <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                    <svg class="mr-1 h-3 w-3" fill="currentColor" viewBox="0 0 8 8">
                      <circle cx="4" cy="4" r="3" />
                    </svg>
                    <%= String.capitalize(@meeting.status) %>
                  </span>
                </dd>
              </div>
              <%= if @meeting.meeting_link do %>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Meeting Link</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    <a href={@meeting.meeting_link} target="_blank" class="text-indigo-600 hover:text-indigo-500 truncate block">
                      <%= truncate_url(@meeting.meeting_link) %>
                    </a>
                  </dd>
                </div>
              <% end %>
            </dl>
          </div>
        </div>
      </div>

      <!-- Account Status Alert -->
      <%= if is_nil(@facebook_account) or is_nil(@linkedin_account) do %>
        <div class="mb-8 rounded-md bg-yellow-50 p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-yellow-800">
                Social Media Accounts Required
              </h3>
              <div class="mt-2 text-sm text-yellow-700">
                <p>
                  To post to social media, you need to connect your accounts first.
                  <%= if is_nil(@facebook_account) do %>
                    <.link href="/auth/facebook" class="font-medium underline hover:text-yellow-600">Connect Facebook</.link>
                  <% end %>
                  <%= if is_nil(@facebook_account) and is_nil(@linkedin_account) do %>
                    <span class="mx-1">or</span>
                  <% end %>
                  <%= if is_nil(@linkedin_account) do %>
                    <.link href="/auth/linkedin" class="font-medium underline hover:text-yellow-600">Connect LinkedIn</.link>
                  <% end %>
                </p>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Content Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
        <!-- Email Content -->
        <.content_card
          title="Email Summary"
          content={@meeting.email}
          field="email"
          copied_field={@copied_field}
          show_post_button={false}
          icon="📧"
        />

        <!-- LinkedIn Post -->
        <.content_card
          title="LinkedIn Post"
          content={@meeting.linkedin_post}
          field="linkedin"
          copied_field={@copied_field}
          show_post_button={true}
          post_action="post_to_linkedin"
          post_button_text="Post to LinkedIn"
          post_button_color="bg-blue-600 hover:bg-blue-700"
          account_connected={not is_nil(@linkedin_account)}
          posting_status={Map.get(@posting_status, :linkedin)}
          platform="linkedin"
          icon="💼"
        />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
        <!-- Facebook Post -->
    <.content_card
    title="Facebook Post"
    content={@meeting.facebook_post}
    field="facebook"
    copied_field={@copied_field}
    show_post_button={true}
    post_action="post_to_facebook"
    post_button_text="Share to Facebook"
    post_button_color="bg-blue-500 hover:bg-blue-600"
    account_connected={not is_nil(@facebook_account) and not token_expired?(@facebook_account)}
    posting_status={Map.get(@posting_status, :facebook)}
    platform="facebook"
    icon="📘"
    />

        <!-- Transcript Preview -->
        <%= if @meeting.transcript do %>
          <div class="overflow-hidden bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <div class="flex items-center justify-between mb-4">
                <div class="flex items-center">
                  <span class="text-lg mr-2">🎙️</span>
                  <h3 class="text-lg font-medium leading-6 text-gray-900">Meeting Transcript</h3>
                </div>
                <div class="flex space-x-2">
                  <button
                  id="copy"
                    type="button"
                    phx-click="copy_text"
                    phx-value-field="transcript"
                    phx-hook="CopyText"
                    class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                  >
                    <%= if @copied_field == "transcript" do %>
                      ✓ Copied!
                    <% else %>
                      📋 Copy
                    <% end %>
                  </button>
                  <button
                    type="button"
                    phx-click="toggle_transcript"
                    class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                  >
                    <%= if @show_transcript do %>
                      👁️ Hide Transcript
                    <% else %>
                      👁️ View Full Transcript
                    <% end %>
                  </button>
                </div>
              </div>

              <!-- Transcript Preview -->
              <div class="prose max-w-none">
                <%= if @show_transcript do %>
                  <div class="max-h-96 overflow-y-auto bg-gray-50 p-4 rounded-md">
                    <div class="space-y-4">
                      <%= for entry <- parse_transcript(@meeting.transcript) do %>
                        <div class="border-l-4 border-indigo-200 pl-4">
                          <div class="flex items-center space-x-2 mb-1">
                            <span class="text-sm font-medium text-gray-900"><%= entry.speaker %></span>
                            <span class="text-xs text-gray-500 bg-gray-200 px-2 py-1 rounded">
                              <%= format_timestamp(entry.start_time) %> - <%= format_timestamp(entry.end_time) %>
                            </span>
                          </div>
                          <p class="text-sm text-gray-700"><%= entry.text %></p>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% else %>
                  <div class="bg-gray-50 p-4 rounded-md">
                    <div class="text-center text-gray-500">
                      <p class="text-sm mb-2">Transcript available with <%= length(parse_transcript(@meeting.transcript)) %> entries</p>
                      <p class="text-xs">Click "View Full Transcript" to see the complete conversation</p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% else %>
          <div class="overflow-hidden bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <div class="text-center py-8">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                </svg>
                <h3 class="mt-2 text-sm font-semibold text-gray-900">No Transcript Available</h3>
                <p class="mt-1 text-sm text-gray-500">
                  Transcript was not generated for this meeting.
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Meeting Statistics -->
      <%= if @meeting.transcript do %>
        <div class="mb-8">
          <div class="overflow-hidden bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">📊 Meeting Analytics</h3>
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div class="bg-blue-50 p-4 rounded-lg">
                  <div class="text-sm font-medium text-blue-600">Total Segments</div>
                  <div class="text-2xl font-bold text-blue-900"><%= length(parse_transcript(@meeting.transcript)) %></div>
                </div>
                <div class="bg-green-50 p-4 rounded-lg">
                  <div class="text-sm font-medium text-green-600">Estimated Duration</div>
                  <div class="text-2xl font-bold text-green-900"><%= get_transcript_duration(@meeting.transcript) %></div>
                </div>
                <div class="bg-purple-50 p-4 rounded-lg">
                  <div class="text-sm font-medium text-purple-600">Speakers</div>
                  <div class="text-2xl font-bold text-purple-900"><%= count_unique_speakers(@meeting.transcript) %></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Component for content cards with enhanced posting functionality
  defp content_card(assigns) do
    assigns = assign_new(assigns, :icon, fn -> "📄" end)
    assigns = assign_new(assigns, :platform, fn -> nil end)

    ~H"""
    <div class="overflow-hidden bg-white shadow sm:rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center">
            <span class="text-lg mr-2"><%= @icon %></span>
            <h3 class="text-lg font-medium leading-6 text-gray-900"><%= @title %></h3>
          </div>
          <div class="flex space-x-2">
            <button
              type="button"
              id="copy_again"
              phx-click="copy_text"
              phx-value-field={@field}
              phx-hook="CopyText"
              class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
            >
              <%= if @copied_field == @field do %>
                ✓ Copied!
              <% else %>
                📋 Copy
              <% end %>
            </button>
            <%= if Map.get(assigns, :show_post_button, false) do %>
              <button
                type="button"
                phx-click={@post_action}
                disabled={not Map.get(assigns, :account_connected, false) or Map.get(assigns, :posting_status) == :posting}
                class={[
                  "inline-flex items-center rounded-md px-3 py-2 text-sm font-semibold shadow-sm transition-colors",
                  if(Map.get(assigns, :account_connected, false) and Map.get(assigns, :posting_status) != :posting,
                    do: "#{Map.get(assigns, :post_button_color, "bg-blue-600 hover:bg-blue-700")} text-white",
                    else: "bg-gray-300 text-gray-500 cursor-not-allowed"
                  )
                ]}
              >
                <%= cond do %>
                  <% Map.get(assigns, :posting_status) == :posting -> %>
                    <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-current" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Posting...
                  <% Map.get(assigns, :posting_status) == :success -> %>
                    <span class="flex items-center">
                      ✅ Posted!
                      <%= if assigns[:platform] do %>
                        <button
                          type="button"
                          phx-click="reset_posting_status"
                          phx-value-platform={@platform}
                          class="ml-2 text-xs underline hover:no-underline"
                        >
                          Reset
                        </button>
                      <% end %>
                    </span>
                  <% Map.get(assigns, :posting_status) == :error -> %>
                    <span class="flex items-center">
                      ❌ Try Again
                      <%= if assigns[:platform] do %>
                        <button
                          type="button"
                          phx-click="reset_posting_status"
                          phx-value-platform={@platform}
                          class="ml-2 text-xs underline hover:no-underline"
                        >
                          Reset
                        </button>
                      <% end %>
                    </span>
                  <% not Map.get(assigns, :account_connected, false) -> %>
                    🔗 Connect Account First
                  <% true -> %>
                    📤 <%= Map.get(assigns, :post_button_text, "Post") %>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>
        <div class="prose max-w-none">
          <%= if @content && String.trim(@content) != "" do %>
            <div class="whitespace-pre-wrap text-sm text-gray-700 bg-gray-50 p-4 rounded-md border max-h-64 overflow-y-auto">
              <%= @content %>
            </div>
          <% else %>
            <div class="text-center py-8 bg-gray-50 rounded-md border-2 border-dashed border-gray-300">
              <p class="text-sm text-gray-500">No content generated for this section</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to check if Facebook token is expired
  defp token_expired?(facebook_account) do
    case facebook_account do
      %{expires_at: nil} -> false
      %{expires_at: expires_at} -> DateTime.compare(DateTime.utc_now(), expires_at) == :gt
      _ -> true
    end
  end

  # Helper functions for formatting and display
  defp format_full_datetime(datetime) when is_struct(datetime, DateTime) do
    datetime
    |> DateTime.to_string()
    |> String.replace("T", " at ")
    |> String.slice(0..18)
  end

  defp format_full_datetime(datetime) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime <> "Z") do
      {:ok, dt, _} -> format_full_datetime(dt)
      _ -> datetime
    end
  end

  defp format_full_datetime(_), do: "Unknown"

  defp format_platform("MEET"), do: "Google Meet"
  defp format_platform("ZOOM"), do: "Zoom"
  defp format_platform("TEAMS"), do: "Microsoft Teams"
  defp format_platform(platform) when is_binary(platform), do: platform
  defp format_platform(_), do: "Unknown"

  defp platform_badge_color("MEET"), do: "bg-green-100 text-green-800"
  defp platform_badge_color("ZOOM"), do: "bg-blue-100 text-blue-800"
  defp platform_badge_color("TEAMS"), do: "bg-purple-100 text-purple-800"
  defp platform_badge_color(_), do: "bg-gray-100 text-gray-800"

  defp calculate_duration(meeting) do
    # This is a placeholder - you might want to calculate actual duration
    # based on transcript timestamps or meeting start/end times
    case meeting.transcript do
      nil ->
        "N/A"

      transcript ->
        case get_transcript_duration_in_minutes(transcript) do
          0 -> "< 1 min"
          minutes when minutes < 60 -> "#{minutes} min"
          minutes -> "#{div(minutes, 60)}h #{rem(minutes, 60)}m"
        end
    end
  end

  defp truncate_url(url) when is_binary(url) do
    if String.length(url) > 50 do
      String.slice(url, 0, 47) <> "..."
    else
      url
    end
  end

  defp truncate_url(_), do: ""

  defp parse_transcript(transcript) when is_binary(transcript) do
    case Jason.decode(transcript) do
      {:ok, transcript_data} when is_list(transcript_data) ->
        transcript_data
        |> Enum.map(fn entry ->
          words = entry["words"] || []
          text = words |> Enum.map(& &1["text"]) |> Enum.join(" ")
          start_time = words |> List.first() |> get_in(["start_timestamp"]) || 0
          end_time = words |> List.last() |> get_in(["end_timestamp"]) || 0

          %{
            speaker: entry["speaker"] || "Unknown",
            text: text,
            start_time: start_time,
            end_time: end_time
          }
        end)

      _ ->
        []
    end
  end

  defp parse_transcript(_), do: []

  defp format_transcript_for_copy(transcript) do
    transcript
    |> parse_transcript()
    |> Enum.map(fn entry ->
      "#{entry.speaker}: #{entry.text}"
    end)
    |> Enum.join("\n\n")
  end

  defp format_timestamp(timestamp) when is_number(timestamp) do
    minutes = div(trunc(timestamp), 60)
    seconds = rem(trunc(timestamp), 60)

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end

  defp format_timestamp(_), do: "00:00"

  defp get_transcript_duration(transcript) do
    case get_transcript_duration_in_minutes(transcript) do
      0 -> "< 1 min"
      minutes when minutes < 60 -> "#{minutes} min"
      minutes -> "#{div(minutes, 60)}h #{rem(minutes, 60)}m"
    end
  end

  defp get_transcript_duration_in_minutes(transcript) do
    transcript
    |> parse_transcript()
    |> case do
      [] ->
        0

      entries ->
        last_entry = List.last(entries)
        trunc(last_entry.end_time / 60)
    end
  end

  defp count_unique_speakers(transcript) do
    transcript
    |> parse_transcript()
    |> Enum.map(& &1.speaker)
    |> Enum.uniq()
    |> length()
  end
end
