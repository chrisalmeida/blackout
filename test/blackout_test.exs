defmodule BlackoutTest do
  use ExUnit.Case

  @schema_name :my_schema
  @bucket_name "my_test_bucket"

  setup _context do
    :stopped = :mnesia.stop()
    :ok
  end

  test "Blackout starts up without conflict" do
    nodes = [Node.self()]
    assert Blackout.join_cluster(@schema_name, nodes) == {:ok, :atomic}
  end

  test "Creating mnesia table twice results in :already_started" do
    nodes = [Node.self()]
    Blackout.join_cluster(@schema_name, nodes)
    assert Blackout.join_cluster(@schema_name, nodes) == {:ok, :already_exists}
  end

  test "Blackout dedups node names successfully" do
    nodes = [Node.self(), Node.self()]
    assert Blackout.join_cluster(@schema_name, nodes) == {:ok, :atomic}
  end

  test "Initial check_bucket returns initial expiration" do
    nodes = [Node.self()]
    expiration = 60_000
    {:ok, :atomic} = Blackout.join_cluster(@schema_name, nodes)
    result = Blackout.check_bucket(@schema_name, @bucket_name, 1, expiration)
    assert result == {:atomic, {:ok, expiration}}
  end

  test "Blackout returns :rate_limited successfully" do
    nodes = [Node.self()]
    expiration = 60_000
    allowed_checks = 1
    {:ok, :atomic} = Blackout.join_cluster(@schema_name, nodes)

    {:atomic, {:ok, ^expiration}} =
      Blackout.check_bucket(@schema_name, @bucket_name, allowed_checks, expiration)

    {:atomic, {result, _expire_at}} =
      Blackout.check_bucket(@schema_name, @bucket_name, allowed_checks, expiration)

    assert result == :rate_limited
  end

  test "Blackout returns :rate_limited successfully with custom increment" do
    nodes = [Node.self()]
    expiration = 60_000
    allowed_checks = 5
    {:ok, :atomic} = Blackout.join_cluster(@schema_name, nodes)

    {:atomic, {:ok, ^expiration}} =
      Blackout.check_bucket(
        @schema_name,
        @bucket_name,
        allowed_checks,
        expiration,
        allowed_checks
      )

    {:atomic, {result, _expire_at}} =
      Blackout.check_bucket(@schema_name, @bucket_name, allowed_checks, expiration)

    assert result == :rate_limited
  end

  test "Blackout deletes bucket successfully" do
    nodes = [Node.self()]
    expiration = 60_000
    {:ok, :atomic} = Blackout.join_cluster(@schema_name, nodes)
    _result = Blackout.check_bucket(@schema_name, @bucket_name, 1, expiration)
    # this would allow for time to be decremented
    :timer.sleep(100)
    {:atomic, :ok} = Blackout.delete_bucket(@schema_name, @bucket_name)
    result = Blackout.check_bucket(@schema_name, @bucket_name, 1, expiration)
    assert result == {:atomic, {:ok, expiration}}
  end

  test "Multiple check_bucket returns decremented expiration" do
    nodes = [Node.self()]
    expiration = 60_000
    allowed_checks = 2
    {:ok, :atomic} = Blackout.join_cluster(@schema_name, nodes)

    {:atomic, {:ok, ^expiration}} =
      Blackout.check_bucket(@schema_name, @bucket_name, allowed_checks, expiration)

    :timer.sleep(100)

    {:atomic, {:ok, expire_at}} =
      Blackout.check_bucket(@schema_name, @bucket_name, allowed_checks, expiration)

    assert expire_at < expiration
  end
end
