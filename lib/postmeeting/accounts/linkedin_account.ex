defmodule Postmeeting.Accounts.LinkedinAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "linkedin_accounts" do
    field :access_token, :string
    field :linkedin_id, :string
    field :name, :string
    field :email, :string
    belongs_to :user, Postmeeting.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(linkedin_account, attrs) do
    linkedin_account
    |> cast(attrs, [:access_token, :linkedin_id, :name, :email, :user_id])
    |> validate_required([:access_token, :user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:linkedin_id)
    |> unique_constraint(:user_id, message: "already has a connected LinkedIn account")
  end
end
