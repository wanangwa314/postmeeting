defmodule PostmeetingWeb.UserSettingsLive do
  use PostmeetingWeb, :live_view

  alias Postmeeting.{Accounts, Calendar, ContentSettings}
  alias Postmeeting.ContentSettings.GenerationSetting

  on_mount {PostmeetingWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:google_accounts, Accounts.list_all_google_accounts(user))
      |> assign(:facebook_accounts, Accounts.list_facebook_accounts(user))
      |> assign(:linkedin_accounts, Accounts.list_linkedin_accounts(user))
      |> assign(:calendar_events, get_calendar_events(user))
      |> assign(:content_settings, ContentSettings.list_user_generation_settings(user.id))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit_content_setting, %{"platform" => platform}) do
    user_id = socket.assigns.current_user.id
    type = get_content_type(platform)

    existing_setting = ContentSettings.get_generation_setting_by_user(user_id, type, platform)

    setting = existing_setting || create_new_setting(user_id, type, platform)

    page_title = if existing_setting, do: "Edit Content Setting", else: "New Content Setting"

    socket
    |> assign(:page_title, page_title)
    |> assign(:content_generation_setting, setting)
  end

  defp apply_action(socket, :new_content_setting, %{"platform" => platform}) do
    user_id = socket.assigns.current_user.id
    type = get_content_type(platform)
    setting = create_new_setting(user_id, type, platform)

    socket
    |> assign(:page_title, "New Content Setting")
    |> assign(:content_generation_setting, setting)
  end

  defp apply_action(socket, _live_action, _params), do: socket

  defp get_content_type("EMAIL"), do: "EMAIL"
  defp get_content_type(_), do: "POST"

  defp create_new_setting(user_id, type, platform) do
    %GenerationSetting{
      type: type,
      platform: platform,
      user_id: user_id,
      name: generate_default_name(platform, type)
    }
  end

  defp generate_default_name(platform, type) do
    platform_name = platform |> String.downcase() |> String.capitalize()
    content_type = if type == "EMAIL", do: "Email", else: "Post"
    "#{platform_name} #{content_type} Template"
  end

  @impl true
  def handle_info(
        {PostmeetingWeb.ContentGenerationSettingLive.FormComponent, {:saved, _}},
        socket
      ) do
    content_settings =
      ContentSettings.list_user_generation_settings(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:content_settings, content_settings)
     |> push_patch(to: ~p"/settings")}
  end

  @impl true
  def handle_event("disconnect_google", %{"id" => account_id}, socket) do
    case Accounts.disconnect_google_account(socket.assigns.current_user, account_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Google Calendar account disconnected successfully.")
         |> assign(:google_accounts, Accounts.list_all_google_accounts(socket.assigns.current_user))
         |> assign(:calendar_events, [])}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error disconnecting Google Calendar account.")}
    end
  end

  @impl true
  def handle_event("disconnect_facebook", %{"id" => account_id}, socket) do
    case Accounts.disconnect_facebook_account(socket.assigns.current_user, account_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Facebook account disconnected successfully.")
         |> assign(
           :facebook_accounts,
           Accounts.list_facebook_accounts(socket.assigns.current_user)
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error disconnecting Facebook account.")}
    end
  end

  @impl true
  def handle_event("disconnect_linkedin", %{"id" => account_id}, socket) do
    case Accounts.disconnect_linkedin_account(socket.assigns.current_user, account_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "LinkedIn account disconnected successfully.")
         |> assign(
           :linkedin_accounts,
           Accounts.list_linkedin_accounts(socket.assigns.current_user)
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error disconnecting LinkedIn account.")}
    end
  end

  @impl true
  def handle_event("refresh_events", _, socket) do
    calendar_events = get_calendar_events(socket.assigns.current_user)
    {:noreply, assign(socket, :calendar_events, calendar_events)}
  end

  defp get_calendar_events(user) do
    case Calendar.list_events_with_zoom(user) do
      {:ok, events} -> events
      {:error, _} -> []
    end
  end

  defp get_setting(content_settings, type, platform) do
    Enum.find(content_settings, &(&1.type == type && &1.platform == platform))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-12 py-12">
      <.integration_section
        title="Google Calendar Integration"
        accounts={@google_accounts}
        connect_path={~p"/auth/google"}
        connect_text="Connect Google Calendar"
        add_text="Add Another Account"
        disconnect_event="disconnect_google"
      />

      <.integration_section
        title="Facebook Integration"
        accounts={@facebook_accounts}
        connect_path={~p"/auth/facebook"}
        connect_text="Connect Facebook Account"
        disconnect_event="disconnect_facebook"
        show_status={true}
      />

      <.integration_section
        title="LinkedIn Integration"
        accounts={@linkedin_accounts}
        connect_path={~p"/auth/linkedin"}
        connect_text="Connect LinkedIn Account"
        disconnect_event="disconnect_linkedin"
        show_status={true}
      />

      <.content_generation_section content_settings={@content_settings} />
    </div>

    <.modal
      :if={@live_action in [:new_content_setting, :edit_content_setting]}
      id="content_generation_setting-modal"
      show
      on_cancel={JS.patch(~p"/settings")}
    >
      <.live_component
        module={PostmeetingWeb.ContentGenerationSettingLive.FormComponent}
        id={@content_generation_setting.id || :new}
        title={@page_title}
        action={@live_action}
        content_generation_setting={@content_generation_setting}
        patch={~p"/settings"}
      />
    </.modal>
    """
  end

  # Component for integration sections
  defp integration_section(assigns) do
    assigns = assign_new(assigns, :show_status, fn -> false end)
    assigns = assign_new(assigns, :add_text, fn -> nil end)

    ~H"""
    <div>
      <div class="flex justify-between items-center">
        <h1 class="text-lg font-semibold leading-8">{@title}</h1>
        <.link
          :if={!Enum.empty?(@accounts) && @add_text}
          href={@connect_path}
          class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
        >
          {@add_text}
        </.link>
      </div>

      <div class="mt-6 bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <div class="space-y-6">
            <%= if Enum.empty?(@accounts) do %>
              <div class="text-sm text-gray-500">
                <p>No accounts connected.</p>
                <.link
                  href={@connect_path}
                  class="mt-4 inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
                >
                  {@connect_text}
                </.link>
              </div>
            <% else %>
              <%= for account <- @accounts do %>
                <div class="flex items-start justify-between">
                  <div class={["flex items-start", if(@show_status, do: "space-x-3", else: "")]}>
                    <div :if={@show_status} class="flex-shrink-0">
                      <.icon name="hero-check-circle" class="h-6 w-6 text-green-500" />
                    </div>
                    <div class={if(@show_status, do: "min-w-0 flex-1", else: "text-sm text-gray-900")}>
                      <p class="text-sm font-medium text-gray-900">
                        <%= if @show_status do %>
                          Connected as {account.name || "Account"}
                        <% else %>
                          {account.name || account.email}
                        <% end %>
                      </p>
                      <%= if @show_status do %>
                        <p class="mt-1 text-xs text-gray-500">
                          Connected {Calendar.format_relative_time(account.inserted_at)}
                        </p>
                      <% else %>
                        <p class="text-gray-500">{account.email}</p>
                      <% end %>
                    </div>
                  </div>
                  <button
                    phx-click={@disconnect_event}
                    phx-value-id={account.id}
                    class="text-sm font-medium text-red-600 hover:text-red-500"
                    data-confirm="Are you sure you want to disconnect this account?"
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
    """
  end

  # Component for content generation settings
  defp content_generation_section(assigns) do
    ~H"""
    <div>
      <h1 class="text-lg font-semibold leading-8">Content Generation Settings</h1>
      <div class="mt-6 bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <div class="space-y-4">
            <p class="text-sm text-gray-700">
              Configure templates for automatically generating content from meeting transcripts.
            </p>

            <.content_setting_card
              title="Email Generation"
              description="Configure how meeting summaries are formatted for email distribution."
              platform="EMAIL"
              setting={get_setting(@content_settings, "EMAIL", "EMAIL")}
            />

            <.content_setting_card
              title="LinkedIn Post Generation"
              description="Configure how meeting insights are formatted for LinkedIn posts."
              platform="LINKEDIN"
              setting={get_setting(@content_settings, "POST", "LINKEDIN")}
            />

            <.content_setting_card
              title="Facebook Post Generation"
              description="Configure how meeting summaries are formatted for Facebook posts."
              platform="FACEBOOK"
              setting={get_setting(@content_settings, "POST", "FACEBOOK")}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component for individual content setting cards
  defp content_setting_card(assigns) do
    ~H"""
    <div class="border border-gray-200 rounded-lg">
      <div class="px-4 py-3 bg-gray-50 rounded-t-lg">
        <h3 class="text-sm font-medium text-gray-900">{@title}</h3>
      </div>
      <div class="px-4 py-3 border-t border-gray-200">
        <p class="text-sm text-gray-600 mb-3">{@description}</p>
        <%= if @setting do %>
          <.link
            patch={~p"/settings/content/edit?platform=#{@platform}"}
            class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
          >
            <.icon name="hero-pencil" class="mr-2 h-4 w-4" />
            Edit {String.split(@title) |> List.first()} Template
          </.link>
          <div class="mt-2 text-xs text-green-600">
            Template configured: {@setting.name}
          </div>
        <% else %>
          <.link
            patch={~p"/settings/content?platform=#{@platform}"}
            class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
          >
            <.icon name="hero-plus" class="mr-2 h-4 w-4" />
            Configure {String.split(@title) |> List.first()} Template
          </.link>
        <% end %>
      </div>
    </div>
    """
  end
end
