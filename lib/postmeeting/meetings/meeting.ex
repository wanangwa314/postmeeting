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
    field :calendar_event_id, :string
    field :description, :string
    field :location, :string
    field :attendees, {:array, :string}, default: []
    field :organizer_email, :string
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
      :email,
      :calendar_event_id,
      :description,
      :location,
      :attendees,
      :organizer_email
    ])
    |> validate_required([:name, :start_time, :user_id, :meeting_link])
    |> unique_constraint(:meeting_link)
    |> unique_constraint(:calendar_event_id)
    |> validate_inclusion(:status, ["scheduled", "in_progress", "completed"])
    |> validate_inclusion(:platform_type, ["MEET", "TEAMS", "ZOOM"])
  end

  @doc """
  Changeset for updating non-critical fields without touching the status.
  Used by calendar sync to update meeting details without affecting workflow status.
  """
  def non_status_changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [
      :name,
      :start_time,
      :meeting_link,
      :platform_type,
      :description,
      :location,
      :attendees,
      :organizer_email
    ])
    |> validate_required([:name, :start_time, :meeting_link])
    |> unique_constraint(:meeting_link)
    |> unique_constraint(:calendar_event_id)
    |> validate_inclusion(:platform_type, ["MEET", "TEAMS", "ZOOM"])
  end

  def update_changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [
      :start_time
    ])
  end
end
