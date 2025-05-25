defmodule Postmeeting.Repo.Migrations.CreateGoogleAccounts do
  use Ecto.Migration

  def change do
    create table(:google_accounts) do
      add :access_token, :text, null: false
      add :refresh_token, :text
      add :expires_at, :utc_datetime
      add :scope, :text
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:google_accounts, [:user_id])
  end
end
