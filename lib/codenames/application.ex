defmodule Codenames.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CodenamesWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:codenames, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Codenames.PubSub},
      {Registry, keys: :unique, name: Codenames.GameRegistry},
      {DynamicSupervisor, name: Codenames.GameSupervisor, strategy: :one_for_one},
      CodenamesWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Codenames.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CodenamesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
