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

---

# 🧪 Ejemplos de uso de Satlink.API

## Crear una ventana demo

```elixir
{:ok, id} = Satlink.API.demo_window("demo-1")
```

## Listar ventanas

```elixir
Satlink.API.list()
```

## Ver detalles

```elixir
Satlink.API.show("demo-1")
```

## Reservar

```elixir
Satlink.API.reserve("demo-1", "user-123")
```

## Seleccionar recursos

```elixir
Satlink.API.select("demo-1", "user-123", %{optical: ["cam1"]})
```

## Cancelar reserva

```elixir
Satlink.API.cancel("demo-1", "user-123")
```

## Cerrar ventana

```elixir
Satlink.API.close("demo-1")
```

---

# 🔄 Flujo completo de ejemplo

```elixir
{:ok, "v1"} = Satlink.API.demo_window("v1")
Satlink.API.show("v1")
Satlink.API.reserve("v1", "alice")
Satlink.API.select("v1", "alice", %{optical: ["cam1"]})
Satlink.API.show("v1")
Satlink.API.close("v1")
Satlink.API.get("nope")
```

---

# 🌐 Ejemplo en clúster


## Crear ventana en node1 y consultar en node2

```elixir
Satlink.API.demo_window("cluster-test")
Satlink.API.show("cluster-test")
```

Demuestra sincronización con Horde.
