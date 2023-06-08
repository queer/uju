defmodule Server.Plugins do
  @spec init() :: :ok | no_return()
  def init() do
    for plugin <- Server.plugins() do
      :ok = plugin.init()
    end
  end

  @spec invoke((module() -> Plugin.callback_result())) :: {:ok, [any()]} | {:error, any()}
  def invoke(callback) do
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

  @spec is?(module(), module()) :: boolean()
  def is?(plugin, behaviour) do
    behaviours = :attributes |> plugin.__info__() |> Keyword.get(:behaviour)
    behaviour in behaviours
  end

  @spec if_is(module(), module(), (module() -> any())) :: any()
  def if_is(plugin, behaviour, callback) do
    if is?(plugin, behaviour) do
      callback.()
    end
  end

  @spec if_is(module(), module(), atom(), [any()] | []) :: any()
  def if_is(plugin, behaviour, function, args) do
    if is?(plugin, behaviour) do
      apply(plugin, function, args)
    end
  end

  @spec invoke_only(module(), (module() -> any())) :: {:ok, [any()]} | {:error, any()}
  def invoke_only(behaviour, callback) do
    invoke(fn plugin ->
      if is?(plugin, behaviour) do
        callback.(plugin)
      end
    end)
  end

  @spec invoke_only(module(), atom(), [any()] | []) :: {:ok, [any()]} | {:error, any()}
  def invoke_only(behaviour, function, args) do
    invoke(fn plugin ->
      if is?(plugin, behaviour) do
        apply(plugin, function, args)
      end
    end)
  end
end
