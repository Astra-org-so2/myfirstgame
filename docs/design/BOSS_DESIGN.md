# AFTER YOU — Boss Design: THE FIRST

Версия: 1.0 (Phase 0, креативный дизайн).

> **The First** (GDD §6.10): первая версия Eli. **Живая** (reveal #7),
> не «память». Бьёт паттернами на основе **ваших** атак (паттерн-
> память). Фазы: Wandering → Workshop. Уязвимость: «ядро» (окно после
> slam; FIRST BLADE расширяет окно). Death → **первая большая
> трансформация мира** (K7).
>
> Boss = «диалог с вашим прошлым» (GDD §6.2): не «монстр» —
> «уставший вы». Садиста в нём нет; есть усталость от цикла.
> (CHARACTER_BIBLE §8.)

## 1. Арена — Undercroft (mine, нижний уровень)

- **Локация:** The Mine, ярус 3 (ADR-010: арена босса = нижний
  уровень шахты; WORLD_BIBLE §4.4/4.9).
- **Размер:** 30×30 м (phase 1), «мастерская Первого» (WORLD_BIBLE §4.9):
  - **Стенд-записки** (3 записки The First — pre-boss read, §2.3);
  - **Стены из «версий оружия»** (his blade, your blade, other blades —
    visual mystery: «столько версий»);
  - **Центр: «печать»** (arena-core: круг из камня, 3 м, «сердце»
    арены — phase 2).
- **Свет:** тьма + 1 фонарь («его фонарь» — `first_traces_seen`).
  (Ritual: «чем ниже, тем ближе к памяти», WORLD_BIBLE §4.4.)
- **Вход:** дверь Undercroft (открывается по boss-условию, §2).

## 2. Вход в бой (условия)

### 2.1 Boss-условие (событийное, не счёт забегов — GDD §8 «окно, не
таймер»)
1. `mine_level_3_explored = true` (игрок спустился в ярус 3 хотя бы раз);
2. `deaths >= 3` (мир «знает смерть игрока»);
3. `first_traces_seen = true` (RUN 05+: «следы + фонарь» The First —
  ярус 3: «большие следы» + «его фонарь»).
→ В **следующем** забеге дверь Undercroft открывается (обычно
RUN 05–07). (FIRST_3_RUNS §4.)

### 2.2 Pre-boss (входе в Undercroft, до боя)
- **3 записки The First** (стенд, read 3×2 с):
  1. *«I was you. I was everyone. That's the trick. That's the trap.»*
  2. *«You'll fight like me. Of course. I taught you, in a way.»*
  3. *«Every time you reach the end, you restart everything. I'm sorry.
     I was, too. — The First»*
- **FIRST BLADE — take/leave** (WEAPON_DESIGN §4.3): на «стенде»,
  1.5× blade. **Выбор:** взять / не взять.
  - Взять: Echo «уважают» (WEAPON_DESIGN §4.1); core-hit window
    расширен (3).
  - Не взять: core-hit window base (2); The First: *«You left it.
    (soft) ...he left it too. One of you will.»*
  - `first_blade_taken = true/false` (WORLD_STATE_DESIGN §2; влияет
    на epilogue, §6).

