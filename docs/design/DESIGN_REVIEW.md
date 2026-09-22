# AFTER YOU — Design Review (критический self-review)

Версия: 1.0 (Phase 0). Обход: 15 документов (GDD v2.0 + 14 design)
против (а) Story & World Master Prompt, (б) технической архитектуры
Phase 0 (TECHNICAL_DESIGN/ARCHITECTURE/ADR), (в) взаимной
непротиворечивости. Формат: проблема → серьёзность → решение
(исправлено / принято).

**Итог:** найдено 19 проблем (7 critical, 8 major, 4 minor).
Все critical и major — **исправлены** в финальной версии документов.
4 minor — приняты (осознанные риски, в §4).

---

## 1. Critical (нарушали канон Master Prompt или ломали систему)

### C1. Signature moments: два разных «канона»
- **Проблема:** NARRATIVE_STRUCTURE v1 (мой первый черновик) выдвинул
  собственный список S1–S10 («оружие в руке», «Again?», ...),
  противоречащий канону GDD §7 (первый Echo, своя записка, NPC помнит,
  изменившееся место, **свой труп**, **Echo принимает решение**,
  The First жив, Archivist показывает историю, «первый Run
  организовали прошлые версии», финальный выбор) и MVP-подмножеству
  GDD §11 («#1–#6, #7, #10-подготовка»).
- **Риск:** все 14 документов ссылались бы на «S-номера», не
  совпадающие с GDD; MVP-чеклист (Phase 11/17 QA) сломан.
- **Решение (исправлено):** NARRATIVE_STRUCTURE §4 переписан:
  канонический список #1–#10 (GDD §7) + отдельный список
  **K1–K7** (ключевые беаты: оружие, «Again?», столб, имя в книге,
  отражение, «let them go», врата светят). Все 14 документов —
  перессыланы (#1…#10, K1…K7). FIRST_30_MINUTES/FIRST_3_RUNS
  переписаны под канон.

### C2. Ending C: перепутаны финалы A и C
- **Проблема:** в первом черновике NARRATIVE_STRUCTURE «C = игрок
  ломает Архив и уходит, 217 выходят», а «стать хранителем» — в A.
  Канон GDD §6.11: **C — Break the Cycle (true ending: игрок
  становится новой Archivist)**; A — Remember Everything (игрок
  становится **записью**, мир замирает).
- **Риск:** финал (ядро темы GDD §14) — против ТЗ.
- **Решение (исправлено):** NARRATIVE_STRUCTURE §6 переписан:
  A = «стать записью» (мир замирает); B = «отпустить» (мир пустеет);
  **C = стать новой Archivist + переписать правило «помнить ≠
  хранить» (217 «уходят»; исполняется K6 «let them go»)**.
  TECHNICAL_DESIGN §14.2 (EndingState) — обновлён (postgame:
  archive/quiet/living).

### C3. Mimic: «подмена объекта» вместо «зеркала поведения»
- **Проблема:** GDD §6.3: Mimic = **«зеркалит доминирующее поведение
  игрока (dodge/ranged/...)»**. Мой первый черновик сделал Mimic
  «подменой объекта» (ящик/стол/дверь) — это другой архетип
  (generic «scare»-враг), а не «зеркало привычки».
- **Риск:** один из 5 архетипов — против ТЗ; «не-generic enemies»
  (Master Prompt) — сорван.
- **Решение (исправлено):** ENEMY_DESIGN §4 переписан: Mimic =
  зеркало dominant_style (punish over-dodge / keep-distance /
  combo-lock; *«I know how you do it.»*). «Подмена объекта»
  вынесена в **странность-«слом»** (WORLD_BIBLE §3.4, ENEMY_DESIGN
  §4.7: scripted, 1 раз в MVP, не в camp).

### C4. Watcher: потерян «глагол» (наблюдение → якорь → Memory Echo)
- **Проблема:** GDD §6.3: Watcher **«оставляет якорь памяти» →
  Memory Echo**. Черновик: «смотрит и исчезает» — без механики.
- **Риск:** Watcher = «статичный декор», не часть Echo-системы
  (ядро игры).
- **Решение (исправлено):** ENEMY_DESIGN §3: 2 с взаимного взгляда →
  **memory anchor** (WORLD_STATE: anchors[], ≤2/run) → в следующем
  забеге на месте якоря — **Memory Echo** (ECHO_SYSTEM_DESIGN §2).
  TECHNICAL_DESIGN: RunEvent `ANCHOR_SET`, WorldState.anchors[].

### C5. Первый Echo: «бой» вместо «говорит и уходит»
- **Проблема:** GDD §8: RUN 02 ~25–30 мин: первый Echo: *«You're
  early.»* — пауза — *«You usually take longer.»* — **и уходит**.
  Черновик: «боевой Remnant (dmg, death → note)» — момент превращён
  в encounter.
- **Риск:** signature #1 (MVP-критичный) — против канона; «первый
  контакт с прошлым» = бой, а не голос.
- **Решение (исправлено):** FIRST_30_MINUTES B4: Echo **говорит 2
  реплики и уходит** (fade, догнать нельзя); «бой с Remnant» —
  последующие RUN (RUN 03+). ECHO_SYSTEM_DESIGN §3/§8, FIRST_3_RUNS
  §2 — обновлены.

### C6. Тексты столба и двери (GDD §5/§8) — потеряны
- **Проблема:** GDD §5: столб с **«YOU HAVE BEEN HERE BEFORE.»**;
  GDD §8 8:00: дверь **«YOU WILL OPEN THIS AFTER YOU DIE.»**; GDD §8
  2:30: camp-записка **«If you find this, don't trust the version of
  me that comes after.»**. Черновик подставил «свои» тексты.
- **Риск:** «hook» первого запуска — против ТЗ (обязательные тексты).
- **Решение (исправлено):** FIRST_30_MINUTES: A2 (pillar-текст),
  A7 (camp-записка, канон), A16 (door-текст). WORLD_STATE_DESIGN §4
  (world-placed notes: 4 канонических).

### C7. Figure 4:00 — Watcher вместо «фигуры, похожей на Eli»
- **Проблема:** GDD §8 4:00: **«фигура, похожая на Eli, исчезает
  (следы ведут в деревню)»**. Черновик: «Watcher (деревянный, 1
  глаз)» — другая сущность.
- **Риск:** scripted-веха первого часа — против канона.
- **Решение (исправлено):** FIRST_30_MINUTES A10 = «фигура, похожая
  на Eli» (fade 1 с, следы → деревня; пред-echo, seed #1). Watcher
  перенесён в A12 (village, pyre).

---

## 2. Major (противоречия между документами / дыры)

### M1. Inheritances: 3 разных списка (13/14/16)
- **Проблема:** PROGRESSION (13: SHARP…THICK SKIN), WEAPON_DESIGN
  (RIP/HEAVY/BREAK — отсутствовали в PROGRESSION), GDD §6.5 (примеры
  канона: **Echo Step, Second Chance, Paradox**).
- **Решение (исправлено):** PROGRESSION_DESIGN §1 = канон: **15
  Inheritances** (8 базовых + 4 NPC-gated = MVP-pool 12; + 3
  post-MVP: BREAKER, PARADOX, RUNNER). THICK SKIN (числовой +HP) и
  LIGHT FEET (CD-число) удалены (GDD §14: «не +5%»); добавлены
  **ECHO STEP** (afterimage, отвлекающий врагов) и **SECOND CHANCE** (1
  auto-dodge/забег при HP=0 — «мир поймал вас»). WEAPON_DESIGN
  перессылан. WORLD_STATE_DESIGN §7 обновлён.

### M2. Echo-бюджет: «5 per run» против «не каждый Run создаёт полный
Echo»
- **Проблема:** ECHO §7 (1+2+1+1=5) против Q-EC2 («MVP — 3») против
  FIRST_3_RUNS (RUN 03: 2).
- **Решение (исправлено):** единый бюджет (ECHO §0/§7/§8): **MVP:
  1 Passive + 1 Combat + 1 «специальный» (Memory|Forgotten|False) =
  max 3/run**; RUN 1: 0; RUN 02: 2; RUN 03: 2; RUN 04+: до 3;
  post-boss: -2. ADR-014 переписан под бюджет. TECHNICAL_DESIGN §5.

### M3. «Что изменилось» + shimmer (GDD §6.7) — отсутствовал в
WORLD_STATE_DESIGN
- **Проблема:** GDD: «всякая перемена видна за 1 секунду (шиммер +
  сводка «Что изменилось»)» + метрика GDD §12 (≥70% замечено).
  Черновик: только flags.
- **Решение (исправлено):** WORLD_STATE_DESIGN §9: shimmer (1 s,
  layer Memory) + UI «Что изменилось» (≤5 строк, 1 строка = 1 flag,
  no numbers, можно пропустить). ROADMAP Phase 10, TEST_PLAN —
  обновлены.

### M4. Mumia (#5): неопределённый `notes_unwritten`
- **Проблема:** «на мумии — записка, которую вы не дописали» —
  механики «недописанной записки» нет нигде (записки = 5-line pool,
  note stands).
- **Решение (исправлено):** FIRST_3_RUNS D2: в руке мумии — **ваша
  последняя записка** (`notes[]` → last note, перед смертью).
  Механика = существующие notes.

### M5. Кетл Mara: реплика RUN 02 без события RUN 1
- **Проблема:** Mara (RUN 02): *«You left a kettle last time. I
  washed it.»* — но в RUN 1 кетл нигде не показан (дыра: «NPC помнит
  то, чего не было в игре»).
- **Решение (исправлено):** FIRST_30_MINUTES A6: кетл на столе
  (world-объект, interact: взять/поставить); WORLD_BIBLE camp: 2-й
  interaction (кетл).

### M6. Veyra B (Cartographer): RUN 03 против RUN 05
- **Проблема:** CHARACTER_BIBLE: «RUN 03: карта Veyra B»;
  MYSTERY_REVEAL_MAP M4.3: «RUN 05: город + Veyra B».
- **Решение (исправлено):** CHARACTER_BIBLE арка: RUN 03 = «smudge»
  (за вратами — «пятно»); **RUN 05 = город + Veyra B** (M4.3).

### M7. The First: мотивация противоречит reveal
- **Проблема:** «знает Archivist» + «не понимает, что Archivist
  хранит его» — неразборчиво.
- **Решение (исправлено):** CHARACTER_BIBLE §8: знает мир/цикл/
  «Хранящую»; **ошибка** — думает, что он «умер и вернулся»
  («оригинал»), а не «одна из 217 хранимых».

### M8. Twist 2: setup-реплика Child отсутствовала в RUN 05
- **Проблема:** MYSTERY_REVEAL_MAP: setup твиста 2 = Child «Some of
  you stayed» (RUN 05) — в FIRST_3_RUNS RUN 05 её нет.
- **Решение (исправлено):** FIRST_3_RUNS RUN 05: реплика добавлена.

### M9. False Echo: «знает следующий ход» — не реализуемо честно
- **Проблема:** «повторяет движение на 1 beat раньше» звучит как
  чтение мыслей (unfair, против «readability», GDD §6.2).
- **Решение (исправлено):** ECHO §5.2: **прогноз от привычки**
  (dominant_style + последние 3 хода, data `false_predict: 3`) —
  «не читает ум, читает привычку» (как Mimic). Читаемо: телеграф
  0.5 с, «не-свой» ход ломает (stun).

### M10. GDD-ссылки битые (TECH_DESIGN §5, CHARACTER_BIBLE §1.7,
MYSTERY_REVEAL_MAP §moments)
- **Решение (исправлено):** GDD: TECHNICAL_DESIGN §2/§4/§5;
  CHARACTER_BIBLE §1.6; MYSTERY_REVEAL_MAP §3.

### M11. ADR-004/010/011 устарели (12 байт / «арена в роще» / старый
Mimic-Echo)
- **Решение (исправлено):** DECISIONS.md: ADR-004 (14 байт, int32;
  все runs), ADR-010 (Undercroft), ADR-011 (Remnant/Mimic/The First —
  данные), ADR-014 (echo-бюджет). Новые: **ADR-015…020** (v2-канон,
  echo-спектр+ambiguity, Inheritances, memory_stats+notes, boss-
  условие, первый опыт).

### M12. ROADMAP Phases 3–12: старые имена (Stalker/Brute, Heartgrove,
LegacyShop, sword, 2 music tracks)
- **Решение (исправлено):** ROADMAP v0.2: Phase 3 (camp-hub, pillar,
  The Forgotten Forest), 4 (BLADE), 5 (Hollow/Remnant/Watcher/Mimic/
  Forgotten + anchor/mirror/whisper), 6 (Inheritances, no currency,
  NPC-gate), 7 (13 rooms, no-filler), 8 (scripted A1–A17, last_death_
  pos, ≤5 строк), 9 (Passive/Combat/Memory + #1 B4), 10 (notes,
  memory_stats, «Что изменилось», K7), 11 (M1–M4 stages, #1–#7,
  K1–K7, ambiguity-тест), 12 (THE FIRST: pattern-memory, core-hit,
  take/leave, K6→K7), 14 («The Wound» ×5), 18 (Windows primary).

