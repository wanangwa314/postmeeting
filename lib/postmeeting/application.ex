defmodule Postmeeting.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PostmeetingWeb.Telemetry,
      Postmeeting.Repo,
      {DNSCluster, query: Application.get_env(:postmeeting, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Postmeeting.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Postmeeting.Finch},
      # Start a worker by calling: Postmeeting.Worker.start_link(arg)
      # {Postmeeting.Worker, arg},
      # Start to serve requests, typically the last entry
      PostmeetingWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Postmeeting.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PostmeetingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
