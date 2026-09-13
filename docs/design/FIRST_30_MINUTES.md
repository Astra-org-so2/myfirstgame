# AFTER YOU — First 30 Minutes (детальный скрипт)

Версия: 1.1 (Phase 0, креативный дизайн).

> Первые 30 минут = RUN 1 (полный, ~18–22 мин) + RUN 02 (старт,
> ~8–10 мин). **Якорь (10 мин, GDD §8):** pillar (0:30) → weapon
> (0:45) → first Hollow (1:30) → camp+note (2:30) → figure (4:00) →
> serious combat (6:00) → sealed door (8:00).
>
> Нумерация: **A1–A19** = якоря RUN 1, **B1–B6** = якоря RUN 02
> (старт). Signature moments — **#1–#10** и беаты **K1–K7**
> (NARRATIVE_STRUCTURE §4) — ссылаются отдельно.
>
> Правила: (1) **никакого меню** (прямой старт, GDD §8: «you wake
> up»); (2) **1 новая идея на 3–5 минут** (no exposition); (3)
> **каждый якорь = ≥1 из 5** (gameplay/visual/narrative/discovery/
> interaction — GDD §12); (4) **события-триггеры**, не таймер
> (player-driven: «когда подойдёт», не «когда пройдёт N минут»;
> FIRST_3_RUNS: «окно, не таймер»).

## 0. RUN 1 — структура (18–22 мин)