### M13. TECHNICAL_DESIGN: UpgradeData (tier_cost/шарды) против
«no currency»
- **Решение (исправлено):** TECHNICAL_DESIGN v0.2: InheritanceData
  (gate: none/npc/behavior, gameplay-эффект, mvp_pool), WeaponData
  (type staff: 4 действия; cannon: ammo/reload; core_hit), EnemyData
  (memory: anchor/mirror/whisper/mirror_ahead; footprint), RunEvent
  (+NOTE_WRITTEN/ANCHOR_SET/ECHO_TRIGGER/ECHO_NOTE_READ/
  MUMMY_EXAMINED; все runs), Save/WorldState (flags, npcs, notes,
  memory, inheritances, weapons, transform, last_death_pos, anchors),
  UI (DeathScreen: Inheritance 1/3 + «Что изменилось» ≤5; Journal
  «Записки»), audio («The Wound» ×5), §14 (BossData, EndingState).

### M14. TEST_PLAN: 12-байтовая запись, «Upgrades tier», «Echo builder
из RunSummary», «Mystery triggers»
- **Решение (исправлено):** TEST_PLAN v0.2: 14 байт/int32; Inheritance
  (NPC-gate/behavior-gate/UX ≤10 s); notes roundtrip; memory_stats;
  «Что изменилось»; Echo builder (Remnant/Mimic/Watcher/Forgotten);
  ambiguity-тест; Scripted anchors (A1–A17, first death window);
  Boss (pattern-memory, core-hit, take/leave, K7).

