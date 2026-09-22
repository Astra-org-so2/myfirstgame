# AFTER YOU — FINAL REVIEW (P19)

**Дата:** 2026-09-22 · **Роль:** независимый senior-аудит перед закрытием MVP.
**Метод:** механический аудит кода/данных/тестов (не «пролистать и
согласиться»): размер/структура скриптов, bare-pass, crash-prone
паттерны, autoload/singleton-аудит, dead-code-скан, data-vs-GDD
согласованность, реестр ассетов, палитра-grep, save-матрица,
локализационное покрытие, release-аудит (check_release 22/22, P18).
Каждый вывод классифицирован: **critical / major / minor / info**.

**Итог:** critical = 0. Найденные major (локализационный слой —
нарушение final lock; 3 ad-hoc цвета вне VisualPalette; тихий
пропуск битых тест-suite в runner) **исправлены в рамках P19**,
регресс-покрытие добавлено. MVP закрыт при задокументированных
known limitations (последний раздел).

**Состояние на момент закрытия:** 138 скриптов / 18 622 строки,
53 тест-suite, 116 data-.tres, 14 сцен. unit **1024/0**,
integration **597/0**. check_release (P18) **22/22**.

---

## 1. Architecture

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 1.1 | Модульная раскладка: `scripts/{world,gameplay/{combat,run,progression,save,enemy,boss},ui,audio,core,player,dev}`, `data/`, `scenes/`, `shaders/`, `audio/`, `tests/`, `docs/`, `tools/`. Гигантских скриптов сверх лимита нет, кроме 1.2. | info | — |
| 1.2 | `main_scene.gd` = **1607 строк** — корень композиции сцены (собирает ~30 систем: world, player, UI-слой, first-run-дирижёр, save-хук, debug-gate). | **major** (known limitation) | Задокументировано; НЕ рефакторится в P19 — риск большого переиспользования на последней фазе; рефактор = отдельная post-MVP фаза с миграционным планом и полным регрессом (см. Known limitations). |
| 1.3 | Autoload = только **EventBus** (7 сигналов). Других singletons нет; системы получают зависимости явно (composition в main_scene). | info | — |
| 1.4 | Data-driven: 116 `.tres` (weapons 4 = 3 архетипа + First Blade narrative, WEAPON_DESIGN §7; enemies; NPC 4 + The Child = 5 по GDD §6.8; areas; quality presets; dialogue/inheritances/mystery; world flags). Новый контент = новый ресурс, без переписывания ядра. | info | — |
| 1.5 | Dead-code: **0** нессылаемых скриптов (скан всех `res://`-ссылок + class_name). | info | — |
| 1.6 | Crash-prone: **0** «голых» `get_node("...")` в game-коде (все — `get_node_or_null` + проверка или композиция). | info | — |
| 1.7 | Bare `pass` = **10** — все проверены по месту: wildcard-ветки match, документированные no-ops (`save_manager:51` — осознанная точка расширения миграций; `first_run_director:203` — A14; ост. — «состояние уже обработано выше»). Ни один не скрывает проблему. | info | — |
| 1.8 | **Локализационного слоя не было** при входе в P19 — нарушение final lock («all strings through the localization layer», «RU data-ready»). 65 уникальных user-visible строк (102 call site) — raw-литералы. | **major** | **Исправлено в P19 (ADR-039):** tr() на всех user-visible строках; `data/loc/strings.csv` (en,ru — RU-драфт, 65/65 заполнено); `tests/unit/localization_test.gd` — двунаправленное покрытие код↔CSV (5 проверок). MVP = EN (tr() без переводов = identity, ноль изменения поведения). |
| 1.9 | Runner молча пропускал suite со сломанной компиляцией (`load()` возвращает non-null и для битого скрипта → 0 проверок без FAIL). | **major** (test infra) | **Исправлено в P19:** guard `has_method("run")` в `tests/runner.gd` = громкий FAIL. |

