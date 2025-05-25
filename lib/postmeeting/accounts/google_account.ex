defmodule Postmeeting.Accounts.GoogleAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "google_accounts" do
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :scope, :string
    belongs_to :user, Postmeeting.Accounts.User

    timestamps()
  end

  def changeset(google_account, attrs) do
    google_account
    |> cast(attrs, [:access_token, :refresh_token, :expires_at, :scope, :user_id])
    |> validate_required([:access_token, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
