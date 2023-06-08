defmodule Server.Cluster do
  @moduledoc """
  Cluster facade, executes any operations that need to run on one-or-more nodes.
  """

  @task_timeout 5_000

  @spec run(function()) :: %{node() => any()}
  def run(func) do
    [Node.list() ++ Node.self()]
    |> Enum.map(fn node ->
      {node,
       Task.Supervisor.async({Server.TaskSupervisor, node}, fn ->
         func.()
       end)}
    end)
    |> Enum.map(fn {node, task} -> {node, Task.await(task, @task_timeout)} end)
    |> Enum.reduce(%{}, fn
      {node, res}, acc ->
        Map.put(acc, node, res)
    end)
  end
end
