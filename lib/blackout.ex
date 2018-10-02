defmodule Blackout do
  @moduledoc """
    A very thin wrapper around Erlang's mnesia used to
    provide distributed rate limiting,
    with little to no configuration
    and a simple API for developer happiness.
  """

  @doc """
  Setup an mnesia schema and table while joining a cluster.

  This function must be called for each node
  registered in the cluster on application startup.

  The default mnesia table options assume concurrent reads/writes
  with **ram only** usage. All options may be overridden except for **:attributes**. Available options can be found at:
  [Mnesia Docs](http://erlang.org/doc/man/mnesia.html#create_table-2)

  ## Default Options
      [
        attributes: [:bucket_name, :rate_limit],
        ram_copies: nodes,
        disc_copies: [],
        disc_only_copies: [],
        storage_properties: [ets: [read_concurrency: true, write_concurrency: true]]
      ]

  ## Examples

      iex> nodes = [Node.self(), some_other_node]

      iex> Blackout.join_cluster(:my_schema, nodes)
      {:ok, :atomic}

      iex> Blackout.join_cluster(:my_schema, nodes)
      {:ok, :already_exists}
  """

  def join_cluster(schema_name, nodes \\ [], mnesia_options \\ []) do
    :mnesia.start()

    nodes =
      (nodes ++ [Node.self()])
      |> MapSet.new()
      |> MapSet.to_list()

    mnesia_options = Keyword.delete(mnesia_options, :attributes)

    options =
      default_options(nodes)
      |> Keyword.merge(mnesia_options)

    :mnesia.create_table(
      schema_name,
      options
    )
    |> case do
      {:atomic, :ok} ->
        {:ok, :atomic}

      {:aborted, {:already_exists, _}} ->
        {:ok, :already_exists}

      e ->
        {:error, e}
    end
  end

  @doc """
  Runs an mnesia transaction to check
  rate limits for a given bucket name.

  ## Examples

      iex> Blackout.check_bucket(:my_schema, "my_bucket_name", 1, 60_000)
      {:atomic, {:ok, 60_000}}

      iex> Blackout.check_bucket(:my_schema, "my_bucket_name", 1, 60_000)
      {:atomic, {:rate_limited, 59155}}
  """
  def check_bucket(schema_name, bucket_name, count_limit, time_limit) do
    :mnesia.transaction(fn ->
      matches = :mnesia.read(schema_name, bucket_name)

      case matches do
        # insert inital timestamp and count
        [] ->
          now = timestamp()
          val = {now, 1}
          insert_bucket(schema_name, bucket_name, val)
          {:ok, time_limit}

        # update existing bucket timestamp and count
        [{^schema_name, ^bucket_name, {_expiration, _count} = val}] ->
          {allow_or_deny, {expiration, time_left, count}} =
            check_limited(bucket_name, val, count_limit, time_limit)

          insert_bucket(schema_name, bucket_name, {expiration, count})
          {allow_or_deny, time_left}

        # Bucket value would have to be malformed
        # so delete bucket and back off
        _ ->
          mnesia_delete_bucket(schema_name, bucket_name)
          {:rate_limited, time_limit}
      end
    end)
  end

  @doc """
  Run an mnesia transaction
  to delete a bucket by name.

  ## Examples

      iex> Blackout.delete_bucket(:my_schema, "my_bucket_name")
      {:atomic, :ok}
  """
  def delete_bucket(schema_name, bucket_name) do
    :mnesia.transaction(fn ->
      mnesia_delete_bucket(schema_name, bucket_name)
    end)
  end

  # PRIVATE

  # Milliseconds from unix epoch
  defp timestamp(), do: :erlang.system_time(:milli_seconds)

  # Update bucket expiration and counter
  defp check_limited(_bucket_name, {expiration, current_count}, count_limit, time_limit) do
    time_now = timestamp()
    milliseconds_since_expiration = time_now - expiration
    expired? = milliseconds_since_expiration >= time_limit
    time_left = time_limit - milliseconds_since_expiration

    if expired? do
      # reset
      expiration = time_now
      time_left = 0
      count = 1
      {:ok, {expiration, time_left, count}}
    else
      rate_limited? = current_count >= count_limit

      if rate_limited?,
        do: {:rate_limited, {expiration, time_left, current_count}},
        else: {:ok, {expiration, time_left, current_count + 1}}
    end
  end

  # Used within an mnesia transaction to delete a bucket
  defp mnesia_delete_bucket(schema_name, bucket_name) do
    :mnesia.delete({schema_name, bucket_name})
  end

  # Used within an mnesia transaction to insert a new bucket value
  defp insert_bucket(schema_name, bucket_name, {_new_expiration, _new_count} = val) do
    :mnesia.write({schema_name, bucket_name, val})
  end

  # Default options for mnesia create table
  # These options assume in-memory usage only
  defp default_options(nodes) do
    [
      attributes: [:bucket_name, :rate_limit],
      ram_copies: nodes,
      disc_copies: [],
      disc_only_copies: [],
      storage_properties: [ets: [read_concurrency: true, write_concurrency: true]]
    ]
  end
end
