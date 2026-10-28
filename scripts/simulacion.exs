{:ok, manager} = SistemaSubastas.start_link()

auctions =
  for {name, base} <- [{"Teclado", 1_000}, {"Monitor", 5_000}, {"Auriculares", 700}] do
    {:ok, created} = SistemaSubastas.crear(manager, name, base, 8_000)
    Map.put(created, :base, base)
  end

parent = self()
start_ref = make_ref()

workers =
  for user_num <- 1..100 do
    spawn(fn ->
      receive do
        {^start_ref, :go} ->
          results =
            Enum.flat_map(auctions, fn auction ->
              query = SistemaSubastas.consultar(manager, auction.id)
              equal = SistemaSubastas.ofertar(manager, auction.id, "usuario#{user_num}", auction.base + 100)
              insufficient = SistemaSubastas.ofertar(manager, auction.id, "usuario#{user_num}", auction.base)
              higher = SistemaSubastas.ofertar(manager, auction.id, "usuario#{user_num}", auction.base + 500 + user_num)
              [{:consulta, auction.id, query}, {:igual, auction.id, equal}, {:insuficiente, auction.id, insufficient}, {:mayor, auction.id, higher}]
            end)
          send(parent, {:usuario, user_num, results})
      end
    end)
  end

Enum.each(workers, &send(&1, {start_ref, :go}))

results =
  for _ <- 1..100 do
    receive do
      {:usuario, user, responses} -> {user, responses}
    after
      15_000 -> raise "Tiempo agotado esperando usuarios"
    end
  end

IO.puts("Participantes: #{length(results)}")
IO.puts("Solicitudes iniciales: #{Enum.reduce(results, 0, fn {_user, responses}, count -> count + length(responses) end)}")
all_responses = Enum.flat_map(results, &elem(&1, 1))
accepted = Enum.count(all_responses, fn {_kind, _id, response} -> match?({:ok, :oferta_aceptada, _}, response) end)
rejected =
  Enum.frequencies_by(all_responses, fn {_kind, _id, response} ->
    case response do
      {:error, {:oferta_insuficiente, _}} -> :oferta_insuficiente
      {:error, reason} -> reason
      _ -> :no_rechazada
    end
  end)
  |> Map.delete(:no_rechazada)

failures = Enum.count(all_responses, fn {_kind, _id, response} -> match?({:error, :timeout}, response) end)
IO.puts("Ofertas aceptadas: #{accepted}")
IO.puts("Rechazos por motivo: #{inspect(rejected)}")
IO.puts("Fallos/timeouts: #{failures}")
IO.puts("Esperando vencimientos automáticos...")
Process.sleep(8_300)

verification =
  Enum.all?(auctions, fn auction ->
    {:ok, final} = SistemaSubastas.consultar(manager, auction.id)

    accepted_for_auction =
      Enum.count(all_responses, fn
        {_kind, id, {:ok, :oferta_aceptada, _state}} when id == auction.id -> true
        _ -> false
      end)

    accepted_snapshots =
      for {_kind, id, {:ok, :oferta_aceptada, state}} <- all_responses, id == auction.id,
          do: {state.mayor_oferta, state.usuario}

    expected = if accepted_snapshots == [], do: {nil, nil}, else: Enum.max_by(accepted_snapshots, &elem(&1, 0))
    consistent = final.estado == :cerrada and final.ofertas_aceptadas == accepted_for_auction and {final.mayor_oferta, final.usuario} == expected

    IO.puts("Subasta #{auction.id} #{auction.producto}: estado=#{final.estado} ofertas_aceptadas=#{final.ofertas_aceptadas} ganador=#{final.usuario || "ninguno"} precio_final=#{final.mayor_oferta || "ninguno"}")
    consistent
  end)

late = Enum.map(auctions, &SistemaSubastas.ofertar(manager, &1.id, "tardio", &1.base + 99_999))
late_ok = Enum.all?(late, &(&1 == {:error, :subasta_cerrada}))
IO.puts("Intentos posteriores al vencimiento: #{length(late)} rechazados")
IO.puts("Verificación: #{if verification and late_ok and failures == 0, do: "EXITOSA", else: "FALLIDA"}")
SistemaSubastas.stop(manager)
if not (verification and late_ok and failures == 0), do: System.halt(1)
