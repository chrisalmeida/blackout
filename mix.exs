defmodule Blackout.MixProject do
  use Mix.Project

  def project do
    [
      app: :blackout,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      name: "Blackout",
      source_url: "https://github.com/chrisalmeida/blackout",
      package: [
        name: "blackout",
        licenses: ["MIT"],
        links: %{"Github" => "https://github.com/chrisalmeida/blackout"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  # Package description
  defp description do
    "A very thin wrapper around Erlang's mnesia used to provide distributed rate limiting, with little to no configuration and a simple API for developer happiness."
  end
end
