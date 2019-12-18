defmodule Crit.FieldConverters.ToSpan2 do
  use Ecto.Schema
  use Crit.Global.Constants
  use Crit.Errors
  import Ecto.Changeset
  alias Pile.TimeHelper
  alias Ecto.Datespan

  # Assumes this partial schema. Fields are constant because they come from
  # the domain.
  
  # field :in_service_datestring, :string
  # field :out_of_service_datestring, :string
  # field :timezone, :string
  
  # field :span, Datespan

  # Note: it's an assumed precondition that the first three fields
  # exist in either the changeset's `data` or its `changes`. That is,
  # they have already been `cast` and `validate_required`. 

  def synthesize(changeset) do
    assume_infinite_up(changeset)
    |> apply_out_of_service_date
    |> check_date_compatibility
  end

  defp assume_infinite_up(changeset) do
    case parse_date(changeset, :in_service_datestring) do
      {:ok, @never} ->
        msg = ~S{"must be a date or "today"}
        add_error(changeset, :in_service_datestring, msg)
      {:ok, in_service} ->
        put_span(changeset, Datespan.infinite_up(in_service, :inclusive))
      {:error, _tag} ->
        add_error(changeset, :in_service_datestring, "is invalid")
    end
  end

  defp apply_out_of_service_date(changeset) do
    case parse_date(changeset, :out_of_service_datestring) do
      {:ok, @never} ->
        changeset # this is what the first step assumed
      {:ok, out_of_service} ->
        tentative_span = fetch_field!(changeset, :span)
        put_span(
          changeset,
          Datespan.convert_to_customary(tentative_span, out_of_service))
      {:error, _tag} ->
        add_error(changeset, :out_of_service_datestring, "is invalid")
    end
  end

  defp check_date_compatibility(%{valid?: false} = changeset), do: changeset
  defp check_date_compatibility(changeset) do
    span = fetch_field!(changeset, :span)
    if Datespan.is_customary?(span) do
      case Date.compare(span.first, span.last) do
        :lt -> changeset
        _ -> add_error(changeset, :out_of_service_datestring, @date_misorder_message)
      end
    else
      changeset
    end
  end

  defp put_span(changeset, span), do: put_change(changeset, :span, span)

  defp parse_date(changeset, field) do
    datestring = fetch_field!(changeset, field)
    timezone = fetch_field!(changeset, :timezone)
    
    case datestring do
      @never ->
        {:ok, @never}
      @today ->
        {:ok, TimeHelper.today_date(timezone)}
      _ -> 
        Date.from_iso8601(datestring)
    end
  end
end  



