defmodule Postmeeting.Repo.Migrations.CreateLinkedinAccounts do
  use Ecto.Migration

  def change do
    create table(:linkedin_accounts) do
      add :access_token, :text, null: false
      add :expires_at, :utc_datetime
      add :linkedin_id, :string
      add :name, :string
      add :email, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:linkedin_accounts, [:user_id])
    create unique_index(:linkedin_accounts, [:linkedin_id])
  end
end