### 2.3 Прелюдия (босс-вход)
- Дверь за спиной закрывается (1 с, звук: «камень»).
- The First: *«You came back. Good. This time I'll be quick.»*
  (CHARACTER_BIBLE §8, #1.)
- **Reveal #7:** он «живой» (не «память»): дышит, моргает, «уставший»
  (worn-материал, CHARACTER_BIBLE §8).

## 3. Механика боя

### 3.1 Базовые статы (data: `data/boss_the_first.tres`)
```
the_first: { hp: 600, speed: 2.2 (85% player),
  melee: { dmg: 20, range: 2.8m, telegraph: 0.5s, cd: 1.2s },
  slam:  { dmg: 35, range: 3.5m, telegraph: 0.8s, cd: 4.0s,
          core_window: 2 (3 с) — 3 (4 с, FIRST BLADE) },
  pattern_memory: 3 (комбо), phases: 2 }
```

### 3.2 Паттерн-память (GDD §6.10, ядро)
- The First **учится на ваших атаках**: если вы повторяете **комбо 3
  раза** (любой sequence: U1-U2-U3, dodge-attack, ...) — он **«выучил»**
  и **парирует** (parry: ваш следующий удар «блокирован», он
  контратакует, dmg 25).
- **UI-сигнал:** при «выученном» паттерне — «взгляд» (head-look, 0.3 с)
  + 1 реплика (cooldown 30 с): *«Again? I've had this swing a hundred
  times.»* (CHARACTER_BIBLE §8, #4.)
- **Слом:** сменить паттерн (3 «не-своих» хода) → он **«теряет
  ритм»** (stun 1.5 с, уязвимость). (Как False Echo, но «он учится» —
  «вы учитесь» (симметрия, GDD §6.2).)
- **Data:** `pattern_memory: 3` (threshold), `parry_window: 0.4s`,
  `reset: 3` (не-своих хода).

### 3.3 Уязвимость: «ядро» (core)
- **Core:** «печать» (arena-core, §1). После **slam** (0.8 s
  telegraph) — **окно** (2 с; **4 с** с FIRST BLADE): удар по «печати»
  → **core-hit** (dmg 50, только FIRST BLADE; без FIRST BLADE: dmg 30,
  «обычный» удар по «печати» (не «core-hit»)).
- **Правило:** «ядро» — **не «hp-бар»**, а **ритуал**: «вы бьёте
  «сердце» арены» (тема: «память = сердце мира»). (GDD §14.)
- **Сигнал:** «печать» подсвечивается (pale glow, 0.5 с) в окне.
  (WORLD_BIBLE §1.1: layer «Memory».)

### 3.4 Фазы (GDD §6.10)

#### Phase 1 — Wandering (hp 100–60%, «ваши призрачные атаки»)
- **Поведение:** melee (dmg 20) + slam (dmg 35) + **паттерн-память**
  (§3.2). «Ваши призрачные атаки» = он **повторяет ваши комбо**
  (Remnant-стиль, ENEMY_DESIGN §2): если вы «melee-heavy» — он
  «melee», если «ranged» — он «клинч» (закрытие дистанции).
- **Скорость:** 85% player. (Чуть быстрее — «он опытнее».)
- **Арена:** «мастерская» (стены из оружия, записки).
- **Реплики (CHARACTER_BIBLE §8):** #1 (вход), #3 (*«You fight like
  me. Of course you do. (smiles) ...I taught you, in a way.»*), #4
  (*«Again? I've had this swing a hundred times.»*), #5 (на FIRST
  BLADE: *«...that was mine. I left it for you. I didn't know which
  you.»*).

#### Phase 2 — Workshop (hp 60–0%, «арена меняется, Remnant вашего
лучшего забега»)
- **Переход (60%):** The First: *«She keeps us all. You think that's
  mercy? It's a cellar. And we are in it.»* (#6) → **арена меняется**
  (1 с: «стены» «открываются» → «workshop»: 30×30 → 40×40, «печать»
  в центре, «версии оружия» «живые» (VFX: emissive)).
- **Минион:** **Remnant (mirror)** — «ваш лучший забег» (run_data:
  best run = max playtime + kills; ECHO_SYSTEM_DESIGN §3): «бьёт как
  вы» (style: best run's dominant_style). (Минион, не boss: hp 80,
  dmg 15, «уходит» при 50% hp (fade) — «он не враг — «вы»».)
- **Поведение:** melee + slam + **паттерн-память (усилено: threshold
  2)** + **core-hit (главная цель: «печать»)**.
- **Скорость:** 90% player.
- **Реплики:** #6, #8 (core-hit: *«— (gasps) ...you felt that. It's
  real. That's the only part of me that's real.»*), #7 (если не взяли
  FIRST BLADE: *«You left it. (soft) ...he left it too. One of you
  will.»*).

### 3.5 Геймплей-контра (читабельность, GDD §6.2)
- **Telegraph:** melee 0.5 s, slam 0.8 s (GDD §6.2: 0.4–0.8 s).
- **Hitbox/hurtbox:** единый DamageResolver (TECHNICAL_DESIGN).
- **Knockback/hit-stop/shake:** feel-бюджет (ARCHITECTURE).
- **Читаемость «паттерн-памяти»:** «взгляд» + реплика (0.3 с) —
  игрок видит «он выучил» (не «сюрприз»).
