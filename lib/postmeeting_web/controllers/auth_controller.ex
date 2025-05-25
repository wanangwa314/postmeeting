defmodule PostmeetingWeb.AuthController do
  use PostmeetingWeb, :controller
  plug Ueberauth

  alias Postmeeting.Accounts
  alias PostmeetingWeb.UserAuth
  alias Postmeeting.Auth.LinkedIn

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

  def callback(%{assigns: %{ueberauth_auth: %{provider: :linkedin} = auth}} = conn, _params) do
    case OAuth2.Client.get_token(Postmeeting.Auth.LinkedIn.client(),
           code: auth.credentials.token,
           grant_type: "authorization_code"
         ) do
      {:ok, client} ->
        case find_or_create_user(%{
               email: auth.info.email,
               name: auth.info.name || auth.info.nickname
             }) do
          {:ok, user} ->
            case Accounts.create_linkedin_account(user, client) do
              {:ok, _linkedin_account} ->
                conn
                |> put_flash(:info, "Successfully connected with LinkedIn.")
                |> UserAuth.log_in_user(user)

              {:error, :already_connected} ->
                conn
                |> put_flash(:error, "This user already has a connected LinkedIn account.")
                |> redirect(to: ~p"/")
            end

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Error authenticating with LinkedIn.")
            |> redirect(to: ~p"/")
        end

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error authenticating with LinkedIn.")
        |> redirect(to: ~p"/")
    end
  end

  def callback(%{assigns: %{ueberauth_auth: %{provider: :facebook} = auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      name: auth.info.name || auth.info.nickname
    }

    case find_or_create_user(user_params) do
      {:ok, user} ->
        case Accounts.create_facebook_account(user, auth) do
          {:ok, _facebook_account} ->
            conn
            |> put_flash(:info, "Successfully connected with Facebook.")
            |> UserAuth.log_in_user(user)

          {:error, :already_connected} ->
            conn
            |> put_flash(:error, "This user already has a connected Facebook account.")
            |> redirect(to: ~p"/")
        end

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error authenticating with Facebook.")
        |> redirect(to: ~p"/")
    end
  end

  # Keep existing Ueberauth callback handler for other providers
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      name: auth.info.name || auth.info.nickname
    }

    case find_or_create_user(user_params) do
      {:ok, user} ->
        # Create new Google account
        {:ok, _google_account} = Accounts.create_google_account(user, auth)

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
