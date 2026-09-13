# AFTER YOU — Progression Design

Версия: 1.1 (Phase 0, креативный дизайн).

> Ядро: **нет валюты** (GDD §6.5). Прогресс = **память мира**.
> **15 Inheritances** (GDD §6.5: «10–15 апгрейдов»):
> - **8 базовых** (MVP pool, без условий);
> - **4 NPC-gated** (MVP pool; требуют живого NPC, trust≥1);
> - **3 post-MVP** (BREAKER, PARADOX, RUNNER (behavior-gated)).
>
> Три правила:
> 1. **1 из 3 при смерти** (перманентный выбор, GDD §6.5).
> 2. **Апгрейды меняют геймплей, не «+5%»** (GDD §14; GDD §6.5:
>    «Echo Step, Second Chance, Paradox» — примеры канона).
> 3. **NPC-gated = цена** (GDD §6.5/§9): смерть NPC = перманентная
>    мета-цена (наследие недоступно никогда).
>
> MVP-pool = **12** (8 базовых + 4 NPC-gated). (~10–15 смертей в
> MVP-прохождении → игрок получает ~8–12.)

## 0. Как работает «1 из 3 при смерти»

- Игрок умирает → **экран смерти** (3 карточки, 1 выбор):
  - 3 карточки = 3 Inheritances (pool: все не-полученные + 1
    «повтор» (усиление уже полученного, max 2)).
  - Выбор **перманентен** (WORLD_STATE: `inheritance_X = true`).
  - **Не за смертью следует «штраф»** — смерть = «переход», не
    «наказание» (GDD §8: camp = sanctuary, first death ~20 мин,
    window не timer).
- **Скорость получения:** 12 (MVP-pool) / ~10–15 смертей (MVP-
  прохождение) → игрок получает ~8–12 (не все). (Риск: «не всё
  увидеть». Митигция: pool data-driven, «повтор»-усиления.)
- **Экран:** 3 карточки (icon + name + 1 строка описания). **Не
  объясняется** «как работает» — только «что делает» (no exposition).
  Пример: SHARP — *«Выпад бьёт глубже.»* (Не «+15 dmg к U3».)
- **UX-бюджет (GDD §12):** death → respawn **≤ 2 с технически** /
  **≤ 10 с UX** (с death screen: 3 карточки, выбор). Игрок, не
  выбравший за 8 с → «случайный из 3» (world выбирает за вас —
  «мир помнит ваш стиль», ambiguity, не «наказание»).

## 1. 15 Inheritances (полный список)

> Format: NAME — тип геймплея-изменения — условие — «что делает»
> (1 строка, no numbers в UI). Статы — data (`data/inheritances/*.tres`).
> (Канон-примеры GDD §6.5: **Echo Step**, **Second Chance**,
> **Paradox** — в списке ниже.)

### Слой A: базовые (8, MVP pool, без условий — всегда в pool)

| # | Name | Геймплей-изменение | «Что делает» (UI) | Data (статы) |
|---|---|---|---|---|
| 1 | **SHARP** | blade U3 усилен | «Выпад бьёт глубже.» | U3 dmg 30→45 |
| 2 | **FLOW** | blade combo 3→4 | «Четвёртый удар ждёт.» | combo +1 (1.5 с, 20 dmg) |
| 3 | **SLOW BURN** | cannon Break CD | «Два выстрела — чаще.» | Break CD 60→40 с |
| 4 | **QUIET STEP** | cannon не будит | «Выстрел не слышен.» | cannon noise 0 (не будит врагов) |
| 5 | **DEEP SIGHT** | staff Read range | «Вишь дальше.» | Read range 8→12 м |
| 6 | **GENTLE HAND** | staff Soothe time | «Сон дольше.» | Soothe 3→5 с |
| 7 | **ECHO STEP** | dodge → afterimage | «Мир смотрит на ваш след.» | dodge оставляет afterimage 0.5 с; враг «смотрит» на него (stun 0.5 с) |
| 8 | **SECOND CHANCE** | 1 auto-dodge при HP=0/забег | «Мир поймал вас. Один раз.» | при HP=1 hit → auto-dodge (i-frames 0.5 с), 1/забег |

