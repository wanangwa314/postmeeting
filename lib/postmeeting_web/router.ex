defmodule PostmeetingWeb.Router do
  use PostmeetingWeb, :router

  import PostmeetingWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PostmeetingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PostmeetingWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/auth", PostmeetingWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
  end

  # Protected routes
  scope "/", PostmeetingWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/calendar", CalendarLive
    live "/settings", UserSettingsLive
    live "/settings/content", UserSettingsLive, :new_content_setting
    live "/settings/content/edit", UserSettingsLive, :edit_content_setting
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:postmeeting, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PostmeetingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
