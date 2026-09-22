# QA Phase 15 — Save/load/recovery (ручной pass владельца)

Дата: 2026-09-22. Состояние: headless-тесты зелёные (unit 995 /
integration 523). Матрица восстановления покрыта unit-тестами
(save_manager_test) + kill-mid-write; device-QA (P16) — поведение
на реальном Android-файловике.

## A. Матрица восстановления (покрыто unit, ручная проверка — device)

| Ситуация | Поведение | Тост |
|---|---|---|
| Нет файла (первый запуск) | `empty`, свежий мир | — |
| Валидный save | `ok`, мир + настройки восстановлены | — |
| Save битый, .bak валиден | `recovered_bak`, .bak поднят в live, битый → `.corrupt_corrupt` | «The world remembers. (save restored)» |
| Save и .bak биты | `fresh`, оба сохранены (`.corrupt_*`), свежий мир | «The world started over. (save was lost)» |
| Save от более новой версии | `newer`, файл НЕ тронут, meta из .bak/defaults | «A newer save was kept. (new world)» |
| Kill во время записи (partial .tmp) | старый файл выигрывает, .tmp игнорируется, следующий save его зачищает | — |

## B. Точки автосохранения (TECH_DESIGN §3.5)

- [ ] **Смерть + выбор наследования** — save сразу после выбора
      (перманентный факт); тост «The world remembers.»
- [ ] **Возврат в лагерь** (safe hub) — тихий save (первый вход
      сессии не считается — сохранять ещё нечего).
- [ ] **Закрытие окна** (WM_CLOSE_REQUEST) — тихий save.

## C. Содержимое (device)

- [ ] WorldState: flags, inheritances (уровни), weapons, NPC
      (alive/trust/interactions), notes (4 stands), mystery
      progress, runs (full + summaries).
- [ ] Settings: quality tier (low/medium/high) + аудио
      (master/music/sfx/ambient + mute) — применяются при старте.
- [ ] 5 MB hard cap: переполнение runs → самые старые full
      сведения в summaries (log), файл не пишется только если
      cap не снять.
- [ ] CRC32: любой бит в файле → crc_mismatch → матрица A.

## D. Mobile (device QA, P16)

- [ ] Размер save на референсе (ожидание: < 200 KB при 10–15
      ранах; runs-секция — рост).
- [ ] Влияние записи на frame (ожидаемо: незаметно — один файл
      < 1 МБ, запись вне physics-тиков).
- [ ] user:// на Android (app_userdata) — нет проблем с правами.
- [ ] Crash-тест: убить процесс между save-точками (adb kill) ->
      следующий старт по матрице A.

## E. Что headless НЕ проверяет (честно)

- Реальные POSIX-свойства atomarности rename на конкретном
  Android-файловике (ext4/f2case) — unit проверяет семантику
  (tmp + rename + partial), device проверяет физический носитель.
- Поведение при заполненном хранилище (ENOSPC) — не симулируется.

## F. Изоляция тестов

- Интеграционные сцены под harness'ом (main scene != current
  scene) получают изолированный save (уникальный путь, чистится
  при выходе сцены) — без перетока состояния между сьюитами.
- save_scene_test (death→save→reload) использует общий путь через
  seam `save_path_override` (ставится до add_child).