### Слой B: NPC-gated (4, MVP pool; требуют живого NPC, trust≥1)

| # | Name | NPC | «Что делает» (UI) | Data (статы) | Цена (NPC death) |
|---|---|---|---|---|---|
| 9 | **EMBER** | Mara | «Костёр лечит.» | full heal у костра (camp) | лагерь гаснет, respawn → «мёртвое» поле |
| 10 | **THE TRACK** | Orren | «Следы не лгут.» | маркеры последних врагов (2 мин) | башня пуста, следы не исчезают |
| 11 | **THE PAGE** | Nia | «Страница — сразу.» | мгновенное чтение 1 записки (1/забег) | книга открыта на вашей странице |
| 12 | **THE COMPASS** | Cartographer | «Карта знает.» | разметка 1 скрытой локации (1/забег) | карта указывает на несуществующее |

**Механика NPC-gate:**
- NPC-gated Inheritance появляется в pool **только** если NPC жив
  **и** trust≥1 (trust = 2 взаимодействия + 1 «помощь» (scripted)).
- Если NPC мёртв → Inheritance **удаляется из pool навсегда**
  (WORLD_STATE: `npc_X_dead = true` → `inheritance_Y_unavailable`).
- **Цена осознанная:** игрок, убивший NPC, теряет наследие.
  Игра **не подсказывает** (no warning) — но **последствие видимо**
  (NPC-смерть: лагерь гаснет и т. д., CHARACTER_BIBLE §2–6).
- **MVP-баланс:** 4 NPC-gated из 12 (33%) — значимая цена, не
  «всё потеряно».

### Слой C: post-MVP (3; архитектура готова)

| # | Name | Тип | Условие | «Что делает» | Data |
|---|---|---|---|---|---|
| 13 | **BREAKER** | базовый | (pool, post-MVP) | «Ломает двоих.» | staff Disrupt: 1→2 echo |
| 14 | **PARADOX** | базовый | (pool, post-MVP) | «Первый удар — бесплатно.» | первый удар забега: no stamina, +40% dmg |
| 15 | **RUNNER** | **behavior-gated** | `fled > 10` (бегство от 10+ врагов) | «Убегаешь — не догонят.» | враги «отстают» (retreat +2 с) |

**Механика behavior-gate (архитектура, MVP-подготовка):**
- memory_stats (WORLD_STATE_DESIGN §4): `fled`, `kills`, `explored`,
  `notes_written`, `npc_killed`, `child_hit`, `strange_actions`.
- Behavior-gated Inheritance появляется в pool **только** если
  threshold достигнут (data: `data/memory_stats_thresholds.tres`).
- **MVP:** RUNNER не в pool (post-MVP), но **memory_stats считаются**
  (WORLD_STATE: счётчики — MVP, Inheritance — post-MVP).

## 2. Прогресс внутри забега (soft progression)

> Не «meta-progression» — **внутри-забега** (сбрасывается при смерти).
> Правило: мягкий, не «power creep» (GDD §14: не «+5%»).

- **Health:** 3 «костра» (healing item, drop: 1/10 врагов, data).
  (Не «+HP» — «восстановить».)
- **Ammo (cannon):** 5/забег (fixed, WEAPON_DESIGN §2). Reload 1 раз.
- **Stamina:** fixed (не «+stamina» — «управление»).
- **Note slots:** 5 (fixed, WORLD_STATE_DESIGN §5).
- **No XP, no level, no currency.** (GDD §9.)

## 3. Прогресс между забегами (meta-progression)

> Перманентные (WORLD_STATE): Inheritances (15: 12 в MVP-pool + 3 post-MVP), weapons (3+1),
> world_flags, memory_stats, NPC trust, NPC death.

- **Inheritances:** 15 (MVP-pool: 8 базовых + 4 NPC-gated; post-MVP:
  BREAKER, PARADOX, RUNNER). Получение: 1 из 3 при смерти. (Перманентно.)
