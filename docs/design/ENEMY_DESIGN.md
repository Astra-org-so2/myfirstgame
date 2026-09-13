# AFTER YOU — Enemy Design

Версия: 1.0 (Phase 0, креативный дизайн).

> 5 архетипов врагов (GDD §11): Hollow, Remnant, Watcher, Mimic,
> Forgotten. Правило: враги — **не генерики**, а «части мира».
> Каждый — «память» (след, эхо, хранение). Бой — это «разговор с
> памятью». Ни один враг не «случайный»: каждый несёт mystery.

## 0. Общие правила (все враги)

- **Health/Damage:** data-driven (Godot Resources, ROADMAP Phase 5).
  Числа — в `data/enemies/*.tres`. No magic numbers (GDD §7).
- **AI:** state machines (idle → alert → chase → attack → retreat).
  Навигация — mock в headless (ADR-002), production — NavMesh
  (Phase 5). Простые правила: «видит» (raycast/fov), «слышит»
  (radius), «помнит» (memory: последние N секунд пути).
- **Агрессия и memory_stats:** агрессивность врагов зависит от
  поведения игрока (WORLD_STATE_DESIGN §4): убийца → враги «злее»
  (быстрее, злее); бегун → враги «спокойнее» (медленнее, но «следят»);
  исследователь → враги «молчаливее» (не реагируют на звук, но
  «видят»). Это — player-behavior-as-story.
- **Death:** враг умирает — и **оставляет след** (footprint/echo).
  След виден в следующем забеге (WORLD_STATE). (Беат A5: «след» первого Hollow.)
- **No-filler:** каждый враг несёт ≥1 из: gameplay / narrative /
  discovery / atmosphere. (ENV_STORYTELLING §4.)
- **Scale:** 5 archetypes × 2–3 variants (size/behavior) = 10–15
  «уникальных» врагов в MVP (GDD §11: 5 archetypes, 10–15 modular
  rooms).

## 1. HOLLOW (базовый враг, «пустой след»)

### 1.1 Концепт
«Пустой» — не человек, а **отпечаток**. Силуэт «кого-то», но «пустой»
(не «мёртвый» — «не-тут»). Ходит, смотрит, «запоминает» путь игрока.
Убивает — и **оставляет след** (виден в следующем забеге).

### 1.2 Поведение (AI)
- **Idle:** стоит, «смотрит» (головы-поворот к игроку, если в FOV).
- **Alert:** слышит/видит → «сводит» (sound: тихий «хруп» — звук
  «стекла»).
- **Chase:** идёт к игроку (медленно, 60% скорости игрока).
- **Attack:** «удар» (одиночный, telegraph: 0.5 с «замирание» → «выпад»).
  Damage: 15 (base). Cooldown: 2 с.
- **Retreat:** если игрок убегает → «отстаёт» (не догоняет дольше 5 с).
- **Memory:** помнит путь игрока (последние 10 с). Если игрок «был
  здесь в прошлый забег» (WORLD_STATE) → Hollow «идёт туда» (seed:
  «враг помнит твой путь»).

### 1.3 Appearance
- Silhouette: «человеческий», но «полупрозрачный» (50% opacity,
  «дымчатый»). Глаза: 2 точки (не «злые» — «пустые»).
- Цвет: серо-голубой (палитра «память»).
- Animation: walk (медленный), idle (stand), attack (lunge), hit (stagger),
  death (dissolve — «рассеивается», не «падает»).
- **Death:** dissolve + **след** (footprint, виден в следующем забеге).

### 1.4 Variants (MVP: 3)
- **Hollow (base):** как выше.
- **Hollow (fast):** быстрее (80% скорости), слабее (12 dmg). Spawn:
  «тёмные» зоны (mine).
- **Hollow (big):** медленнее (50%), сильнее (25 dmg). Spawn: «старые»
  зоны (village, shrine).

### 1.5 Mystery (несёт)
- A5: «след» после смерти (виден в RUN 02). Mystery 2 (почему мир
  помнит) — stage 1.

### 1.6 Data (sketch)
```
hollow_base: { hp: 30, dmg: 15, speed: 1.8 (60% player), fov: 120°,
  hear: 5m, attack_cooldown: 2.0, memory_window: 10s }
hollow_fast: { hp: 24, dmg: 12, speed: 2.4 (80%), fov: 130°, hear: 7m }
hollow_big:  { hp: 45, dmg: 25, speed: 1.5 (50%), fov: 100°, hear: 4m }
```

