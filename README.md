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

## Usage

### Connect Nodes

- **Node 1:** iex --name n1@x.x.x.x --cookie secret -S mix
- **Node 2:** iex --name n2@x.x.x.x --cookie secret -S mix

### Join Cluster

```Elixir
defmodule SomeModule.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {SomeModule.Worker, []}
    ]

    # Your nodes should be connected by this point
    connected_nodes = Node.list() ++ [Node.self()]
    schema = :my_schema_name

    {:ok, _} = Blackout.join_cluster(schema, connected_nodes)

    opts = [strategy: :one_for_one, name: SomeModule.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Check Rate Limit

```Elixir
iex(n1@x.x.x.x)1> schema = :my_schema_name
:my_schema_name

iex(n1@x.x.x.x)2> bucket_name = "route_requests"
"route_requests"

iex(n1@x.x.x.x)3> allowed_count = 2
2

iex(n1@x.x.x.x)4> bucket_expiration = 10_000
10_000

iex(n1@x.x.x.x)5> Blackout.check_bucket(schema, bucket_name, allowed_count, bucket_expiration)
{:atomic, {:ok, 10_000}}
```

### Delete Bucket

```Elixir
iex(n1@x.x.x.x)1> schema = :my_schema_name
:my_schema_name

iex(n1@x.x.x.x)2> bucket_name = "route_requests"
"route_requests"

iex(n1@x.x.x.x)3> Blackout.delete_bucket(schema, bucket_name)
{:atomic, :ok}
```
