defmodule Server.External.V1WebsockHandler do
  import Server.External.V1Payloads
  alias Server.Protocol.V1
  alias Server.Protocol.V1.ServerMessagePayload

  @behaviour WebSock

  @impl true
  def init(state) do
    if state.session_id do
      case V1.Session.lookup_session(state.session_id) do
        {:ok, session} ->
          # TODO: Authenticate
          {:ok,
           %{
             session: session,
             session_id: state.session_id,
             parent: self()
           }}

        {:error, :not_found} ->
          {:stop, nil, {1008, "session not found"}, state}
      end
    else
      {:ok, session, session_id} =
        V1.Machine.init_session(
          %V1.SessionConfig{
            format: state.format,
            compression: state.compression,
            metadata: state.metadata
          },
          self()
        )

      {:ok,
       %{
         session: session,
         session_id: session_id
       }}
    end
  end

  @impl true
  def handle_control({_frame, [opcode: _opcode]}, state) do
    # "Note that implementations SHOULD NOT send a pong frame in response; this
    # MUST be automatically done by the web server before this callback has
    # been called."
    {:ok, state}
  end

  @impl true
  def handle_in({_frame, [opcode: :binary]}, state) do
    {:stop, nil, {1003, "uju clients cannot send compressed frames"}, state}
  end

  @impl true
  def handle_in({frame, [opcode: :text]}, state) do
    session = state.session
    config = V1.Session.get_config(session)
    {:ok, message} = V1.parse(V1.Payload, frame)
    V1.Session.send_incoming_message(session, message)
    {:ok, state}
  end

  @impl true
  def handle_info({:out, msg, config}, state) do
    {:push, encode(msg, config), state}
  end

  @impl true
  def handle_info(_, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp encode(data, config) do
    data =
      case config.format do
        "json" -> Jason.encode!(data)
        "msgpack" -> Msgpax.pack!(data)
      end

    data =
      case config.compression do
        "none" ->
          case config.format do
            "json" -> {:text, data}
            "msgpack" -> {:binary, data}
          end

        "zstd" ->
          {:binary, :ezstd.compress(data)}
      end

    data
  end
end
