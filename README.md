# Sistema de Subastas

Trabajo práctico individual de Taller de Programación I (FIUBA).

## Datos del estudiante

- Nombre: DIEGO
- Padrón: 106978
- Elixir: 1.19.5
- Erlang/OTP: 28

## Requisitos

Se necesita Elixir y Erlang/OTP instalados. El proyecto no usa dependencias externas.

Desde una clonación limpia:

```bash
git clone URL_DEL_REPOSITORIO
cd sistema-subastas
mix deps.get
mix compile
mix test
mix format --check-formatted
```

En PowerShell, `cd sistema-subastas` es igual. `mix deps.get` no descarga nada porque no hay dependencias.

## Ejecutar

CLI interactiva:

```bash
mix run -e "SistemaSubastas.CLI.run()"
```

Comandos disponibles:

- `crear "PRODUCTO" PRECIO DURACION_MS`
- `activas`
- `consultar ID`
- `ofertar ID USUARIO IMPORTE`
- `ayuda`
- `salir`

Ejemplo:

```text
> crear "Teclado" 1000 30000
OK subasta=1 producto="Teclado" precio_inicial=1000 duracion_ms=30000
> ofertar 1 ana 1200
OK oferta_aceptada subasta=1 usuario=ana importe=1200
> consultar 1
subasta=1 producto="Teclado" estado=activa precio_inicial=1000
ofertas_aceptadas=1 mayor_oferta=1200 usuario=ana
```

La CLI informa errores de entrada y continúa aceptando comandos.

## Diseño

El coordinador asigna identificadores y conserva el mapa de subastas. Cada subasta tiene un proceso propio, que mantiene su estado y procesa pedidos secuencialmente usando `send` y `receive`. Una referencia única relaciona cada pedido con su respuesta.

Cada proceso calcula un vencimiento con `System.monotonic_time/1` y programa un mensaje de temporizador. También comprueba el plazo al procesar consultas y ofertas, por lo que el cierre no depende de que el mensaje del timer se atienda puntualmente. La primera oferta debe superar el precio inicial; cada oferta siguiente, la mayor vigente.

Limitaciones: los datos viven en memoria y se pierden al cerrar la aplicación. No hay persistencia ni autenticación. El coordinador atiende solicitudes de CLI de una en una; el estado de cada subasta permanece aislado.

## Tests y simulación

```bash
mix test
mix run scripts/simulacion.exs
```

La simulación crea tres subastas y 100 procesos usuarios, coordina su comienzo, recoge respuestas, espera vencimientos y contrasta el estado final con las ofertas aceptadas. Los ganadores pueden variar por el orden de atención.


