defmodule PostmeetingWeb.AuthController do
  use PostmeetingWeb, :controller
  plug Ueberauth

  alias Postmeeting.Accounts
  alias PostmeetingWeb.UserAuth

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      name: auth.info.name || auth.info.nickname
    }

    case find_or_create_user(user_params) do
      {:ok, user} ->
        # Store Google tokens
        {:ok, _google_account} = Accounts.create_or_update_google_account(user, auth)

        conn
        |> put_flash(:info, "Successfully authenticated.")
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error authenticating with Google.")
        |> redirect(to: ~p"/")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: ~p"/")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  defp find_or_create_user(%{email: email} = params) do
    case Accounts.get_user_by_email(email) do
      nil -> register_user(params)
      user -> {:ok, user}
    end
  end

  defp register_user(params) do
    Accounts.register_user(params)
  end
end
