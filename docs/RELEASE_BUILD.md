# AFTER YOU — RELEASE_BUILD (Phase 18, Android)

Первичная платформа — **Android** (ADR-021). Эта инструкция —
мост между песочницей и устройством: всё, что песочница НЕ может
сделать (фактический сбор APK — ADR-012/§15.5), выполняется
владельцем по шагам ниже. Конфигурация экспорта (пресеты,
version strings, иконка, exclude-фильтры, signing-политика) —
готовая и в git.

## 0. Что где (честное разделение)

| Где | Что |
|---|---|
| Песочница (git) | `export_presets.cfg` (2 пресета), version strings (`project.godot`: `config/version=0.1.0`, `package` в пресетах), `icon.png` (процедурная, ADR-ASSET_LICENSES), `tools/check_release.py` (readiness-аудит, проходит в песочнице), signing-политика (keystore НЕ в git — `.gitignore`) |
| Владелец (машина + устройство) | Android SDK/JDK, keystores, фактический `--export-debug`/`--export-release`, ADB-QA-прогон, верификация Exit-чек-листа |

## 1. Предварительные установки (однократно)

1. **Godot 4.7.2-stable STANDARD** (не .NET, не mono) +
   **Export Templates 4.7.2** (Editor → Manage Export Templates).
2. **JDK 17** (LTS): `java -version` → 17.x.
3. **Android SDK**: Android Studio (или cmdline-tools) с
   - Platform-Tools (adb),
   - Platforms: Android 34 (API 34 — target),
   - Build-Tools 34.x.
4. В Godot: **Editor Settings → Export → Android** →
   `android_sdk_path` (папка SDK) + `java_path` (JDK).
5. Проверка: Godot Editor → Project → Export → Android —
   пресеты «Android QA» и «Android» подхватываются без ошибок.

## 2. Signing (секреты НЕ в git — §15.3)

**Debug (для ADB-QA)** — генерируется Android Studio:
`Tools → Android → Create Android Keystore` → файл, например,
`~/android-keystores/debug.keystore` (алг. RSA-2048, CN=debug).
В Godot: Editor Settings → Export → Android →
`keystore/debug_keystore` = путь, пароль/alias — как создано.

**Release** — отдельный keystore, создаётся ОДИН РАЗ и
сохраняется в надёжном месте (НЕ в git, НЕ в проекте):
```bash
keytool -genkey -v -keystore after_you_release.keystore \
  -alias after_you -keyalg RSA -keysize 2048 -validity 10000
```
Путь + пароли — локально/в CI env vars. Потеря release-keystore
= невозможность обновлений в магазине: бэкап обязателен.

## 3. СБОРКА DEBUG-APK (ADB-QA) — первый шаг

```bash
# из корня репозитория
godot --headless -path . --export-debug "Android QA" \
    export/builds/after_you_qa.apk
```
(или Editor → Project → Export → Android QA → Export Project).
Результат: `export/builds/after_you_qa.apk` (в gitignore).

Установка:
```bash
adb install -r export/builds/after_you_qa.apk
adb shell am start -n after.you.qa/com.godot.game.GodotActivity
```

### ADB-QA прогон (Exit-чек-лист ROADMAP P18)

- [ ] **APK стартует** на референс-устройстве (SD7/8 GB — High;
      SD6xx/4 GB — Low), до playable ≤8/10 s (cold start, §12).
- [ ] **Проигрывает**: RUN 1 (30 мин) до первой смерти,
      death screen, respawn, RUN 02.
- [ ] **Save/load**: смерть + выбор → save (user://), перезапуск
      APK → мир восстановлен (flags/inheritances/NPC/notes/runs),
      tост-матрица P15 не нарушена.
- [ ] **0 debug-остатков**: F1/F6/F8/F9 НЕ работают в release
      (см. п. 5); в QA-сборке F1-оверлей и F6-benchmark РАБОТАЮТ
      (это и есть QA-инструменты: PERF_REPORT §2).
- [ ] **Touch**: кнопки (joy + действия) в safe area, landscape
      на всех аспектах 16:9–20:9, notch не режет UI
      (qa_phase17 §C/§E).
- [ ] **Perf-протокол** (PERF_REPORT §2): F1-оверлей + F6
      (10 c → `user://perf_<area>.txt`) → `adb pull` → цифры
      в PERF_REPORT (High: 60 fps mid-range; Low: 30 fps
      low-end floor; thermal 30 мин).
- [ ] **Backgrounding**: свайп в фон на 10+ c и обратно —
      run clock не прыгает, мир когерентен (proxy пройден в
      песочнице, P17).
- [ ] **Логи**: `adb logcat | grep -E "ERROR|SCRIPT ERROR"` —
      0 script-ошибок в типовом сценарии.

## 4. СБОРКА RELEASE-APK

```bash
godot --headless -path . --export-release "Android" \
    export/builds/after_you.apk
```
Проверить `package/version`: `0.1.0` (code 1) — при каждом
релизе `version/code` +1 (магазин требует монотонность).

## 5. Верификация release-сборки (0 debug-остатков)

- [ ] F1/F6/F8/F9 — мёртвы (guard `OS.is_debug_build()` в
      обработчиках + **creation guard** P18: узлы DebugOverlay/
      PerfBenchmark в release не создаются вообще).
- [ ] В APK нет `tests/`, `tools/`, `docs/`
      (exclude_filter пресетов: `tests/*,tools/*,docs/*`).
- [ ] `scripts/dev/` (perf_benchmark) и `scripts/ui/
      debug_overlay.gd` в бандле только как зависимости
      main_scene (preload — нельзя исключить без code change;
      они инертны: не создаются, не подключены).
- [ ] Иконка — костёр (icon.png), версия 0.1.0, название
      «AFTER YOU».
- [ ] APK-size: см. оценку ниже (≤ ~2 GB — §15.2, с огромным
      запасом: ассеты 4.8 МБ → APK ~50–80 МБ вместе с
      Godot-шаблоном).
- [ ] Landscape-lock, immersive, safe area.

## 6. Troubleshooting (частое)

| Симптом | Причина / лечение |
|---|---|
| `Android build failed` + gradle errors | JDK 17 не подхватился: Editor Settings → Export → Android → `java_path`; `JAVA_HOME` |
| `Keystore not found` | путь в Editor Settings → Export → Android (не в пресете — пресеты секреты не хранят) |
| `minSdk` complaint на старом устройстве | minSdk 26 (Android 8.0) — §15.2; устройство новее |
| F1 не открывается в QA-сборке | убедитесь, что это `--export-debug` (не release): debug-тулзы только в debug-сборке |
| APK не ставится | `adb install -r`; package `after.you` vs `after.you.qa` не конфликтуют |
| Экспорт «no export template» | Templates 4.7.2 не установлены (п. 1.1) |

## 7. CI (когда появится)

- Job 1 (песочница/CI Linux): `tools/run_tests.sh unit` +
  `integration` + `tools/check_release.py` — всё headless.
- Job 2 (нужен Android SDK): `--export-release` + размер/
  `aapt dump badging` (version, permissions) — артефакт в
  release.
- ADB-QA — НЕ в CI: на устройстве владельца (§15.3).