---

## 3. Minor (стиль/точность)

### m1. Смешанные латиница/кириллица (бeаты, TЗ, прерывает, Бeат)
- **Решение (исправлено):** полный scan (regex) + fix по всем 15
  документам (0 остатков).

### m2. Версии документов (все 1.0)
- **Решение (исправлено):** обновлённые — 1.1 (NARRATIVE_STRUCTURE,
  WORLD_BIBLE, PROGRESSION, ENEMY_DESIGN, ECHO, WORLD_STATE,
  WEAPON, FIRST_30_MINUTES, FIRST_3_RUNS); новые — 1.0 (BOSS,
  MYSTERY_REVEAL_MAP, DIALOGUE, ENV).

### m3. GDD §15 Q3 → CHARACTER_BIBLE §1.7 (раздела не было)
- **Решение (исправлено):** ссылка → §1.6.

### m4. ENV §6.2 «5 note stands» против WORLD_STATE «4»
- **Решение (исправлено):** WORLD_STATE_DESIGN §4: 4 note stands
  (camp, village, shrine, undercroft); подножие gate = world-placed
  (read-only). notes_max: 4.

---

## 4. Принятые риски (осознанно, не «исправлено»)

| # | Риск | Принятие | Митигция (в документах) |
|---|---|---|---|
| R-A1 | Повтор между RUN (10–15 забегов MVP) | да — roguelite-по определению | «Что изменилось» + shimmer (WORLD_STATE §9); Mimic (стиль); Echo budget; NPC-арки; «окно, не таймер» (tempo за игроком) |
| R-A2 | Blade-комбо (3 удара) — тонко для 2 ч MVP | да — оружие «язык», не DPS | Riposte (timing) + Inheritances (FLOW/ECHO STEP/SECOND CHANCE) + cannon (дистанция) + staff (4 действия) |
| R-A3 | 9 зон — «короткий мир»? | да (GDD §11 жёстко: 8+hub) | плотность (5 NPC, 5 врагов, 3 оружия, 13 комнат, no-filler чек-лист) — WORLD_BIBLE Q-W1 |
| R-A4 | «Вечные сумерки» — однообразно? | да (палитра канон) | memory flurries; слои (5); K7-трансформация (свет теплеет) — WORLD_BIBLE Q-W2 |
| R-A5 | Gate «3 впадины» — не объяснены | да (mystery) | ENV: «форма = вопрос»; объяснение — Act II+ (post-MVP); MVP: «дверь открывается после смерти» (A16) |
| R-A6 | Удар по Child = «наказание»? | нет — «реакция мира» (story) | GDD §6.9: «эксперименты не наказываются» — последствие = **сцена/реплика/изменение мира** (Child реже), не damage/loot-loss (CHARACTER_BIBLE §5) |
| R-A7 | False Echo «предсказывает» — unfair? | нет (habit-прогноз) | M9: не «чтение ума» — «привычка» (3 хода); telegraph 0.5 с; «не-свой» ход = лом (fair, GDD §6.2) |
| R-A8 | 15 Inheritances / ~10–15 смертей — не всё увидеть | да (roguelite) | «повтор»-усиления (max 2) (PROGRESSION §0); pool data-driven (сжатие до 10) |

