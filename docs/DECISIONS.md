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

## ADR-012. Release-экспорт (Android) выполняется на железе владельца
Статус: ACCEPTED (updated: Android first, ADR-021)
Контекст: Android-тулчейн (export templates, Android SDK, gradle/AAPT2,
JDK) недоступен/не гарантирован в песочнице (см. ADR-002, §15.5);
wasm-риг — не средство экспорта.
Решение: песочница готовит всё (project, export_presets.cfg с Android
preset, docs/RELEASE_BUILD.md с пошаговой инструкцией: шаблон 4.7.2,
Android export (API 26+, landscape), feature Release, иконка, версия,
signing via env); владелец выполняет экспорт APK и ADB-QA и проверяет
по чек-листу Phase 18.
Последствия: последний шаг релиза (сбор APK + запуск на устройстве) —
ручной (задокументирован); всё до него — автоматизировано/проверено.

## ADR-013. Язык: EN primary, data-localizable
Статус: ACCEPTED (решение владельца, GDD §15 Q2)
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

## ADR-021. Платформа: Android first (mobile-first для всех решений)
Статус: ACCEPTED (решение владельца, GDD §15 Q1; 2026-09)
Контекст: владелец скорректировал первоначальный «PC first»:
«целевая платформа у нас мобильная… Не надо делать PC-версию первой,
даже как основной target. Можно использовать PC для удобства разработки
и тестирования, но все технические решения должны приниматься с позиции:
«сможет ли это нормально работать на Android-смартфоне?»». 3D +
динамический свет + VFX + AI + Echo-система легко перегружают
мобильный GPU/CPU, если архитектура не мобильная с первого дня.
Решение:
- **Primary: Android.** Secondary: iOS позже (если архитектура/бюджет
  позволяют). PC = только dev/QA-удобство (не target).
- **Renderer: Forward+ (Vulkan)**, mobile-first (ASTC-текстуры,
  texture-atlas, локальные источники света ≤6/preset, no heavy post,
  draw calls ≤150/локацию). Mobile renderer = опция/fallback для очень
  слабых устройств; фиксация «Forward+ vs Mobile» — замерами Phase 16.
- **Минимальная конфигурация (MVP):** Android 8.0 (API 26), GPU
  Adreno 6xx / Mali G72+ (современные; точный список — Phase 16), RAM
  3 GB (низшая граница Mid), APK ≤ ~2 GB.
- **Performance-политика (бюджеты — TECHNICAL_DESIGN §12):** 60 fps
  (Med/High) на mid-range (SD 7-класс, 1080×2400 — смартфон владельца);
  30 fps floor (Low, 720p) на low-end (SD 6xx-класс); frame P95 ≤22/45 ms;
  particles ≤200/100; RAM ≤1.2/1.0 GB; tex ≤256/192 MB; cold start
  ≤8/10 c; save ≤50/80 ms; thermal 30-мин сессия без drop ниже
  60/55/30 fps.
- **Тач-контролы первичны** (TECHNICAL_DESIGN §7): вирт. джойстик +
  кнопки + drag-камера; layout — data (`data/ui/touch_layout.tres`).
  Keyboard/mouse + gamepad = dev/QA.
- **UI:** landscape, aspect 16:9–20:9 + safe area, thumb-зоны.
- **Экспорт:** Android release (ADR-012); save — `user://` (внутреннее
  хранилище), atomic write обязателен (low-memory/сбои питания).
- **Auto-quality-drop: post-MVP** (MVP — preset по выбору +
  рекомендация по GPU-name на старте).
Последствия: все фазы ROADMAP с пометкой mobile (Phase 1/2/13/16/17/18);
замеры Performance — на референс-устройстве (ADR-012, R9); риски R8/R9;
iOS-совместимость — держим (общая архитектура), отдельный pass — post-MVP.

## ADR-022. Ограничения wasm-рига: кросс-файл-ссылки через preload-константы
Статус: ACCEPTED (вынуждено сборкой рига, 2026-09, Phase 2)
Контекст: headless-риг (Godot 4.7.2-stable wasm на Node, ADR-018/ADR-002)
не регистрирует кастомные `class_name` в runtime: любой кросс-файл
ссылочный паттерн, использующий имя класса, падает на парсе. Проверено
5 независимыми экспериментами (отдельные/парные preload, ordered
`load()` в `_ready`, `ClassA.new()` после успешного `load()`,
`extends preload(...)`):
1. `class_name` не становится глобальным идентификатором —
   `Parse Error: Identifier "ClassA" not declared`;
2. `extends` принимает только имя встроенного/зарегистрированного класса
   (`Expected superclass name after "extends"`) — кросс-файл-наследование
   скриптов невозможно вообще;
3. членов built-in enum `JoyAxis` в runtime нет (`Cannot find member
   "RIGHT_X" in base "JoyAxis"`) — частичная регистрация глобалов;
4. **`Callable.call()` на Callable, созданном в другом скрипте, — FATAL-
   crash движка** (cowdata index -1); создание + вызов в пределах одного
   скрипта — работает;
5. **скрипт-метод с именем built-in метода базового класса, вызываемый
   кросс-скрипт — FATAL** (репрод: `CameraRig.rotate(Vector2)` тень
   `Node3D.rotate(axis, angle)`); переименование — лечит (в проекте:
   `rotate` → `orbit`);
6. отсутствует часть «float-математики» и Node3D-API: `sinf/cosf/tanf/
   atanf/expf` (→ использовать `sin/cos/tan/atan/exp`),
   `Node3D.get_global_origin()` (→ `global_position`), `modulate` у
   Node3D отсутствует (CanvasItem-only; 3D-flash — через albedo
   StandardMaterial3D мешей);
7. работают: обычные кросс-файл вызовы методов, чтение/запись свойств
   (включая @export) кросс-скрипт, передача объектов/Vector2, `is`/`==`
   на preload-скрипты, static через константу и инстанс, сигналы
   (connect/call в пределах скрипта);
8. **движок стартует в PAUSED-состоянии**: `_process`/`_physics_process`
   не вызываются вообще, пока не вызван `GodotInstance.resume()`
   (таймеры при этом работают — маскирует проблему); после `resume()` —
   стабильные 60 Hz в pump; harness.mjs вызывает `resume()` перед
   pump (проверено счётчиками кадров);
9. **`Input.parse_input_event` не питает action-state**
   (`is_action_pressed` остаётся false) — тестовый ввод =
   `Input.action_press/release` (синхронно, проверено);
10. **`is_action_just_pressed` сбрасывается только реальными frame
    boundaries** (release/flush его не чистят) → production-код
    использует held-edge (нажат в этом тике и не в прошлом) —
    эквивалентно в движке, устойчиво к пропущенным кадрам и работает
    в риге;
11. **время тестов не доверять engine-frame'ам**: часть «игрового
    времени» может протечь во время boot, до старта pump (ноды тогда
    молчат) → integration-тесты ведут детерминированную ручную
    «часовую стрелку»: `node._physics_process(DT)`, `DT = 1/60`
    (tests/integration/player_scene_test.gd);
12. **частичная регистрация геометрии** (Phase 3): `ConeMesh`,
    `NavMeshData`/`NavMeshInstance3D` отсутствуют в wasm-сборке
    (проверено `strings` по .wasm + runtime: «Cannot get class»).
    `BoxMesh/CylinderMesh/SphereMesh/CapsuleMesh` — работают.
    Конус = `CylinderMesh(radial_segments=3, top_radius≈0)`.
    **`.ts`-декларации `@ringozz/godot/gen` описывают полный API, а не
    то, что зарегистрировано в этой сборке** — источник правды =
    сам .wasm + прогон;
13. **`MultiMesh.transform_format` по умолчанию `TRANSFORM_2D`** —
    3D-инстансы требуют `transform_format = 1` (TRANSFORM_3D);
    enum-константы классов не всегда связаны в runtime → именованные
    int-константы;
14. **конструкторы `Basis` частичные**: работает только axes-конструктор
    `Basis(Vector3, Vector3, Vector3)`; `Basis(Vector3)` (scale) и
    `Basis(float, float, float)` (диагональ) — «No constructor matches».
    `Transform3D(Basis, Vector3)` — работает;
15. **`PackedVector3Array`** — без varargs-конструктора из floats (только
    из массива `Vector3`); **`Node.find_children`** — иная сигнатура
    (arg 2 — String); для поиска по имени — `find_child(String, bool,
    bool)` (работает) или явные имена нод;
16. **`class_name` с именем autoload — parse error**
    («Class "X" hides an autoload singleton») — autoload-скрипты
    объявляются без class_name (доступ = `/root/X`);
17. **GDScript-lambda захватывает value-типы по КОПИИ** (float/int/
    bool): запись в переменную из lambda снаружи не видна;
    reference-типы (Array/объекты) — по ссылке (мутация видна).
    Pattern «lambda возвращает значение» не работает — мутировать
    общий объект или читать состояние извне;
18. **аудио в риге — dummy-драйвер**: `AudioStreamPlayer.play()`
    работает, но печатает WARNING «driver doesn't support sample
    playback» (не ошибка, звук не слышен) — тесты SFX проверяют
    роутинг/генерацию, не саму playback.
Сборка (custom build 4.7.2) — не наш артефакт; пересборка/апгрейд рига
вне фазы (R5).
Решение (единственный рабочий контракт кросс-файл-ссылок в проекте):
- `const _X = preload("res://...")` — для ТИПА, конструктора
  (`_X.new()`), static (`_X.stat()`), enum (`_X.State.MEMBER`) и проверки
  (`n is _X`, `n.get_script() == _X`);
- `extends` — только встроенные классы Godot;
- общий enum/константы — отдельный dependency-free файл
  (`player_state.gd`), читаемый preload-константой;
- **pull по Callable между скриптами запрещён** — только push
  (источник сам вызывает метод получателя) или общий holder;
  (JoystickProvider = push: джойстик шлёт вектор, игрок читает);
- built-in enum'ы с отсутствующими членами — именованные int-константы
  (`AXIS_RIGHT_X = 2`);
- математика — `sin/cos/tan/atan/exp` (не `sinf/cosf/...`), глоб. позиция
  — `global_position` (не `get_global_origin()`);
- имена методов: без пересечения с built-in методами базового класса
  (тень `Node3D.rotate` = FATAL кросс-скрипт-вызова);
- геометрия — только проверенно-присутствующие классы
  (`BoxMesh/CylinderMesh/SphereMesh/CapsuleMesh`); конус = 3-ребёрный
  цилиндр; `MultiMesh` — всегда `transform_format = 1`; `Basis` —
  axes-конструктор;
- `.tscn`: NodePath-свойства на сценарные типы не используются
  (lookup через `$` в `_ready`); ресурсы (`.tres`) — через ext_resource.
