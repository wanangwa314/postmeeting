defmodule Postmeeting.Repo.Migrations.AddFieldsToMeetings do
  use Ecto.Migration

  def change do
    alter table(:meetings) do
      add :platform_type, :string
      add :linkedin_post, :text
      add :facebook_post, :text
      add :email, :text
    end
  end
end
