defmodule Postmeeting.Accounts.GoogleAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "google_accounts" do
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :scope, :string
    field :name, :string
    field :email, :string
    field :is_primary, :boolean, default: false
    field :calendar_sync_enabled, :boolean, default: false
    belongs_to :user, Postmeeting.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(google_account, attrs) do
    google_account
    |> cast(attrs, [:access_token, :refresh_token, :expires_at, :scope, :name, :email, :user_id, :is_primary, :calendar_sync_enabled])
    |> validate_required([:access_token, :email, :user_id])
    |> unique_constraint([:user_id, :email], name: :google_accounts_user_id_email_index)
    |> unique_constraint(:user_id, name: :google_accounts_primary_index, where: "is_primary = true")
  end
end
