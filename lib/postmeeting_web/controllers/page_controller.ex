defmodule PostmeetingWeb.PageController do
  use PostmeetingWeb, :controller

  def home(conn, _params) do
    # Redirect to calendar if already logged in
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/calendar")
    else
      render(conn, :home, layout: false)
    end
  end
end
