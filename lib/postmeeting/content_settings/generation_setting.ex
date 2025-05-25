defmodule Postmeeting.ContentSettings.GenerationSetting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_generation_settings" do
    field :name, :string
    field :type, :string
    field :platform, :string
    field :description, :string
    field :example, :string
    belongs_to :user, Postmeeting.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(generation_setting, attrs) do
    generation_setting
    |> cast(attrs, [:name, :type, :platform, :description, :example, :user_id])
    |> validate_required([:name, :type, :platform, :user_id])
    |> validate_inclusion(:type, ["EMAIL", "POST"])
    |> validate_inclusion(:platform, ["FACEBOOK", "LINKEDIN", "EMAIL"])
    |> unique_constraint([:user_id, :type, :platform])
  end
end
