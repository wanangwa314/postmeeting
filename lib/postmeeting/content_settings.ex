defmodule Postmeeting.ContentSettings do
  @moduledoc """
  The ContentSettings context.
  """

  import Ecto.Query, warn: false
  alias Postmeeting.Repo
  alias Postmeeting.ContentSettings.GenerationSetting

  @doc """
  Returns the list of content generation settings for a user.
  """
  def list_user_generation_settings(user_id) do
    Repo.all(
      from g in GenerationSetting,
        where: g.user_id == ^user_id,
        order_by: [asc: g.platform, asc: g.type]
    )
  end

  @doc """
  Gets a single generation_setting.
  """
  def get_generation_setting!(id), do: Repo.get!(GenerationSetting, id)

  @doc """
  Gets a generation setting by user, type, and platform.
  """
  def get_generation_setting_by_user(user_id, type, platform) do
    Repo.get_by(GenerationSetting, user_id: user_id, type: type, platform: platform)
  end

  @doc """
  Creates a generation_setting.
  """
  def create_generation_setting(attrs \\ %{}) do
    %GenerationSetting{}
    |> GenerationSetting.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a generation_setting.
  """
  def update_generation_setting(%GenerationSetting{} = generation_setting, attrs) do
    generation_setting
    |> GenerationSetting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a generation_setting.
  """
  def delete_generation_setting(%GenerationSetting{} = generation_setting) do
    Repo.delete(generation_setting)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking generation_setting changes.
  """
  def change_generation_setting(%GenerationSetting{} = generation_setting, attrs \\ %{}) do
    GenerationSetting.changeset(generation_setting, attrs)
  end
end
