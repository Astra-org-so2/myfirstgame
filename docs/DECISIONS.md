# AFTER YOU — Decision Log (ADR)

Формат: ID / статус / контекст / решение / последствия.
Статусы: PROPOSED → ACCEPTED → (SUPERSEDED BY).

---

## ADR-001. Версия движка: Godot 4.7.2-stable
Статус: ACCEPTED
Контекст: владелец требует стабильную 4.x, предпочтительно 4.7.2.
Решение: **Godot 4.7.2-stable** (подтверждено: релиз существует,
официальный linux x86_64 zip: sha256
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`,
77 860 424 байт, релиз `godotengine/godot-builds` tag 4.7.2-stable).
Последствия: project.godot features = "4.7"; экспорт-шаблоны 4.7.2 —
на ПК владельца (ADR-012).

## ADR-002. Движок в песочнице: Godot 4.7.2 wasm на Node (headless rig)
Статус: ACCEPTED
Контекст: песочница без GPU/X, без apt, с ограниченной сетью
(github/pypi/npm). Официальный бинарник Godot недоступен
(release-assets и godotengine.org заблокированы; GitHub Actions отключён
для репозитория; gitlab/bitbucket/codeberg/docker недоступны;
сборка из исходников невозможна — нет dev-библиотек и apt).
Решение: headless-тест-риг на **npm `@ringozz/godot` 4.7.2-626**
(wasm32-сборка Godot 4.7.2 + emnapi Node bindings): `tools/godot-node/`
(bootstrap: npm install + 2 патча + esbuild-бандлы; harness: DOM-shim
(jsdom) + boot + stage проекта в MEMFS + frame pump
`GodotInstance.iteration()` по jsdom-RAF ~60fps + exit code).
**Проверено (spike, Phase 0):** запуск 0.5 c; сцена+GDScript+ресурсы+
сигналы+таймеры+60Гц-тики+math+File I/O+quit(rc).
**Ограничения (проверены):** 3D-физика = Dummy server (гравитация/
коллизии нет); часть нав-класса отсутствует; рендер/аудио-вывод нет
(ожидаемо).
Последствия:
- вся НЕ-физическая логика тестируется в песочнице автоматически;
- movement-логика — через `MockMovementPort` (тест-двойник; production-
  код — `EngineMovementPort`);
- navmesh/pathfinding-логика — чистый код с injectable source;
- physics-feel, рендер, аудио — ручное QA/замер на ПК владельца
  (честно задокументировано, не «fake tested»);
- тот же риг может гонять владелец на ПК (но с тем же wasm-билдом —
  physics-feel всё равно только native).

## ADR-003. Room-варианты с общими doorway-якорями
Статус: ACCEPTED
Контекст: ghost воспроизводит прошлый забег; при процедурной перестановке
комнат пути ghost могли бы вести «сквозь стены» в новом layout.
Решение: геометрия-«якоря» стабильна: (1) локация = набор hand-authored
room-вариантов; (2) у всех вариантов одной комнаты doorway-якоря
(позиции/направления дверей) ИДЕНТИЧНЫ; (3) RunEvent хранит room-local
координаты; (4) ghost-реплей мапит room_id(лога) → room-вариант
текущего seed: совпадает — прямая проекция на navmesh, не совпадает —
переход к ближайшему совместимому keyframe (dissolve-визуал).
Последствия: «процедурность» = выбор вариантов/связей/спавнов/лута
(не free-form geometry) — осознанный trade-off, сохраняющий replay-
консистентность и снижающий риск «невозможных раскладок».

## ADR-004. Event-based run recording (не video)
Статус: ACCEPTED
Контекст: ghost/echo требуют данных прошлых забегов; video-запись —
дорогая, огромная, хрупкая.
Решение: запись только значимых событий (RunEvent, 14-байтная запись,
int32-время, ≤4096 на забег, sampling-политика), полные логи — все
забеги (MVP: ~150 КБ), старые — RunSummary (post-MVP),
остальные — RunSummary. Позиции — room-local, квантованные (1cm, 0.1s).
Последствия: компактность (забег ~50KB), воспроизводимость по данным;
ghost = интерполяция между keyframes (TECH_DESIGN §5), не frame-
replay.

## ADR-005. Text-first art policy (prototype-арт кодом, осознанный)
Статус: ACCEPTED
Контекст: в песочнице нет редактора Godot → импорт бинарных ассетов
(textures→.ctex, gltf→.scn) невозможен; при этом проект должен
развиваться и тестироваться.
Решение: MVP-визуал строится на примитив-моделях + `.tres`-материалах +
генерируемых `.ctex`/`.strm` (tools/utils). Каждый визуальный элемент
помечен статусом (ASSET_STATUS.md): `final` (генеративный, осознанный
стилистически) или `prototype` (заглушка). Замена на импортированные
CC0-ассеты — инкрементальна через SceneRef (model_scene-поля в data).
Финальный визуальный pass (Phase 13) закрывает ВСЕ `prototype`-элементы.
Последствия: ранние скриншоты — стилизованные примитивы (осознанно);
лицензионно чистый путь; ноль блокировок из-за недоступности источников.

## ADR-006. Asset acquisition в условиях сетевой песочницы
Статус: ACCEPTED
Контекст: источники ассетов (Poly Haven, Quaternius, Kenney, Freesound,
Pixabay, OpenGameArt) из песочницы недоступны (проверено).
Решение: приоритет: (1) процедурный/текстовый ассет (ADR-005); (2)
GitHub-зеркала CC0-пакетов (проверять LICENSE в репо); (3) загрузка
владельцем в `assets/inbox/` + запись лицензии; (4) пересмотр
потребности. Массовых «ассет-покупок» нет (no asset spam).
Последствия: часть финального арта готовится владельцем (явно
запланировано в ROADMAP: Phase 2 персонаж, Phase 3 environment,
Phase 13-14 финалы); лицензионная запись обязательна (ASSET_GUIDE §6).

## ADR-007. Тест-фреймворк: собственный мини-раннер
Статус: ACCEPTED
Контекст: GUT/gdUnit — сторонние плагины (версионная привязка,
зависимости, «чужая» архитектура); нам нужен минимум + полный контроль
над headless-ригом.
Решение: мини-раннер в `tests/headless/` (TestRegistry + assert-хелперы,
~150 строк), работает в wasm-риге (TESTS_DONE-маркер + exit code).
Последствия: ноль зависимостей; API-поверхность аскетична (unit +
integration достаточно); при росте — расширяем, не меняем.

## ADR-008. Save format: versioned JSON + CRC32 + atomic rename
Статус: ACCEPTED
Контекст: требования — атомарность-ish, устойчивость к повреждению,
версии, миграции, safe defaults, graceful recovery.
Решение: JSON (читаем для отладки/миграции), поле version, CRC32,
запись tmp+rename, .bak-копия при каждой успешной записи, миграции —
цепочка чистых функций, recovery-каскад (→ .bak → fresh + log + UI).
Последствия: простота + отлаживаемость; размер ≤5MB (cap); JSON-
парсинг на 5MB — миллисекунды (не bottleneck).

## ADR-009. Autoload-дисциплина: ровно 9 (список фиксирован)
Статус: ACCEPTED
Контекст: «глобальные singleton-зависимости без необходимости» —
запрещено (по задаче).
Решение: полный список autoload'ов — ARCHITECTURE §6 (EventBus,
SaveManager, RunManager, WorldDirector, GhostDirector, UIManager,
AudioManager, QualityManager, DebugTools[release-off]). Новый autoload
= новый ADR.
Последствия: проверяемость зависимостей; остальное — composition.

## ADR-010. Размер мира и длина забега
Статус: ACCEPTED
Контекст: «маленький, но отполированный» — жёсткие числовые рамки.
Решение: 1 биом (The Forgotten Forest); 9 зон (хаб-camp + 8); boss-
арена = **Undercroft** (нижний уровень шахты, не «роща» — правка по
GDD v2.0); 2–3 room-варианта на локацию; забег до boss 15–25 мин
(обычно RUN 05–07 — событийное условие, BOSS_DESIGN §2); полный
обход 40–60 мин; ≤12 активных врагов в локации; ≤6 локальных
источников света (High).
Последствия: бюджет-совместимо (TECH_DESIGN §12); контент-план
ограничен (качественный, не «ещё один»).

## ADR-011. Echo/Mimic зависят от run-данных (данные > хардкод)
Статус: ACCEPTED
Контекст: ключевые враги темы «мир помнит» — из прошлых забегов.
Решение (GDD v2.0): **Remnant** (Combat Echo) строится из run-данных
(RunEvent/RunSummary: путь, оружие, стиль); **Mimic** зеркалит
доминирующее поведение игрока (memory_stats.dominant_style —
dodge/ranged/melee); **The First** бьёт паттернами на основе атак
игрока (паттерн-память, BOSS_DESIGN §3.2). Пустая история →
осознанный default-вариант (помечен, не fake).
Последствия: эти враги неразделимы с run-системой (зависимость
enemies→run через данные, не код — ARCHITECTURE §7).

## ADR-012. Release-экспорт выполняется на ПК владельца
Статус: ACCEPTED
Контекст: export templates (~1GB) недоступны в песочнице (см. ADR-002);
wasm-риг — не средство экспорта.
Решение: песочница готовит всё (project, export_presets.cfg,
docs/RELEASE_BUILD.md с пошаговой инструкцией: шаблон 4.7.2,
feature Release, иконка, версия); владелец выполняет экспорт и
проверяет по чек-листу Phase 18.
Последствия: последний шаг релиза — ручной (задокументирован),
всё до него — автоматизировано/проверено.

## ADR-013. Язык: EN primary, data-localizable
Статус: PROPOSED (Q3 GDD)
Решение: тексты — в DialogueData/UpgradeData (data-driven), EN —
активный; RU-поддержка = добавление перевода в те же ресурсы (без
кода). MVP — EN only.
Последствия: нет i18n-сложности в MVP; локализация — data-only.

## ADR-014. Echo-бюджет: 1 Passive + 1 Combat + 1 «специальный» (MVP)
Статус: ACCEPTED (GDD v2.0; расширяет PROPOSED «только последняя жизнь»)
Контекст: «не каждый Run создаёт полный Echo» (GDD v2.0 §15 Q5);
Echo — спектр из 5 типов (ECHO_SYSTEM_DESIGN).
Решение: per run (MVP): 1 Passive (replay последнего забега) + 1
Combat (Remnant, из run-данных) + 1 «специальный» (Memory|Forgotten|
False) = max 3. RUN 1: 0; RUN 02: 2; RUN 03: 2; RUN 04+: до 3.
Post-boss: -2 («тише»). До 5 per run — post-MVP. GhostDirector
способен на несколько ghost (список replay-таймлайнов).
Последствия: проще/дешевле; эмоция «мои прошлые версии» — через
бюджет + следы + «Что изменилось»; расширение без переписывания.

---

## ADR-015. Креативное направление v2 (Story & World Master Prompt)
Статус: ACCEPTED
Контекст: после технического Phase 0 владелец поставил полное
креативное направление (мир Veyra, Eli, 5 NPC, Archivist, 5
архетипов врагов, 3 архетипа оружия, 6 актов, 4 mystery, 2 твиста,
3 финала). Старый v0.1-креатив (Stalker/Brute/Watcher/Mimic/Echo,
Keeper, longsword/dagger/axe, M1–M5, 2 финала) — SUPERSEDED.
Решение: канон v2 зафиксирован в `docs/GDD.md` v2.0 + 14
дизайн-документах `docs/design/*` (GDD §1–§15). Техническая
архитектура Phase 0 (autoloads, RunEvent, save, риг) — без изменений.
Последствия: весь контент-план (ROADMAP Phases 3–12) — по v2;
старые имена врагов/оружия в TEST_PLAN — обновлены.

## ADR-016. Echo — спектр (5 типов) + ambiguity-правило
Статус: ACCEPTED
Контекст: ядро игры — «мир помнит»; Echo = «запись» или «живой»?
Решение: 5 типов: Passive (ghost replay) / Combat (Remnant, из
run-данных) / Memory (scripted reconstruction; в т.ч. из Watcher
anchor) / Corrupted (Forgotten; шепчет фразы из истории игрока) /
False (mirror-ahead: повторяет движение игрока на 1 beat раньше).
**Ambiguity-правило:** игра НИКОГДА не отвечает «запись или живой»
(до Act II). (ECHO_SYSTEM_DESIGN §6; MYSTERY_REVEAL_MAP §4.5.)
Последствия: все Echo-реплики проходят DIALOGUE_GUIDELINES §7;
твист 1 («все — настоящие») — только Act II (post-MVP).

## ADR-017. Прогрессия: нет валюты; 15 Inheritances (12 в MVP)
Статус: ACCEPTED
Контекст: «апгрейды должны менять геймплей, не +5%»; «NPC death =
permanent meta cost».
Решение: 15 Inheritances: 8 базовых + 4 NPC-gated (MVP-pool = 12) +
3 post-MVP (BREAKER, PARADOX, RUNNER (behavior-gated)). 1 из 3 при
смерти (UX ≤ 10 s). 4 NPC-gated: смерть NPC = наследие недоступно
навсегда. (PROGRESSION_DESIGN §1.)
Последствия: нет currency-системы (упрощение save/UI); цена NPC-
смерти — осознанная и видимая (WORLD_STATE_DESIGN §5).

## ADR-018. memory_stats (скрытые счётчики) + записки игрока
Статус: ACCEPTED
Контекст: «поведение игрока = сюжет» (GDD v2.0 §6.9); «игрок
пишет записки — мир их хранит».
Решение: 10 скрытых счётчиков (kills, fled, explored, notes_written,
dominant_style, npc_killed, child_hit, strange_actions, deaths,
runs_completed) — игрок не видит числа, видит последствия (NPC-
реплики, Mimic, Echo aggression, discoveries). Записки: 4 note
stands, 5-line pool (no free text), читаются в следующем забеге.
(WORLD_STATE_DESIGN §3–§4.)
Последствия: data-driven (thresholds в Resources); «странное
поведение» — не наказание, а сцена/секрет/клише (GDD §6.9).

## ADR-019. Boss: событийное условие + арена Undercroft
Статус: ACCEPTED
Контекст: «окно, не таймер» (GDD v2.0 §8); ADR-010 (арена) требует
правки.
Решение: дверь Undercroft открывается, когда: (1) mine_level_3_
explored; (2) deaths >= 3; (3) first_traces_seen (RUN 05+: следы +
фонарь The First). → обычно RUN 05–07. Арена = Undercroft (нижний
уровень шахты; BOSS_DESIGN §1). FIRST BLADE — take/leave choice
(WEAPON_DESIGN §4.3).
Последствия: tempo — за игроком (не таймером); ADR-010 обновлён.

## ADR-020. Первый опыт: скрипт A1–A19/B1–B6 + 10 signature (канон)
Статус: ACCEPTED
Контекст: GDD v2.0 §8 (фиксированные вехи: 0:30 pillar, 0:45 blade,
1:30 Hollow, 2:30 camp+note, 4:00 figure, 6:00 combat, 8:00 sealed
door; first death ~20 мин; RUN 02 ~25–30 мин первый Echo).
Решение: детальный скрипт — FIRST_30_MINUTES (якоря A1–A19, B1–B6);
10 signature moments (канон, GDD §7) + 7 ключевых беатов K1–K7 —
NARRATIVE_STRUCTURE §4; карта — MYSTERY_REVEAL_MAP §3. First death
= окно ~20 мин (window, не таймер); camp = sanctuary.
Последствия: Phase 8 (run system) + Phase 11 (mystery) валидируют
вехи по FIRST_30_MINUTES; QA-маршрут Phase 17 — по FIRST_3_RUNS.

---

## Реестр рисков (Phase 0, живые)

| # | Риск | Влияние | Митигция |
|---|---|---|---|
| R1 | Финальный rigged-персонаж CC0 с полным набором анимаций не найден | Phase 2/13 | ASSET_GUIDE §4 fallback + владелец; персонаж-заглушка не блокирует код |
| R2 | «Что изменилось» не замечается игроком (механика памяти не считывается) | Ядро retention | Memory-manifest UI + шиммер-маркеры + qa-метрика (GDD §6) |
| R3 | Ghost-визуал «пластиковый» на примитивах | Ощущение identity | Phase 13 — финальный shader-пасс; бюджет VFX зафиксирован |
| R4 | Бой «ватный» (feel не добивается) | Ядро геймплея | Phase 4 exit-criteria = feel-чек-лист; итерации ДО Phase 5 |
| R5 | Тест-риг: ограничения wasm-сборки (физика/нав) расширяются/сужаются в других версиях | Тест-инфра | Пинг версии 4.7.2-626 (package.json); smoke-тест рига в run_tests.sh |
| R6 | Владелец недоступен на ручной QA-шагах | Скорость | Все ручные шаги — компактные чек-листы с конкретными командами |
| R7 | Мистика «объясняется слишком рано» | Нарратив | Mystery-прогресс по стадиям (2–3 фрагмента), qa-маршрут Phase 11 |