## 2. REMNANT (боевой Echo, «остаток забегания»)

### 2.1 Концепт
**Боевой Echo** (ECHO_SYSTEM_DESIGN §3): копия игрока, «собранный» из
данных забегания (run data). Не «запись» — «версия». Знает, где игрок
был, что делал, как бился. **Говорит** (1–3 реплики на encounter).

### 2.2 Поведение (AI)
- **Spawn:** не «случайный» — «где игрок был в прошлый забег»
  (WORLD_STATE: run_data, last N positions). Если игрок «не был» —
  Remnant не спавнится (ambiguity: «он там, где ты был»).
- **Combat:** **копирует стиль игрока** (memory_stats: если игрок
  «убийца» → Remnant «бьёт как игрок»; если «бегун» → Remnant
  «уходит и бьёт издалека»). (Player-behavior-as-story: враг =
  зеркало игрока.)
- **Attack:** использует **оружие игрока** (если игрок с BLADE →
  Remnant с BLADE; с CANNON → CANNON). Damage: 20 (base).
- **Speech:** 1–3 реплики (ECHO_SYSTEM_DESIGN §5). Первая встреча:
  *«You're early.»* / *«You usually take longer.»* — и уходит (#1.)
- **Death:** dissolve + **записка** (note: 1 строка из пула,
  «от Remnant»). (Mystery: «он знал, что я приду».)

### 2.3 Appearance
- Модель: **модель игрока** (Eli, тот же пол) + «worn»-материал
  (как The First, но «свежее»).
- Цвет: «тот же», что у игрока, но «выцветший» (50% saturation).
- Animation: **анимации игрока** (игрок узнаёт: «он двигается как я»).
- **Death:** dissolve + note (1 строка).

### 2.4 Variants (MVP: 2)
- **Remnant (mirror):** копия стиля игрока (как выше).
- **Remnant (false):** «ложный» (ECHO_SYSTEM_DESIGN §5): копия, но
  «не знает» (slower, weaker, не говорит). Spawn: «старые» зоны
  (village, bridge). (Ambiguity: «запись» vs «живой».)

### 2.5 Mystery (несёт)
- #1: первый Echo («You're early.» — и уходит). Mystery 3 (кто
  создаёт Echo) — stage 2. Mystery 1 (кто Eli) — seed: «он — я».

### 2.6 Data (sketch)
```
remnant_mirror: { hp: 60, dmg: 20, speed: 2.0 (75%), style: player_style,
  weapon: player_weapon, speech: 1-3, note_on_death: true }
remnant_false:  { hp: 40, dmg: 15, speed: 1.6 (60%), style: random,
  weapon: random, speech: 0, note_on_death: false }
```

## 3. WATCHER (наблюдатель; «глагол»: наблюдение → якорь → Memory Echo)

### 3.1 Концепт
«Смотрит». Не атакует (MVP, GDD §6.3: «наблюдатель (не DPS)»).
Единственный «глагол» — **наблюдение**: 2 секунды взаимного взгляда
(eye-line, low hum) → на месте игрока остаётся **memory anchor**
(«якорь памяти», WORLD_STATE: `anchor_X = pos`). В **следующем
забеге** на месте якоря — **Memory Echo** (scripted reconstruction,
ECHO_SYSTEM_DESIGN §2): «мир запомнил момент, когда вас смотрели».
Watcher — **связующее звено** между наблюдением и Memory Echo:
мир «запоминает» через взгляд.

### 3.2 Поведение (AI)
- **Idle:** «смотрит» (головы-поворот, 360°).
- **Observed:** если игрок смотрит (eye-line) → «взаимный взгляд»
  (2 с, audio: low hum) → **memory anchor** (WORLD_STATE: `anchor_X`).
- **Follow:** если игрок crouch → «идёт» (slow, 40% скорости, не
  атакует).
- **Vanish:** если игрок убегает → teleport (1 с, 10 м).
- **Death:** не умирает в MVP (неуязвим). (Design: «не его убивать».)
- **Budget:** anchors ≤ 2 per run (data); каждый anchor → 1 Memory
  Echo в следующем забеге (ECHO §2 budget).

