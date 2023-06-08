defmodule Server do
  alias __MODULE__.Plugin

  @spec plugins() :: [module()]
  def plugins, do: Application.get_env(:server, :plugins)

  @spec invoke_plugins((module() -> Plugin.callback_result())) :: {:ok, [any()]} | {:error, any()}
  def invoke_plugins(callback) do
    do_invoke_plugin(Server.plugins(), [], callback)
  end

  defp do_invoke_plugin([plugin | plugins], results, callback) do
    case callback.(plugin) do
      :ignore ->
        do_invoke_plugin(plugins, results, callback)

      :ok ->
        do_invoke_plugin(plugins, results, callback)

      {:ok, result} ->
        do_invoke_plugin(plugins, results ++ [result], callback)

      :halt ->
        {:ok, results}

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_invoke_plugin([], results, _callback) do
    {:ok, results}
  end
end
