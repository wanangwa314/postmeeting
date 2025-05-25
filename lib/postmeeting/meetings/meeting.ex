defmodule Postmeeting.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meetings" do
    field :name, :string
    field :start_time, :utc_datetime
    field :transcript, :string
    field :bot_id, :string
    field :status, :string, default: "scheduled"
    belongs_to :user, Postmeeting.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [:name, :start_time, :transcript, :bot_id, :status, :user_id])
    |> validate_required([:name, :start_time, :user_id])
    |> validate_inclusion(:status, ["scheduled", "in_progress", "completed"])
  end
end
