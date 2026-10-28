defmodule SistemaSubastas do
  @moduledoc "API and process coordinator for independent auctions."

  def start_link do
    manager = spawn_link(fn -> manager_loop(1, %{}) end)
    {:ok, manager}
  end

  def stop(manager), do: call(manager, :stop)

  def crear(manager, producto, precio, duracion) do
    cond do
      not is_binary(producto) or String.trim(producto) == "" -> {:error, :producto_invalido}
      not positive_integer?(precio) -> {:error, :precio_inicial_invalido}
      not positive_integer?(duracion) -> {:error, :duracion_invalida}
      true -> call(manager, {:crear, String.trim(producto), precio, duracion})
    end
  end

  def activas(manager), do: call(manager, :activas)
  def consultar(manager, id), do: call(manager, {:consultar, id})

  def ofertar(manager, id, usuario, importe) do
    cond do
      not is_binary(usuario) or String.trim(usuario) == "" -> {:error, :usuario_invalido}
      not positive_integer?(importe) -> {:error, :importe_invalido}
      true -> call(manager, {:ofertar, id, String.trim(usuario), importe})
    end
  end

  defp positive_integer?(n), do: is_integer(n) and n > 0

  defp call(pid, request) when is_pid(pid) do
    ref = make_ref()
    send(pid, {self(), ref, request})

    receive do
      {^ref, response} -> response
    after
      5_000 -> {:error, :timeout}
    end
  end

  defp manager_loop(next_id, auctions) do
    receive do
      {from, ref, {:crear, producto, precio, duracion}} ->
        id = next_id
        vence = System.monotonic_time(:millisecond) + duracion
        pid = spawn(fn -> SistemaSubastas.Subasta.run(id, producto, precio, vence) end)

        send(
          from,
          {ref,
           {:ok, %{id: id, producto: producto, precio_inicial: precio, duracion_ms: duracion}}}
        )

        manager_loop(next_id + 1, Map.put(auctions, id, pid))

      {from, ref, :activas} ->
        result =
          auctions
          |> Enum.sort_by(&elem(&1, 0))
          |> Enum.map(fn {id, pid} -> {id, SistemaSubastas.Subasta.request(pid, :consultar)} end)

        active = for {_id, {:ok, %{estado: :activa} = state}} <- result, do: state

        send(from, {ref, {:ok, active}})
        manager_loop(next_id, auctions)

      {from, ref, {:consultar, id}} ->
        send(from, {ref, lookup(auctions, id, :consultar)})
        manager_loop(next_id, auctions)

      {from, ref, {:ofertar, id, usuario, importe}} ->
        response =
          case Map.fetch(auctions, id) do
            {:ok, pid} -> SistemaSubastas.Subasta.request(pid, {:ofertar, usuario, importe})
            :error -> {:error, :subasta_inexistente}
          end

        send(from, {ref, response})
        manager_loop(next_id, auctions)

      {from, ref, :stop} ->
        Enum.each(auctions, fn {_id, pid} -> send(pid, :stop) end)
        send(from, {ref, :ok})

      _other ->
        manager_loop(next_id, auctions)
    end
  end

  defp lookup(auctions, id, request) do
    case Map.fetch(auctions, id) do
      {:ok, pid} -> SistemaSubastas.Subasta.request(pid, request)
      :error -> {:error, :subasta_inexistente}
    end
  end
end
