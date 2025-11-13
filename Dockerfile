# Dockerfile
FROM hexpm/elixir:1.16.2-erlang-26.2.5-debian-bullseye-20240423

# Paquetes básicos (git para deps, build-essential para compilar nativos)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Crear usuario no root
ARG USER=app
ARG UID=1000
RUN useradd -m -u ${UID} ${USER}

WORKDIR /app
ENV MIX_ENV=dev

# Instalar Hex y Rebar (si no vienen)
RUN mix do local.hex --force, local.rebar --force

# Montaremos el código como volumen, pero dejamos cache de deps/build
RUN mkdir -p /home/${USER}/.cache/mix && chown -R ${USER}:${USER} /home/${USER}
ENV MIX_HOME=/home/${USER}/.cache/mix
ENV HEX_HOME=/home/${USER}/.cache/hex

USER ${USER}
