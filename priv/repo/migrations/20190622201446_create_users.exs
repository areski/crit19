defmodule Crit.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false
      add :email, :citext, null: false
      add :password_hash, :string

      timestamps()
    end

    create index("users", :email)


  end
end
