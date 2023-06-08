import Config

config :emit, :task_scheduler, Server.Emit.TaskScheduler

config :server, :plugins, [
  Server.Internal.SendQuery.Plugin
]
