defmodule Openapi.MixProject do
  use Mix.Project

  def project do
    [
      app: :openapi,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/modules"]
  defp elixirc_paths(_), do: ["lib"]

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
