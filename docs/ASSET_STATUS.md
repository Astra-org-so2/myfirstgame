# ASSET_STATUS — реестр статусов визуальных и аудио-элементов

Трекер из ADR-005 (text-first): каждый визуальный элемент помечен
`final` (генеративный, осознанный стилистически — примитивы/текстуры/
материалы, построенные из данных проекта) или `prototype` (заглушка,
требует закрытия). Замена на импортированные CC0-ассеты —
инкрементальна через data-поля, без переписывания сцен.

Правила:
- `final` = осознанный стилистический выбор (не «пока что»).
- `prototype` = MUST закрыться до выхода из фазы, где элемент в scope
  (P13 — визуальные элементы, P14 — аудио).
- «Явно принят» = элемент остаётся простыней/примитивом по решению
  дизайна (записано здесь, с причиной).
- Регенерация: `python3 tools/utils/gen_textures.py` (детерминированно,
  byte-идентично — seed зашит в скрипт).

## 1. Мир (сгенерировано из данных)

| Элемент | Где | Статус | Примечание |
|---|---|---|---|
| Полы/стены/дверные рамы комнат | room_node.gd | **final** (P13) | палитра WORLD_BIBLE §1 + текстуры stone/ground |
| Обstacles/слайбы | room_node.gd | **final** (P13) | stone_dark |
| Роль-пропы (disc/beam/table/slab/crate) | room_node.gd `_prop` | **final** (P13) | один проп = идея комнаты (ENV_STORYTELLING §3); wood/stone |
| RoomLight (в пределах light-бюджета) | room_node / zone_world | **final** (P13) | бюджеты 3/4/6 по preset (§12); сверх бюджета узла нет |
| Печати sealed-дверей | room_node.gd `_seal` | **final** | тёмное кольцо + 3 зарубки (A16) |
| Путь/палатки/монументы/деревья лагеря | camp_world.gd | **final** (P13) | ground/cloth/stone/wood_dark; листва flat (локальный декор) |
| Костёр (кольцо/бревна/угольки/ядро) | scenes/world/Bonfire.tscn | **final** (P13) | ember из палитры; единственный тёплый источник до босса |
| Стол с кружками, столб, столбик с запиской, самовар | CampWorld + NoteStand/Pillar/Kettle tscn | **final** | примитив-модели, стилистика лагеря |
| ZoneMarker/ZoneGates (8) | CampWorld + ZoneMarker tscn | **final** | stone-текстура |
| Watchtower / GateSilhouette (силуэты на горизонте) | tscn | **final** | WORLD_BIBLE §3.2 — читаются сквозь туман |
| Sky/fog/environment (WorldEnvironment) | scenes/main.tscn | **final** (P13) | filmic tonemap, серый-синий туман; color grade = P13-батч 1 |
| Sun (DirectionalLight3D) | scenes/main.tscn | **final** | тёплый низкий свет; тени по preset |
| Текстуры stone/stone_dark/ground/wood/wood_dark/cloth/rust | assets/textures/*.png | **final** (P13) | gen_textures.py, 64×64 tileable, seed зашит |
| fog_soft (мягкий alpha-блот) | assets/textures/fog_soft.png | **final** (P13) | зарезервирован для K5-шимера (P14-визуал) |
| Подвал/арена босса (комнаты) | data/areas/undercroft.tres + room_node | **final** | те же примитивы, роль-пропы арены |

## 2. Персонажи

| Элемент | Где | Статус | Примечание |
|---|---|---|---|
| Eli (игрок) | Player.tscn + placeholder_visual_anim.gd | **final** (P13) | hood+scarf+visor (CharacterVisual); cloth-текстура, канонический cloak-тон |
| NPC (Mara/Orren/Nia/Cartographer) | npc_node.gd + Mara.tscn | **final** (P13) | hood+scarf (акцент = идея персонажа, data); cloth; Mara = camp-look |
| The Child | world_child.gd | **final** (P13) | child_pale + cloth; инволибилити — не визуал |
| THE FIGURE (gate) | first_run_director.gd | **final** (P13) | eli_fresh (FRESH-копия, GDD §8) + hood/scarf — читается как Eli с 30 м |
| Враги (5 архетипов) | enemy_controller.gd | **final** (P13) | cloth + сигнатурный акцент (eye/core/blade); Mimic = echo-tint (§1.1) |
| THE FIRST (босс) | boss_controller.gd | **final** (P13) | worn-Eli (wear 0.55) + hood + rust-шарф + rust-фонарь |
| Remnant (миньон фазы 2) | boss (P12) | **final** (P13) | Eli-white cloth + blade (как есть по §2.2) |
| Ghost (эхо-реконструкция) | ghost_controller.gd | **явно принят** | полупрозрачный силуэт игрока — осознанный минимализм (эхо = память, не персонаж) |

## 3. UI

| Элемент | Где | Статус | Примечание |
|---|---|---|---|
| Все панели (toast/inventory/note/death/dialogue) | scripts/ui/* | **final (структура)** | не Godot-дефолт: StyleBoxFlat, свои цвета, FULL_RECT |
| Единый UI-kit (общие цвета/радиусы/шрифты) | scripts/ui/ | **prototype → final (P13-батч 3)** | сейчас цвета ad-hoc per-screen; батч 3: kit + чек 20:9 |
| Touch-layout (joystick/cam/actions) | touch_layout.gd | **final** | normalized 16:9–20:9 + safe-area + thumb-зоны (ADR-021) |

## 4. Аудио (P14 закрыт)

| Элемент | Где | Статус | Примечание |
|---|---|---|---|
| «The Wound» ×5 вариаций (Normal/Memory/Echo/Archivist/Ending) | assets/audio/wound_*.wav | **final** | процедурная (gen_audio.py, seed, byte-стабильно), 11025 Hz, ~24 c loop, GDD §7 |
| Ambient-слои (camp/wild/stone/mine/lake/undercroft) | assets/audio/amb_*.wav | **final** | там же; 16 c loop, seam crossfade; зоны делят слои (wild: деревня/башня/мост; stone: храм/врата) |
| Stinger (boss reveal) | assets/audio/stinger.wav | **final** | там же; 4 s one-shot |
| SFX (12 кью: swing/hit/riposte/hurt/shot/pickup + door/seal/death/note/ui/echo) | sfx_library.gd | **final** | процедурные в рантайме (математика, seed, детерминированно) |
| AudioManager (buses Music/SFX/Ambient, crossfade, stinger, settings) | scripts/audio/ | **final** | P14: ADR-033; settings-экран = settings_panel (F9 debug) |

Примечание: «prototype-статус» SFX из P4 снят в P14 — полная сетка кью +
маршрутизация в SFX-бус + уровни/мьют в settings. Голосовые реплики —
текст (toast/death screen), не аудио (MVP без TTS/войса — осознано).

## 5. Чек P13-экзита (визуал)

- [ ] Все строки раздела 2 = `final` или «явно принят» (батч 2)
- [ ] UI-kit (раздел 3) = `final` (батч 3)
- [ ] Цвета структур мира только из VisualPalette (grep-чек: нет ad-hoc `_mat(r,g,b)`
      в room_node/camp_world, кроме осознанных исключений)
- [ ] Light-бюджеты по preset (тесты visual_scene)
- [ ] Текстуры — только из assets/textures (генератор), детерминированно
- [ ] QA: tests/qa/qa_phase13_visual.md + мобильные чек-листы
