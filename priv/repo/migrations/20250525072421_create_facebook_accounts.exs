defmodule Postmeeting.Repo.Migrations.CreateFacebookAccounts do
  use Ecto.Migration

  def change do
    create table(:facebook_accounts) do
      add :access_token, :text, null: false
      add :expires_at, :utc_datetime
      add :facebook_id, :string
      add :name, :string
      add :email, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:facebook_accounts, [:user_id])
    create unique_index(:facebook_accounts, [:facebook_id])
  end
end
