defmodule Openapi.MixProject do
  use Mix.Project

  def project do
    [
      app: :openapi,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:yaml_elixir, "~> 2.12"}
    ]
  end
end