---

## 5. Проверка «Master Prompt → документы» (traceability)

| Требование (Master Prompt) | Где | Статус |
|---|---|---|
| Мир Veyra; игрок узнаёт правду последними актами | WORLD_BIBLE, GDD §4 | ok |
| Eli ~25–30, пол игрока, рабочее имя | CHARACTER_BIBLE §1 | ok (кандидаты §1.6, GDD §15 Q3) |
| 5 NPC (Mara/Orren/Nia/Child/Cartographer) + арки + цена смерти | CHARACTER_BIBLE §2–6 | ok |
| Archivist — не злодей («Nothing should ever truly disappear») | CHARACTER_BIBLE §7, GDD §6.11 | ok |
| The First — первая версия Eli, живая (reveal) | CHARACTER_BIBLE §8, BOSS_DESIGN, #7 | ok |
| 5 врагов (Hollow/Remnant/Watcher/Mimic/Forgotten) — «симптомы мира» | ENEMY_DESIGN (глаголы по GDD §6.3) | ok |
| 3 оружия (BLADE/HAND CANNON/ECHO STAFF) + THE FIRST BLADE | WEAPON_DESIGN | ok |
| Энддинги A/B/C (C = true, новая Archivist) | NARRATIVE_STRUCTURE §6, GDD §6.11 | ok |
| 4 mystery, 2 твиста, 6 актов, 10 signature moments | NARRATIVE_STRUCTURE, MYSTERY_REVEAL_MAP | ok |
| Скриптовые первые 10 минут (pillar 0:30 … sealed door 8:00) | FIRST_30_MINUTES A1–A17 | ok |
| Первая смерть «Again?» → RUN 02 → дверь | A19/B2 (K2, #4) | ok |
| Первый Echo «You're early. / You usually take longer.» | B4 (#1) | ok |
| Скрытая память (memory_stats) → NPC/Mimic/Echo/discoveries/epilogues | WORLD_STATE_DESIGN §3 | ok |
| Поведение игрока = сюжет | GDD §6.9, WORLD_STATE §3, ENEMY §7 | ok |
| Нет filler (комната ≥1 из 5) | ENV_STORYTELLING §3 (чек-лист), GDD §12 | ok |
| Свобода (не-линейно) | GDD §11/§9, FIRST_3_RUNS (8 зон, любой порядок) | ok |
| Quality bar (3 вопроса) | GDD §13, DIALOGUE §7 (чек-лист), ENV §9 | ok |
| Юмор сухой ≤1/5 | DIALOGUE §1.4 (data: humor flag) | ok |
| 1 идея за взаимодействие, no exposition | DIALOGUE §1.1–§1.3, NARRATIVE §7 | ok |
| Эксперименты не наказываются | GDD §6.9, ENEMY §4.5, CHARACTER_BIBLE §5, R-A6 | ok |
| Апгрейды = геймплей, не +5% | GDD §14, PROGRESSION (15), WEAPON §6.2 | ok |
| 1 биом, 8 локаций + hub, 13 комнат, 5 NPC, 1 босс, Echo, Act I + начало Act II | GDD §11, WORLD_BIBLE, BOSS_DESIGN | ok |
| «все решения соответствуют технической архитектуре» | ADR-001…020; TECHNICAL_DESIGN v0.2; TEST_PLAN v0.2 | ok |

## 6. Открытые вопросы (для владельца; не блокируют)

> **Обновление (2026-09):** все 4 вопроса **решены владельцем** — см.
> GDD §15 (таблица решений): платформа = **Android first** (ADR-021,
> mobile-first; PC-вариант отклонён), локализация = EN-only/ADR-013,
> Eli = финально, The Child = неуязвим. Ниже — исходные формулировки.

1. **Платформы PC-релиза:** Windows first + Linux позже (предложение)
   или одновременно? (GDD §15 Q1; ROADMAP Phase 18.)
2. **Локализация:** EN-only в MVP, RU = data-only (предложение).
   (GDD §15 Q2; ADR-013.)
3. **Имя Eli:** принять как финальное или кандидаты (Wren/Ash/Noor,
   CHARACTER_BIBLE §1.6)? (GDD §15 Q3.)
4. **The Child неуязвим:** подтвердить (альтернатива: убиваемый с
   уникальными последствиями). (GDD §15 Q4.)

## 7. Вердикт

Дизайн-фаза **закрыта**: 15 документов согласованы между собой и с
Master Prompt; critical/major проблемы исправлены; остаточные риски —
приняты и задокументированы (§4); техническая архитектура Phase 0 —
соблюдена (ADR-001…020). **Программирование (Phase 1) может
начинаться** — по ROADMAP v0.2.