Контракт тестов в риге (см. ограничения 8–11): ввод =
`Input.action_press/release`; время = ручной `node._physics_process(DT)`
с фиксированным `DT` (детерминированная «часовая стрелка», без
`await create_timer`); node-колбэки — только после `resume()` harness'а.
Конвенция распространяется на весь проект (не только тесты): в реальном
Godot-редакторе `class_name`-декларации в файлах оставляются (они
инертны в риге, а в редакторе дают автодополнение и рефакторинг).
Последствия: ARCHITECTURE §3.4 (один `MovementPort` с ENGINE/MOCK
бэкендами вместо иерархии портов); все Phase-2+ скрипты пишутся по
контракту; при смене/апгрейде рига (R5) контракт можно упростить —
проверяется smoke-тестом.

---

## ADR-023. Бой без Area3D: hitbox = sector-sampling, hit-stop = delta-scaler, EventBus с Phase 4
Статус: ACCEPTED (Phase 4, 2026-09)
Контекст: ARCHITECTURE §5 описывает hitbox как Area3D на layer
`player_hitbox`, включаемом на кадр удара. В wasm-риге нет 3D-физики
(ADR-002/ADR-022) — Area3D-мониторинг не работает, и тесты боя
невозможны. Плюс мобайл-бюджет (ADR-021): Area3D-поиск каждый активный
кадр — лишняя физ-работа на SD7.
Решение (реализовано в Phase 4, `scripts/gameplay/combat/`):
1. **Hitbox = sector-sampling** (чистая математика): на каждом активном
   тике свинга WeaponController проверяет зарегистрированные в
   DamageResolver цели: горизонтальное расстояние ≤ range И угол между
   facing и направлением на цель ≤ arc/2. Цель бьётся ОДИН раз за
   свинг (per-swing hit set). Детерминировано, тестировано в риге
   (37 integration-проверок), без Area3D.
   Layers §5 остаются зарезервированными (projectiles Phase 6+,
   interactables Phase 7+) — для melee hitbox Area3D не используется.
2. **HitStop = delta-scaler, не SceneTree time scaling**: узел сцены
   (main) гонит игрока с `hitstop.update(real_delta)` (0.0 пока
   заморожено); движение + оружие замораживаются вместе, камера живёт
   (shake во время hit-stop = осознанный feel). Не трогает pump рига
   (ADR-022: engine-время тестам не доверяется). Длительности —
   данные оружия (blade: 0.05 s hit / 0.1 s kill — baseline, тюнинг
   по feel-чек-листу).
3. **EventBus-autoload создан в Phase 4** (ADR-009: autoload
   появляется с фазой своей системы): сигналы `player_died /
   player_spawned / target_killed` (только built-in типы параметров —
   ADR-022). Run/World/Audio/UI-системы (Phase 8+) подписываются
   сюда; DamageResolver эмитит `target_killed` в EventBus
   толерантно (get_node_or_null — юнит-тесты без autoload).
4. **Состояние оружия сбрасывается на respawn** (weapon_logic.reset):
   combo-окно/рипост-CD не утекают через смерть (поймано
   integration-тестом: combo-окно из сценария N влияло на сценарий
   N+1).
5. **SFX Phase 4 = процедурные заглушки (prototype-статус)** по
   ROADMAP: AudioStreamWAV генерируется из математики (SfxLibrary:
   swing/hit/riposte/hurt, детерминированные сиды, unit-тесты на
   байты), проигрываются пулом из 3 AudioStreamPlayer (SfxBus).
   Финальный аудио-пайплайн (buses, settings) — AudioManager, Phase 14.
