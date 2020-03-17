defmodule Crit.Reservations.ReservationImpl.Write do
  alias Crit.Reservations.HiddenSchemas.Use
  alias Crit.Setup.Schemas.{ServiceGap,Animal}
  alias Crit.Reservations.Schemas.Reservation
  alias Crit.Sql
  alias Ecto.Multi
  alias Crit.Setup.AnimalApi

  def create(struct, institution) do
    struct_to_changeset(struct) |> Sql.insert(institution)
  end

  def create_noting_conflicts(struct, institution) do
    import Ecto.Query
    animals_query = AnimalApi.ids_to_query(struct.chosen_animal_ids)

    service_gap_animals_fn = fn _repo, _so_far ->
      {:ok, ServiceGap.unavailable_by(animals_query, struct.date, institution)}
    end

    use_animals_fn = fn _repo, _so_far ->
      {:ok, Use.unavailable_by(animals_query, struct.span, institution)}
    end

    changeset = struct_to_changeset(struct)

    
    {:ok, result} = 
      Multi.new
      |> Multi.run(:service_gap, service_gap_animals_fn)
      |> Multi.run(:use, use_animals_fn)
      |> Multi.insert(:insert, changeset, Sql.multi_opts(institution))
      |> Sql.transaction(institution)
    
    {:ok, result.insert, %{service_gap: result.service_gap, use: result.use}}
  end


  defp struct_to_changeset(struct) do
    uses = 
      Use.cross_product(struct.chosen_animal_ids, struct.chosen_procedure_ids)
    
    attrs =
      Map.from_struct(struct)
      |> Map.put(:uses, uses)

    Reservation.changeset(%Reservation{}, attrs)
  end
    
end
