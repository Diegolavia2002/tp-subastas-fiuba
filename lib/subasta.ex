defmodule SistemaSubastas.Subasta do
  @moduledoc false

  def run(id, producto, precio_inicial, vence) do
    restante = max(0, vence - System.monotonic_time(:millisecond))
    Process.send_after(self(), :vencer, restante)

    loop(%{
      id: id,
      producto: producto,
      precio_inicial: precio_inicial,
      vence: vence,
      estado: :activa,
      ofertas_aceptadas: 0,
      mayor_oferta: nil,
      usuario: nil
    })
  end

  def request(pid, accion) do
    ref = make_ref()
    send(pid, {self(), ref, accion})

    receive do
      {^ref, respuesta} -> respuesta
    after
      5_000 -> {:error, :timeout}
    end
  end

  defp loop(state) do
    receive do
      {from, ref, accion} ->
        {response, next_state} = process(accion, state)
        send(from, {ref, response})
        loop(next_state)

      :vencer ->
        loop(close(state))

      :stop ->
        :ok

      _ ->
        loop(state)
    end
  end

  defp process(accion, state) do
    # El instante se toma al comenzar a atender el mensaje; si ya venció,
    # el cierre se aplica antes de resolver cualquier pedido.
    ahora = System.monotonic_time(:millisecond)
    state = if state.estado == :activa and ahora >= state.vence, do: close(state), else: state

    case accion do
      :consultar ->
        {{:ok, state}, state}

      {:ofertar, _usuario, _importe} when state.estado == :cerrada ->
        {{:error, :subasta_cerrada}, state}

      {:ofertar, usuario, importe} ->
        referencia = if state.mayor_oferta, do: state.mayor_oferta, else: state.precio_inicial

        if ahora < state.vence and importe > referencia do
          next = %{
            state
            | mayor_oferta: importe,
              usuario: usuario,
              ofertas_aceptadas: state.ofertas_aceptadas + 1
          }

          {{:ok, :oferta_aceptada, next}, next}
        else
          {{:error, {:oferta_insuficiente, referencia}}, state}
        end
    end
  end

  defp close(%{estado: :activa} = state), do: %{state | estado: :cerrada}
  defp close(state), do: state
end
