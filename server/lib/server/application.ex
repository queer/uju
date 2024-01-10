defmodule Server.Application do
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
      {Emit.DB, Emit.DB.default_table()},
      {
        Bandit,
        plug: Server.External.RestAPI, port: 8080, websocket_options: [compress: false]
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