## 2. Gameplay

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 2.1 | Run/respawn-цикл: seed = `derive_seed` (splitmix64, P8), «what changed» на respawn (≤5 строк, WORLD_STATE_DESIGN §9.2, строки — данные world_flags.tres). Покрыто integration `run_cycle` (якоря первых 30 минут A1–A19/B1–B2). | info | — |
| 2.2 | Оружие: 4 `.tres` = 3 архетипа (blade/staff/cannon) + First Blade (narrative, не архетип) — согласовано с WEAPON_DESIGN §7 и final lock («exactly 3 weapon archetypes»). | info | — |
| 2.3 | NPC: 4 interactable (Mara, Orren, Nia, Cartographer) + The Child (narrative entity, неуязвим по final lock) = 5 — GDD §6.8 «5–7 memorable NPC» в пределах. | info | — |
| 2.4 | Boss (The First, P12): канонические 10 линий, order-фикс, parry/phase-механика — покрыто boss-сьютами (unit + scene). | info | — |
| 2.5 | Дефекты P17 (4) закрыты и покрыты: int64-CRC (ADR-036), CampDrop (ADR-037), `take_hit` при `_dead`, fineness спавна. P19-свип новых gameplay-дефектов **не выявил** (edge_cases-свип 12 сценариев зелёный). | info | — |
| 2.6 | Experimentation не наказывается (странные действия → сцена/диалог/Echo/секрет): механически — mystery-реакции + echo-триггеры + «what changed»; нет penalty-путей. | info | — |

## 3. UX

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 3.1 | Touch-first (P6): тот же input-map для kb/m и touch, touch-слой, layout-тесты на аспектах. UI-kit `data/ui/ui_theme.tres` (P13) используется 5 панелями (toast, death_screen, inventory, note, settings). | info | — |
| 3.2 | Локализация: EN MVP через tr(); RU-драфт готов в CSV; исключены (задокументировано): символы ("!", "X", "· "), имя собственное «VEYRA B», log/push_error-сообщения. Контент data-driven-строк (диалоги NPC, наследия, «what changed») переводится правкой `.tres` — слой тот же. | minor (RU = draft) | Задокументировано; RU-релиз = компиляция .translation в редакторе (2 мин, владелец) + locale. |
| 3.3 | Death→respawn ≤ 10 c (P8, покрыто): screen-оффер → respawn без загрузки. Toast-жизни ≤ 4.5 c, не перекрывают UI-критичное. | info | — |
| 3.4 | Debug-тулзы (F1–F8) отключены в release на уровне creation (P18, ADR-038) — release-бандл не несёт debug-узлы. | info | — |

## 4. Visuals

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 4.1 | ASSET_STATUS: все строки раздела 2 = `final`/«явно принят»; UI-kit `final`. §5 чек-лист P13-экзита — **6/6 закрыто** (P19, с отметками). | info | — |
| 4.2 | 3 ad-hoc material-сайта в `room_node.gd` (seal ring + glow, seal notches ×2, mystery beam + glow) — вне VisualPalette, не документированные исключения. | **minor** | **Исправлено в P19:** 5 новых записей палитры (`seal_ring/seal_glow/seal_notch/mystery_beam/mystery_glow`, значения идентичны старым литералам — ноль визуального изменения); grep-чек `_mat(r,g,b)` вне палитры = **0** совпадений в room_node/camp_world. |
| 4.3 | Текстуры — процедурный генератор `tools/utils/gen_textures.py`, детерминированный; light-бюджеты по quality preset — покрыто visual_scene-тестами. | info | — |
| 4.4 | Рендерер Forward+ (mobile-first): на low-end Android — задокументированный trade-off (см. Release risks). | info (risk) | — |
| 4.5 | Имя файла `placeholder_visual_anim.gd` при финальном визуале (P13) — историческое; переименование = churn без пользы. | info | Задокументировано. |

