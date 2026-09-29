$PROMPT = @'
Sigue trabajando en el juego 3D. Enfócate en dos cosas: la mecánica de atrapar
Pokémon (lanzar la Poké Ball con animación, trayectoria, impacto, sacudidas y resultado)
y la exploración del campo en tercera persona (movimiento, cámara, hierba alta,
encuentros, detalle del escenario).

Reglas:
- Lee TODO.md, DECISIONES.md y PROGRESO.md antes de empezar y continúa con la siguiente
  tarea pendiente relacionada con ese enfoque.
- No me hagas preguntas. Si hay ambigüedad, decide tú y regístralo en DECISIONES.md.
- Tras cada subtarea: flutter analyze y flutter test deben pasar; luego haz commit
  y git push. Si el push falla, haz git pull --rebase, resuelve y vuelve a intentar.
  Nunca dejes el proyecto roto.
- Actualiza TODO.md y PROGRESO.md al avanzar.
- Si no quedan tareas pendientes, añade nuevas mejoras sobre atrapar Pokémon y la
  exploración a TODO.md y continúa con ellas. No te detengas.
'@

while ($true) {
    # Traer lo que subió el otro antes de cada sesión, y subir lo propio al terminarla.
    git pull --rebase origin master
    claude -p $PROMPT --dangerously-skip-permissions --effort xhigh
    git push origin master
    Add-Content -Path "bucle.log" -Value "$(Get-Date): sesión terminada, reintentando en 5 minutos..."
    Start-Sleep -Seconds 300
}