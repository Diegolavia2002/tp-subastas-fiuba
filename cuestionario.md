# Cuestionario

1. Un proceso en Elixir es una unidad de ejecución liviana administrada por la VM BEAM. Tiene su propio flujo de ejecución y memoria. La memoria aislada significa que no comparte variables mutables con otros procesos; intercambian datos enviándose mensajes.

2. Concurrencia es organizar varias tareas para que progresen durante períodos que se intercalan. Paralelismo es ejecutarlas literalmente al mismo tiempo en distintos núcleos. Puede haber concurrencia con un solo núcleo mediante alternancia entre tareas.

3. Una condición de carrera sucede cuando el resultado depende del orden impredecible de operaciones concurrentes. Si dos participantes leen la misma oferta máxima y luego escriben por separado, ambos podrían creer que su oferta era válida y sobrescribir el estado.

4. Si un proceso es el único dueño de un estado y atiende cada pedido completo antes del siguiente, cada decisión usa el estado actualizado. Aun así, puede haber mensajes tardíos, vencimientos, timeouts, fallos y órdenes distintos entre emisores; hay que diseñar esas situaciones.

5. Elixir conserva el orden de los mensajes enviados por un mismo proceso al mismo destinatario. No promete un orden global entre procesos emisores distintos; los mensajes de varios emisores pueden llegar intercalados.

6. El mailbox es la cola de mensajes que recibió un proceso y todavía no consumió. `receive` busca un mensaje que coincida con sus patrones y guardas. Los que no coinciden permanecen pendientes para futuros `receive`.

7. Si llegan mensajes más rápido de lo que se atienden, crece el consumo de memoria y la espera de respuesta. Buscar coincidencias entre muchos mensajes también puede costar más. Se puede limitar la entrada, responder rápido, aplicar contrapresión, descartar o agrupar trabajo cuando la lógica lo permita y monitorear el tamaño de las colas.

8. Un timeout indica que el solicitante no recibió respuesta dentro del plazo de espera; no demuestra que el destinatario haya cancelado la operación. La respuesta puede llegar tarde y confundirse con una nueva solicitud. Reintentar puede duplicar efectos, por eso conviene identificar solicitudes y diseñar operaciones idempotentes cuando sea necesario.

9. Envío asincrónico significa que `send` coloca un mensaje sin esperar a que el receptor lo procese. Enviar, que el mensaje llegue y que termine el procesamiento son momentos distintos; una respuesta explícita permite confirmar el resultado.

10. Cuando termina un proceso, desaparecen su memoria y su mailbox. Otro proceso puede conocer la terminación mediante monitoreo, que notifica un mensaje `DOWN` con el motivo. Sirve para limpiar referencias, informar fallos y recuperar o cerrar recursos relacionados.
