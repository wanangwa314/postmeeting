defmodule Postmeeting.Auth.GoogleTokenRefresher do
  require Logger
  alias Postmeeting.Accounts
  alias Postmeeting.Accounts.GoogleAccount

  # Define a Tesla client
  defmodule Client do
    use Tesla

    plug Tesla.Middleware.FormUrlencoded
    plug Tesla.Middleware.JSON
    # Or your preferred adapter like Finch
    adapter(Tesla.Adapter.Hackney)
  end

  @google_token_url "https://oauth2.googleapis.com/token"

  def refresh_access_token(%GoogleAccount{} = google_account) do
    client_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth, [])
    client_id = Keyword.get(client_config, :client_id)
    client_secret = Keyword.get(client_config, :client_secret)

    unless client_id && client_secret do
      Logger.error("Google client_id or client_secret not configured.")
      # Corrected return
      {:error, :config_missing}
    else
      if is_nil(google_account.refresh_token) do
        # Corrected Logger.warn to Logger.warning
        Logger.warning(
          "Google account ##{google_account.id} has no refresh token. Skipping refresh."
        )

        # Corrected return
        {:error, :no_refresh_token}
      else
        params = [
          client_id: client_id,
          client_secret: client_secret,
          refresh_token: google_account.refresh_token,
          grant_type: "refresh_token"
        ]

        # Use Tesla for the POST request
        case Client.post(@google_token_url, params) do
          {:ok, %Tesla.Env{status: 200, body: body}} ->
            handle_successful_refresh(google_account, body)

          {:ok, %Tesla.Env{status: status_code, body: body}} ->
            Logger.error(
              "Failed to refresh Google token for account ##{google_account.id}. Status: #{status_code}, Body: #{inspect(body)}"
            )

            {:error, :http_error, status_code, body}

          # Match Tesla.Error
          {:error, %Tesla.Error{reason: reason}} ->
            Logger.error(
              "HTTP request failed for Google token refresh for account ##{google_account.id}. Reason: #{inspect(reason)}"
            )

            {:error, :http_request_failed, reason}
        end
      end
    end
  end

  # body from Tesla with JSON middleware is already decoded
  defp handle_successful_refresh(
         google_account,
         %{"access_token" => new_access_token, "expires_in" => expires_in_seconds} =
           new_token_data
       ) do
    expires_at = DateTime.add(DateTime.utc_now(), expires_in_seconds, :second)
    # Keep old scope if not returned
    scope = Map.get(new_token_data, "scope", google_account.scope)

    attrs_to_update = %{
      access_token: new_access_token,
      expires_at: expires_at,
      scope: scope
    }

    case Accounts.update_google_account(google_account, attrs_to_update) do
      {:ok, updated_account} ->
        Logger.info("Successfully refreshed Google token for account ##{updated_account.id}")
        {:ok, updated_account}

      {:error, changeset} ->
        Logger.error(
          "Failed to update Google account ##{google_account.id} after token refresh: #{inspect(changeset.errors)}"
        )

        {:error, :db_update_failed, changeset}
    end
  end

  # Handle cases where the body might not be the expected map (e.g., error in JSON decoding by middleware)
  defp handle_successful_refresh(google_account, body) do
    Logger.error(
      "Unexpected body structure in Google token refresh response for account ##{google_account.id}. Body: #{inspect(body)}"
    )

    {:error, :unexpected_json_structure, body}
  end
end
