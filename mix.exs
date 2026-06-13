defmodule Openapi.MixProject do
  use Mix.Project

  def project do
    [
      app: :openapi,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Openapi.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.3"},
      {:yaml_elixir, "~> 2.12"},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
end
