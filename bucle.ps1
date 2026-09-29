$PROMPT = @'
Sigue trabajando en el juego 3D. Enfócate en dos cosas: la mecánica de atrapar
Pokémon (lanzar la Poké Ball con animación, trayectoria, impacto, sacudidas y resultado)
y la exploración del campo en tercera persona (movimiento, cámara, hierba alta,
encuentros, detalle del escenario).

Reglas:
- Lee TODO.md, DECISIONES.md y PROGRESO.md antes de empezar y continúa con la siguiente
  tarea pendiente relacionada con ese enfoque.
- No me hagas preguntas. Si hay ambigüedad, decide tú y regístralo en DECISIONES.md.
- Tras cada subtarea: flutter analyze y flutter test deben pasar; luego haz commit.
  Nunca dejes el proyecto roto.
- Actualiza TODO.md y PROGRESO.md al avanzar.
- Si no quedan tareas pendientes, añade nuevas mejoras sobre atrapar Pokémon y la
  exploración a TODO.md y continúa con ellas. No te detengas.
'@

while ($true) {
    claude -p $PROMPT --dangerously-skip-permissions --effort xhigh
    Add-Content -Path "bucle.log" -Value "$(Get-Date): sesión terminada, reintentando en 5 minutos..."
    Start-Sleep -Seconds 300
}