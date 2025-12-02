# Satlink

Proyecto distribuido con nodos Elixir ejecutándose en contenedores Docker.

## 🚀 Requisitos

- Docker
- Docker Compose

## ⚙️ Puesta en marcha del entorno

### 1. Construir las imágenes

```bash
docker compose build
```

### 2. Levantar los servicios

```bash
docker compose up -d
```

### 3. Instalar dependencias (primera vez)

```bash
docker compose exec node1 mix do deps.get, deps.compile
```

### 4. Entrar a cada nodo

```bash
docker compose exec node1 iex --name node1@node1.local --cookie satlink -S mix
docker compose exec node2 iex --name node2@node2.local --cookie satlink -S mix
```

# Ejemplos de uso de `Satlink.API`
# 🚀 1. Usuarios

Los usuarios son actores distribuidos que reciben notificaciones y mantienen su estado vivo en el cluster.

## ➤ Crear un usuario

```elixir
Satlink.API.create_user(%{
  id: "u1",
  name: "Alice"
})
```

## ➤ Obtener un usuario

```elixir
Satlink.API.get_user("u1")
```

## ➤ Notificar manualmente a un usuario

```elixir
Satlink.API.notify_user("u1", "Mensaje de prueba")
```

## ➤ Ver notificaciones del usuario

```elixir
Satlink.API.list_user_notifications("u1")
```

Ejemplo de salida:

```
Notificación: %{at: ~U[2025-12-01 12:00:00Z], message: "Tu reserva fue confirmada"}
Notificación: %{at: ~U[2025-12-01 12:05:20Z], message: "La ventana v3 coincide con tu alerta"}
```

---

# 🛰️ 2. Ventanas

Una ventana representa una oportunidad de uso del satélite.

## ➤ Crear una ventana completa

```elixir
now = DateTime.utc_now()

Satlink.API.create_window(%{
  id: "v1",
  satellite: "SAT-AR-1",
  mission_type: :optical,
  resources: %{optical: ["cam1", "cam2"]},
  starts_at: now,
  ends_at: DateTime.add(now, 3600),
  offer_deadline: DateTime.add(now, 900)
})
```

## ➤ Listar ventanas activas

```elixir
Satlink.API.list_windows()
```

## ➤ Ver detalles de una ventana

```elixir
Satlink.API.show("v1")
```

---

# 🎫 3. Reservas y selección de recursos

## ➤ Reservar una ventana

```elixir
Satlink.API.reserve("v1", "u1")
```

Si el usuario no existe:

```
{:error, :unknown_user}
```

## ➤ Seleccionar recursos en una ventana reservada

```elixir
Satlink.API.select("v1", "u1", {:optical, "cam1"})
```

## ➤ Cancelar una reserva

```elixir
Satlink.API.cancel("v1", "u1")
```

## ➤ Cerrar una ventana manualmente

```elixir
Satlink.API.close("v1")
```

---

# 🔔 4. Alertas

Una alerta monitorea ventanas futuras.  
Cuando una ventana coincide con una alerta → **el usuario recibe una notificación automática**.

## ➤ Crear una alerta

```elixir
now = DateTime.utc_now()

Satlink.API.create_alert(%{
  user_id: "u1",
  mission_type: :optical,
  from: now,
  to: DateTime.add(now, 7200)
})
```

## ➤ Listar alertas

```elixir
Satlink.API.list_alerts()
```

---

# 🔄 5. Flujo completo de ejemplo

```elixir
# Crear usuario
Satlink.API.create_user(%{
  id: "u1",
  name: "Alice"
})

# Crear ventana
now = DateTime.utc_now()

Satlink.API.create_window(%{
  id: "v1",
  satellite: "SAT-AR-1",
  mission_type: :optical,
  resources: %{optical: ["cam1"]},
  starts_at: now,
  ends_at: DateTime.add(now, 3600),
  offer_deadline: DateTime.add(now, 600)
})

# Crear alerta para ese usuario
Satlink.API.create_alert(%{
  user_id: "u1",
  mission_type: :optical,
  from: now,
  to: DateTime.add(now, 7200)
})

# Reservar
Satlink.API.reserve("v1", "u1")

# Seleccionar recurso
Satlink.API.select("v1", "u1", {:optical, "cam1"})

# Ver ventana
Satlink.API.show("v1")

# Ver notificaciones del usuario
Satlink.API.list_user_notifications("u1")

# Cerrar ventana
Satlink.API.close("v1")
```

# 🌐 Ejemplo en clúster


## Crear ventana en node1 y consultar en node2

```elixir
Satlink.API.demo_window("cluster-test")
Satlink.API.show("cluster-test")
```

Demuestra sincronización con Horde.