### 3.3 Appearance
- Silhouette: «высокий» (1.8× рост игрока), «тонкий» (не «человеческий»
  — «деревянный»). Глаза: 1 (не 2 — «один глаз»).
- Цвет: тёмно-зелёный (палитра «лес»).
- Animation: idle (stand), observe (head-rotate), follow (slow walk),
  vanish (fade).
- **Death:** нет (MVP).

### 3.4 Variants (MVP: 1)
- **Watcher (base):** как выше. (Post-MVP: Watcher (hunter) — атакует.)

### 3.5 Mystery (несёт)
- Mystery 3 (кто создаёт Echo) — seed: «кто-то следит» + «взгляд
  оставляет след» (anchor → Memory Echo: «память = наблюдение»).
- **Atmosphere:** «мир смотрит». (ENV_STORYTELLING: «тишина вокруг».)

### 3.6 Data (sketch)
```
watcher_base: { hp: 999 (invulnerable MVP), dmg: 0, speed: 0 (idle) /
  1.2 (follow, 40%), fov: 360°, observe_time: 2.0, vanish_dist: 10m,
  crouch_trigger: true, anchors_per_run: 2 }
```

## 4. MIMIC (подражатель; «глагол»: зеркало привычки игрока)

### 4.1 Концепт
**Зеркало доминирующего поведения игрока** (GDD §6.3: «зеркалит
доминирующее поведение игрока (dodge/ranged/...)»). Mimic — не
«привидение-копия» (это Remnant), а **живое зеркало**: он «учится»
на том, **как** вы играете (memory_stats: dominant_style), и
**зеркалит ваш глагол**:
- вы «зациклились на уворотах» (dodge-heavy) → Mimic **уходит в
  уворот** от каждого вашего удара (контр-стиль: punish over-dodge);
- вы «держите дистанцию» (ranged/cannon) → Mimic **давит в упор**
  (закрывает дистанцию, punish keep-distance);
- вы «бьёте комбо» (melee-heavy) → Mimic **ломает комбо** (interrupt
  на 2-м ударе, punish combo-lock).

Это «разговор с привычкой»: Mimic **высмеивает ваш паттерн**.

### 4.2 Поведение (AI)
- **Learn:** в начале забега «читает» `dominant_style` (memory_stats:
  `dodge_count`, `ranged_hits`, `melee_hits`, `fled`, за N забегов).
- **Mirror:** в бою «зеркалит» (punish-стиль против dominant_style,
  см. 4.1). 1 паттерн (data: `mimic_punish_X`).
- **Attack:** «удар» (одиночный, telegraph: 0.4 с — «короткий»,
  «быстрый»). Damage: 25 (base). Cooldown: 1.5 с.
- **Speech:** 1 реплика (на spawn): *«I know how you do it.»*
  (Mystery: «он знает мои привычки» — M3 seed.)
- **Death:** dissolve + **ничего** (no loot, no note — «он не даёт
  ничего, только зеркало»). (Дизайн: «наказание паттерна» — не
  «награда».)

### 4.3 Appearance
- Silhouette: «человеческий», но **«перевёрнутый»** (материал:
  «зеркальный» (emissive, desaturated — палитра «echo» (GDD §7:
  «desaturated + emissive»))).
- Цвет: «ваш» (палитра игрока), но **«перевёрнутый»** (emissive).
- Animation: **ваши** (копия стиля), но **«зеркально»** (left/right
  flip) — «он двигается как вы, но «наизнанку»».
- **Death:** dissolve (no drops).

### 4.4 Variants (MVP: 3 — по dominant_style)
- **Mimic (dodge-mirror):** punish over-dodge (spawn: dodge-heavy
  player).
- **Mimic (range-mirror):** punish keep-distance (spawn: ranged-heavy
  player).
- **Mimic (combo-mirror):** punish combo-lock (spawn: melee-heavy
  player).
- **(Post-MVP: Mimic (person) — «остаток» (твист 2, Act III).)**

### 4.5 Mystery (несёт)
- Mystery 3 (кто создаёт Echo) — seed: «он знает мои привычки»
  («зеркало» = «память поведения»).
- **Player-behavior-as-story:** Mimic = «ваше зеркало» — «мир
  копирует вас» (WORLD_STATE_DESIGN §3: `dominant_style`).
