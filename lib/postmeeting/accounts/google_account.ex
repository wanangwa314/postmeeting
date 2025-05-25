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
    belongs_to :user, Postmeeting.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(google_account, attrs) do
    google_account
    |> cast(attrs, [:access_token, :refresh_token, :expires_at, :scope, :name, :email, :user_id])
    |> validate_required([:access_token, :email, :user_id])
    |> unique_constraint([:user_id, :email], name: :google_accounts_user_id_email_index)
  end
end
