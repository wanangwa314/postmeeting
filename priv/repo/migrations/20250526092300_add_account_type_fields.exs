defmodule Postmeeting.Repo.Migrations.AddAccountTypeFields do
  use Ecto.Migration

  def change do
    alter table(:google_accounts) do
      add :is_primary, :boolean, default: false
      add :calendar_sync_enabled, :boolean, default: true
    end

    # Create a unique index to ensure only one primary Google account per user
    create unique_index(:google_accounts, [:user_id], where: "is_primary = true", name: :google_accounts_primary_user_id_index)
  end
end
