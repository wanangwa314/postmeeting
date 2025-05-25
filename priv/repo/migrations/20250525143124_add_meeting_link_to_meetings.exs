defmodule Postmeeting.Repo.Migrations.AddMeetingLinkToMeetings do
  use Ecto.Migration

  def change do
    alter table(:meetings) do
      add :meeting_link, :string
    end

    create unique_index(:meetings, [:meeting_link])
  end
end
