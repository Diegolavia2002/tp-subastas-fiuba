defmodule SistemaSubastasTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, manager} = SistemaSubastas.start_link()
    on_exit(fn -> if Process.alive?(manager), do: SistemaSubastas.stop(manager) end)
    %{manager: manager}
  end

  test "crear, consultar, ofertar y validar entradas", %{manager: m} do
    assert {:ok, %{id: 1}} = SistemaSubastas.crear(m, "Teclado", 100, 5_000)
    assert {:ok, %{id: 2}} = SistemaSubastas.crear(m, "Monitor", 500, 5_000)
    assert {:ok, active} = SistemaSubastas.activas(m)
    assert Enum.map(active, & &1.id) == [1, 2]
    assert {:error, :producto_invalido} = SistemaSubastas.crear(m, "  ", 10, 100)
    assert {:error, :precio_inicial_invalido} = SistemaSubastas.crear(m, "X", 0, 100)
    assert {:error, :duracion_invalida} = SistemaSubastas.crear(m, "X", 10, 0)
    assert {:error, :subasta_inexistente} = SistemaSubastas.consultar(m, 99)
    assert {:ok, :oferta_aceptada, _} = SistemaSubastas.ofertar(m, 1, "ana", 101)
    assert {:error, {:oferta_insuficiente, 101}} = SistemaSubastas.ofertar(m, 1, "bruno", 101)
    assert {:error, :usuario_invalido} = SistemaSubastas.ofertar(m, 1, " ", 200)

    assert {:ok, %{ofertas_aceptadas: 1, mayor_oferta: 101, usuario: "ana"}} =
             SistemaSubastas.consultar(m, 1)
  end

  test "cierra sola, incluso sin ofertas, y resultado no cambia", %{manager: m} do
    {:ok, %{id: id}} = SistemaSubastas.crear(m, "Reloj", 100, 80)
    {:ok, %{id: no_bids}} = SistemaSubastas.crear(m, "Libro", 20, 80)
    assert {:ok, :oferta_aceptada, _} = SistemaSubastas.ofertar(m, id, "ana", 150)
    Process.sleep(150)

    assert {:ok, %{estado: :cerrada, mayor_oferta: 150, usuario: "ana"}} =
             SistemaSubastas.consultar(m, id)

    assert {:ok, %{estado: :cerrada, mayor_oferta: nil, usuario: nil, ofertas_aceptadas: 0}} =
             SistemaSubastas.consultar(m, no_bids)

    assert {:error, :subasta_cerrada} = SistemaSubastas.ofertar(m, id, "beto", 200)
    assert {:ok, %{mayor_oferta: 150}} = SistemaSubastas.consultar(m, id)
  end

  test "ofertas iguales concurrentes se serializan", %{manager: m} do
    {:ok, %{id: id}} = SistemaSubastas.crear(m, "Consola", 100, 3_000)
    parent = self()

    1..20
    |> Enum.each(fn n ->
      spawn(fn -> send(parent, {:respuesta, SistemaSubastas.ofertar(m, id, "u#{n}", 200)}) end)
    end)

    responses =
      for _ <- 1..20 do
        receive do
          {:respuesta, r} -> r
        after
          2_000 -> flunk("timeout")
        end
      end

    assert Enum.count(responses, &match?({:ok, :oferta_aceptada, _}, &1)) == 1
    assert Enum.count(responses, &match?({:error, {:oferta_insuficiente, 200}}, &1)) == 19
    assert {:ok, %{mayor_oferta: 200, ofertas_aceptadas: 1}} = SistemaSubastas.consultar(m, id)
  end

  test "ofertas distintas y subastas independientes", %{manager: m} do
    {:ok, %{id: first}} = SistemaSubastas.crear(m, "A", 10, 3_000)
    {:ok, %{id: second}} = SistemaSubastas.crear(m, "B", 100, 3_000)
    parent = self()

    senders =
      for amount <- 11..30 do
        spawn(fn ->
          send(parent, {:answer, amount, SistemaSubastas.ofertar(m, first, "u#{amount}", amount)})
        end)
      end

    assert length(senders) == 20

    answers =
      for _ <- 1..20 do
        receive do
          {:answer, amount, result} -> {amount, result}
        after
          2_000 -> flunk("timeout")
        end
      end

    accepted =
      Enum.filter(answers, fn {_amount, result} -> match?({:ok, :oferta_aceptada, _}, result) end)

    assert {:ok, %{mayor_oferta: 30, ofertas_aceptadas: count}} =
             SistemaSubastas.consultar(m, first)

    assert count == length(accepted)

    assert {:ok, %{mayor_oferta: nil, ofertas_aceptadas: 0, estado: :activa}} =
             SistemaSubastas.consultar(m, second)
  end
end
