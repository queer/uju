# Bandit test websocket client
# Source: https://github.com/mtrudel/bandit/blob/caafa65148a8ecb15642c5f7ca0a0f19bdbf72e1/test/support/transport.ex
# Under the MIT licence as per the source repo
defmodule Transport do
  @moduledoc false

  def tcp_client(context) do
    {:ok, socket} =
      :gen_tcp.connect(~c"localhost", context[:port], active: false, mode: :binary, nodelay: true)

    {:client, %{socket: socket, transport: :gen_tcp}}
  end

  def tls_client(context, protocols) do
    {:ok, socket} =
      :ssl.connect(~c"localhost", context[:port],
        active: false,
        mode: :binary,
        nodelay: true,
        verify: :verify_peer,
        cacertfile: Path.join(__DIR__, "../support/ca.pem"),
        alpn_advertised_protocols: protocols
      )

    {:client, %{socket: socket, transport: :ssl}}
  end

  def send({:client, %{transport: transport, socket: socket}}, data) do
    transport.send(socket, data)
  end

  def recv({:client, %{transport: transport, socket: socket}}, length) do
    transport.recv(socket, length)
  end

  def close({:client, %{transport: transport, socket: socket}}) do
    transport.close(socket)
  end

  def sockname({:client, %{transport: :gen_tcp, socket: socket}}) do
    :inet.sockname(socket)
  end

  def sockname({:client, %{transport: :ssl, socket: socket}}) do
    :ssl.sockname(socket)
  end
end
