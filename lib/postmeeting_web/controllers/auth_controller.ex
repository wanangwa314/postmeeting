defmodule PostmeetingWeb.AuthController do
  use PostmeetingWeb, :controller
  plug Ueberauth

  alias Postmeeting.Accounts
  alias PostmeetingWeb.UserAuth
  alias Postmeeting.Auth.LinkedIn

  # Only allow Google for initial login
  def login(conn, _params) do
    redirect(conn, to: ~p"/auth/google")
  end

  # Handle LinkedIn OAuth specifically
  def request(conn, %{"provider" => "linkedin"}) do
    redirect(conn, external: LinkedIn.authorize_url!())
  end

  # Keep existing Ueberauth request handler for other providers
  def request(conn, _params) do
    render(conn, :request)
  end

  # Handle LinkedIn OAuth callback specifically
  def callback(conn, %{"provider" => "linkedin", "code" => code}) do
    client = LinkedIn.get_token!(code: code)
    user_info = LinkedIn.get_user_profile(client)

    user_params = %{
      email: user_info.email,
      name: "#{user_info.first_name} #{user_info.last_name}"
    }

    case find_or_create_user(user_params) do
      {:ok, user} ->
        # Create LinkedIn account connection
        {:ok, _linkedin_account} = Accounts.create_linkedin_account(user, client)

        conn
        |> put_flash(:info, "Successfully connected with LinkedIn.")
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error authenticating with LinkedIn.")
        |> redirect(to: ~p"/")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: ~p"/")
  end

  def callback(%{assigns: %{ueberauth_auth: %{provider: :google} = auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      name: auth.info.name || auth.info.nickname
    }

    case conn.assigns[:current_user] do
      nil ->
        # First time Google login or returning user
        case Accounts.create_user_with_google(user_params, auth) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Welcome back! Successfully logged in.")
            |> UserAuth.log_in_user(user)

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Error authenticating with Google.")
            |> redirect(to: ~p"/")
        end

      current_user ->
        # Adding additional Google account for calendar sync
        case Accounts.add_google_calendar_account(current_user, auth) do
          {:ok, _google_account} ->
            conn
            |> put_flash(:info, "Successfully added Google Calendar account.")
            |> redirect(to: ~p"/calendar")

          {:error, :already_connected} ->
            conn
            |> put_flash(:error, "This Google account is already connected.")
            |> redirect(to: ~p"/calendar")

          {:error, reason} ->
            dbg(reason)
            conn
            |> put_flash(:error, "Error connecting Google Calendar account.")
            |> redirect(to: ~p"/calendar")
        end
    end
  end

  def callback(%{assigns: %{ueberauth_auth: %{provider: :linkedin} = auth}} = conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "Please log in with your Google account first.")
        |> redirect(to: ~p"/auth/google")

      current_user ->
        case Accounts.add_linkedin_account(current_user, auth) do
          {:ok, _linkedin_account} ->
            conn
            |> put_flash(:info, "Successfully connected LinkedIn for posting.")
            |> redirect(to: ~p"/settings")

          {:error, :already_connected} ->
            conn
            |> put_flash(:error, "This LinkedIn account is already connected.")
            |> redirect(to: ~p"/settings")

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Error connecting LinkedIn account.")
            |> redirect(to: ~p"/settings")
        end
    end
  end

  def callback(%{assigns: %{ueberauth_auth: %{provider: :facebook} = auth}} = conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "Please log in with your Google account first.")
        |> redirect(to: ~p"/auth/google")

      current_user ->
        case Accounts.add_facebook_account(current_user, auth) do
          {:ok, _facebook_account} ->
            conn
            |> put_flash(:info, "Successfully connected Facebook for posting.")
            |> redirect(to: ~p"/settings")

          {:error, :already_connected} ->
            conn
            |> put_flash(:error, "This Facebook account is already connected.")
            |> redirect(to: ~p"/settings")

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Error connecting Facebook account.")
            |> redirect(to: ~p"/settings")
        end
    end
  end

  def callback(%{assigns: %{ueberauth_auth: _auth}} = conn, _params) do
    conn
    |> put_flash(:error, "Unsupported authentication provider.")
    |> redirect(to: ~p"/")
  end

  # Keep existing Ueberauth callback handler for other providers
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      name: auth.info.name || auth.info.nickname
    }

    case find_or_create_user(user_params) do
      {:ok, user} ->
        # Create or update Google account
        {:ok, _google_account} = Accounts.create_or_update_google_account(user, auth)

        conn
        |> put_flash(:info, "Successfully authenticated.")
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error authenticating.")
        |> redirect(to: ~p"/")
    end
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
