defmodule Server.Internal.SendQuery.Plugin do
  @behaviour Server.Plugins.V1

  alias Server.Cluster
  alias Server.Internal.SendQuery.{Compiler, Planner}
  alias Server.Protocol.V1

  @table :session_metadata

  def table, do: @table

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
  def handle_send(_session, %V1.SendPayload{config: config, data: data, query: query}) do
    Cluster.run(fn ->
      %Planner.Query{plan: %Planner.Plan{query: query, ordering: _ordering}} =
        query
        |> Compiler.compile()
        |> Planner.plan()

      sessions =
        query
        |> Lethe.compile()
        |> Lethe.run()
        # TODO: Don't explode here
        |> OK.unwrap_ok!()

      for target_session <- sessions do
        V1.Session.send_outgoing_message(
          target_session,
          V1.build(:RECEIVE, %V1.ReceivePayload{
            nonce: config.nonce,
            data: data,
            _: %{
              pid: "#{inspect(target_session)}"
            }
          })
        )
      end
    end)

    :ok
  end

  @impl true
  def handle_configure(session, %V1.ConfigurePayload{
        config: %V1.SessionConfig{metadata: metadata}
      })
      when not is_nil(metadata) do
    :mnesia.transaction(fn ->
      :mnesia.write({@table, session, metadata})
    end)

    :ok
  end

  def handle_configure(_session, %V1.ConfigurePayload{config: _}) do
    :ok
  end

  @impl true
  def handle_message_after(_session, _message) do
    :ok
  end

  @impl true
  def handle_connect(session) do
    :mnesia.transaction(fn ->
      :mnesia.write({@table, session, %{}})
    end)

    :ok
  end

  @impl true
  def handle_disconnect(session) do
    :mnesia.transaction(fn ->
      :mnesia.delete({@table, session, :_})
    end)

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
