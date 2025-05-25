defmodule Postmeeting.Workers.ScheduledCalendarSyncWorker do
  use Oban.Worker, queue: :calendar, max_attempts: 3

  alias Postmeeting.Accounts
  alias Postmeeting.Workers.CalendarSyncWorker

  @impl Oban.Worker
  def perform(_job) do
    users = Accounts.list_users()

    Enum.each(users, fn user ->
      CalendarSyncWorker.new(%{"user_id" => user.id}) |> Oban.insert()
    end)

    :ok
  end
end
