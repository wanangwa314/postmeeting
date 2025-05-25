defmodule Postmeeting.Repo.Migrations.CreateContentGenerationSettings do
  use Ecto.Migration

  def change do
    create table(:content_generation_settings) do
      add :name, :string, null: false
      add :type, :string, null: false  # EMAIL or POST
      add :platform, :string, null: false  # FACEBOOK, LINKEDIN, or EMAIL
      add :description, :text
      add :example, :text
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:content_generation_settings, [:user_id])
    create index(:content_generation_settings, [:type])
    create index(:content_generation_settings, [:platform])
    create unique_index(:content_generation_settings, [:user_id, :type, :platform])
  end
end
