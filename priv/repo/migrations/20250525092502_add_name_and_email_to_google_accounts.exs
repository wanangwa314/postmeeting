defmodule Postmeeting.Repo.Migrations.AddNameAndEmailToGoogleAccounts do
  use Ecto.Migration

  def change do
    alter table(:google_accounts) do
      add :name, :string
      add :email, :string
    end

    create unique_index(:google_accounts, [:user_id, :email],
             name: :google_accounts_user_id_email_index
           )
  end
end
