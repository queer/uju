defmodule Server.Protocol.V1.Session do
  use GenServer

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
          authenticated: boolean(),
          parent: pid() | nil
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

  ## Invoked internally, called by state machine

  def handle_cast(:finish_auth, state) do
    state =
      state
      |> Map.put(:authenticated, true)

    Emit.sub(%{})

    {:noreply, state}
  end

  def handle_cast({:configure, config}, state) do
    state =
      state
      |> Map.put(:config, config)

    {:noreply, state}
  end

  ## External API: Async calls

  ## Invoked externally, calls into state machine
  def handle_cast({:in, message}, state) do
    state =
      state
      |> Map.put(:last_client_interaction, now())

    Machine.process_message(self(), message)

    {:noreply, state}
  end

  ## Invoked externally, never touches state machine
  def handle_cast({:out, message}, state) do
    if state.parent && Process.alive?(state.parent) do
      # We provide the config to the external connection so that it can
      # determine how to encode the message
      send(state.parent, {:out, message, state.config})

      {:noreply, state}
    else
      state =
        state
        |> Map.put(:session_mailbox, [message | state.session_mailbox])
        |> Map.put(:session_size, state.session_size + 1)

      {:noreply, state}
    end
  end

  ## External API: Sync data retrieval

  def handle_call(:get_session_size, _from, state) do
    {:reply, state.session_size, state}
  end

  def handle_call(:flush_mailbox, _from, state) do
    {:reply, state.session_mailbox, %{state | session_mailbox: []}}
  end

  def handle_call(:get_config, _from, state) do
    {:reply, state.config, state}
  end

  def handle_call(:authenticated?, _from, state) do
    {:reply, state.authenticated, state}
  end

  def handle_call({:reparent, pid}, _from, state) do
    {:reply, :ok, %{state | parent: pid}}
  end

  ## External API: Sync data manipulation

  def flush_mailbox(session) do
    GenServer.call(session, :flush_mailbox)
  end

  def get_config(session) do
    GenServer.call(session, :get_config)
  end

  def authenticated?(session) do
    GenServer.call(session, :authenticated?)
  end

  def reparent(session, new_parent) do
    GenServer.call(session, {:reparent, new_parent})
  end

  ## External API: Message I/O

  def send_incoming_message(session, message) do
    GenServer.cast(session, {:in, message})
  end

  def send_outgoing_message(session, message) do
    GenServer.cast(session, {:out, message})
  end

  ## State machine API

  def finish_auth(session) do
    GenServer.cast(session, :finish_auth)
  end

  def configure(session, config) do
    GenServer.cast(session, {:configure, config})
  end

  ## External API: Misc. helpers

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