- **Weapons:** 3 (blade, cannon, staff) + first blade (pre-boss choice).
  (Перманентно, `weapon_X_found`.)
- **World flags:** `run_02_door_open`, `boss_defeated`, `npc_X_dead`,
  `child_hit`, `first_blade_taken`, ... (WORLD_STATE_DESIGN §3.)
- **Memory stats:** `kills`, `fled`, `explored`, `notes_written`,
  `npc_killed`, `child_hit`, `strange_actions` (WORLD_STATE_DESIGN §4).
  (Влияют на NPC dialogue, Mimic spawn, Echo aggression, discoveries,
  epilogues — NARRATIVE_STRUCTURE §7.)

## 4. Trust-система (NPC)

> Гейт для NPC-gated Inheritances (4). Простая: 0–2.

- **Trust 0:** NPC «чужой» (1 реплика, не «даёт»).
- **Trust 1:** NPC «знает» (2+ реплики, **даёт Inheritance**).
  Условие: 2 взаимодействия + 1 «помощь» (scripted: 1 действие,
  data per NPC: Mara — «принести дрова», Orren — «посмотреть с башни»,
  Nia — «прочитать страницу», Cartographer — «сравнить карты»).
- **Trust 2:** NPC «доверяет» (3 реплики, **epilogue** (post-MVP),
  **hint** (1 additional dialogue, «дверь»)).
  Условие: trust 1 + 2 взаимодействия + memory_stats (NPC-специфичное:
  Mara — `notes_written > 2`, Orren — `explored > 30%`, Nia —
  `strange_actions > 3`, Cartographer — `explored > 50%`).
- **Death:** trust reset (NPC мёртв — «не доверяет» — «нет»).
  (Цена: Inheritance недоступно, epilogue недоступно.)

## 5. Правила (все)

1. **Нет валюты.** (GDD §9.) Прогресс = память мира.
2. **Апгрейды меняют геймплей**, не «+5%». (GDD §14.)
3. **1 из 3 при смерти.** (Не «штраф» — «переход».)
4. **NPC-gated = цена.** (Смерть NPC = перманентная потеря.)
5. **Behavior-gated = заслужено.** (Memory_stats, не «kills».)
6. **No XP, no level.** (Прогресс = «что вы приносите», не «сколько
   вы убили».)
7. **Data-driven.** (Все Inheritances, trust, thresholds — Resources.)

## 6. Связи с системами
- **WORLD_STATE_DESIGN** — Inheritances, memory_stats, world_flags,
  trust (WORLD_STATE: перманентные).
- **WEAPON_DESIGN** — Inheritances (SHARP, FLOW, SLOW BURN, ...).
- **ENEMY_DESIGN** — memory_stats → aggression (slayer/runner/explorer).
- **CHARACTER_BIBLE** — NPC trust, NPC-gated Inheritances, death-
  consequences.
- **NARRATIVE_STRUCTURE** — memory_stats → epilogues (post-MVP).

## 7. Open questions (progression)
- Q-P1: 15 Inheritances (12 в MVP-pool) — не «слишком много» ли?
  (Митигция: 12 — верхняя граница диапазона GDD «10–15». Pool
  data-driven, легко «сжать» (MVP: 6 базовых + 4 NPC-gated = 10).
  Решение: MVP — 12, post-MVP — 15.)
- Q-P2: «1 из 3 при смерти» — не «слишком медленно» ли (12 / 10–15
  смертей)? (Митигция: «повтор»-усиления (max 2) → «ощущение
  прогресса». Data: pool 3 = 2 новых + 1 повтор, если новых < 2.)
- Q-P3: NPC-gated «цена» — не «слишком жёстко» ли (убил NPC → потерял
  Inheritance)? (Митигция: игра не подсказывает, что NPC можно убить.
  Но последствие видно (лагерь гаснет). Решение: да, жёстко —
  осознанный выбор, не «наказание».)
