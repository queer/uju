import Config

config :emit, :task_scheduler, Server.Emit.TaskScheduler

config :server, :plugins, [
  Server.Internal.V1.SendQuery.Plugin
]

config :server, :sessions, heartbeat_interval: 10_000

env_config = "#{Mix.env()}.exs"

if File.exists?("config/#{env_config}") do
  import_config(env_config)
end
