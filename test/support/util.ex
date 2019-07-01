defmodule Crit.Test.Util do
  use ExUnit.CaseTemplate
  alias Crit.Factory
  alias Crit.Repo
  alias Crit.Accounts


  def saved_user(attrs \\ %{}) do
    {:ok, user} = user_attrs(attrs) |> Accounts.create_user
    # attrs will have virtual field, but result structure will not.
    %{user | password: nil}
  end

  def user_attrs(attrs \\ %{}) do 
    Factory.build(:user, attrs) |> string_keys
  end

  
  def assert_same_values(one_maplike, other_maplike, keys) do
    one_map = string_keys(one_maplike)
    other_map = string_keys(other_maplike)
    for k <- stringify(keys) do
      assert Map.has_key?(one_map, k)
      assert Map.has_key?(other_map, k)
      assert one_map[k] == other_map[k]
    end
  end

  def assert_has_exactly_these_keys(keylist, keys) do
    assert MapSet.new(Keyword.keys(keylist)) == MapSet.new(keys)
  end

  def string_keys(maplike) do
    keys = Map.keys(maplike)
    Enum.reduce(keys, %{},
      fn (k, acc) ->
        Map.put(acc, stringify(k), Map.get(maplike, k))
      end)
  end

  def stringify(x) when is_atom(x), do: Atom.to_string(x)
  def stringify(x) when is_binary(x), do: x
  def stringify(x) when is_list(x), do: Enum.map(x, &stringify/1)
end