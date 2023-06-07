defmodule Server.Plugin do
  @callback init(any()) :: {:ok, any()} :: {:error, any()}
end
