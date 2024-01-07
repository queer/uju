defmodule Server.External.V1Payloads do
  alias Server.Protocol.V1
  alias Server.Protocol.V1.ServerMessagePayload

  def ok_payload(data) do
    V1.build(:SERVER_MESSAGE, %ServerMessagePayload{
      code: V1.codes()[:_response_status_success],
      message: V1.messages()[:_response_status_success],
      extra: data,
      layer: "protocol"
    })
  end

  def error_payload(data) do
    V1.build(:SERVER_MESSAGE, %ServerMessagePayload{
      code: V1.codes()[:_response_status_failure],
      message: V1.messages()[:_response_status_failure],
      extra: data,
      layer: "protocol"
    })
  end
end