| Время | Якорь | Что происходит | Новая идея |
|---|---|---|---|
| 0:00 | **A1. Пробуждение** | Чёрный экран → звук (дыхание, шаги) → «вы стоите». Никакого меню. | «Вы уже здесь.» |
| 0:30 | **A2. Pillar (K3)** | Каменный столб, выцарапано: **«YOU HAVE BEEN HERE BEFORE.»** | «Мир помнит. Я — не первый.» |
| 0:45 | **A3. Weapon (K1)** | BLADE — «рука сама». *«I don't remember learning this.»* | «Тело помнит. Голова — нет.» |
| 1:00 | **A4. First steps** | Ходьба, бег, туман, тишина; 1 Hollow вдалеке (atmosphere, не бой). | «Мир — место, не уровень.» |
| 1:30 | **A5. First Hollow** | Первый враг («пустой», рывок с windup). Убит → **оставляет след** (виден в RUN 02). | «Враг — память. Убил — оставил.» |
| 2:00 | **A6. Camp** | Лагерь (hub), костёр (warm). Mara: *«You've been walking a long time. Eat something.»* | «Есть дом. Он знает.» |
| 2:30 | **A7. Camp + note (#2)** | Note stand: записка **своим почерком**: *«If you find this, don't trust the version of me that comes after.»* | «Я предупреждал себя. Мир хранит.» |
| 3:00 | **A8. Mara** | *«The road eats people. This fire doesn't.»* (trust 0→1 start). | «NPC доверяет. Не объясняет.» |
| 3:30 | **A9. Leave camp** | Выход; 8 зон — любой порядок; landmark: watchtower. | «Свобода. Но мир следит.» |
| 4:00 | **A10. Figure** | **Фигура, похожая на Eli**, стоит в 30 м — и **исчезает** (fade, 1 с). **Следы ведут в деревню.** (Не Watcher — см. A12.) | «Кто-то «как я» был здесь. Куда ведут следы?» |
| 5:00 | **A11. Village (Nia) (#3)** | *«You already asked me that.» — «When?» — «Yesterday.»* (NPC помнит прошлый Run.) | «NPC помнит то, чего со мной не было.» |
| 5:30 | **A12. Pyre + Watcher** | Пепелище (`village_pyre_seen`): что сгорело? Не объясняется. У края — **Watcher** (2 с взгляда, low hum, teleport; memory anchor). | «Мир знает. И мир смотрит.» |
| 6:00 | **A13. Serious combat** | 2–3 Hollow (base + fast). Riposte (blade special, 0.5 с окно). | «Бой — решение, не урон.» |
| 7:00 | **A14. Mine** | Ярус 1: HAND CANNON в ящике (**не взять** — RUN 02+). Note: *«It's heavy. Use it once. — E.»* (`mine_note_read`). | «Оружие ждёт. Не даётся — остаётся.» |
| 7:30 | **A15. Shrine** | ECHO STAFF в нише (**не взять** — RUN 02–3). Шёпот: *«Nothing should ever truly disappear.»* | «Сущность хранит. Это принцип, не злоба.» |
| 8:00 | **A16. Sealed door** | Ancient Gate: круг с 3 впадинами, **запечатан**; вырезано: **«YOU WILL OPEN THIS AFTER YOU DIE.»** Подножие: 3 записки «предыдущих версий» (seed M4). | «Дверь ждёт смерти. Не «после квеста» — «после остановки».» |
| 9:00 | **A17. Lake** | Тишина (audio-gas). Отражение RUN 1 = **нормальное** (K5 — только RUN 05). Note на берегу: *«Don't go to the lake before the mine. — E.»* | «Озеро хранит. Предупреждение — от меня.» |
| 10:00 | — | **Конец 10-минутного якоря.** Игрок чувствует: мир помнит, я не первый, дверь ждёт. (M2 stage 1; M4 seed.) | (Переход к свободному исследованию.) |
| 12:00 | **A18. Free exploration** | 8 зон, любой порядок (GDD §11). 1–2 Mimic (зеркало привычки), 1 Forgotten (шёпот: *«...where...?»*). | «Свобода = нарратив (memory_stats: explored, dominant_style).» |
| ~18–22 | **A19. First death (K2)** | Смерть (Hollow big / Forgotten — **не scripted**, окно ~20 мин). Экран: *«Again?»* (1 раз). 3 карточки Inheritance. | «Смерть — переход, не наказание.» |
| ~20 | **B0. RUN 02 — старт** | (РАЗДЕЛ 2.) Gate открыт (#4). Cannon. Первый Echo: *«You're early.»* — и уходит (#1). | «Мир открыл. Не я.» |

## 1. RUN 1 — детали якорей

### A1 (0:00) — Пробуждение
- **Visual:** чёрный экран 2 с → «вы стоите» (Eli в тумане).
  Никакого «нажмите X». (GDD §8: 0:00–15 s — black screen, ветер,
  Eli открывает глаза; 0:15 — управление.)
- **Audio:** дыхание, шаги, distant-шёпот (3 с, fade).
- **Gameplay:** управление сразу включено (WASD + mouse).
  Туториала нет (GDD §8).
- **Идея:** вы не «появились» — вы «встали».

### A2 (0:30) — Pillar (K3)
- **Visual:** каменный столб (2 м). Выцарапано (глубоко, «старо»):
  **«YOU HAVE BEEN HERE BEFORE.»** (GDD §5: «первая загадка».)
- **Gameplay:** interact (E) — «рассмотреть» (1 с; zoom, следы
  царапин — «много рук» — seed #9: «прошлые версии»).
- **Идея:** hook. (Reveal #9 — post-MVP: столб выцарапали
  **прошлые версии**, не «мир».)

### A3 (0:45) — Weapon (K1)
- **Visual:** BLADE «в руке» (авто-pickup 1 с, «рука сама»).
- **Gameplay:** `blade_found = true` (навсегда); combo 3 (WEAPON_DESIGN §1.3).
- **Реплика (K1):** *«I don't remember learning this.»* (CHARACTER_BIBLE §1.3.)
- **Идея:** мышечная память = Mystery 1, stage 1.

### A4 (1:00) — First steps
- **Visual:** туман, следы, тишина. 1 Hollow вдали (atmosphere).
- **Gameplay:** walk/run/dodge — «ощущение тела».
- **Идея:** мир — место, не уровень.

### A5 (1:30) — First Hollow
- **Visual:** Hollow (человек без лица, GDD §6.3; 50% opacity,
  «дымчатый», «смотрит»).
- **Gameplay:** blade (dmg 25) vs Hollow (hp 30, dmg 15, рывок с
  windup 0.5 с, CD 2 с). 1–2 удара.
- **Death:** dissolve 3 с + **след** (виден в RUN 02). (ENEMY_DESIGN §1.3.)
- **Идея:** убил память — она оставила след. (M2 stage 1.)

### A6–A8 (2:00–3:00) — Camp, note (#2), Mara
- **Visual:** лагерь: костёр (янтарь), 3 палатки, note stand,
  стол с кружками + **кетл** (world-объект; interact: взять/поставить
  — мелочь-интерактив, seed #3: Mara RUN 02: *«You left a kettle last
  time. I washed it.»*).
- **Gameplay:** note stand → чтение: записка **своим почерком**:
  *«If you find this, don't trust the version of me that comes
  after.»* (**#2 «Своя записка»**, GDD §8, канонический текст).
  Mara — 2 реплики (CHARACTER_BIBLE §2, #1–2); trust 0→1 старт
  (PROGRESSION_DESIGN §4: условие: 2 взаимодействия + «принести
  дрова»).
- **Идея:** дом, который «знает»; предупреждение «себе» (ambiguity:
  «какой версии не доверять?»).

### A10 (4:00) — Figure
- **Visual:** фигура, **похожая на Eli** (ваша модель, 100% opacity,
  без «worn»-материала — «свежая»), стоит в 30 м, поворачивает
  голову к вам — и **fade** (1 с). **Следы** (footprints) ведут
  **в деревню**. (GDD §8: «фигура, похожая на Eli, исчезает (следы
  ведут в деревню)».)
- **Gameplay:** не атакует, не говорит. (Это «пред-echo» — seed #1;
  не Watcher — он в A12.)
- **Идея:** «кто-то «как я» был здесь». (M3 seed; #1 — RUN 02.)

### A11 (5:00) — Village (Nia) (#3)
- **Dialog:** *«You already asked me that.» — «When?» —
  «Yesterday.»* (CHARACTER_BIBLE §4, #1; **#3 «NPC помнит прошлый
  Run»**, канон GDD §7.)
- **Идея:** NPC помнит «вчера» — которого не было (ambiguity:
  «запись или живой?» — GDD §7).

### A12 (5:30) — Pyre + Watcher
- **Visual:** пепелище (1 изба из 5). `village_pyre_seen = true`.
  У края — **Watcher** (1.8×, «деревянный», 1 глаз): 2 с взаимного
  взгляда, low hum → teleport (1 с, 10 м) → **memory anchor**
  (ENEMY_DESIGN §3; в RUN 02 здесь — Memory Echo).
- **Interaction:** можно оставить записку (note stand в деревне):
  «что сгорело?» (player-driven mystery, no answer).
- **Идея:** мир знает, не объясняет; мир смотрит (M3 seed).

### A13 (6:00) — Serious combat
- **Combat:** 2–3 Hollow (base + fast). Riposte (0.5 с окно, 30 с CD).
- **Идея:** бой — решение (timing), не урон (GDD §14).

### A14 (7:00) — Mine
- **Visual:** ярус 1 (свет), ящик с HAND CANNON (**не взять**:
  `cannon_found` ставится только в RUN 02+ — «мир даёт оружие
  после первой смерти»).
- **Note:** *«It's heavy. Use it once. — E.»* (`mine_note_read = true`).
- **Идея:** оружие ждёт (WEAPON_DESIGN §2.4).

### A15 (7:30) — Shrine
- **Visual:** полукруг камней (7, один «не тот»), ECHO STAFF в нише
  (**не взять** — RUN 02–3), шёпот Archivist:
  *«Nothing should ever truly disappear.»* (CHARACTER_BIBLE §7, #1.)
- **Идея:** сущность хранит — это принцип (M3 seed).

### A16 (8:00) — Sealed door
- **Visual:** Ancient Gate: круг с 3 впадинами, запечатан. Вырезано:
  **«YOU WILL OPEN THIS AFTER YOU DIE.»** (GDD §8.) Подножие:
  3 записки «предыдущих версий» (разные «почерка» — M4 seed).
- **Gameplay:** не открывается (RUN 01). (`run_02_door_open` — после
  A19.)
- **Идея:** дверь откроется «после смерти» — не «после квеста».

### A17 (9:00) — Lake
- **Visual:** тишина (audio-gas), «ледяной» круг. Отражение RUN 1 =
  нормальное (K5 — только RUN 05: Archivist).
- **Note на берегу:** *«Don't go to the lake before the mine. — E.»*
  (Предупреждение «от себя» — и вы только что были в mine, A14:
  «я послушался» / «я не понял». Ambiguity.)
- **Идея:** озеро хранит (M3 seed).

### A18 (12:00) — Free exploration
- **Content:** 8 зон, любой порядок; 1–2 Mimic (зеркало привычки:
  «I know how you do it.»), 1 Forgotten (шёпот: *«...where...?»* /
  ваши фразы — ENEMY_DESIGN §5).
- **memory_stats:** `explored`, `dominant_style`, `strange_actions`
  растут (WORLD_STATE_DESIGN §3).
- **Идея:** свобода = нарратив.

### A19 (~18–22 мин) — First death (K2)
- **Событие:** смерть (Hollow big / Forgotten). **Не scripted** —
  окно ~20 мин (GDD §8: «~20:00 (window, не таймер) первая смерть»;
  camp = sanctuary).
- **Экран:** тьма, 2 с, голос: *«Again?»* (однажды — CHARACTER_BIBLE
  §1.3; далее — тишина).
- **Inheritance:** 3 карточки (1 из 3, PROGRESSION_DESIGN §0;
  UX ≤ 10 с).
- **WORLD_STATE:** `deaths += 1`; `last_death_pos` (→ мумия в RUN 03,
  #5); `run_02_door_open = true` (A16 → открыт).
- **Идея:** смерть — переход. (M2 stage 2: «врата открываются после
  смерти».)

## 2. RUN 02 — старт (8–10 мин)

| Время | Якорь | Что происходит | Новая идея |
|---|---|---|---|
| 0:00 | **B1. Respawn (#3)** | Лагерь. Mara: *«You left a kettle last time. I washed it.»* (CHARACTER_BIBLE §2, #3; #3 — «NPC помнит прошлый Run», 2-я ипостась). | «Мир помнит мелочи.» |
| 1:00 | **B2. Gate — open (#4)** | Ancient Gate: `run_02_door_open` — **открыт** (faint light; был запечатан). UI: «Что изменилось» (WORLD_STATE_DESIGN §9). Реплика Eli: *«That wasn't there.»* | «Мир изменился. Не я.» |
| 3:00 | **B3. Cannon** | Mine, ярус 1: pickup HAND CANNON (`cannon_found`). Ammo 5/забег, reload ×1. Note рядом уже «ваш» (прочитан в RUN 1). | «Расстояние = не обязан быть рядом.» |
| 5:00 | **B4. First Echo (#1)** | Копия игрока (Remnant, mirror) «на вашем пути» (RUN 1 path). Говорит: *«You're early.»* — пауза — *«You usually take longer.»* — **и уходит** (fade, не бой). (GDD §8, канон; #1.) | «Копия говорит. Запись или живой?» |
| 7:00 | **B5. Shrine — staff** | ECHO STAFF (ниша) — **взять** (`staff_found`, RUN 02–3). Note: *«It sees what you left. Use it gently. — E.»* | «Память = видеть, ломать, успокаивать, бить.» |
| 8:00 | **B6. RUN 02 — переход** | Игрок чувствует: дверь открыта, оружие взято, копия сказала «you're early». (M2 stage 2, M3 stage 2.) | (Переход к полному RUN 02 — FIRST_3_RUNS §2.) |

### B4 — детали (значимый момент)
- **Почему «уходит», а не «бьёт»:** первый Echo — **разговор**, не
  бой (GDD §8: «и уходит»). Игрок **не может** его догнать (fade
  1 с, distance > 20 м). (Дизайн: «первый контакт = голос, не
  кулаки» — mystery, не action.)
- **Амбиент:** 2 с тишины (audio-gas) → 2 реплики (voice: «ваш»
  голос, но «усталый» (slight pitch -10%)) → fade.
- **WORLD_STATE:** `first_echo_seen = true`; `echo_lines_heard += 1`.
- **Что игрок делает:** ничего (только слушает). (Дизайн: «moment»,
  не «encounter».)

## 3. Бюджет 30 минут (проверка качества)

- **Новых идей:** 19 якорей × 1 идея (каждая проходит 3 вопроса
  quality bar — GDD §13).
- **Signature moments (канон, NARRATIVE_STRUCTURE §4):** #1 (B4),
  #2 (A7), #3 (A11/B1), #4 (B2) = 4 из 7 MVP за 30 минут.
  (#5 «свой труп» — RUN 03; #6 «echo принимает решение» — RUN 03;
  #7 «The First жив» — boss.)
- **Ключевые беаты:** K1 (A3), K2 (A19), K3 (A2), K7 (post-boss).
- **Mystery stages:** M1 stage 1 (A3), M2 stages 1–2 (A5, A19/B2),
  M3 seeds (A10, A12, A15, A17), M4 seed (A16). (MYSTERY_REVEAL_MAP.)
- **Оружия:** 2 из 4 (blade A3, cannon B3; staff B5 — опционально).
- **NPC:** 2 из 5 (Mara, Nia) + 2 «видения» (figure A10, шёпот A15).
- **Смертей:** 1 (A19). Inheritance: 1 (выбор из 3).
- **Echo:** RUN 1: 0; RUN 02 (старт): 1 (#1, B4). (ECHO §8.)

## 4. Связи с системами
- **FIRST_3_RUNS** — полные RUN 1/2/3 (этот документ = «детали якорей»).
- **WORLD_STATE_DESIGN** — flags (`blade_found`, `cannon_found`,
  `staff_found`, `mine_note_read`, `village_pyre_seen`,
  `run_02_door_open`, `first_echo_seen`, `last_death_pos`),
  notes (#2), memory_stats.
- **ECHO_SYSTEM_DESIGN** — RUN 1: 0 echo; RUN 02: 1 Combat (#1).
- **ENEMY_DESIGN** — Hollow (A5, A13), Watcher (A12, anchor),
  Mimic (A18), Forgotten (A18).
- **WEAPON_DESIGN** — blade (A3), cannon (B3), staff (B5).
- **NARRATIVE_STRUCTURE** — #1/#2/#3/#4, K1/K2/K3/K7, M1–M4
  (stages 1–2).

## 5. Open questions (first 30 min)
- Q-F1: 19 якорей / 30 мин — не «конвейер» ли? (Митигция: якоря —
  триггеры, не таймер; A18 — 6+ мин «свободы». Решение: да, плотно,
  но «окно».)
- Q-F2: first death ~20 мин — не рано? (Митигция: окно, не таймер;
  camp = sanctuary; A3+A7 дали «телу» и «себе» перед смертью.
  Решение: ~20 мин — «act end» RUN 1.)
- Q-F3: staff в B5 (RUN 02) — не «слишком рано» 3-е оружие? (Митигция:
  B5 — опциональный якорь (7-я минута RUN 02); игрок, идущий в mine,
  не зайдёт в shrine. Data: `staff_min_run: 2`. Решение: ок.)
