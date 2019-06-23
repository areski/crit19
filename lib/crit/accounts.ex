defmodule Crit.Accounts do
  import Ecto.Query, warn: false
  alias Crit.Repo

  alias Crit.Accounts.User

  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.harmlessly_updatable_changeset(attrs)
    |> Repo.update()
  end

  def change_user(%User{} = user) do
    User.harmlessly_updatable_changeset(user, %{})
  end
end
