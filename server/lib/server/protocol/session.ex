defmodule Server.Protocol.V1.Session do
  use GenServer

  alias Server.Protocol.V1
  alias Server.Protocol.V1.{Machine, SessionConfig}

  @type initial_state() :: %{
          config: SessionConfig.t(),
          session_id: binary()
        }

  @type state() :: %{
          config: SessionConfig.t(),
          session_id: binary(),
          session_size: non_neg_integer(),
          session_mailbox: list(),
          last_client_interaction: non_neg_integer(),
          authenticated: boolean()
        }

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  def init(state) do
    :ok = :syn.register(:sessions, state.session_id, self())

    state =
      state
      |> Map.put(:session_size, 0)
      |> Map.put(:session_mailbox, [])
      |> Map.put(:last_client_interaction, now())
      |> Map.put(:authenticated, false)

    {:ok, state}
  end

  def handle_info({:in, message}, state) do
    state =
      state
      |> Map.put(:last_client_interaction, now())

    Server.invoke_plugins(fn plugin ->
      plugin.handle_message_before(self(), message)
    end)

    Machine.process_message(self(), message)

    Server.invoke_plugins(fn plugin ->
      plugin.handle_message_after(self(), message)
    end)

    {:noreply, state}
  end

  def handle_info({:out, message}, state) do
    state =
      state
      |> Map.put(:session_mailbox, [message | state.session_mailbox])
      |> Map.put(:session_size, state.session_size + 1)

    {:noreply, state}
  end

  def handle_info(:finish_auth, state) do
    state =
      state
      |> Map.put(:authenticated, true)

    {:noreply, state}
  end

  def handle_info({:configure, config}, state) do
    state =
      state
      |> Map.put(:config, config)

    {:noreply, state}
  end

  def handle_call(:get_session_size, _from, state) do
    {:reply, state.session_size, state}
  end

  def handle_call(:flush_mailbox, _from, state) do
    {:reply, state.session_mailbox, %{state | session_mailbox: []}}
  end

  def handle_call(:get_config, _from, state) do
    {:reply, state.config, state}
  end

  def flush_mailbox(session) do
    GenServer.call(session, :flush_mailbox)
  end

  def get_config(session) do
    GenServer.call(session, :get_config)
  end

  def lookup_session(session_id) do
    case :syn.lookup(:sessions, session_id) do
      {session, _} -> {:ok, session}
      :undefined -> {:error, :not_found}
    end
  end

  defp now() do
    :os.system_time(:millisecond)
  end
end