## 5. Audio

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 5.1 | P14 final: 5 wound-слоёв, 6 ambient-слоёв, stinger, 12 SFX-cue, music director (зоны/вариации). Bus-структура Master/Music/SFX/Ambient покрыта тестами. | info | — |
| 5.2 | Голосов/TTS нет — по дизайну: The Child молчит (final lock — часть мистики), реплики босса/дирижёра = текст (on-screen). | info | — |

## 6. Performance

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 6.1 | Бюджеты §12 зафиксированы тестами (quality_preset + perf_benchmark): frame High ≤16.6 ms (P95 ≤22) / Low ≤33.3 (P95 ≤45); draw calls ≤150/≤120; AI ≤4/≤5 ms; bodies ≤40; particles ≤200/≤100; nodes ≤2000; texmem ≤256/≤192 MB; RAM ≤1.2/≤1.0 GB; cold start ≤8/≤10 s; save ≤50/≤80 ms и ≤5 MB; thermal floor 60/55/30. | info | — |
| 6.2 | Headless-риг не измеряет GPU/thermal/батарею — device QA **открыт** (владелец, ADB-чек-лист RELEASE_BUILD §3). Единственный крупный остаток MVP. | **major** (process) | Задокументировано в Release risks; чек-лист готов. |
| 6.3 | 10-s benchmark (F6) пишет `user://perf_*.txt` — воспроизводимый протокол для device-прогона. | info | — |

## 7. Persistence

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 7.1 | Save `user://save/ay_save.json`: envelope `{format:"ay_save", version, crc32}`; atomic-ish запись + `.bak`; статусы ok/empty/recovered_bak/fresh/newer; карантин `.corrupt_*`; versioned + миграции (migrator покрыт); 5 MB cap (run-history reduction). | info | — |
| 7.2 | P17: int64-маркер `i64:` (ADR-036) — ложная «коррупция» на 2-3-м ране устранена, round-trip стабилен. | info | — |
| 7.3 | `script_export_mode=1` — скрипты в APK читаемы; save **не шифрован**. | minor | Осознанно: в save нет секретов; зашифрование = усложнение без выигрыша (см. Known limitations). |

