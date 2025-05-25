defmodule Postmeeting.Repo.Migrations.AddUniqueUserConstraints do
  use Ecto.Migration

  def change do
    drop index(:facebook_accounts, [:user_id])
    create unique_index(:facebook_accounts, [:user_id])

    drop index(:linkedin_accounts, [:user_id])
    create unique_index(:linkedin_accounts, [:user_id])
  end
end
