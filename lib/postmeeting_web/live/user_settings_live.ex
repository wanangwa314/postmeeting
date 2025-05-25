defmodule PostmeetingWeb.UserSettingsLive do
  use PostmeetingWeb, :live_view

  alias Postmeeting.Accounts

  on_mount {PostmeetingWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    google_account = Accounts.get_google_account(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Settings",
       google_account: google_account
     )}
  end

  @impl true
  def handle_event("disconnect_google", _, socket) do
    case Accounts.disconnect_google_account(socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Google Calendar disconnected successfully.")
         |> assign(:google_account, nil)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error disconnecting Google Calendar.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-12 py-12">
      <div>
        <h1 class="text-lg font-semibold leading-8">Google Calendar Integration</h1>
        <div class="mt-6 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <%= if @google_account do %>
              <div class="flex items-start">
                <div class="flex-shrink-0">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="h-6 w-6 text-green-500"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm">Your Google Calendar is connected.</p>
                  <button
                    phx-click="disconnect_google"
                    class="mt-2 text-sm font-medium text-indigo-600 hover:text-indigo-500"
                  >
                    Disconnect
                  </button>
                </div>
              </div>
            <% else %>
              <div class="flex items-start">
                <div class="flex-shrink-0">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="h-6 w-6 text-red-500"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm">Your Google Calendar is not connected.</p>
                  <a
                    href="/auth/google"
                    class="mt-2 inline-block text-sm font-medium text-indigo-600 hover:text-indigo-500"
                  >
                    Connect Google Calendar
                  </a>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