## 8. Security

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 8.1 | Экспорт: `user_permissions` без INTERNET (оба пресета); нет файлового доступа вне `user://`; нет shell/OS-вызовов; JSON-парсинг везде с invariants-проверками (save_data: 0-panic на мусоре, matrix-тесты). | info | — |
| 8.2 | Debug-gate: в release ни обработчики, ни creation debug-узлов (P18, ADR-038). | info | — |
| 8.3 | Keystores вне git (.gitignore: *.keystore/*.jks/keystore.properties); release-keystore — только на машине владельца (RELEASE_BUILD §2). | info | — |

## 9. Licensing

| # | Находка | Класс | Статус |
|---|---------|-------|--------|
| 9.1 | Все ассеты — из легальных бесплатных источников (Poly Haven → Quaternius → Kenney), per-pack лицензии в `docs/ASSET_LICENSES.md`; icon + текстуры — процедурные (генераторы). 0 ассетов с неизвестным происхождением. Бюджет 0 ₽ сохранён. | info | — |
| 9.2 | `data/loc/strings.csv` — оригинальный контент проекта; RU-переводы — наша работа (draft). | info | — |

## 10. Known bugs

| # | Бад | Класс | Статус |
|---|-----|-------|--------|
| 10.1 | int64 > 2^53 в save → ложная crc-mismatch (2-й+ ран) | major (был) | **Закрыт в P17** (ADR-036) + регресс. |
| 10.2 | CampDrop непикабелен (нет сигнала/target) | major (был) | **Закрыт в P17** (ADR-037) + регресс. |
| 10.3 | `take_hit` при `_dead`; fineness спавна | minor (были) | **Закрыты в P17** + регресс. |
| 10.4 | Отсутствие локализационного слоя (final lock) | major | **Закрыт в P19** (ADR-039) + покрытие. |
| 10.5 | 3 ad-hoc цвета вне VisualPalette (room_node) | minor | **Закрыт в P19** (5 записей палитры, grep=0). |
| 10.6 | Тихий пропуск битых тест-suite в runner | major (test infra) | **Закрыт в P19** (has_method-guard). |
| 10.7 | Риг: GDScript без `Dir/RegEx/RegExMatch`, без `String.is_lower/is_upper`; boot-time class-cache падает на вызове в continuation-line внутри многострочного `PackedStringArray([` в class_name-скрипте. | info (sandbox) | **Ограничение ригов, не движка** — обходы: DirAccess + строковый скан (тест), вызовы на одной строке (gate-футноуты). Зафиксировано в ADR-039. |

## 11. Release risks

| # | Риск | Вероятность/влияние | Митигация |
|---|------|--------------------|-----------|
| 11.1 | **Device QA не пройдёт** (GPU/thermal/память на реальном Android; риг ≠ device) | средняя / высокая | ADB-чек-лист RELEASE_BUILD §3 (собственник); perf-протокол F6; quality Low preset как страховка; бюджет §12 зафиксирован тестами. |
| 11.2 | Forward+ на low-end Android | средняя / средняя | Low preset (тени/лимиты частиц), device-проверка в 11.1. |
| 11.3 | iOS (вторичная цель) | низкая (MVP не блокирует) | Отложено; архитектура (ADR-021) позволяет отдельную фазу. |
| 11.4 | RU-релиз: CSV = draft, .translation не скомпилирован | низкая | 2-минутный шаг в редакторе + locale (документировано); EN MVP от этого не зависит. |
| 11.5 | APK-size рост при добавлении контента | низкая | Сейчас 64.7 MB ≪ 2 GB; exclude_filter tests/tools/docs. |

## 12. Known limitations (задокументированы, не блокируют MVP)

1. **`main_scene.gd` 1607 строк** — корень композиции сцены. Рефактор
   только post-MVP отдельной фазой: план, миграция, полный регресс
   (1024+597) — на финальной фазе риск > пользы.
2. **Save не шифрован, `script_export_mode=1`** — в save нет секретов;
   читаемость APK-скриптов — свойство Godot-экспорта (безопасно для
   этого контента), усложнение нецелесообразно.
3. **RU = draft** (CSV); EN — язык MVP.
4. **Голосов/TTS нет** — по дизайну (тишина The Child — часть мистики).
5. **iOS отложен** (вторичная цель).
6. **Device QA открыто** — единственный крупный остаток; чек-лист
   готов (RELEASE_BUILD §3).
7. **Имя `placeholder_visual_anim.gd`** — историческое, визуал final.
8. **Риг-ограничения** (п. 10.7) — влияют на написание кода в
   песочнице: не использовать Dir/RegEx в скриптах, вызовы в
   многострочных списках — на одной строке (class_name-скрипты).

## 13. P19: что сделано (итог фазы)

1. Механический аудит по всем разделам (объём: 138 скриптов, 116
   ресурсов, 53 сьюта, 14 qa-чек-листов).
2. **Major-фикс: локализационный слой** (ADR-039): 102 tr()-вызова,
   65 ключей, `data/loc/strings.csv` (RU draft 65/65),
   `localization_test.gd` (5 проверок, двунаправленное покрытие).
3. **Minor-фикс: VisualPalette** — 5 записей (seal/mystery),
   ad-hoc-цвета room_node = 0.
4. **Test-infra-фикс: runner** — громкий FAIL вместо тихого пропуска
   битых сьютов.
5. Чистка: 2 мёртвых конста (LINE_A14, LINE_ARCHIVIST_NPC — дубли
   WEAPON_LINES / main_scene-тоста).
6. Закрыт §5 ASSET_STATUS (6/6).
7. ADR-039, FINAL_REVIEW.md, ROADMAP v1.9.

**Выход P19:** review закрыт; known limitations задокументированы
(раздел 12); critical = 0; unit 1024/0, integration 597/0,
check_release 22/22. **MVP завершён.**
