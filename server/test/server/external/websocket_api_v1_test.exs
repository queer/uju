defmodule Server.External.WebsocketAPIV1Test do
  use ExUnit.Case, async: true
  use Plug.Test

  @port 0

  setup :http_server

  @tag :websocket
  describe "basic functionality" do
    test "a session can be created and send and receive messages", context do
      # Start the session
      IO.puts("Starting session...")
      client = SimpleWebSocketClient.tcp_client(context)
      SimpleWebSocketClient.http1_handshake(client, "/api/v1/socket", context)

      # Assert the HELLO interaction
      IO.puts("Awaiting HELLO...")
      assert {:ok, frame} = SimpleWebSocketClient.recv_text_frame(client)

      assert %{
               "opcode" => "HELLO"
             } = Jason.decode!(frame)

      # Authenticate with the server
      IO.puts("Authenticating...")

      SimpleWebSocketClient.send_text_frame(
        client,
        Jason.encode!(%{
          opcode: "AUTHENTICATE",
          payload: %{auth: "a", config: %{format: "json", compression: "none"}}
        })
      )

      assert {:ok, frame} = SimpleWebSocketClient.recv_text_frame(client)

      assert %{
               "opcode" => "SERVER_MESSAGE",
               "payload" => %{"code" => 0, "layer" => "protocol", "message" => "auth success"}
             } = Jason.decode!(frame)

      # Send a message
      IO.puts("Sending a message...")

      SimpleWebSocketClient.send_text_frame(
        client,
        Jason.encode!(%{
          opcode: "SEND",
          payload: %{
            method: "immediate",
            data: "test",
            query: %{
              _debug: %{},
              filter: [],
              select: nil
            },
            config: %{nonce: "asdf", await_reply: false}
          }
        })
      )

      __test_is_too_quick!()

      # Assert the RECEIVE interaction
      IO.puts("Awaiting RECEIVE...")
      assert {:ok, frame} = SimpleWebSocketClient.recv_text_frame(client)

      assert %{
               "opcode" => "RECEIVE",
               "payload" => %{
                 "data" => "test",
                 "nonce" => "asdf"
               }
             } = Jason.decode!(frame)

      IO.puts("Done!")
    end
  end

  defp __test_is_too_quick! do
    :timer.sleep(10)
  end

  defp http_server(_context) do
    {:ok, server_pid} =
      [
        plug: Server.External.RestAPI,
        port: @port,
        ip: :loopback
      ]
      |> Bandit.child_spec()
      |> start_supervised()

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    [base: "http://localhost:#{port}", port: port, server_pid: server_pid]
  end
end
