# QA Phase 9 — Ghost/Echo (budget per ADR-014)

Цель: «ghost бегает по хабу, повторяет действия, читается как
«прошлый я», ≤ 0.5 ms/frame; #1 (B4) воспроизводится (playtest)»
(ROADMAP Phase 9 exit). Риг-покрытие: **886 проверок** (unit 615 +
integration 271; новые сьюты: echo — budget rows, GhostTimeline
(build/remap/Catmull-Rom/ry-wrap/action), budget-state;
echo_scene — полный цикл: RUN 1 echo-free → смерть → RUN 02:
Passive-реплей (движется, fade-out на конце), B4 Remnant «где
игрок был» (обе реплики канона, dissolve-уход, ECHO_TRIGGER в
записи, слот бюджета потрачен), маркер точки смерти RUN 1;
enemy_scene — RUN 1 = 4 врага без remnant, RUN 02-симуляция =
5).

Важно: (1) RUN 1 — **без эхов** (ADR-014: «нет прошлого»);
(2) ghost — НЕ живой: не атакует, не говорит, просвечивает;
(3) реплей = ключевые моменты пути (записи), а не покадровое
видео — между ними Catmull-Rom (TECHNICAL_DESIGN §5);
(4) финальный dissolve/rim-шейдер — Phase 13 (MVP: 50% opacity,
серо-голубой tint, faint emissive).

## A. RUN 1 (echo-free)

1. Лагерь: 4 врага (hollow/remnant **нет**/watcher/mimic/
   forgotten). Прогулка + бой — никаких теней/копий.
2. Смерть → выбор Inheritance.

## B. RUN 02 (2 эха)

1. **Passive Echo** (в лагере, по пути RUN 1):
   - «дымчатая» копия игрока (50% opacity, серо-голубая),
     идёт по маршруту прошлого забега (столб → убитый Hollow →
     точка смерти);
   - не реагирует на игрока, не бьёт, «просвечивает»;
   - по завершении пути — dissolve (3 с); если игрок оторвался
     >20 м — рассеивается раньше;
   - следы-маркеры вдоль пройденного пути.
2. **B4 — Combat Echo (#1)**: Remnant (выцветшая копия) стоит
   «где игрок был» (последняя точка в лагере из RUN 1):
   - подойти: *«You're early.»* — пауза — *«You usually take
     longer.»* — dissolve (1 с) и уходит; **не воюет**;
   - второй раз не появляется (1 Combat per run).
3. **Маркер**: faint-метка на земле в точке смерти RUN 1.
4. Зоны: реплей продолжает путь RUN 1 в зонах, где комнаты
   совпали; «не совпало» — перематка (pulse-вспышка, «не всё
   помнится»).

## C. RUN 03+ (по бюджету)

- RUN 03: ghost RUN 2 + Remnant. RUN 04+: +1 «специальный»
  (Memory/Forgotten/False — контент Phase 10/11).
- «Что изменилось» / run-записи: ECHO_TRIGGER в логе RUN 02
  (combat).

## D. Измерения (обязательно, «no fine without numbers»)

- Стоимость ghost: в риге замер цикла ghost-update (exit-
  критерий ≤ 0.5 ms/frame — референс в integration echo_scene;
  на железе — Phase 16).
- Размер runs-секции после 5 смертей (реплей-источник): ≤
  ~150 КБ (5 МБ-кэп, ADR-004).

**Результат проверки:** _заполнить владельцу: pass/fail по
пунктам A–C + цифры D._
