# Blackout

A very thin wrapper around Erlang's mnesia used to provide distributed rate limiting, with little to no configuration and a simple API for developer happiness.

## Installation

[Blackout HexDocs](https://hexdocs.pm/blackout)

### Stand-Alone Applications

Install by adding `blackout` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:blackout, "~> 0.1.0"}
  ]
end
```

### Umbrella Applications

Add `blackout` to each umbrella application's `mix.exs` the same as above.
