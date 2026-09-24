# Migracion de proyecto existente al formato mio

Reorganiza el proyecto completo en bloques.

## Formato

    // @anchor:ruta/archivo.ext
    // @block:id [desc]
    ...codigo completo...
    // @end:id

## Convencion

- src/main.tsx -> main-001
- src/App.tsx -> app-001
- src/components/Navbar.tsx -> ui-navbar
- package.json -> pkg-001
- vite.config.js -> vite-001
- index.html -> html-001
- src/index.css -> css-001

## Reglas

1. Devuelve TODOS los bloques en UN mensaje.
2. Envuelve cada bloque en triple backtick.
3. Preserva TODO el codigo.
