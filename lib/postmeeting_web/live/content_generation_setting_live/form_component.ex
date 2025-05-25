defmodule PostmeetingWeb.ContentGenerationSettingLive.FormComponent do
  use PostmeetingWeb, :live_component

  alias Postmeeting.ContentSettings

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          Use this form to manage content generation setting records in your database.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="content_generation_setting-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />

        <input type="hidden" name="generation_setting[type]" value={@form[:type].value} />
        <input type="hidden" name="generation_setting[platform]" value={@form[:platform].value} />
        <input type="hidden" name="generation_setting[user_id]" value={@form[:user_id].value} />

        <.input
          field={@form[:description]}
          type="textarea"
          label="Description"
          placeholder="Describe what this template is used for and any specific formatting requirements..."
        />
        <.input
          field={@form[:example]}
          type="textarea"
          label="Example"
          placeholder="Provide an example of the generated content format. Use placeholders like {{meeting_name}}, {{key_points}}, {{attendees}}, etc."
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save Content generation setting</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{content_generation_setting: content_generation_setting} = assigns, socket) do
    # Create changeset with empty changes to populate form with existing data
    changeset = ContentSettings.change_generation_setting(content_generation_setting, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"generation_setting" => generation_setting_params}, socket) do
    changeset =
      socket.assigns.content_generation_setting
      |> ContentSettings.change_generation_setting(generation_setting_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"generation_setting" => generation_setting_params}, socket) do
    # Use the action from assigns, not socket.assigns.action
    action = if socket.assigns.content_generation_setting.id, do: :edit, else: :new
    save_content_generation_setting(socket, action, generation_setting_params)
  end

  defp save_content_generation_setting(socket, :edit, generation_setting_params) do
    case ContentSettings.update_generation_setting(
           socket.assigns.content_generation_setting,
           generation_setting_params
         ) do
      {:ok, content_generation_setting} ->
        notify_parent({:saved, content_generation_setting})

        {:noreply,
         socket
         |> put_flash(:info, "Content generation setting updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_content_generation_setting(socket, :new, generation_setting_params) do
    case ContentSettings.create_generation_setting(generation_setting_params) do
      {:ok, content_generation_setting} ->
        notify_parent({:saved, content_generation_setting})

        {:noreply,
         socket
         |> put_flash(:info, "Content generation setting created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
