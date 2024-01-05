defmodule Server.MixProject do
  use Mix.Project

  def project do
    [
      app: :server,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Server.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},
      {:bandit, "~> 0.7.4"},
      {:delta_crdt, "~> 0.6.4"},
      {:emit, "~> 0.1.2"},
      {:ezstd, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:lethe, "~> 0.6.0"},
      {:msgpax, "~> 2.3"},
      {:plug, "~> 1.14"},
      {:syn, "~> 3.3"},
      {:typed_struct, "~> 0.3.0", override: true}
    ]
  end
end