Последствия: damage-поток — единственный через DamageResolver
(ARCHITECTURE §3.2); player-сцена получает Weapon-узел (bind из main);
main-сцена владеет боевыми сервисами (состав, не autoload'ы);
test-мишени — только в tests/ (не в игре, по ROADMAP Phase 4).

---

## ADR-024 — Враги: code-built визуал + staggered-бюджет в директоре (Phase 5)

**Статус:** принято (Phase 5, 2026-09-15).

**Контекст.** Phase 5 = 5 архетипов (11 вариантов EnemyData: 3+2+1+3+2,
ENEMY_DESIGN v2). Ограничения: (а) AI-бюджет ≤4 ms/кадр на устройстве
(TECHNICAL_DESIGN §AI) — 5+ врагов × полноценный 60 Hz-тик не
влезает на референс-железе (Adreno); (б) данные-driven — новый враг =
новый .tres, без переписывания кода; (в) риг (ADR-022) без рендера —
визуал проверяется только в редакторе/на устройстве, значит код
визуала должен быть простым и детерминированным.

**Решение.**
1. **Сцены-врагов нет.** `scenes/enemies/` — пустой каталог;
   `EnemyController._build_visual()` собирает примитив (капсула +
   StandardMaterial3D по `EnemyData.visual_color/scale` + Label3D
   реплики) в коде. Причина: у 11 вариантов визуал = параметры
   (цвет/размер/реплика), а не уникальная геометрия — сцена на
   вариант дала бы 11 почти пустых .tscn и второй источник правды.
   Примитивы = нулевой лицензионный риск (ASSET_LICENSES: нет
   ассетов); финальный облик — Phase 13 (замена примитива на
   rigged-модель, точка входа = `_build_visual`).
2. **Staggered-бюджет владеет `EnemyDirector`** (не враги): каждый
   враг тикает в своём `update_hz` (demo — 10 Hz) и за один тик
   продвигает логику на **фактически прошедшее игровое время**
   (полная скорость, а не 1/hz — ранний баг: логика шла в 1/6
   реального времени). Расписание якорится на
   `phase + count*period` (без дрейфа: `next += period`
   накапливает квантование кадров и занижает hz — поймано
   integration-тестом). Стаггер: слот i стартует со сдвигом
   i/N периода — тики разнесены по кадрам (integration: ≤2 тика/
   кадр; в демо — 1). Итог: AI-стоимость плоская и предсказуемая —
   5 врагов ≈ 5 логик-тиков, распределённых по 30 кадрам.
3. **Логика — чистый `EnemyLogic` (не Node)**: FSM + тайминги +
   эвент-поток, без сцены/визуала — юнитится напрямую (65
   проверок: переходы, инварианты архетипов, float-границы EPS).
   Поток: `Director.update(dt)` → `Controller.tick(step)` →
   `Logic.update → events` → Controller (визуал/атаки/решалка) →
   Director (despawn/anchor/MemoryStats) → EventBus (`enemy_killed`).
4. **Спавн-таблица = ресурс** `SpawnTable` (.tres,
   `Array[SpawnEntry]([SubResource…])` — единственная рабочая форма
   массива ресурсов в .tres, ADR-022 item 23). Состав лагеря
   (5 демо-врагов, слоты по CampLayout) меняется данными.

**Последствия.** `ticks_run` в контроллере — телеметрия для
device-замера AI-бюджета Phase 16 (не удалять); тюнинг врагов —
 EnemyData + ENEMY_DESIGN (не код); риг без рендера — visual-pass
 врагов и feel-телеграфов — только редактор/устройство
 (qa_phase5_enemies.md раздел A/B); навигация на графе лагеря
 (Phase 3 layout → camp_nav.tres) — навмеш-источник injectable,
 замена на NavMesh — Phase 16 по профилю.

---

## ADR-025 — Значения уровней 2–3 Inheritance: эскалация в данных (Phase 6)

**Статус:** принято (Phase 6, 2026-09-17).

**Контекст.** PROGRESSION_DESIGN фиксирует механику повтора
(смерть → «1 из 3» → повтаряемая Inheritance до уровня 3) и
качественную природу большинства эффектов (GDD: апгрейды
меняют геймплей, а не «+5%»), но **числа уровней 2–3 не
специфицированы** (в документах задан только уровень 1). Значения
нужно зафиксировать: они живут в .tres и влияют на баланс
повторных смертей (второй/третий выбор = усиление уже
выбранного пути).

**Решение.** Эскалация уровня 2/3 = **усиление того же
качественного эффекта**, а не новая механика (новая механика на
повторе ломала бы правило «выбор = путь»). Все значения — в
`data/inheritances/*.tres` (`effect_value_1/2/3`), читает
`InheritanceData.effect_value(level)`; кода на уровни нет.
Таблица MVP (L1 / L2 / L3):

| Inheritance | эффект | L1 | L2 | L3 |
|---|---|---|---|---|
| sharp | урон U3 | 45 | 55 | 65 |
| flow | + удар(ы) в комбо | 1 | 2 | 3 |
| slow_burn | CD Break, с | 40 | 30 | 25 |
| quiet_step | шум атаки | выкл | выкл | выкл |
| deep_sight | дальность Read, м | 12 | 14 | 16 |
| gentle_hand | сон Soothe, с | 5 | 6 | 7 |
| echo_step | оглушение afterimage, с | 0.5 | 0.75 | 1.0 |
| second_chance | авто-доджей, шт | 1 | 2 | 3 |
| ember | костёр лечит | да | да | да |
| the_track | время следа, с | 120 | 240 | 360 |
| the_page | + записка в run | 1 | 2 | 3 |
| the_compass | + направление | 1 | 2 | 3 |
| breaker | целей Disrupt | 2 | 3 | 4 |
| paradox | множитель первого удара | 1.4 | 1.6 | 1.8 |
| runner | + к отступлению, м | 2 | 3 | 4 |

Принципы выбора чисел: (1) шаг L1→L3 ≈ ×1.3–×1.5 на
множительные эффекты и +1–2 на счётчиковые (повтор — заметное
но не доминирующее усиление: 3 уровня = осознанный путь, а не
мгновенный потолок); (2) toggle-эффекты (ember, quiet_step)
не эскалируются численно — их «уровень» углубляет нарратив
(в MVP — без дополнительного геймплея; расширение — post-MVP по
поведенческим гейтам); (3) все значения — `@export` в .tres,
тuning без правки кода (data-driven, PROGRESSION_DESIGN §7).

**Последствия.** Баланс повторов настраивается данными
(ADR-017: 12 в MVP-пуле + 4 NPC-gated); unit-тест
`inheritance_effects` покрывает композицию (flow + sharp
суммируются; slow_burn + quiet_step — разные слои); если
device-QA покажет, что повтор «неощутим»/«доминирует»,
правятся .tres (не код). Значения L2/L3 — стартовые, не
канон: финальная калибровка — Phase 16 (баланс по
телеметрии memory_stats).

---

## ADR-026 — Процедурные комнаты: геометрический спавн-проф и walk-through-двери в headless-риге (Phase 7)

**Статус:** принято (Phase 7, 2026-09-17).

**Контекст.** Phase 7 (ROADMAP: «Procedural rooms (13 modular)»)
требует генератора + обязательной валидации
(TECHNICAL_DESIGN §6) ДО старта ранa. Валидация включает
«spawn-in-wall»-проверку (п. 2) — но headless wasm-риг
(ADR-022) **не имеет физсервера**: raycast/shape-cast в тестах
невозможны. Параллельно переходы между зонами (exit-criterion
«room transitions») требуют детекта «игрок прошёл через
дверь» — в риге нет CollisionObject3D-событий.

**Решение.**

1. **Геометрический спавн-проф** (честная замена физики, не
   фейк): вся геометрия комнаты = данные (`RoomData`:
   footprint AABB + `ObstacleBox[]` + двери). Валидатор
   (`LayoutValidator`) проверяет каждый spawn/loot/event-спот
   аналитически: внутри footprint (−0.25 м от стены), вне
   всех `ObstacleBox` (AABB-contains), ≥0.85 м от любого
   дверного проёма. Та же геометрия: (а) сцена строит из неё
   collision/volume-меш в реальном движке, (б) unit-тест
   подтверждает, что сломанные данные (спот в obstacle, спот
   за стеной) ОТКАЗЫВАЮТСЯ. Проф детерминирован и
   воспроизводим — это не «фейк физики», а **чистая функция
   над теми же данными**, которыми движок построит коллизии.

2. **Walk-through-двери** (честная замена коллизий): дверь —
   это точка на границе комнаты (`DoorwayDef.local_pos`), и
   «переход» = игрок физически прошёл через проём
   (расстояние до точки проёма < 1.05 м). `ZoneWorld`
   детектит это в `_physics_process` (дистанция + cooldown
   1.0 с от двойного срабатывания). Смена уровня =
   `main._enter_level(area)`: director.clear() →
   load_nav(уровень) → start(таблица уровня) → построение
   визуалов зоны из placement → оружие (fixed_loot) → туман.
   В реальном движке тот же триггер заменится Area3D-монитором
   в проёме (данные — те же: `local_pos` + `facing`), логика
   `main._on_door_crossed` не меняется.

3. **Генератор — чистая функция** `(seed, world_state, pool) →
   RunLayout`: 1–3 комнаты на зону (взвешенный сэмпл без
   повтора room_id; варианты одного id — по world-потоку),
   цепочка entry→exit, все двери RESOLVED (ADR-003: якоря
   идентичны между вариантами), координаты комнат вдоль −Z
   (проёмы door_b↔door_a совпадают до 1.2 м коридора),
   спавны — COPIES таблиц зоны (`.tres` неизменяемы) по
   encounter-потоку. Потоки RNG (RngStreams: world/encounter/
   loot/event) — splitmix64 от master-seed (4.7.2: hex-литералы
   > INT64_MAX запрещены — константы записаны signed-децималом).

4. **Обязательная валидация + fallback**: каждая попытка
   (seed+1, ≤8) проходит `LayoutValidator`: hub+boss
   присутствуют, все двери резолвятся, BFS-достижимость от
   camp (boss — единственный sink, достижим IFF открыт его
   вход; sealed undercroft = валидное состояние, ADR-016),
   нет изолированных зон, геометрический проф,
   монотонность сложности (нет шортката в boss из camp),
   no-filler в глубину. 8 провалов → **reference layout**
   (entry + первая комната пула, детерминированный,
   всегда валидный) + push_warning. В exit-прогоне 100/100
   сидов прошли без fallback.

**Последствия.** (1) В риге нет физ-валидации — в Phase 16
(реальный движок/экспорт) добавить повторный спавн-проф по
collision-mesh (данные те же; риск = расхождение данных и
меша, митигция = меш строится из тех же `ObstacleBox`).
(2) Дверной триггер по дистанции чувствителен к скорости
игрока на больших delta (туннель) — cooldown + радиус 1.05 м
покрывают 60 Hz; в реальном движке Area3D устраняет туннель.
(3) `director.clear()` (новый метод) — враги уровня
освобождаются при смене; run-level anchor store сохраняется
(запись ранa, не уровня).

---


## ADR-027 — Seed ранa и реконструкция на respawn; «Что изменилось» = 5 самых свежих изменений (Phase 8)

**Статус:** принято (Phase 8, 2026-09-18).

**Контекст.** Phase 8 (ROADMAP: «Run system (scripted first
10 min)») закрывает контракт: RUN 1 = канонический сценарный
мир (FIRST_30_MINUTES A1–A17 — якоря должны воспроизводиться в
playtest), каждый следующий run = **другая** раскладка («Мир
изменился. Не я.», B2), death → respawn ≤ 2 s hard / ≤ 10 s UX
(GDD §12, TECHNICAL_DESIGN §12), «Что изменилось» ≤ 5 строк на
respawn (WORLD_STATE_DESIGN §9.2). Четыре проблемы: (1) политика
seed не была зафиксирована; (2) риг (ADR-022) не имеет
движкового цикла — реконструкция мира на respawn должна быть
синхронной и детерминированной; (3) пример из дизайн-дока
(«Дверь открылась / Оружие ждёт / Кетл (Mara)») тонет в
memory-флагах самого ранa (столб, клинок, фигура… — уже
«известные» игроку факты), если брать «первые 5 строк из
таблицы»; (4) RUN 02 availability-флаги (cannon/staff/kettle)
ставит сцена — run-система должна сделать снапшот ПОСЛЕ.

**Решение.**

1. **Seed-политика.** RUN 1 = seed сессии (20260917 —
   каноническая раскладка, ADR-016/026 не меняются; якоря
   A1–A17 воспроизводимы). Run N>1 = `derive_seed(session, N)`
   (splitmix64-цепочка, `derive_seed(s, 1) == s` — первый run не
   «производный от себя»). WorldState-флаги передаются в
   генератор — мир помнит (дверь в undercroft открыта с RUN 02,
   A16 → B2).
2. **Death → respawn = синхронная реконструкция в одном
   тике.** Цепь (production, без deferred):
   bus.player_died → сцена ставит RUN 02 availability-флаги
   (`cannon_found`, `staff_found`, `kettle_washed`) →
   `RunManager.on_player_died` (PLAYER_DIED в запись,
   `run_02_door_open`, `first_death_done`, finish_run + history,
   pending-строки «что изменилось») → death screen 1/3 (P6) →
   выбор игрока (время на выбор не входит в 2 s — UX ≤ 10 s) →
   request_respawn → `_do_respawn`: `begin_next_run` (новый
   seed) → генератор + валидатор (fallback-раскладка) →
   `zone_world.setup` (level_freed → NPC в holding) →
   `director.clear` → `_enter_level(camp)` →
   `on_run_started` (след первого убийства A5, «Again?» A19,
   один раз за сессию) → spawn игрока. Измерено в риге: **41 ms**
   (бюджет ≤ 2 s).
3. **«Что изменилось» = 5 самых свежих.** Снапшот флагов на
   конец ранa vs снапшот на его начало; строки — **в порядке
   от самых новых** (пример дизайна: дверь, оружие, кетл —
   изменения мира СЕЙЧАС; memory-флаги ранa для игрока не
   «изменение»). Известный набор флагов = таблица строк
   (data, `world_flags.tres`) — дублирующего hardcode-списка в
   run-системе нет. Overlay на respawn: ≤ 5 строк, 3 s,
   пропускаемый, layer 30 (WORLD_STATE_DESIGN §9.2).
4. **Сценарные беаты (A1–A17) event-driven, не таймлайн.**
   `FirstRunDirector`: каждый беат = реальный момент игрока
   (interact/swing/kill/переход уровня); хуки — в `setup()`, не
   в `_ready()` (в `_ready` сцена ещё не скомпозирована,
   `_main == null` — хуки молча бы не установились);
   ENTER_ROOM и A-якоря пишутся в run-запись (RunEvent 14
   байт, Phase 15 ghost/echo).

**Последствия.** (1) Контракт сцена → run-система: RUN 02
availability-флаги ставятся ДО `on_player_died` — иначе
pending-строки молча потеряют оружие (покрыто
integration run_cycle: «changed lines include the
cannon/door»). (2) Риг: вся цепь смерти→respawn исполняется в
одном physics-тике, тест меряет wall-time (41 ms); реальный
движок — тот же код, стоимость = сборка уровня (примитивы,
мобильный бюджет ADR-021) — замер в Phase 16. (3)
`changed_lines` newest-first: при >5 флагах за run старейшие
выпадают (лимит дизайн-пула, Q-WD2 — 5 строк = 5 «дверей»,
data-driven). (4) RUN 1 = каноническая раскладка: playtest
якорей воспроизводим; с RUN 2 раскладка сидированно случайна —
сценарные беаты привязаны к world-state (ноут-станды ставятся
при входе в уровень), а не к геометрии.



## ADR-028 — Echo-бюджет (data + world-state + per-run счётчики), ghost = «pure timeline + визуальный контроллер» (Phase 9)

**Статус:** принято (Phase 9, 2026-09-18).

**Контекст.** Phase 9 (ROADMAP: «Ghost/Echo (budget per ADR-014)»):
GhostDirector/Replay/Controller по TECHNICAL_DESIGN §5, Passive Echo
(replay последнего забега) + маркеры старых runs (3–5), Combat Echo
(Remnant) — интеграция: спавн «где игрок был», реплики #1
(«You're early.» — и уходит, B4). Четыре проблемы: (1) remnant из
Phase 5 спавнился по camp-таблице во ВСЕХ runs (condition «always»)
— в RUN 1 появлялся «echo» при запрете (ECHO_SYSTEM_DESIGN §8:
RUN 1 = 0); (2) источник реплея = запись пред. ранa в раскладке
**прошлого** ранa (раскладка регенерируется, ADR-027) — remap по
§5.2 («карта в текущий мир») не был реализован; (3) часы ранa были
заморожены: `int(round(1/60 × 10)) == 0` — дробная часть
бросалась каждый кадр, ВСЕ RunEvent получали t=0, playtime_ms
всегда 0; (4) при рестарте уровня (director.clear + start) все
стеггер-слоты срабатывали в одном кадре (schedule был привязан к
t=0, а не ко времени спавна).

**Решение.**

1. **Бюджет = data + world-state + per-run счётчики.**
   `data/echo/echo_budget.tres` (rows: min_run → passive/combat/
   special; RUN 1 = 0, RUN 02/03 = 1+1, RUN 04+ = 1+1+1) +
   `EchoBudgetState` (счётчики ранa; владеет GhostDirector,
   EnemyDirector опрашивает) + remnant в spawn-таблицах гатится
   condition-типом `flag:first_death_done` (новый тип `flag:<id>` —
   world-state, универсален, без кода на флаг). RUN 02: 1 Combat
   (первый Remnant) + 1 Passive.
2. **Passive Echo = GhostTimeline (pure) + GhostController
   (визуал, без физики).** Timeline: события полного лога пред.
   ранa → keyframes (t, pos, ry, action); **remap**: комната
   keyframe-а (footprint-содержание) в новой раскладке
   разыскивается по room id (ADR-003: якоря идентичны между
   вариантами) — позиция сдвигается на дельту origin; комнаты нет
   → keyframe отбрасывается («перематка», §5.2; pulse-
   подсветка). Интерполяция Catmull-Rom (ry — angle-wrapped lerp);
   ghost «догоняет» сэмпл с max_speed 4 м/с (speed-cap §5.3 — без
   телепорт-артефактов). Ghost — per-level (keyframes текущей
   зоны; camp-кольцо — по footprint hub-комнаты, уровень camp
   пустой). Dissolve: конец реплея ИЛИ игрок оторвался
   (dist > fade_dist 20 м) — fade_time 3 с (data,
   `passive_echo.tres`).
3. **Combat Echo (B4 #1):** spawn-override —
   `director.spawn_overrides[remnant_id]` = последняя точка
   игрока в лагере пред. ранa (из RunRecord; лагерь стабилен —
   remap тождествен). Канон-секвенция теперь **полная и в
   порядке** (обе реплики, не random-одна — enemy_logic),
   уход = data-driven dissolve (`leave_fade` в EnemyData), не hard
   despawn.
4. **Маркеры старых runs:** ≤5 (пул) `last_death_pos` полных
   записей, remap-нутые, per-level, faint emissive (шиммер —
   полиш Phase 13/10).
5. **Часы ранa:** накопление дробных deciseconds
   (60 Гц: +0.167 ds/кадр → 10 ds/с); регрессионный unit-тест.
6. **Stagger-якорь t0:** schedule слота = t_spawn + phase +
   count×period — рестарт уровня не бьёт все слоты в один кадр.
7. **ECHO_TRIGGER в run-записи:** bus-сигнал `echo_triggered`
   (первая речь Remnant; тип в data-байте 0..4).

**Последствия.** (1) Финальный dissolve/rim-шейдер ghost —
Phase 13 (MVP — честный prototype-материал: transparency + tint +
faint emissive; mobile-бюджет ADR-021). (2) Маркеры старейших
runs сжимаются вместе с логами (5 МБ-кэп → summary без позиции) —
принято (MVP 10–15 runs, ADR-004). (3) B4-Remnant живёт в лагере
(«путь игрока» = последние точки в лагере) — «echo на моём пути»
читается по позиции; зональный путь реплея у Passive. (4)
`flag:`-условия — общее расширение spawn-системы (фазы 10/11
используют без кода).


## ADR-029 — Persistent world: WorldDirector (stand-ы записок, мумия, K7-трансформация), полный persist WorldState/MemoryStats (Phase 10)

**Статус:** принято (Phase 10, 2026-09-18).

**Контекст.** Phase 10 (ROADMAP: «World memory: WorldState persist,
WorldDirector apply, заметки, мумия, K7»): мир должен помнить
(§1 WORLD_STATE_DESIGN), «что изменилось» должно замечаться (GDD
§12 — risk R2). Четыре проблемы: (1) WorldState держал
flags/inheritances/weapons/npcs/runs, но **не держал** заметки
(§4: 4 stand-а, пул из 5 строк, без free text) и не умел
сериализоваться целиком — Phase 15 (SaveManager) должна обёрнуть
**этот же** класс, без смены модели данных; (2) «постоянные
объекты мира» (записки игрока, мумия #5, K7-визуал) не были
собраны в один слой — каждый будущий объект тянул бы свой
wiring в main_scene (God-class, ADR-001/023); (3) K7
(§6: boss_defeated → мир «теплеет») не имела ни триггера, ни
визуала; (4) MemoryStats (10 скрытых счётчиков, §3) не
сериализовался — память стилий терялась бы между сессиями.

**Решения.**
1. **WorldState: заметки + полный JSON-раундтрип.** `notes`
   (stand_id → {line_id, run_id, t}), `write_note` (только 4
   канон-stand-а, перезапись заменяет), `last_note()` (последняя
   по t — записка в руках мумии). `to_dict()/load_dict()` =
   flags (включая Vector3-значения, например `first_kill_pos`),
   inheritances, weapons, npcs, notes, runs (через
   RunHistory.to_dict). load_dict — защита от битого сейва:
   битые значения клампятся, неизвестные stand-а отбрасываются,
   пустой словарь = свежее состояние. Файловый I/O/CRC/миграции
   = Phase 15 (SaveManager обёрнёт этот же класс).
2. **WorldDirector (scripts/world/world_director.gd)** — слой
   постоянных объектов (scene-composed, не autoload):
   `prepare_run` (respawn-ребилд) + `on_level_entered` (после
   zone_world.enter) + `update(delta)` (шиммер). Ставит: 4
   player stand-а (data/player_note_stands.tres; camp — в
   CampWorld, зоны — в комнату раскладки), мумию (run_id ≥ 3,
   `last_death_pos` пред. ранa, remap ADR-028; комнаты нет →
   push_warning + skip), K7-визуал (gate glow + city silhouette
   за дверью). Шиммер «мемориальных» объектов: один 1-с emissive
   пульс при первом подходе в ран (§9.2 — игрок замечает
   «что изменилось»; O(1): ≤5 targets, distance-only).
3. **Станд-записок (Node3D + Interactable):** interact →
   NotePanel (code-built Controls, паттерн DeathScreen,
   `press(idx)` для детерминированных тестов) → игрок выбирает
   1 из 5 (NO free text, ADR-018) → WorldState +
   `notes_written` (trust Mara) + NOTE_WRITTEN (line в data-байте)
   → readable **с RUN N+1** (`run_id < current`). Чтение в
   ране N+1 — ECHO_NOTE_READ (first time).
4. **Мумия (#5, RUN 03 D2):** капсула лёжа + записка в руках
   (последняя записка игрока, data-driven), examine →
   «You died here. The world kept you.» + flag `corpse_seen`
   (линия «A mummy waits where you fell.» в world_flags.tres) +
   MUMMY_EXAMINED. Мумия следует run-space точке смерти: она
   видна в любой зоне, чей footprint содержит точку (то же
   правило, что у P9 death-маркеров — пространственная
   консистентность).
5. **K7 (триггер = флаг `boss_defeated`, сам босс — Phase 12):**
   data/world_transform_post_boss.tres (fog ×0.375 = 0.8→0.3,
   light 4000K→5500K, gate glow, city, echo «тише»
   passive 0/combat 1/special 0 = ECHO §8, footprint permanent,
   npc_calm). Применяется: `_set_fog` (fog-фактор),
   GhostDirector.prepare_run (бюджет-override),
   ghost-отпечатки остаются на уровне (reparent на fade-finish),
   NpcData.post_boss_line (NPC говорит спокойную реплику вместо
   обычной), gate-визуал WorldDirector.
6. **#6 (RUN 03 D2, Ремнант читает записку):** beat = реплика.
   FirstRunDirector ловит `echo_triggered(combat)` в ран ≥ 3 при
   наличии записки → `enemy_controller.add_encounter_line` →
   enemy_logic: `extra_lines` доклеиваются к канон-секвенции
   («…I forgot that.» — третья строка перед LEAVE). MVP-лимит:
   реплика, а не хореография «прерывает бой, подходит»
   (documented).

**Последствия.** (1) `WorldState.load_dict`/`to_dict` — готовый
контракт Phase 15 (SaveManager: CRC32 + миграции поверх).
(2) Мумия/маркеры в зонах с перекрывающимися footprint-ами —
принято (пространственная консистентность > «одна зона»).
(3) K7-триггер — флаг; до Phase 12 мир не видит `boss_defeated`
(тесты ставят флаг вручную — честно: триггер босса ещё не
существует). (4) `extra_lines` в enemy_logic — единственное
расширение боевого FSM (добавление, не переписывание; данные
ресурсов не мутируются). (5) NotePanel — единственный новый
UI-слой фазы (CanvasLayer 25, code-built, headless-safe).


## ADR-030 — Mystery layer: MysteryDirector + data (stages/lines/spawns), reveal-gate, ремнант note-encounter (Phase 11)

**Статус:** принято (Phase 11, 2026-09-18).

**Контекст.** Phase 11 (ROADMAP: «Mystery system: M1–M4 × 3 stages,
triggers, dialogue, #1–#7 + K1–K7, reveal rules»): 4 mystery × 3
стадии (MVP; 4-я стадия + twist-раскрытие — post-MVP, GDD v2.0 §11).
Три проблемы: (1) правила раскрытия («стадия N+1 только после
флага N», run-минимум, **1 стадия на mystery в run**, «мир не
торопится») не имели ни данных, ни исполнителя — каждый триггер
затащил бы в main_scene свою логику (God-class, ADR-001/023);
(2) реплики NPC-слоя (5 NPC × условия run/trust/flag) должны были
оцениваться в момент разговора — таблица с приоритетом и
«used/repeat»-семантикой; (3) #6 (P9, «…I forgot that.») —
реплику добавлял FirstRunDirector, но **встреча не могла
произойти**: `remnant_met` (session-флаг, P5) гасил
`first_encounter` у ремнанта последующих ранов, а REMNANT
переходит в SPEAK только из IDLE — записка пишется в середине
рана, после спавна (P9-дефект: фича реализована, но
недостижима; P9-интеграция её не покрывала).

**Решения.**
1. **MysteryDirector (scripts/gameplay/mystery/, RefCounted,
   scene-composed)** — чистый гейт раскрытия: `setup(stages)`
   (data/mystery/mystery_stages.tres, 13 стадий), `can_reveal(id,
   ws, run_id)` = run_id ≥ run_min И текущая стадия = stage−1 И
   flag_req (если задан) И mystery не раскрыт в этом run;
   `reveal()` = прогресс + flag_set атомарно (WorldState),
   `reset_run()` на каждый run, `progress_view` (тестовый seam).
   Стадии: data-driven (mystery_id, stage, run_min, flag_req,
   flag_set) — новый content = строка в .tres, ядро не трогается
   (data-driven-правило).
2. **WorldState.mystery_progress** — forward-only (no rewind:
   `set_mystery_stage` только вверх; persist с clamp 0–4).
   Прогресс 4 mystery — часть того же JSON-раундтрипа (ADR-029),
   Phase 15 SaveManager обёрнёт без смены модели.
3. **Данные реплик (data/dialogue/npc_mystery_lines.tres,
   DialogueLines.for_char)** — таблица-приоритет (первое
   совпадение): char/run_req/flag_req/trust_req + flag_set +
   repeat. NpcNode._line_for оценивает таблицу ПЕРЕД trust-линией;
   `mystery_line_spoken(line_id)` — сигнал в main_scene
   (раскрытие m4_city). used-диктонарий на NPC; repeat-линии
   (carto_city) повторимы — при смещении стадии +1 run (см. 5).
4. **Читер-слои сцены:** K4 WorldBook (страница = состояние мира:
   blank → «Eli. Profession: —.» → filled, RUN 05+; «Look (E)»
   открывает Label3D на 6 c + page_read → раскрытие m1_book/m1_page),
   K5 lake reflection (RUN 05+, фигура-силуэт 2 c, once), Child
   (RUN 04–05 village, deaths ≥ 3, инвульнерабелен; RUN 04 линия
   без стадии (run_min 5), RUN 05 «217» → m4_child; attempt_hit →
   мягкий пенальти-флаг), Veyra-map board (camp, после
   veyra_city_told, «VEYRA B»).
5. **Смещение стадии (поведение, не баг):** правило «1 стадия на
   mystery в run» сильнее графика MYSTERY_REVEAL_MAP — если в RUN
   05 M4 уже получила стадию (Child «217»), городская реплика
   картографа **говорится** (флаг veyra_city_told), но m4_city
   ложится в RUN 06 (линия repeat — он одержим). Тест
   фиксирует смещение (assert: стадия не сдвинулась в RUN 05).
6. **Ремнант note-encounter (фикс P9-дефекта, ADR-029 #4
   продолжение):** `enemy_director.remnant_note_met` (session,
   потребляется, когда ремнант С записной строкой ушёл);
   `enemy_controller._note_encounter_allowed()` (remnant +
   remnant_met + не потреблено + last_note() не пусто) —
   вычисляется **в момент зрения** (записка может быть написана
   после спавна); `enemy_logic.note_encounter`: IDLE→SPEAK (как
   first_encounter) **и CHASE→SPEAK** (если sense.player_seen —
   встреча читает записку, останавливая бой: нарративный момент,
   не боевое состояние — узкое расширение FSM, паттерн
   ADR-029 (4)). `_report_echo` покрывает обе встречи
   (ECHO_TRIGGER в записи).

**Альтернативы.** (1) Флаги-прогресс прямо в world_flags.tres —
отклонено: стадии это не булевы флаги (порядок, run-минимумы,
budget per run); отдельный слой честнее и persist-обёртывается
целиком. (2) Mystery как Node/автозагрузчик — отклонено: чистая
логика без дерева сцены (RefCounted, паттерн WorldState/
MemoryStats, ADR-023). (3) Note-encounter через «убить
remnant_met-гейт» — отклонено: сломало бы P5-поведение
«встреча один раз» (регресс-тест enemy_scene). (4) SPEAK из
CHASE без условия player_seen — отклонено: ремнант прочёл бы
записку невидимому игроку за 30 м (и встретился бы потреблён
впустую).

**Последствия.** (1) Reveal-правила проверяемы unit-ом (stage
таблица, gate, persist/clamp) — main_scene держит только wiring
(подключение сигналов + passive-ghost/child-колбэки). (2) М2.3
(the_first_seen) = данные+флаг, реплика — Phase 12 (boss). (3)
Ambiguity-бюджет: ни одна реплика не «отвечает» (unit-скан
таблицы реплик + стадий: ключевых answer-слов нет) — финальная
амбивалентность кадра сохранена (twist только post-MVP). (4)
Whisper #4 (gate, post-boss) — флаг gate_welcome_whisper, триггер
фазы 12 (паттерн K7, ADR-029). (5) Реестр R7 (мистика
«объясняется слишком рано») — подкреплён тестом: reveal-gate
unit + маршрут integration.


## ADR-031 — THE FIRST (Undercroft boss): module scripts/gameplay/boss/, одна-флаг дверь, parry-окно, core-удар по печати, Remnant-миньон (Phase 12)

**Статус:** принято (Phase 12, 2026-09-18).

**Контекст.** Phase 12 (ROADMAP: «Boss: THE FIRST (Undercroft) — 2
фазы, pattern-memory, core-hit, FIRST BLADE take/leave,
Remnant-миньон, death sequence K6->K7»): первый и единственный
босс MVP (BOSS_DESIGN.md). Проблемы: (1) ядро босса (FSM,
pattern-memory, окно ядра, фазы) — самая «плотная» игровая логика
проекта; в main_scene она стала бы God-class (ADR-001) и была бы
не тестируема без сцены (ADR-023); (2) дверь в Undercroft —
событийное условие из трёх фактов (mine_level_3_explored + 3
смерти + first_traces_seen, BOSS_DESIGN §2.1), но слой
комнат/дверей data-driven на ОДНОМ флаге (area_connection.
condition) — композитное правило и интерфейс-флаг должны жить
раздельно (ADR-019: «окно, не таймер»); (3) parry босса —
единственный в проекте механизм, где «блок» должен покрыть
удар, ещё в полёте (active-фаза прихода идёт ПОСЛЕ
swing_started) — простое «invulnerable на кадр» блокировало бы
только кадр, а не удар; (4) FIRST BLADE (WEAPON_DESIGN §4.3) —
выбор take/leave должен читаться миром (Echoes «уважают» клинок,
босс комментирует оба исхода) без нового механизма выбора —
только world-state + существующие сигналы.

**Решения.**
1. **Модуль scripts/gameplay/boss/ (6 скриптов):** `boss_data`
   (Resource: все числа боя в data/boss_the_first.tres),
   `pattern_memory` (RefCounted: история шагов,
   LEARNED/PARRY_TRIGGER/BROKEN, пороги из данных, фазовое
   reset_threshold), `boss_sense` (RefCounted: позиция игрока —
   логика не знает сцену), `boss_logic` (RefCounted FSM:
   IDLE/TELE-*/ACTIVE-*/CORE_WINDOW/LOOK/PARRY/STUN/
   PHASE_SHIFT/DEATH_*/DEFEATED; решения только, перемещение —
   нет), `boss_gate` (RefCounted: композитное правило двери ->
   ОДИН флаг boss_door_open, «once open, always open»),
   `boss_controller` (Node3D: визуал, steering (полоса 1.5–3.0
   м вокруг печати), доставка атак через DamageResolver,
   печать (TorusMesh, emission в окне ядра), Label3D-реплики,
   миньон, dissolve). Паттерн P4–P11: чистая логика RefCounted +
   тонкий Node-мост (ADR-023); main_scene держит только
   composition + 3 колбэка (defeated/stage_reveal/weapon_changed).
2. **Шаги pattern-memory = «weapon_id:hit_index» (melee).**
   Оружие — источник событий (swing_started у melee-контроллера),
   босс не знает оружие; ranged/staff не дают шагов (босс
   «учит ваши замахи» — melee-ядро дизайна). Комбо клинка
   (3 нажатия, combo_window 0.5 с) = последовательность
   [0,1,2]; 3 повторения = LEARNED (0.3 с «look» + реплика #4,
   cd 30 с); следующее завершение = PARRY_TRIGGER.
3. **Parry = CombatTarget.invulnerable на всё окно (0.4 с) +
   counter 25.** Ключевой момент: `parry_swing()` (boss_logic)
   fires counter и помечает used, но **не выходит из PARRY** —
   блок держится до конца окна (тик логики гасит state), иначе
   active-фаза пришедшего удара (0.35 с после swing_started)
   проходила бы после «окна». Контроллер additionally ставит
   invulnerable=true синхронно в кадре триггера (до
   hitbox-sampling того же удара) — гонка порядка обработки
   нод. Unit-тест фиксирует оба свойства (window-hold,
   once-only counter).
4. **Core-удар = one-shot по печати в окне (2 с / 4 с с клинком;
   30/50 dmg).** Окно открывается ПОСЛЕ slam (событие
   core_window_open -> emission печати: «ядро видно», GDD §6.2);
   окно = состояние FSM (CORE_WINDOW), а не таймер-флаг;
   успешный core_hit закрывает окно (IDLE). Проверка удара —
   в swing_started (melee, dist(player, seal) <= range+0.5) —
   до hitbox-sampling (честно: «удар достал печать»).
5. **Дверь Undercroft: композит -> один флаг.**
   `boss_gate.should_open(ws, deaths)` (mine_level_3_explored И
   deaths >= 3 И first_traces_seen; плюс short-circuit на уже
   открытом boss_door_open) оценивается в `_begin_new_run` ДО
   `run_generator.generate` (генератор читает progress.ws.flags);
   data/areas/the_mine.tres condition = `boss_door_open`
   (data-driven, как все двери). Факты ложатся из сцены:
   `_check_mine_deep` (тик 0.5 с, только в the_mine: комната
   index >= 2 по run_layout = mine_level_3_explored; RUN 05+ =
   first_traces_seen + toast) и `first_run_director.
   place_first_traces` (глубочайшая комната: 3 тёмных овала +
   его фонарь, emission без dynamic light — мобильный бюджет).
   Тело босса (boss_defeated) — НЕ условие двери: босс
   достижим только когда окно уже открыто, а «once open»
   коротко замыкает правило.
6. **Миньон = duplicate remnant_mirror через существующий
   enemy pipeline.** `EnemyController.setup(duplicate(true),
   pos, player, director)` (health 80/damage 15 из boss_data,
   first_encounter_leaves=false); на <=50% hp — `gentle_leave()`
   (enemy_logic: _enter(LEAVE)) = dissolve-as-LEAVE: **без
   kill-записи** (EV_LEAVE-путь директора, P5), без
   remnant_met-флагов мира (это не встреча). Новый код —
   `gentle_leave()` (2 строки в logic) + passthrough в
   controller; pipeline не расширялся.
7. **FIRST BLADE take/leave = world-state + существующие
   сигналы, без нового механизма.** Pickup (WeaponPickup,
   fixed path) -> ws.set_weapon_found + first_blade_found;
   main `_on_weapon_changed` (weapon_first_blade) -> флаг
   `first_blade_taken` + `boss.blade_taken_changed(true)`
   (реплика #5 + logic.set_blade: окно 4 с/50 dmg). «Уважение»
   (WEAPON_DESIGN §4.1): `enemy_director.respects_first_blade()`
   (флаг ws) гейтит REMNANT IDLE-aggro (не first/note-встречи);
   первый реальный удар по такому ремнанту гасит respect
   (`_respect_broken`); одноразовая реплика «...that was mine.»
   (<=3 м, speech-bubble — без нового UI).
8. **Death sequence K6 -> K7:** hp<=0 (set_hp, death BEFORE
   phase check) -> DEATH_DISSOLVE (3 с, dissolve-алфа
   _body_mat, реплика #9) -> DEATH_FINAL (реплика #10 «let
   them go», 2 с) -> DEFEATED -> сигнал defeated ->
   main: `boss_defeated` (флаг K7: gate glow/туман — P10,
   flag-driven на следующем входе) + toasts «The door is
   open.» / «The fog thins.» + M2.3: `stage_reveal("m2_first")`
   на PHASE_SHIFT (реплика #6 = линия стадии; гейт reveal —
   RUN 05+, MYSTERY_REVEAL_MAP; сцена RUN <5 получает сигнал,
   но стадия не ложится — честный гейт, integration проверяет
   оба факта). Переходы состояний детектирует контроллер
   member-переменной `_prev_state` (set_hp/parry/core_hit меняют
   state МЕЖДУ тиками — tick-local prev терял биаты: реплика
   смерти не звучала).
9. **Реплики #1–#10 (CHARACTER_BIBLE §8):** #2/#3 — pre-boss
   стенды (3 записки The First, BOSS_DESIGN §2.2); остальные —
   в бою по триггерам (вход/learn/blade/phase2/last-stand-30%/
   core/death/final). #7 (не взял клинок) — в last stand (30%),
   а не на phase-shift: на phase-shift уже #6 (M2.3) — две
   реплики подряд ломали beat-ритм (найдено integration-тестом:
   #7 затирает #6 в Label3D).

**Альтернативы.** (1) Босс как «большой EnemyController»
(archetype BOSS в enemy_data) — отклонено: pattern-memory +
core + фазы + миньон не вписываются в encounter-FSM (разные
инварианты: босс не спавнится таблицей, не имеет
encounter-флагов, не «уходит»); модуль честнее, а миньон
использует enemy pipeline как есть. (2) Дверь через
boss_defeated напрямую — отклонено: BOSS_DESIGN §2.1 — окно
(три факта), а не «победил босса»; plus boss_defeated ложится
в середине рана (дверь для следующего). (3) Parry через
отменённый DamageRequest (flag block) — отклонено: инвази
resolver-семантики (blocked = i-frames/unkillable);
invulnerable-тарагет — уже существующий путь (P4). (4) Миньон
«убиваемый» (kill-запись) — отклонено: BOSS_DESIGN §3.4 —
«уходит на 50%», не смерть; kill-запись подделала бы
memory-stats (REM kill) и remnant-флаги. (5) Следы первого
(The First) как world_director-объект — отклонено: beat
принадлежит FirstRunDirector (RUN-гated beats, паттерн A16/
B2/K5); флаг first_traces_seen — world_flags (35 строк).

**Последствия.** (1) 49 unit-проверок (data/pm/fsm/core/death/
gate) + 40 integration (boss_scene: арена-контент, melee,
learn, parry-блок+counter, core, phase2+миньон+reveal, blade
take, death, gate-флаг) + обновлённый run_cycle (дверь sealed
в RUN 02 — поведение P7/P11 «дверь открыта в RUN 02» заменено
правилом окна, BOSS_DESIGN §2.1). (2) М2 закрыт (m2_first),
MVP-end: M1:4 M2:3 M3:3 M4:3 (unit mystery). (3) Босс атакует
по distance-to-seal (логика), а не distance-to-boss: за печат
он «держит арену» — swing издалека не бьёт (дальность
проверяет контроллер); осознанный trade-off (читаемость: телеграф
всегда у ядра). (4) R6-чек-лист: телеграф-читабельность (>=70%)
— ручной шаг владельца (qa_phase12_boss.md). (5) Бюджет: +2
MeshInstance-секции на босса (капсула+голова, общий material),
+2 у печати, 0 dynamic lights (emission) — в рамках ADR-021.


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
| R8 | GPU-divergence: Adreno/Mali/PowerVR рендерят/перф-ведут себя по-разному (арт-артефакты, просадки на конкретном вендоре) | Визуал/перф релиза | Референс-железо = Adreno (владелец); Mali-проверка — Phase 16/17 (по доступности); консервативные шейдеры/бюджеты; fallback mobile renderer (ADR-021) |
| R9 | Android-тулчейн (SDK/gradle/AAPT2/JDK) отсутствует в песочнице → APK не собирается/не проверяется здесь | Release-этап | Честное ограничение (ADR-012, §15.5): APK-сбор + ADB-QA — на железе владельца по чек-листу Phase 18; песочница готовит export-конфиг и RELEASE_BUILD.md; headless-тесты покрывают логику |

## ADR-032 — Visual polish: палитра/качество/текстуры/персонажи как данные, light-бюджет = жизненный цикл узлов, UI-kit (Phase 13)

**Статус:** принято (Phase 13, 2026-09-20).

**Контекст.** Phase 13 (ROADMAP: визуальный pass по всем сценам,
замена prototype-элементов по ASSET_STATUS.md, UI-отделка
mobile-вёрсткой, mobile-графика по TECH_DESIGN §12 — ASTC/атлас/
draw calls ≤150/lights ≤6/no heavy post, camera polish, color
grade). Проблемы: (1) цвета — ad-hoc по файлам (комнаты, лагерь,
персонажи, UI) при каноне WORLD_BIBLE §1 — «один источник»
нарушен; (2) mobile-графика (§12) — нет пресетов качества и
контроля числа локальных источников (Light3D в Forward+ — самая
дорогая статья мобильной GPU); (3) текстуры — ASSET_GUIDE §7
обещал tools/utils (генераторы), но их не было; (4) каст —
каждый персонаж строил свой примитив (5 разных кодов, разный
язык), prototype-долг P11/P12 (босс = капсула+голова); (5) UI —
не Godot-дефолт, но цвета ad-hoc per-screen; (6) headless wasm
rig не регистрирует часть нативных сеттеров (Light3D.enabled,
Environment.msaa, Viewport.render_scale, MeshInstance3D.material)
и не имеет глобального кэша class_name — тесты не могут
просто «установить и прочитать» часть визуального состояния.

**Решения.**
1. **VisualPalette (Resource, data/visual/palette.tres) — единый
   источник цветов мира** (WORLD_BIBLE §1: muted green-grey,
   grey-blue fog, ember = единственный тёплый источник до босса,
   cold white, rust, layer-tints). Комнаты (floor/walls/frames/
   obstacles/props), лагерь (path/tents/monoliths/trunks),
   персонажи — только палитра. Правило проверено unit-тестом
   (validate(): warm/cold инварианты).
2. **QualityPreset (data/quality/{low,medium,high}.tres) +
   QualityManager (scene-composed).** Тир-бюджеты §12: lights
   3/4/6, shadows off/on/on, render_scale 0.75/1.0/1.0, particles
   0.5/0.75/1.0, MSAA 1/1/2, tex 512/1024. Дефолт = medium
   (mid-range Android — референс-устройство). F8 (debug builds)
   циклирует тир с toast. apply(): set_shadow() (rig-
   регистрируемая пара) + production-only контролы
   (msaa/render_scale/atlas — в rig их сеттеры no-op; device-QA
   P16).
3. **Light-бюджет = жизненный цикл узлов, а не enabled-флаг.**
   ZoneWorld при enter/set_light_budget создаёт RoomLight только
   в комнатах до бюджета (chain order: входные комнаты светят,
   глубинные — на солнце); при повышении бюджета — пересоздаёт
   из RoomData. Почему: (a) `Light3D.enabled` в rig no-op
   (проверено) — флаг не наблюдаем тестами; (b) в production
   несуществующий свет — реальная экономия (слот GPU), а
   enabled=false остаётся в light-list; (c) детерминизм:
   min(rooms, budget) узлов. room_node.ensure_light/drop_light
   (immediate free — бюджет не может пережить кадр).
4. **Генеративные текстуры (tools/utils/gen_textures.py): чистый
   stdlib (zlib/struct/hashlib), детерминированный seed, 8 ×
   64×64 tileable RGBA (stone/stone_dark/ground/wood/wood_dark/
   cloth/rust/fog_soft), 15 КБ всего.** TextureBank
   (scene-composed) грузит PNG (Image.load_from_file — имя в rig),
   tint-модель: albedo_color = palette_target / texture_base —
   вариация текстуры переживает тон (проверено unit: tint
   «приземляется» на палитровую цель ±0.02). ASTC — на уровне
   export preset (post-MVP), .tres-атлас не нужен: примитив-UV
   0..1, 64px на фасет достаточно; честная пометка в
   ASSET_STATUS.md.
5. **CharacterVisual (статический билдер) — один язык каста:**
   капсула + hood (сплюснутая сфера) + scarf/collar (цилиндр) +
   emissive visor; wear (0..1) десычатирует cloth (босс =
   «усталый ты»). Eli (hood/scarf/visor, cloth-тон = канон
   eli_cloak — prototype-синий из tscn отозван), 4 NPC
   (accent = идея персонажа в data: Mara=ember, Orren=grey-blue,
   Nia=moss, Cartographer=ink), Child (child_pale), THE FIGURE
   (eli_fresh — FRESH-копия, GDD §8), враги (архетипные цвета
   + сигнатурный акцент eye/core/blade сохранены; Mimic =
   echo_tint §1.1), босс (worn-Eli + rust-шарф/фонарь), Remnant
   (Eli-white + blade). Марра = camp-look + hood (tscn) + cloth
   (reskin через NPC-ноду — репарентинг раньше банка).
6. **UI-kit (UiTheme, data/ui/ui_theme.tres):** один набор
   цветов/радиусов/типографики для всех четырёх экранов
   (toast/inventory/note/death) — «dark matte + warm parchment +
   campfire-акцент» (WORLD_BIBLE в UI). Тест: все 4 экрана
   используют `_th()` (нет ad-hoc-цветов). Touch-layout
   (16:9–20:9 + safe-area + thumb-зоны) не тронут — ADR-021
   уже mobile-вёрстка.
7. **Color grade (main.tscn Environment):** холодный ambient
   (fog-тон, energy 0.3) + лёгкий adjustment (sat 0.96,
   contrast 1.04, value 0.99) — «muted» WORLD_BIBLE §1; filmic
   tonemap и fog (fog_blue) уже были; glow/тяжёлый пост — нет
   (§12 no heavy post; MSAA ≤4x).
8. **Camera polish:** aspect-aware base FOV (60° @16:9 → 68°
   @20:9, линейно; compute_base_fov — чистая функция, unit) +
   sprint-kick (+6°, демпф 1/с, set_sprinting из player
   RUN-состояния) — «мощь», не дисторсия.
9. **Риг-лимиты как контракт (документировано в тестах):**
   материал читаем через material_override / mesh.material
   (оба registered; MeshInstance3D.material — NO); class_name —
   только preload (глобального кэша нет — конвенция проекта);
   Light3D.enabled/Environment.msaa/Viewport.render_scale —
   production-only (device-checklist P16). Материалы нод-билдеров
   держатся в членах (room_node.floor_material, camp
   _reskin-реестр) — это же production-хук для reskin/grading.

**Альтернативы.** (a) Импортированные CC0-модели/текстуры —
нет: budget 0 ₽ + text-first ADR-005 + лицензионная чистота;
замена инкрементальна через data (SceneRef). (b) Light-бюджет
через enabled+energy-зеркало — отклонено: зеркало — фейк
состояния; создание/удаление узлов — честный контроль в обоих
средах. (c) UI через Theme-ресурс и theme-наследование —
отклонено: экраны code-built (ADR-002), StyleBoxFlat из кита —
минимальный путь без переписывания вёрстки. (d) Атлас UV для
примитивов — отклонено: UV примитивов 0..1, ремэп ради атласа
= переписывание работающего; 8 × 64px = 15 КБ не давят на
бюджет. (e) Глобальные class_name в rig — недоступны (кэш
строится редактором), preload — конвенция проекта (ADR-022).

**Последствия.** Визуал MVP = «осознанные примитивы + генерация»
(final-generative по ASSET_STATUS.md): все prototype-элементы
закрыты или явно приняты (Ghost — принят). Каст читается
(характеры: hood+scarf+accent). Mobile: lights ≤6 по тирам,
текстуры 15 КБ, no heavy post, MSAA ≤4x, render_scale по тиру;
device-верификация (ASTC/export, draw calls, FPS, терм.) — P16
checklist. Риг не валидирует рендер-свойства (msaa/render_scale/
atlas/enabled) — это честно помечено в qa_phase13_visual.md.

## ADR-033 — Audio: процедурный саундтрек офлайн, buses + crossfade-менеджер, настройки-дикт (Phase 14)

**Статус:** принято (Phase 14, 2026-09-22).

**Контекст.** Phase 14 (ROADMAP: все категории GDD §7,
AudioManager (buses/pool/levels), «The Wound» ×5 (Normal/Memory/
Echo/Archivist/Ending) + ambient-слои + 1 stinger (boss reveal),
звуковой язык слоёв WORLD_BIBLE §1.1; exit: полный audio pass,
volumes/mute в settings). Проблемы: (1) бюджет 0 ₽ + лицензионная
чистота — финальных лицензионных трэков нет; (2) музыка по
GDD = «одна мелодия в 5 вариациях» + ambient + stinger = 12
стримов ~20 с каждый — рантайм-синтез на wasm (5 × 24 s ×
22050 Hz × гармоники) = секундная hitch на старте и в каждом
переключении; (3) headless-риг: AudioServer-API работает
(add_bus/set_bus_name/set_bus_volume_db/set_bus_mute/set_bus_
send, AudioStreamPlayer.bus/play/playing — проверено
audio_env_test), но `Math`/`ln()`/`log10()`-глобалы частично
отсутствуют (log() есть), enum-константы AudioStreamWAV не
гарантированы; (4) P4-долг: SfxBus «prototype» с 6 кью без
буса, SfxLibrary «заглушки»; (5) exit требует «volumes/mute в
settings», а settings-экрана не было (P15 держит persistence).

**Решения.**
1. **Саундтрек = офлайн-генерация (tools/utils/gen_audio.py,
   чистый stdlib: wave/math/random, зашитые seeds) -> 12 WAV
   11025 Hz mono 16-bit (~4.8 MB), byte-стабильная
   регенерация** (md5-проверено). Тот же контракт, что
   gen_textures.py (P13): звук — математика, не ассеты, 0 ₽,
   ноль лицензионных обязательств (ASSET_LICENSES: «внешних
   ассетов нет»). Почему офлайн: рантайм-генерация 12 × ~20 с
   = wasm-hitch; почему 11025 Hz: контент < 3.1 kHz (птицы
   2.8k + свип 300) — вдвое меньше памяти/времени, aliasing
   невидим (Nyquist 5.5 kHz).
2. **MusicLibrary = runtime-банк** (FileAccess -> AudioStreamWAV,
   путь, доказанный текстурами P13): 5 вариаций (loop 24 s,
   seam crossfade 0.25 s — шов мелодии на одной ноте D4), 6
   ambient (loop 16 s, seam 0.5 s), stinger (4 s one-shot).
   Уровни запечены в файлах: музыка/stinger peak 0.85,
   ambient 0.35 (bed); сверху — бусы (см. 5).
3. **Мелодия «The Wound»: 8-долевая фраза (D-minor), которая
   поднимается и не разрешается + 8-долевой ответ ниже;
   loop = фраза+ответ+фраза (24 s @60 BPM).** Вариации
   меняют ТЕМБР И ВРЕМЯ, но не ноты (GDD §7: «скромный, но
   цельный»): normal (sparse, sine+гарм.2), memory (октава
   вверх, long decay, 3-tap reverb), echo (каждый 4-й нот
   «игрaет назад» — reversed-фрагмент + 4-tap echo),
   archivist (чистый синус = monochrome, стаккато, дрон D2,
   rust-metal акцент Bb5 на сильных долях), ending (2
   гармоники, тёплый пад D3/A3/F4, финальная фраза +октава).
4. **MusicDirector (RefCounted, чистая логика): цепочка
   приоритетов ENDING > ARCHIVIST > ECHO > MEMORY > NORMAL**,
   ранги = факты, которые сцена уже знает: boss_defeated &&
   undercroft (финальная сцена), boss в бою (monochrome-арена
   THE FIRST), Passive Echo рядом, post-boss (мир помнит —
   P11), иначе normal. Сцена кормит факты, менеджер только
   плейбек — никакого audio-состояния, которого нет у сцены.
   Crossfade 1.5 s (A/B-голоса), повторный pick того же факта
   бесплатен (needs_switch).
5. **AudioManager (Node, scene-composed): бусы Music/SFX/Ambient
   на Master** (создаются в _ready, add_bus+set_bus_name+
   set_bus_send — валидация audio_env_test), дефолты 0/-3/-9 dB;
   music-голос (2 игрока, crossfade), ambient-голос (loop,
   swap по зоне), stinger (one-shot на Music-бусе), **settings:
   master/music/sfx/ambient (0..1) + mute** -> dB на бусах
   (20*log10 через log()/ln-константу — Math-синглтона в риге
   нет; 0 -> -80 dB floor). get_settings()/settings_from_dict()
   — дикт, который P15 сохранит в save (persistence — P15,
   честно).
6. **SfxBus (P4 -> final): 12 кью** (P4/P6: swing/hit/riposte/
   hurt/shot/pickup; P14: door/seal/death/note/ui/echo — все
   процедурные в рантайме, seed, пик < 0.9), пул 3 слота
   (oldest-steal), **роутинг в SFX-бус** (менеджер создаётся
   в дереве раньше пула; без менеджера — Master, честно).
   Смысл кью: door = смена зоны; seal = смерть босса; death =
   падение (тело 200->40 Hz + удар + reversed-шёпот, «Again?» —
   текст, не голос — MVP без TTS осознано); note = бумага; ui =
   тик; echo = шёпот-набухание при появлении Passive Echo.
7. **SettingsPanel (пятый экран, ADR-002 code-built + UiTheme-
   kit): 4 слайдера + Mute, живое применение на бусах**,
   центральный бокс (aspect-safe 16:9–20:9), thumb-строки
   >= 44 px, tap/drag (тот же _gui_input-путь, ADR-021) +
   детерминированный API set_slider()/toggle_mute() для тестов.
   F9 (debug action уже был в input map) — toggle; release:
   экран живёт за settings-меню P15.
8. **Wiring в main_scene (seams, не новая логика):** _enter_level
   -> set_zone + update_music; undercroft -> stinger +
   _boss_in_fight; boss_defeated -> seal + update_music (ENDING);
   door_crossed -> door; death -> death; note_read -> note;
   Passive Echo reveal -> echo + update_music; F9 -> панель.

**Альтернативы.** (a) CC0-трэки/войс (Freesound и т.п.) —
отклонено: бюджет 0 ₽ + «только бесплатные легальные» +
лицензионный трекинг 12+ файлов vs ноль; процедурный путь уже
доказан в проекте (текстуры P13, SFX P4). (b) OGG-сжатие —
отклонено: 4.8 MB WAV не давят на мобильный бюджет (P16), OGG-
декодер в wasm-риге непроверен (не валидировать то, что не
нужно). (c) Music-состояние в AudioManager (авто-pick) —
отклонено: менеджер не знает мир (ADR-019 «окно, не таймер»;
факты у сцены). (d) Voice-бус — не создаём: голосовых реплик в
MVP нет (текст); бус без контента = unnecessary system.
(e) Settings-экран в P15 — отклонено: P14-экзит требует
работающих volumes/mute; экранный путь (kit-вёрстка + API)
небольшой, persistence всё равно P15.

**Получено.** Полный audio pass (GDD §7): 5 вариаций + 6 ambient
+ stinger + 12 SFX + 3 буса + settings. Headless-контракт
рига для аудио задокументирован (audio_env_test). Prototype-
долги P4 (SfxBus/SfxLibrary) сняты — ASSET_STATUS: аудио
= final. Mobile: 12 стримов ~4.8 MB RAM (11025 Hz mono),
обработка = mix-инги Godot (лёгкая), battery-влияние
измеряется в P16.

## ADR-034 — Save: один слот, CRC32, восстановление по матрице, изоляция тестов (Phase 15)

**Статус:** принято (Phase 15, 2026-09-22).

**Контекст.** Phase 15 (ROADMAP: SaveManager по TECHNICAL_DESIGN §3
(atomic, crc, versions, migration, recovery), save-матрица +
kill-mid-write симуляция, settings в save; exit: crash/invalid/
old-version/missing-asset — без loss core-прогрессии, без crash).
Проблемы: (1) WorldState (P6) уже был спроектирован под save
(to_dict/load_dict + «Phase 15 обернёт ЭТОТ ЖИ класс»), но
envoIope/CRC/файловый слой не существовал; (2) headless-риг:
user://-I/O работает (probe: write/rename/remove,
make_dir_recursive с user://-путями), но нет String.to_utf8
(UTF-8 для CRC — вручную), JSON.stringify сортирует ключи по
умолчанию, а JSON.parse_string возвращает ВСЕ числа как float
(int -> float-дрейф ломает CRC-стабильность: 1757760000
возвращается "1757760000.0"); (3) settings (P13 quality, P14
audio) должны попасть в save и применяться при старте, но
создаются в разное время (audio до progress, quality после);
(4) интеграционные тесты: save в user:// — разделяемое
состояние между 14+ сьюитами одного harness-процесса (первый
death-choice в одном сьюите ломал RUN-1-инварианты в
последующих).

**Решения.**
1. **Три слоя (scripts/gameplay/save/):** `SaveData` (pure:
   envelope {format, version, saved_at_unix, engine_version,
   world, settings, crc32}, canonical JSON, CRC32-IEEE
   бит-в-бит, verify-матрица с именованными проблемами),
   `SaveMigrator` (pure: цепочка шагов from-version -> Callable,
   target; «newer» = отдельный именованный исход, gap =
   andменованный; шаг обязан продвигать версию — guard от
   зацикливания), `SaveManager` (Node, scene-composed: file I/O,
   матрица, atomic-запись, cap). Менеджер работает с ДИКТАМИ
   (world = WorldState.to_dict(); сцена применяет load_dict) —
   нет зависимости от progression.
2. **CRC-стабильность через нормализацию чисел:** canonical(d)
   = stringify(отсортировано + целочисленные float -> int).
   Это делает CRC инвариантным к int->float-циклу JSON-парсера
   (без этого любой round-trip давал crc_mismatch). Проверено:
   вектор "123456789" = 0xCBF43926, order-free canonical,
   round-trip verifies.
3. **Atomic-ish запись (TECH_DESIGN §3):** .tmp -> flush ->
   close -> DirAccess.rename (POSIX/NTFS атомарно на файле);
   crash между шагами оставляет СТАРЫЙ или НОВЫЙ файл (тест
   kill-mid-write: partial .tmp + целый старый -> старый
   выигрывает, tmp зачищается следующим save). Предыдущий
   ВАЛИДНЫЙ файл копирован в .bak (невалидный не
   промутационируется в .bak).
4. **Матрица восстановления (именованные статусы):**
   ok / empty / recovered_bak (битый main + валидный .bak ->
   .bak поднят в live, битый сохранён .corrupt_corrupt) /
   fresh (оба биты -> оба сохранены, свежий мир) / newer
   (save от новой версии: файл НЕ ТРОГАЕТСЯ — это save
   пользователя для другого билда; meta из .bak или safe
   defaults). quarantine = rename в .corrupt_* (данные
   пользователя НИКОГДА не удаляются).
5. **Settings в save (P14-экзит, закрывший P14) + P13 quality:**
   save-секция {quality: tier-id, audio: {master, music, sfx,
   ambient, muted}}. Точки: смерть+выбор (перманентный факт,
   тост «The world remembers.»), возврат в лагерь (safe hub,
   тихо), WM_CLOSE_REQUEST (тихо). Применение при старте —
   после создания ОБОИХ систем (audio существует раньше
   progress, quality — после: `_apply_saved_settings()` вызван
   в run-setup, мир-секция — до run_manager.init_session,
   т.к. история ранов = world fact).
6. **Изоляция тестов без environment-sniffing:** сигнал —
   «main scene не current_scene» (под harness'ом root =
   runner, в игре main.tscn = current scene). Изолированный
   save (уникальный путь, чистится в _exit_tree) у каждой
   интеграционной сцены; тест, которому нужен общий файл
   (death->save->reload), ставит `save_path_override` ДО
   add_child (seam), и сцена не претендует на путь.
   (DisplayServer в риге = "web", не "headless" — environment-
   проверки отброшены.)
7. **5 MB hard cap на файл:** runs-секция — единственный
   растущий участок; RunHistory уже тримит в рантайме,
   файловый уровень — последняя линия (oldest full -> summary,
   log; не снять cap — save НЕ пишется, старый остаётся).

**Альтернативы.** (a) Save в нескольких файлах (world/runs/
settings) — отклонено: §3 «одна слот-файл», атомарность
целого проще, CRC одного файла. (b) OGG-подобная бинарная
запись — отклонено: JSON читаем человеком (QA, recovery на
device), 5 MB cap при 15 ранах ~150-300 КБ — нет причины
жать. (c) Авто-автосейв по таймеру — отлонено: «окно, не
таймер» (ADR-019) — сейвы на фактах (смерть/выбор/хаб/закрытие).
(d) Load в _ready с реальным путём + чистка user:// перед
тестами — отклонено: чистка общего хранилища из тестов
опасна (реальный save разработчика), изоляция по-сьюитно
честнее. (e) run_count как world fact (схема §3) — НЕ
введён: нумерация ран сессионная (новый старт = run 1),
персистентны РЕКОРДЫ (runs-секция) — текущая модель
RunManager/RunHistory, честнее, чем синтетический счётчик.

**Получено.** Save-система по §3: один слот, CRC32, версии
(v1, цепочка готова), атомарная запись, бэкап, матрица
восстановления (6 именованных исходов, все покрыты unit),
kill-mid-write, settings (quality + audio) в save, три точки
автосейва. Prototype-долгов: нет. Device-QA (P16):
физический файловик Android, ENOSPC, crash-тесты.

## ADR-035 · P16: Performance — песочница меряет CPU/структуру, GPU — на устройстве (2026-09-22)

**Контекст.** §12-бюджеты (frame ≤16.6/33.3 ms, draw calls ≤150/120,
tex mem, RAM, thermal) требуют замера. Песочница (wasm Godot-риг)
не имеет GPU-бренда и физического дисплея: `OS.get_render_info`,
`OS.get_used_memory_bytes` в риге пусты (verified P15), frame
wall-time в wasm ≠ frame на Snapdragon.

**Решение.** Честное разделение (тот же принцип, что ADR-021):

1. **Песочница (integration, каждый прогон = замер):** структура
   сцены (nodes/bodies/fx/local lights vs §12) + frame CPU (логика
   кадра: player + director + boss, P50/P95) + save write (ms).
   Результаты в PERF_REPORT: camp 281 nodes / CPU p95 0.16 ms;
   mine 340 / 0.07 ms (4 lights = exactly Medium-бюджет);
   boss-арена 334 / 0.09 ms (босс в цепи); save 1 ms — **всё в
   §12 с запасом**. Аудит-фиксы: High tex 1024→2048 (data-дрейф),
   Ultra-пресет создан (отсутствовал), `soft_shadows` в apply().
2. **Устройство (владелец, ADB):** draw calls, tex mem, RAM,
   frame wall-time, thermal 30 мин, cold start — PERF_REPORT §2
   (чек-лист по TEST_PLAN §7; референс: SD7/8GB High 60 fps,
   SD6xx/4GB Low 30 fps floor).
3. **Инструменты:** F1 DebugOverlay (4 Hz, P50/P95, budgets,
   device-метрики guarded) + F6 PerfBenchmark (10 s →
   `user://perf_<area>.txt`, P50/P95/peak + counts) —
   `OS.is_debug_build()`-guarded, release off (P14-принцип).

**Почему так.** «Все бюджеты pass» из песочницы про GPU было бы
фейком — GPU-строки в риге пусты. Разделение фиксирует, ЧТО
валидировано (CPU/структура/данные) и ЧТО ожидает device
(GPU/thermal) — exit P16 по §12 закрывается владельцем по
чек-листу. CPU-замеры в wasm — относительные (доказывают:
логика не bottleneck), абсолютные ms — device.

**Следствия.** F1/F6 — debug-only; benchmark-файлы — формат
текста (adb pull, diff между build); PERF_REPORT обновляется
после каждого device-прогона; preset-рекомендация по GPU
(post-MVP) — когда будут device-данные по моделям.

## ADR-036 · P17: int64 > 2^53 в save — формат-фикс «i64:» (2026-09-22)

**Контекст.** §6-свип (edge_cases) убил игрока 5 раз подряд:
world dict накопил derived run-seeds (splitmix64, P8:
`derive_seed` — полный int64, ~1e17–1e18). Save-файл при этом
«корруптился»: load → crc_mismatch → quarantine → recovered_bak
→ **игрок тихо откатывался на state последнего успешно
прочитанного save**.

**Корень.** JSON-числа в Godot (и в риге) — float64:
`JSON.parse_string` возвращает float для КАЖДОГО числа. int64
за пределами 2^53 (9007199254740992) возвращается ОКРУГЛЁННЫМ
→ canonical-текст после parse ≠ исходный → CRC не сходится.
На native и в риге одинаково — production-баг, не артефакт
песочницы. P15 его не видел: 1 ран = seed 20260917 (<< 2^53);
баг проявляется с 2-3-го рана (derived seed).

**Решение.** Формат-уровень (save_data.gd, без изменения
структуры world — SAVE_VERSION остаётся 1):
- canonical: int за пределами ±2^53 пишется как строка
  `"i64:<цифры>"`; в пределах — plain number (старые файлы
  байт-идентичны).
- parse: строки с префиксом `i64:` возвращаются в int — только
  при СТРОГОМ `is_valid_int()` остатка (заметка-строка вида
  «i64:123 is a number» не перетолковывается: остаток не
  целое литерал).
- CRC считается по canonical-тексту → round-trip стабилен.

**Почему не «уменьшить seed».** derived seed — часть A-контракта
P8 (каждый respawn = новый мир; seed deterministically
производный). Сжатие до 2^53/2^31 урезало бы пространство
layouts. Формат-фикс не трогает геймплей.

**Следствия.** Regression: save_data_test (exact round-trip
3569610106698308992 и отрицательного, граница 2^53-1, CRC,
marker-string guard) + edge_cases saves (двойной save после 5
ранов: status ok). Device-строка: открыть save после нескольких
ранов, seeds целы.

## ADR-037 · P17: CampDrop был непикабелен — сигнал + target (2026-09-22)

**Контекст.** §6-строка «полный инвентарь (pickup отказ +
feedback)» не тестировалась никем до P17: P6 проверял
InventoryLogic напрямую, scene-level pickup костра не
покрывался. Свип нашёл, что camp item (единственный
консумабл MVP) **невозможно подобрать**:
1. `signal interacted` — обещан docstring-ом CampDrop и
   подключён в main_scene (`drop.interacted.connect(...)`), но
   **никогда не объявлен** в классе. Connection висела в
   никуда (в риге тихо, на native — ScriptError при каждом
   дропе).
2. Target Interactable = scene root, у которого нет
   `get_body_position()` → distance-poll падает/пуст →
   prompt не показывается даже в принципе.

**Решение.** (camp_drop.gd): `signal interacted(interactable)`
объявлен + форвард из дочернего Interactable
(`_on_interactable_interacted`); `setup(p_item, p_player)` —
target = player (паттерн WeaponPickup). main_scene:
`drop.setup(_CAMP_ITEM, player)`. Lambda сцены — вызов add в
переменную, потом ветка (риг-артефакт: `if add():` в
условии JS-мост перекомпилировал неверно; на native форма
равносильна — переменная безопасна в обоих мирах).

**Почему это важно.** Костёр — ядро «второго шанса» (GDD §9:
heal-консумабл, 3/ран, 1/10 drop). Механика существовала в
данных и в логике, но была отрезана от игрока на последнем
сантиметре (сигнал). Типичный класс дефекта, который ловит
ТОЛЬКО end-to-end sweep (не unit логики, не unit сцены).

**Следствия.** Regression: edge_cases inventory (drop →
pickup в последний слот; drop при полном баге → тост «No room
in the bag.»; мёртвый игрок + drop).
