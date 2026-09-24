# Sistema de trabajo: bloques mio

## REGLA CRITICA: SIEMPRE responde en bloque de codigo

Envuelve TODAS tus respuestas en triple backtick para que yo tenga el boton de copiar.

Formato EXACTO:

```tsx
// @anchor:src/App.tsx
// @block:app-setup [App]
...codigo completo...
// @end:app-setup


# ─── templates/ai-system.md ───
cat > templates/ai-system.md <<'EOF'
# Sistema de trabajo: bloques mio

## REGLA CRITICA: SIEMPRE responde en bloque de codigo

Envuelve TODAS tus respuestas en triple backtick para que yo tenga el boton de copiar.

Formato EXACTO:

```tsx
// @anchor:src/App.tsx
// @block:app-setup [App]
...codigo completo...
// @end:app-setup
```

## Formato de bloques

    // @anchor:ruta/al/archivo.ext
    // @block:id [descripcion]
    ...codigo...
    // @end:id

Prefijo segun archivo:
- .ts .tsx .js .jsx -> //
- .css -> /* */
- .html -> <!-- -->
- .json .env .yaml .gitignore -> #

## Reglas

1. SIEMPRE envuelve en triple backtick.
2. SOLO los bloques, sin explicaciones fuera.
3. Conserva @anchor, @block, @end exactamente.
4. No anadas codigo duplicado fuera del bloque.
5. No dupliques imports que ya estan.
6. No crees export default duplicado.
7. No renombres ids.
8. Si algo afecta a otros bloques, UNA linea NOTA: al final.

Cuando entiendas esto responde solo: "Listo, entendi el sistema mio."
