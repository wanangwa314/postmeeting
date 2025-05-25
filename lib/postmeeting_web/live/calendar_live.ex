defmodule PostmeetingWeb.CalendarLive do
  use PostmeetingWeb, :live_view

  on_mount {PostmeetingWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Calendar")}
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
    </div>
    """
  end
end
