defmodule Server.Protocol.ProtocolV1Test do
  use ExUnit.Case, async: true
  alias Server.Protocol.V1, as: Protocol

  alias Server.Protocol.V1.{
    HelloPayload,
    AuthenticatePayload,
    ServerMessagePayload,
    SendPayload,
    ReceivePayload,
    PingPayload,
    PongPayload,
    ConfigurePayload,
    SendImmediateConfig,
    SendLaterConfig,
    SessionConfig
  }

  describe "HelloPayload" do
    test "it parses" do
      assert %HelloPayload{session: "a", heartbeat: 1} =
               Protocol.parse(HelloPayload, %{"session" => "a", "heartbeat" => 1})
    end
  end

  describe "AuthenticatePayload" do
    test "it parses" do
      assert %AuthenticatePayload{auth: "a", config: %{format: "json", compression: "none"}} =
               Protocol.parse(AuthenticatePayload, %{
                 "auth" => "a",
                 "config" => %{"format" => "json", "compression" => "none"}
               })
    end
  end

  describe "ServerMessagePayload" do
    test "it parses" do
      assert %ServerMessagePayload{code: 1, message: "a", extra: "b", layer: "protocol"} =
               Protocol.parse(ServerMessagePayload, %{
                 "code" => 1,
                 "message" => "a",
                 "extra" => "b",
                 "layer" => "protocol"
               })

      assert %ServerMessagePayload{code: 1, message: "a", extra: "b", layer: "application"} =
               Protocol.parse(ServerMessagePayload, %{
                 "code" => 1,
                 "message" => "a",
                 "extra" => "b",
                 "layer" => "application"
               })
    end
  end

  describe "SendPayload" do
    test "it parses" do
      assert_raise RuntimeError, fn ->
        %SendPayload{method: "immediate", config: nil} =
          Protocol.parse(SendPayload, %{"method" => "immediate", "config" => nil})
      end

      assert %SendPayload{
               method: "immediate",
               config: %SendImmediateConfig{nonce: "a", await_reply: true}
             } =
               Protocol.parse(SendPayload, %{
                 "method" => "immediate",
                 "config" => %{"nonce" => "a", "await_reply" => true}
               })

      assert %SendPayload{
               method: "immediate",
               config: %SendImmediateConfig{nonce: "a", await_reply: false}
             } =
               Protocol.parse(SendPayload, %{
                 "method" => "immediate",
                 "config" => %{"nonce" => "a"}
               })

      assert %SendPayload{method: "later", config: %SendLaterConfig{group: "test"}} =
               Protocol.parse(SendPayload, %{
                 "method" => "later",
                 "config" => %{"group" => "test"}
               })
    end
  end

  describe "ReceivePayload" do
    test "it parses" do
      assert %ReceivePayload{nonce: "a", data: "b", _: %{}} =
               Protocol.parse(ReceivePayload, %{"nonce" => "a", "data" => "b", "_" => %{}})
    end
  end

  describe "PingPayload" do
    test "it parses" do
      assert %PingPayload{nonce: "a"} = Protocol.parse(PingPayload, %{"nonce" => "a"})
    end
  end

  describe "PongPayload" do
    test "it parses" do
      assert %PongPayload{nonce: "a", session_size: 0} =
               Protocol.parse(PongPayload, %{"nonce" => "a", "session_size" => 0})
    end
  end

  describe "ConfigurePayload" do
    test "it parses" do
      assert %ConfigurePayload{
               scope: "session",
               config: %SessionConfig{format: "json", compression: "zstd"}
             } =
               Protocol.parse(ConfigurePayload, %{
                 "scope" => "session",
                 "config" => %{"format" => "json", "compression" => "zstd"}
               })
    end
  end
end
