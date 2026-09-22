# QA Phase 12 — Boss THE FIRST (Undercroft)

Цель: «босс побеждаем в обоих вариантах (с FIRST BLADE и без);
K7-трансформация видна (qa-чек-лист); «достаточно качественный»
по чек-листу: телеграф-читабельность >= 70%» (ROADMAP Phase 12
exit). Риг-покрытие: **1189 проверок** (unit 767 + integration
422; новые сьюты: boss — data/pattern_memory/FSM/core/death/
gate (49); boss_scene — полный цикл в main.tscn: арена-контент
(босс + печать + 3 записки + клинок), melee (telegraph 0.5 с),
pattern-learn (3 комбо -> «look» + #4), parry (окно-блок +
counter 25), core (30 plain / окно one-shot), phase 2 (миньон
80/15, leave на 50%, M2.3-сигнал + честный run-гейт), blade
take (флаг + #5 + respect), death (#9 -> #10 -> флаг
boss_defeated + gate-правило)).

Важно: (1) дверь Undercroft = **окно** (BOSS_DESIGN §2.1):
mine level 3 + >= 3 смерти + first_traces_seen (RUN 05+) ->
дверь в СЛЕДУЮЩЕМ ране (обычно RUN 05-07); RUN 02 дверь
sealed («The door is closed. (stone)»); (2) босс атакует,
когда ИГРОК в радиусе печати (держит арену) — издалека он
может «махать» (свободный ход FSM), но удар не достаёт;
(3) FIRST BLADE — take/leave оба легальны: взял -> core 50/
окно 4 с, Echoes не атакуют первыми («...that was mine.»);
не взял -> #7 на 30% hp; (4) босс — единственный killable-
«NPC» (CHARACTER_BIBLE §8): смерть = K6 («let them go») ->
K7 (врата светят, туман редеет — на следующем входе в gate,
flag-driven, P10).

## A. Вход (RUN 05-07, после окна)

1. Mine: глубокий ярус (комната 3+) — флаг mine_level_3_explored
   (тихо). RUN 05+: следы The First в глубочайшей комнате
   (3 тёмных овала + его фонарь, emission) + toast «...the
   footprints are bigger than mine.» (one-shot).
2. Следующий ран: дверь Mine -> Undercroft открыта. До окна
   (RUN <05 / <3 смертей): sealed, stone-toast, уровень не
   переключается (run_cycle: RUN 02 sealed — риг).
3. Арена: 3 записки The First (стенды у входа, читать можно),
   FIRST BLADE на loot-споте (warm-подпись), босс на печати
   (капсула+голова, тусклый grey, его фонарь), печать —
   каменное кольцо (center, event_spot).
4. Вход: *«You came back. Good. This time I'll be quick.»*
   (Label3D над головой, 3 с).

## B. Бой (feel-чек-лист, ручной — владелец)

1. **Телеграфы >= 70% (R4/R6):** melee (0.5 с windup, 20) /
   slam (0.8 с, 35) — видно ДО удара; 20-30 ударов босса,
   засечь/уходить/парировать-окно: процент «успел среагировать»
   >= 70%. Записать: ____/30.
2. **Pattern-memory:** повторить одно комбо 3 раза -> босс
   «смотрит» (0.3 с) + *«Again? I've had this swing a hundred
   times.»* (cd 30 с); повторить ещё раз -> PARRY: ваш удар
   заблокирован (окно 0.4 с), его counter 25 (melee-радиус);
   3 «чужих» шага подряд -> break-stun (1.5 с, уязвим).
3. **Core:** после SLAM печать светится (2 с; 4 с с клинком):
   melee-удар, достигающий печати (range+0.5), = 30 (plain) /
   50 (First Blade) + *«— (gasps) ...you felt that. ...»*;
   окно one-shot.
4. **Фаза 2 (60% hp):** сдвиг 1.5 с, реплика M2.3 (*«She keeps
   us all. ...»*), печать горит постоянно, +Remnant-миньон
   (угол арены, 80 hp/15 dmg); на 50% hp миньон **уходит**
   (dissolve, без kill-записи — memory-stats не растёт).
5. **LAST STAND (30%):** если клинок не взят — *«You left it.
   (soft) ...he left it too. One of you will.»*

## C. FIRST BLADE (take/leave)

1. **Взял:** pickup -> loadout + world-state (перманентно);
   босс: *«...that was mine. I left it for you. I didn't know
   which you.»*; core 50/окно 4 с; REMNANT не атакуют первым
   (подойти к ремнанту: не бьёт, пока вы с клинком; первый
   ваш удар по нему — respect сломан, он бьётся);
   «...that was mine.» (<=3 м, one-shot).
2. **Не взял:** записка/стенд остаются на месте навсегда;
   #7 на 30% (п. B5).

## D. Смерть + K6/K7

1. Смерть босса: dissolve 3 с (рассеивается, не падает) +
   *«You reached the end. You always do. ...don't make me
   proud of it.»* -> *«Tell her I said: let them go.»* (2 с).
2. Toasts: «The door is open.» / «The fog thins.»; флаг
   boss_defeated (мировой).
3. **K7 (следующий вход в ancient_gate / новый ран):** врата
   светятся, город за вратами (P10), туман gate 0.8 -> 0.3
   (риг k7), post-boss реплики NPC (Mara: «The fire is
   brighter. I don't like it.»), Whisper #4 (gate_welcome_
   whisper, P11-флаг). Арена без босса: записки + стенд +
   печать (aftermath).
4. Dверь остаётся открытой навсегда (once open).

## E. Мобильный бюджет (R8)

- +2 mesh-секции босс (общий material), +2 печать, 0 dynamic
  lights (emission-only), 1 Label3D (visible 3 с); миньон =
  существующий remnant-визуал; steering = прямое преследование
  (без nav); физ-тик босса — один _physics_process.
- Therm/battery: бой <= ~2 мин; проверить FPS на референс-
  железе (Adreno) в арене с фазой 2 + миньон (бюджет ADR-021:
  <= 40 ms/frame headroom).

## F. Риг (регресс)

- `./tools/run_tests.sh unit` — 767 (boss 49).
- `./tools/run_tests.sh integration` — 422 (boss_scene 40;
  run_cycle: RUN 02 door sealed — поведение P7 «дверь открыта
  в RUN 02» заменено правилом окна, BOSS_DESIGN §2.1;
  mystery_scene: MVP-end M1:4 M2:3 M3:3 M4:3 не сдвинулся).
