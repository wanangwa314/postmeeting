defmodule Postmeeting.Accounts.FacebookAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "facebook_accounts" do
    field :access_token, :string
    field :expires_at, :utc_datetime
    field :facebook_id, :string
    field :name, :string
    field :email, :string
    belongs_to :user, Postmeeting.Accounts.User

    timestamps()
  end

  def changeset(facebook_account, attrs) do
    facebook_account
    |> cast(attrs, [:access_token, :expires_at, :facebook_id, :name, :email, :user_id])
    |> validate_required([:access_token, :user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:facebook_id)
    |> unique_constraint(:user_id, message: "already has a connected Facebook account")
  end
end
