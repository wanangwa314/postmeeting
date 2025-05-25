defmodule Postmeeting.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meetings" do
    field :name, :string
    field :start_time, :utc_datetime
    field :transcript, :string
    field :bot_id, :string
    field :status, :string, default: "scheduled"
    field :meeting_link, :string
    field :platform_type, :string
    field :linkedin_post, :string
    field :facebook_post, :string
    field :email, :string
    belongs_to :user, Postmeeting.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [
      :name,
      :start_time,
      :transcript,
      :bot_id,
      :status,
      :user_id,
      :meeting_link,
      :platform_type,
      :linkedin_post,
      :facebook_post,
      :email
    ])
    |> validate_required([:name, :start_time, :user_id, :meeting_link])
    |> unique_constraint(:meeting_link)
    |> validate_inclusion(:status, ["scheduled", "in_progress", "completed"])
    |> validate_inclusion(:platform_type, ["MEET", "TEAMS", "ZOOM"])
  end

  def update_changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [
      :start_time
    ])
  end
end
