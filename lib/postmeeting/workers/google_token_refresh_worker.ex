defmodule Postmeeting.Workers.GoogleTokenRefreshWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  require Logger
  alias Postmeeting.Accounts
  alias Postmeeting.Auth.GoogleTokenRefresher

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting Google token refresh job.")
    # Refresh tokens expiring in the next hour (or already expired)
    threshold_datetime = DateTime.add(DateTime.utc_now(), 1, :hour)

    google_accounts_to_refresh = Accounts.list_google_accounts_expiring_soon(threshold_datetime)

    if Enum.empty?(google_accounts_to_refresh) do
      Logger.info("No Google tokens need refreshing at this time.")
    else
      Logger.info(
        "Found #{Enum.count(google_accounts_to_refresh)} Google accounts needing token refresh."
      )

      Enum.each(google_accounts_to_refresh, fn account ->
        case GoogleTokenRefresher.refresh_access_token(account) do
          {:ok, _updated_account} ->
            # Handled by logger in refresher
            :ok

          {:error, :no_refresh_token} ->
            # Handled by logger in refresher
            :ok

          {:error, reason} ->
            Logger.error(
              "Skipping refresh for account #{account.id} due to error: #{inspect(reason)}"
            )
        end
      end)
    end

    :ok
  end
end
