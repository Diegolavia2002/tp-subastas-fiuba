defmodule SistemaSubastas.CLI do
  @moduledoc "Interactive command line interface."

  def run do
    {:ok, manager} = SistemaSubastas.start_link()
    IO.puts("Sistema de subastas. Escriba ayuda para ver los comandos.")
    loop(manager)
    SistemaSubastas.stop(manager)
  end

  defp loop(manager) do
    case IO.gets("> ") do
      :eof ->
        :ok

      line ->
        case execute(manager, String.trim(line)) do
          :salir -> :ok
          :continue -> loop(manager)
        end
    end
  end

  def execute(manager, line) do
    case parse(line) do
      :ayuda ->
        IO.puts(
          "crear \"PRODUCTO\" PRECIO DURACION_MS | activas | consultar ID | ofertar ID USUARIO IMPORTE | ayuda | salir"
        )

      :salir ->
        :salir

      {:crear, producto, precio, duracion} ->
        print_create(SistemaSubastas.crear(manager, producto, precio, duracion))

      :activas ->
        print_active(SistemaSubastas.activas(manager))

      {:consultar, id} ->
        print_query(SistemaSubastas.consultar(manager, id))

      {:ofertar, id, usuario, importe} ->
        print_offer(SistemaSubastas.ofertar(manager, id, usuario, importe), id, usuario, importe)

      :error ->
        IO.puts("ERROR comando_invalido. Escriba ayuda.")
    end

    if parse(line) == :salir, do: :salir, else: :continue
  end

  defp parse(line) do
    cond do
      line in ["ayuda", "help"] ->
        :ayuda

      line in ["salir", "exit"] ->
        :salir

      line == "activas" ->
        :activas

      match = Regex.run(~r/^crear\s+"([^"]*)"\s+(\S+)\s+(\S+)$/, line) ->
        [_, producto, precio, duracion] = match

        with {p, ""} <- Integer.parse(precio),
             {d, ""} <- Integer.parse(duracion),
             do: {:crear, producto, p, d},
             else: (_ -> :error)

      match = Regex.run(~r/^consultar\s+(\S+)$/, line) ->
        [_, id] = match
        with {n, ""} <- Integer.parse(id), do: {:consultar, n}, else: (_ -> :error)

      match = Regex.run(~r/^ofertar\s+(\S+)\s+(\S+)\s+(\S+)$/, line) ->
        [_, id, usuario, importe] = match

        with {i, ""} <- Integer.parse(id),
             {n, ""} <- Integer.parse(importe),
             do: {:ofertar, i, usuario, n},
             else: (_ -> :error)

      true ->
        :error
    end
  end

  defp print_create({:ok, a}),
    do:
      IO.puts(
        "OK subasta=#{a.id} producto=\"#{a.producto}\" precio_inicial=#{a.precio_inicial} duracion_ms=#{a.duracion_ms}"
      )

  defp print_create({:error, reason}), do: print_error(reason)
  defp print_active({:ok, []}), do: IO.puts("No hay subastas activas.")

  defp print_active({:ok, list}) do
    Enum.each(list, fn a ->
      offer = if a.mayor_oferta, do: "#{a.mayor_oferta} por #{a.usuario}", else: "sin ofertas"
      IO.puts("#{a.id} | #{a.producto} | #{offer}")
    end)
  end

  defp print_query({:ok, a}) do
    IO.puts(
      "subasta=#{a.id} producto=\"#{a.producto}\" estado=#{a.estado} precio_inicial=#{a.precio_inicial}"
    )

    if a.estado == :activa do
      offer =
        if a.mayor_oferta,
          do: "mayor_oferta=#{a.mayor_oferta} usuario=#{a.usuario}",
          else: "sin_ofertas"

      IO.puts("ofertas_aceptadas=#{a.ofertas_aceptadas} #{offer}")
    else
      winner = if a.usuario, do: a.usuario, else: "ninguno"
      price = if a.mayor_oferta, do: a.mayor_oferta, else: "ninguno"
      IO.puts("ofertas_aceptadas=#{a.ofertas_aceptadas} ganador=#{winner} precio_final=#{price}")
    end
  end

  defp print_query({:error, reason}), do: print_error(reason)

  defp print_offer({:ok, :oferta_aceptada, _state}, id, user, amount),
    do: IO.puts("OK oferta_aceptada subasta=#{id} usuario=#{user} importe=#{amount}")

  defp print_offer({:error, reason}, _id, _user, _amount), do: print_error(reason)
  defp print_error(:producto_invalido), do: IO.puts("ERROR producto_invalido")
  defp print_error(:precio_inicial_invalido), do: IO.puts("ERROR precio_inicial_invalido")
  defp print_error(:duracion_invalida), do: IO.puts("ERROR duracion_invalida")
  defp print_error(:usuario_invalido), do: IO.puts("ERROR usuario_invalido")
  defp print_error(:importe_invalido), do: IO.puts("ERROR importe_invalido")
  defp print_error(:subasta_inexistente), do: IO.puts("ERROR subasta_inexistente")
  defp print_error(:subasta_cerrada), do: IO.puts("ERROR subasta_cerrada")

  defp print_error({:oferta_insuficiente, ref}),
    do: IO.puts("ERROR oferta_insuficiente referencia=#{ref}")

  defp print_error(:timeout), do: IO.puts("ERROR tiempo_de_espera_agotado")
  defp print_error(other), do: IO.puts("ERROR #{inspect(other)}")
end
