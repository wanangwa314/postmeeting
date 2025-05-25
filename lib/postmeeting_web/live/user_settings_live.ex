defmodule PostmeetingWeb.UserSettingsLive do
  use PostmeetingWeb, :live_view

  alias Postmeeting.{Accounts, Calendar}

  on_mount {PostmeetingWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    google_accounts = Accounts.list_google_accounts(socket.assigns.current_user)
    facebook_accounts = Accounts.list_facebook_accounts(socket.assigns.current_user)
    linkedin_accounts = Accounts.list_linkedin_accounts(socket.assigns.current_user)
    calendar_events = get_calendar_events(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Settings",
       google_accounts: google_accounts,
       facebook_accounts: facebook_accounts,
       linkedin_accounts: linkedin_accounts,
       calendar_events: calendar_events
     )}
  end

  @impl true
  def handle_event("disconnect_google", %{"id" => account_id}, socket) do
    case Accounts.disconnect_google_account(socket.assigns.current_user, account_id) do
      {:ok, _} ->
        google_accounts = Accounts.list_google_accounts(socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Google Calendar account disconnected successfully.")
         |> assign(:google_accounts, google_accounts)
         |> assign(:calendar_events, [])}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error disconnecting Google Calendar account.")}
    end
  end

  @impl true
  def handle_event("disconnect_facebook", %{"id" => account_id}, socket) do
    case Accounts.disconnect_facebook_account(socket.assigns.current_user, account_id) do
      {:ok, _} ->
        facebook_accounts = Accounts.list_facebook_accounts(socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Facebook account disconnected successfully.")
         |> assign(:facebook_accounts, facebook_accounts)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error disconnecting Facebook account.")}
    end
  end

  @impl true
  def handle_event("disconnect_linkedin", %{"id" => account_id}, socket) do
    case Accounts.disconnect_linkedin_account(socket.assigns.current_user, account_id) do
      {:ok, _} ->
        linkedin_accounts = Accounts.list_linkedin_accounts(socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:info, "LinkedIn account disconnected successfully.")
         |> assign(:linkedin_accounts, linkedin_accounts)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error disconnecting LinkedIn account.")}
    end
  end

  @impl true
  def handle_event("refresh_events", _, socket) do
    calendar_events = get_calendar_events(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:calendar_events, calendar_events)}
  end

  defp get_calendar_events(user) do
    case Calendar.list_events_with_zoom(user) do
      {:ok, events} -> events
      {:error, _} -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-12 py-12">
      <div>
        <div class="flex justify-between items-center">
          <h1 class="text-lg font-semibold leading-8">Google Calendar Integration</h1>
          <.link
            :if={!Enum.empty?(@google_accounts)}
            href={~p"/auth/google"}
            class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
          >
            Add Another Account
          </.link>
        </div>
        <div class="mt-6 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="space-y-6">
              <%= if Enum.empty?(@google_accounts) do %>
                <div class="text-sm text-gray-500">
                  <p>No Google Calendar accounts connected.</p>
                  <.link
                    href={~p"/auth/google"}
                    class="mt-4 inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
                  >
                    Connect Google Calendar
                  </.link>
                </div>
              <% else %>
                <%= for account <- @google_accounts do %>
                  <div class="flex items-start justify-between">
                    <div class="text-sm text-gray-900">
                      <p class="font-medium">{account.name || account.email}</p>
                      <p class="text-gray-500">{account.email}</p>
                    </div>
                    <button
                      phx-click="disconnect_google"
                      phx-value-id={account.id}
                      class="text-sm font-medium text-red-600 hover:text-red-500"
                      data-confirm="Are you sure you want to disconnect this Google account?"
                    >
                      Disconnect
                    </button>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div>
        <h1 class="text-lg font-semibold leading-8">Facebook Integration</h1>
        <div class="mt-6 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="space-y-6">
              <%= if Enum.empty?(@facebook_accounts) do %>
                <div class="text-sm text-gray-500">
                  <p>No Facebook accounts connected.</p>
                  <.link
                    href={~p"/auth/facebook"}
                    class="mt-4 inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
                  >
                    Connect Facebook Account
                  </.link>
                </div>
              <% else %>
                <%= for account <- @facebook_accounts do %>
                  <div class="flex items-start justify-between">
                    <div class="flex items-start space-x-3">
                      <div class="flex-shrink-0">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke-width="1.5"
                          stroke="currentColor"
                          class="h-6 w-6 text-blue-500"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                          />
                        </svg>
                      </div>
                      <div>
                        <p class="text-sm font-medium text-gray-900">
                          Connected as {account.name}
                        </p>
                        <p class="mt-1 text-xs text-gray-500">
                          Connected {Calendar.format_relative_time(account.inserted_at)}
                        </p>
                      </div>
                    </div>
                    <button
                      phx-click="disconnect_facebook"
                      phx-value-id={account.id}
                      class="text-sm font-medium text-red-600 hover:text-red-500"
                    >
                      Disconnect
                    </button>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div>
        <h1 class="text-lg font-semibold leading-8">LinkedIn Integration</h1>
        <div class="mt-6 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="space-y-6">
              <%= if Enum.empty?(@linkedin_accounts) do %>
                <div class="text-sm text-gray-500">
                  <p>No LinkedIn accounts connected.</p>
                  <.link
                    href={~p"/auth/linkedin"}
                    class="mt-4 inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
                  >
                    Connect LinkedIn Account
                  </.link>
                </div>
              <% else %>
                <%= for account <- @linkedin_accounts do %>
                  <div class="flex items-start justify-between">
                    <div class="flex items-start space-x-3">
                      <div class="flex-shrink-0">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke-width="1.5"
                          stroke="currentColor"
                          class="h-6 w-6 text-gray-400"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M20.25 14.15v4.25c0 1.094-.787 2.036-1.872 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25m16.5 0a2.18 2.18 0 00.75-1.661V8.706c0-1.081-.768-2.015-1.837-2.175a48.114 48.114 0 00-3.413-.387m4.5 8.006c-.194.165-.42.295-.673.38A23.978 23.978 0 0112 15.75c-2.648 0-5.195-.429-7.577-1.22a2.016 2.016 0 01-.673-.38m0 0A2.18 2.18 0 013 12.489V8.706c0-1.081.768-2.015 1.837-2.175a48.111 48.111 0 013.413-.387m7.5 0V5.25A2.25 2.25 0 0013.5 3h-3a2.25 2.25 0 00-2.25 2.25v.894m7.5 0a48.667 48.667 0 00-7.5 0M12 12.75h.008v.008H12v-.008z"
                          />
                        </svg>
                      </div>
                      <div class="min-w-0 flex-1">
                        <p class="text-sm font-medium text-gray-900">
                          {account.name || "LinkedIn Account"}
                        </p>
                        <p class="mt-1 text-xs text-gray-500">
                          Connected {Postmeeting.Calendar.format_relative_time(account.inserted_at)}
                        </p>
                      </div>
                    </div>
                    <div class="ml-4 flex flex-shrink-0">
                      <button
                        phx-click="disconnect_linkedin"
                        phx-value-id={account.id}
                        type="button"
                        class="inline-flex text-sm font-medium text-red-600 hover:text-red-500"
                      >
                        Disconnect
                      </button>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
