defmodule Postmeeting.Meetings do
  alias Postmeeting.Repo
  alias Postmeeting.Meetings.Meeting
  import Ecto.Query, warn: false

  def list_user_meetings(user_id) do
    now = DateTime.utc_now()

    upcoming_meetings =
      from(m in Meeting,
        where: m.user_id == ^user_id and m.status == "scheduled" and m.start_time > ^now,
        order_by: [asc: m.start_time]
      )
      |> Repo.all()

    ongoing_meetings =
      from(m in Meeting,
        where: m.user_id == ^user_id and m.status == "in_progress",
        order_by: [asc: m.start_time]
      )
      |> Repo.all()

    completed_meetings_with_transcripts =
      from(m in Meeting,
        where: m.user_id == ^user_id and m.status == "completed" and not is_nil(m.transcript),
        order_by: [desc: m.start_time]
      )
      |> Repo.all()

    %{
      upcoming: upcoming_meetings,
      ongoing: ongoing_meetings,
      completed_with_transcripts: completed_meetings_with_transcripts
    }
  end

  def get_user_meeting(user_id, meeting_id) do
    # Assuming you have a Meeting schema and repo
    # Adjust this query based on your actual schema structure
    from(m in Meeting,
      where: m.user_id == ^user_id and m.id == ^meeting_id
    )
    |> Repo.one()
  end
end
