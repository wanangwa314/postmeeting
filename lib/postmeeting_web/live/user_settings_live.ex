defmodule PostmeetingWeb.UserSettingsLive do
  use PostmeetingWeb, :live_view

  alias Postmeeting.Accounts

  on_mount {PostmeetingWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    google_accounts = Accounts.list_google_accounts(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Settings",
       google_accounts: google_accounts
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
         |> assign(:google_accounts, google_accounts)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error disconnecting Google Calendar account.")}
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
            <div class="space-y-6">
              <%= for account <- @google_accounts do %>
                <div class="flex items-start justify-between">
                  <div class="flex items-start space-x-3">
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
                    <div>
                      <p class="text-sm">Connected Google Calendar</p>
                      <p class="mt-1 text-xs text-gray-500">Added <%= Calendar.strftime(account.inserted_at, "%B %d, %Y") %></p>
                    </div>
                  </div>
                  <button
                    phx-click="disconnect_google"
                    phx-value-id={account.id}
                    class="text-sm font-medium text-red-600 hover:text-red-500"
                  >
                    Disconnect
                  </button>
                </div>
              <% end %>

              <div class="mt-6 flex justify-center">
                <a
                  href="/auth/google"
                  class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="-ml-0.5 mr-1.5 h-5 w-5"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M12 4.5v15m7.5-7.5h-15"
                    />
                  </svg>
                  Add Another Google Calendar
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
