defmodule Server.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :syn.add_node_to_scopes([
      :sessions
    ])

    Server.Plugins.init()

    children = [
      {Task.Supervisor, name: Server.Emit.TaskScheduler},
      {Task.Supervisor, name: Server.TaskSupervisor},
      Emit.Cluster,
      Emit.DB,
      {Bandit, plug: Server.External.RestAPI, options: [port: 8080]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
