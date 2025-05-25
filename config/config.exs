# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :postmeeting,
  ecto_repos: [Postmeeting.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :postmeeting, PostmeetingWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PostmeetingWeb.ErrorHTML, json: PostmeetingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Postmeeting.PubSub,
  live_view: [signing_salt: "x6IUPr3x"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :postmeeting, Postmeeting.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  postmeeting: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  postmeeting: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Ueberauth
config :ueberauth, Ueberauth,
  providers: [
    google:
      {Ueberauth.Strategy.Google,
       [
         default_scope: "email profile https://www.googleapis.com/auth/calendar.readonly",
         prompt: "consent",
         access_type: "offline"
       ]},
    facebook:
      {Ueberauth.Strategy.Facebook,
       [
         default_scope: "email,public_profile,pages_manage_posts,publish_actions"
       ]}
  ]

# Configure Google OAuth
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: "1085518600345-gdejvt7bmi752nuf2gdl4jhep8nco9pe.apps.googleusercontent.com",
  client_secret: "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"

config :ueberauth, Ueberauth.Strategy.Facebook.OAuth,
  client_id: System.get_env("FACEBOOK_CLIENT_ID"),
  client_secret: System.get_env("FACEBOOK_CLIENT_SECRET")

# Configure Recall.ai
config :postmeeting, :recall, api_key: System.get_env("RECALL_API_KEY")

config :postmeeting, Oban,
  repo: Postmeeting.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"@hourly", Postmeeting.Workers.GoogleTokenRefreshWorker},
       {"* * * * *", Postmeeting.Workers.ScheduledCalendarSyncWorker}
     ]}
  ],
  queues: [
    calendar: 10,
    meetings: 10,
    transcripts: 10,
    # Added maintenance queue for token refresh
    maintenance: 5
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
