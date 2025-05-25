defmodule Postmeeting.Repo.Migrations.AddCalendarFieldsToMeetings do
  use Ecto.Migration

  def change do
    alter table(:meetings) do
      add :calendar_event_id, :string
      add :description, :text
      add :location, :string
      add :attendees, {:array, :string}, default: []
      add :organizer_email, :string
    end

    create unique_index(:meetings, [:calendar_event_id])
  end
end
