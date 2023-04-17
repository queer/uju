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
      assert {:ok, %HelloPayload{session: "a", heartbeat: 1}} =
               Protocol.parse(HelloPayload, %{"session" => "a", "heartbeat" => 1})
    end
  end

  describe "AuthenticatePayload" do
    test "it parses" do
      assert {:ok,
              %AuthenticatePayload{auth: "a", config: %{format: "json", compression: "none"}}} =
               Protocol.parse(AuthenticatePayload, %{
                 "auth" => "a",
                 "config" => %{"format" => "json", "compression" => "none"}
               })
    end
  end

  describe "ServerMessagePayload" do
    test "it parses" do
      assert {:ok, %ServerMessagePayload{code: 1, message: "a", extra: "b", layer: "protocol"}} =
               Protocol.parse(ServerMessagePayload, %{
                 "code" => 1,
                 "message" => "a",
                 "extra" => "b",
                 "layer" => "protocol"
               })

      assert {:ok, %ServerMessagePayload{code: 1, message: "a", extra: "b", layer: "application"}} =
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
      assert {:error, :invalid_input,
              %{schema: _, input: %{"config" => nil, "method" => "immediate"}}} =
               Protocol.parse(SendPayload, %{"method" => "immediate", "config" => nil})

      assert {:ok,
              %SendPayload{
                method: "immediate",
                config: %SendImmediateConfig{nonce: "a", await_reply: true}
              }} =
               Protocol.parse(SendPayload, %{
                 "method" => "immediate",
                 "config" => %{"nonce" => "a", "await_reply" => true}
               })

      assert {:ok,
              %SendPayload{
                method: "immediate",
                config: %SendImmediateConfig{nonce: "a", await_reply: false}
              }} =
               Protocol.parse(SendPayload, %{
                 "method" => "immediate",
                 "config" => %{"nonce" => "a"}
               })

      assert {:ok, %SendPayload{method: "later", config: %SendLaterConfig{group: "test"}}} =
               Protocol.parse(SendPayload, %{
                 "method" => "later",
                 "config" => %{"group" => "test"}
               })
    end
  end

  describe "ReceivePayload" do
    test "it parses" do
      assert {:ok, %ReceivePayload{nonce: "a", data: "b", _: %{}}} =
               Protocol.parse(ReceivePayload, %{"nonce" => "a", "data" => "b", "_" => %{}})
    end
  end

  describe "PingPayload" do
    test "it parses" do
      assert {:ok, %PingPayload{nonce: "a"}} = Protocol.parse(PingPayload, %{"nonce" => "a"})
    end
  end

  describe "PongPayload" do
    test "it parses" do
      assert {:ok, %PongPayload{nonce: "a", session_size: 0}} =
               Protocol.parse(PongPayload, %{"nonce" => "a", "session_size" => 0})
    end
  end

  describe "ConfigurePayload" do
    test "it parses" do
      assert {:ok,
              %ConfigurePayload{
                scope: "session",
                config: %SessionConfig{format: "json", compression: "zstd"}
              }} =
               Protocol.parse(ConfigurePayload, %{
                 "scope" => "session",
                 "config" => %{"format" => "json", "compression" => "zstd"}
               })

      assert {:ok,
              %ConfigurePayload{
                scope: "session",
                config: %SessionConfig{format: "msgpack", compression: "zstd"}
              }} =
               Protocol.parse(ConfigurePayload, %{
                 "scope" => "session",
                 "config" => %{"format" => "msgpack", "compression" => "zstd"}
               })
    end
  end

  describe "SessionConfig" do
    test "it parses" do
      assert {:ok, %SessionConfig{format: "json", compression: "none"}} =
               Protocol.parse(SessionConfig, %{"format" => "json", "compression" => "none"})

      assert {:error, :invalid_input, %{input: %{"format" => "json"}, schema: _}} =
               Protocol.parse(SessionConfig, %{"format" => "json"})
    end
  end
end