- **Нет «наказания» (GDD §14):** Mimic — не «наказание за паттерн»,
  а «вызов»: «попробуй иначе» (разнообразие). (Дизайн: «высмеивает»,
  не «карает».)

### 4.6 Data (sketch)
```
mimic_base: { hp: 50, dmg: 25, speed: 2.4 (80%), attack_cooldown: 1.5,
  telegraph: 0.4, mirror: true (dominant_style), speech: 1 }
mimic_punish: { dodge-heavy: { evasive_dodge: 0.8, punish_window: 0.5 },
  ranged-heavy: { close_distance: 1.2, punish_window: 0.4 },
  melee-heavy: { interrupt_combo: 0.6, punish_window: 0.5 } }
mimic_spawn_chance: { base: 0.1, consistent_style: 0.2, varied_style: 0.05 }
```

### 4.7 Примечание (disguise-object — не Mimic)
«Подмена объекта» (ящик/стол/дверь = «не то, чем кажется») — **не
архетип врага**, а **странность-«слом»** (WORLD_BIBLE §3.4, уровень
«слом»): 1 раз в MVP (scripted, не spawn). (Игрок «взаимодействует»
→ «объект» «оживает» (1 Hit, 30 dmg, teleport) → «рассеивается»
(no drops).) (Дизайн: «мир «не только хранит» — он «подражает»» —
M2 seed, но **не** враг.)

## 5. FORGOTTEN (забытый, «не помнит себя» — элитный)

### 5.1 Концепт
**Забытый** (ECHO_SYSTEM_DESIGN §4: corrupted Echo). «Бывший игрок»
(прошлая версия Eli), но «забыл себя». Не «злой» — «потерянный».
Ходит, «ищет» (random path), «бьёт» (если игрок рядом).
**Говорит** (1 реплика: *«...where...?»* — не понимает, где он).

### 5.2 Поведение (AI)
- **Wander:** random path (не «к игроку» — «куда угодно»).
- **Alert:** если игрок рядом (5 м) → «бьёт» (не «целится» — «махает»).
- **Attack:** «мах» (одиночный, telegraph: 1 с — «медленный», «слабый»).
  Damage: 35 (base, элитный). Cooldown: 3 с.
- **Speech (шёпот — GDD §6.3: «шепчет фразы из истории игрока»):**
  Forgotten **шепчет** (не «кричит») — 1 из: (а) *«...where...?»*
  (б) **фраза из ВАШЕЙ истории**: 1 строка из ваших записок (notes[],
  WORLD_STATE_DESIGN §4) / 1 ваша одноречие-реплика (Eli line pool) /
  1 реплика NPC, которую вы слышали (Mara/Nia). (Data: `forgotten_
  whisper_pool = player_history`.) (Mystery: «он говорит моими
  словами» — M1 seed: «он был мной?».)
- **Death:** dissolve + **fragment** (mystery fragment: 1 строка,
  «от Забытого»). (Mystery: «он был мной?»)

### 5.3 Appearance
- Silhouette: «человеческий» (модель Eli, «очень worn» — «треснувший»,
  «выцветший до белого»). Глаза: 0 (не «пустые» — «нет»).
- Цвет: белый (палитра «забытый» — Archivist-ближайший).
- Animation: wander (slow, «шатающийся»), attack (slow swing),
  hit (stagger, «не реагирует» — «не чувствует»), death (dissolve,
  «медленный» — 3 с).
- **Death:** dissolve (3 с) + fragment (1 строка).

### 5.4 Variants (MVP: 2)
- **Forgotten (wanderer):** как выше. Spawn: «старые» зоны (village,
  shrine, lake).
- **Forgotten (guard):** «стоит» (не wander), «бьёт» (если игрок
  рядом). Spawn: mine, undercroft. (Boss-adjacent.)

### 5.5 Mystery (несёт)
- Mystery 1 (кто Eli) — seed: «он был мной?». (Shrine, lake.)
- Mystery 4 (почему «сотни раз») — seed: «забытые — «остатки»».
  (Act III: «оставшиеся» = Forgotten-формы.)

### 5.6 Data (sketch)
```
forgotten_base: { hp: 120, dmg: 35, speed: 1.4 (55%), attack_cooldown: 3.0,
  telegraph: 1.0, speech: 1, fragment_on_death: true, wander_radius: 15m }
forgotten_guard: { hp: 150, dmg: 40, speed: 0 (idle), attack_cooldown: 2.5,
  telegraph: 0.8, speech: 1, fragment_on_death: true }
```

