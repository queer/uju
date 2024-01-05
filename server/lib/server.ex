defmodule Server do
  @spec version() :: Version.t() | no_return()
  def version do
    :server
    |> Application.spec(:vsn)
    |> to_string()
    |> Version.parse!()
  end

  @spec plugins() :: [module()]
  def plugins, do: Application.get_env(:server, :plugins)
end
