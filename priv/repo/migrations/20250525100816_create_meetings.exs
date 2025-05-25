defmodule Postmeeting.Repo.Migrations.CreateMeetings do
  use Ecto.Migration

  def change do
    create table(:meetings) do
      add :name, :string, null: false
      add :start_time, :utc_datetime, null: false
      add :transcript, :text
      add :bot_id, :string
      add :status, :string, default: "scheduled", null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:meetings, [:user_id])
    create index(:meetings, [:status])
  end
end