## 6. Сводная таблица (для data)

| Враг | HP | DMG | Speed | Атака | Mystery (несёт) | Spawn-правило |
|---|---|---|---|---|---|---|
| Hollow (base) | 30 | 15 | 60% | рывок (windup 0.5 с), 2 с | M2 (K2: след) | все зоны |
| Hollow (fast) | 24 | 12 | 80% | рывок, 1.5 с | M2 | mine (тьма) |
| Hollow (big) | 45 | 25 | 50% | рывок, 2.5 с | M2 | village, shrine |
| Remnant (mirror) | 60 | 20 | 75% | повторяет ваш ход боя (run data) | #1, M3, M1 | «где игрок был» |
| Remnant (false) | 40 | 15 | 60% | зеркальный бой (на 1 beat раньше) | M3 | village, bridge |
| Watcher | 999 | 0 | 0/40% | наблюдение → anchor → Memory Echo | M3, atmosphere | shrine, lake, village |
| Mimic (dodge-mirror) | 50 | 25 | 80% | зеркало привычки (punish over-dodge) | M3 | «consistent style» player |
| Mimic (range-mirror) | 50 | 25 | 80% | зеркало привычки (punish keep-distance) | M3 | «consistent style» player |
| Mimic (combo-mirror) | 50 | 25 | 80% | зеркало привычки (punish combo-lock) | M3 | «consistent style» player |
| Forgotten (wanderer) | 120 | 35 | 55% | мах, 3 с; шёпот (ваши фразы) | M1, M4 | village, shrine, lake |
| Forgotten (guard) | 150 | 40 | 0 | мах, 2.5 с; шёпот (ваши фразы) | M1, M4 | mine, undercroft |

**Итого: 5 archetypes × 11 variants (MVP).** GDD §11: 5 archetypes.
(«Подмена объекта» — странность-«слом», не враг — ENEMY_DESIGN §4.7.)

## 7. Агрессия и memory_stats (player-behavior-as-story)

- **Убийца (slayer):** memory_stats.kills > threshold → враги «злее»
  (speed +10%, dmg +5%, «помнят» путь игрока). Remnant «бьёт как игрок».
  (NPC-реплики: Orren: *«Slayers get remembered differently.»*)
- **Бегун (runner):** memory_stats.fled > threshold → враги «спокойнее»
  (speed -10%, «не догоняют» дольше), но Watcher «чаще» (следит).
  (NPC-реплики: Orren: *«Runners live longer.»*; Child: *«You always
  run.»*)
- **Исследователь (explorer):** memory_stats.explored > threshold →
  враги «молчаливее» (не реагируют на звук) + discoveries (секретные
  комнаты по порогам exploration, GDD §6.9).
- **Упрямый (consistent style):** memory_stats.dominant_style «за-
  фиксирован» (N забегов один глагол) → Mimic «чаще» («мир подражает
  вашей привычке», ENEMY_DESIGN §4).
- **Данные:** thresholds — в `data/memory_stats_thresholds.tres`
  (WORLD_STATE_DESIGN §4).

## 8. Связи с системами
- **ECHO_SYSTEM_DESIGN** — Remnant (боевой), Forgotten (corrupted),
  Watcher (passive, seed).
- **WORLD_STATE_DESIGN** — memory_stats, spawn-правила, follow-правила.
- **WEAPON_DESIGN** — Remnant «использует оружие игрока».
- **ENV_STORYTELLING_GUIDE** — «враг = часть мира» (atmosphere).

## 9. Open questions (enemy)
- Q-E1: Watcher не умирает (MVP) — не «обидит» ли игрока? (Митигция:
  он «не враг» — «наблюдатель»; игрок «не может» его убить —
  design, не bug.)
- Q-E2: Mimic «не даёт ничего» — не «пусто» ли? (Митигция: он
  «боль» — не «награда». Но «опознать» Mimic = discovery (ENV_
  STORYTELLING §5).)
- Q-E3: Forgotten «бьёт как не понимает» — не «слишком легко» ли?
  (Митигция: dmg 35, telegraph 1 с — «медленный, но опасный».)
