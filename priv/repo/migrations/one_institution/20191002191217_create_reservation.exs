defmodule Crit.Repo.Migrations.CreateReservation do
  use Ecto.Migration

  def change do
    create table(:timeslots) do
      add :name, :string, null: false
      add :start, :time, null: false
      add :duration, :integer, null: false
    end
    
    create table(:reservations) do
      add :species_id, references("species", on_delete: :restrict), null: false
      add :span, :tsrange, null: false
      add :date, :date, null: false
      add :timeslot_id, references("timeslots"), null: false
      add :responsible_person, :string
      add :billing_code, :string
      timestamps()
    end

    create table("uses") do
      add :animal_id, references("animals"), null: false
      add :procedure_id, references("procedures"), null: false
      add :reservation_id, references("reservations"), null: false
    end
  end
end