- **Fairness:** «ядро» — **не «hidden»**: «печать» видна (0.5 s
  glow), «slam» telegraph 0.8 s. (GDD §6.2: «readability + feel».)

## 4. Death sequence (K6 → K7)

### 4.1 Смерть (hp 0)
- The First: *«You reached the end. You always do. ...don't make me
  proud of it.»* (#9) → **dissolve** (3 с, «рассеивается», не
  «падает»): «материал» (worn) «рассыпается» (VFX: particles, slow).
- **K6:** *«Tell her I said: let them go.»* (#10, seed Act II, C) —
  2 с тишины (audio-gas).
- **FIRST BLADE:** если взят — «гаснет» (VFX: emissive off); если не
  взят — «останется» на «стенде» (post-boss: «он ушёл, меч — нет»
  (ambiguity)).

### 4.2 Transformation (K7, WORLD_STATE_DESIGN §6)
- **Триггер:** `boss_defeated = true` → **world_transform** (1 раз,
  permanently).
- **Визуал (2 с cutscene-«мира»):**
  - Туман редеет (0.8 → 0.3); свет «теплее» (4000K → 5500K);
  - **Врата светятся** (gate_glow); **город-силуэт** (city_visible);
  - Echo «тише» (budget -2); следы «навсегда» (footprint_permanent);
  - NPC «спокойнее» (npc_calm).
- **NPC post-boss-реплики** (CHARACTER_BIBLE §2–6): Mara, Orren
  (башня пуста), Nia, Cartographer (доска).
- **MVP-финал:** игрок стоит у врат (свет, город, тишина).
  (NARRATIVE_STRUCTURE §1: Act I завершён, Act II начинается.)

## 5. Технические требования (ROADMAP Phase 11)

- **Data-driven:** `data/boss_the_first.tres` (hp, dmg, speed,
  telegraph, phases, pattern_memory, core_window). (GDD: «no core
  rewrites».)
- **AI:** state machine (idle → attack → parry → slam → core →
  phase_transition). (NavMesh: mock в headless, ADR-002.)
- **Паттерн-память:** data (sequence buffer, threshold 3, parry
  window 0.4 s). (Не «hardcoded» — data.)
- **Core-hit:** damage resolver (special: core, window 2/4 s).
- **Remnant-миниион:** ECHO_SYSTEM_DESIGN §3 (run_data: best run).
- **Performance:** 60 fps @High 1080p (GDD §12); boss-сцена =
  «peak» (замер Phase 16).
- **Tests:** TEST_PLAN Phase 11 (boss-encounter: phases, parry,
  core-hit, Remnant-миниион, death sequence, transformation).

## 6. Связи с системами
- **WEAPON_DESIGN** — FIRST BLADE (core-hit, take/leave, Echo «уважают»).
- **ECHO_SYSTEM_DESIGN** — Remnant-миниион (best run).
- **WORLD_STATE_DESIGN** — flags (`mine_level_3_explored`,
  `first_traces_seen`, `first_blade_taken`, `boss_defeated`),
  transformation (K7).
- **CHARACTER_BIBLE** — The First (реплики, мотивация, «живой»).
- **NARRATIVE_STRUCTURE** — #7 (reveal), K6 (let them go), K7
  (transformation), Act I (конец).
- **MYSTERY_REVEAL_MAP** — M1.4 (The First = «я»), M2.3 («She keeps
  us all»), M3.4 (Act II).

## 7. Open questions (boss)
- Q-B1: hp 600 — не «слишком долго» (5–8 мин)? (Митигция: «паттерн-
  память» + core-hit = «стратегия» (не «dps check»). Data: `hp: 600`
  (tune Phase 11). Решение: 5–8 мин — «boss = act end».)
- Q-B2: «Remnant-миниион» (best run) — не «слишком сложно» (2 цели)?
  (Митигция: минион «уходит» при 50% hp (не «kill» — «оставить»);
  «он не враг — «вы»» (ambiguity). Data: `minion_fade: 50%`.
  Решение: ок — «диалог с прошлым».)
- Q-B3: «Паттерн-память» (threshold 3) — не «слишком наказательно»?
  (Митигция: «взгляд» + реплика (сигнал); «слом» (3 не-своих хода) =
  «вы учитесь» (fair). Data: `pattern_memory: 3` (tune). Решение:
  ок — «ядро» (GDD §6.10).)
