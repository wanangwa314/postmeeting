defmodule PostmeetingWeb.UserAuth do
  use PostmeetingWeb, :verified_routes

  import Plug.Conn
  import Phoenix.LiveView
  import Phoenix.Component, only: [assign_new: 3]

  alias Postmeeting.Accounts

  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_postmeeting_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  def log_in_user(conn, user, _params \\ %{}) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
    |> Phoenix.Controller.redirect(to: ~p"/calendar")
  end

  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> Phoenix.Controller.redirect(to: ~p"/")
  end

  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    with {:ok, socket} <- mount_current_user(socket, session) do
      if socket.assigns.current_user do
        {:cont, socket}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
          |> redirect(to: ~p"/")

        {:halt, socket}
      end
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    mount_current_user(socket, session)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must log in to access this page.")
      |> Phoenix.Controller.redirect(to: ~p"/auth/google")
      |> halt()
    end
  end

  defp mount_current_user(socket, session) do
    case session do
      %{"user_token" => user_token} ->
        {:ok,
         assign_new(socket, :current_user, fn ->
           Accounts.get_user_by_session_token(user_token)
         end)}

      %{} ->
        {:ok, assign(socket, :current_user, nil)}
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
