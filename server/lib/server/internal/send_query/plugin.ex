defmodule Server.Internal.SendQuery.Plugin do
  @behaviour Server.Plugins.V1

  alias Server.Cluster
  alias Server.Protocol.V1

  @table :metadata

  @impl true
  def init() do
    :mnesia.create_schema([])
    :mnesia.start()
    :mnesia.create_table(@table, attributes: [:session, :metadata])

    :ok
  end

  @impl true
  def handle_message_before(_session, _message) do
    :ok
  end

  @impl true
  def handle_send(session, %V1.SendPayload{config: config, data: data}) do
    Cluster.run(fn ->
      IO.puts("!!!")
    end)

    send(
      session,
      {:out,
       V1.build(:RECEIVE, %V1.ReceivePayload{
         nonce: config.nonce,
         data: data,
         _: %{
           pid: "#{inspect(session)}"
         }
       })}
    )

    :ok
  end

  @impl true
  def handle_configure(session, %V1.ConfigurePayload{
        config: %V1.SessionConfig{metadata: metadata}
      })
      when not is_nil(metadata) do
    :ok
  end

  def handle_configure(_, _) do
    :ok
  end

  @impl true
  def handle_message_after(_session, _message) do
    :ok
  end

  @impl true
  def name() do
    "Send/Query"
  end

  @impl true
  def description() do
    "Implements the query-and-send protocol."
  end

  @impl true
  def version() do
    Server.version()
  end
end
