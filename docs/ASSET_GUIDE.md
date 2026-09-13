# AFTER YOU — Asset Guide (pipeline, лицензии, качество)

Версия: 0.1 (Phase 0). Критически важный документ — лицензионная
безопасность — часть Definition of Done.

---

## 1. Политика

1. Только легально распространяемые бесплатные ассеты. Приоритет:
   **Poly Haven → Quaternius → Kenney →** другие с явной свободной лицензией.
2. Для КАЖДОГО внешнего ассета — запись в `docs/ASSET_LICENSES.md`
   (шаблон §6). **Нет записи — ассет не используется.**
3. Лицензия неизвестна → ассет не используется (без исключений).
4. Запрещены: ripped-ассеты, ассеты из коммерческих игр, ассеты с
   непонятным происхождением, «free packs» без лицензии, платные
   подписочные сервисы.
5. Каждый ассет = gameplay- или visual-назначение. Нет ассет-спама.

## 2. ⚠ Ограничение среды (важно, ADR-006)

Разрабатывающая песочница имеет **ограниченный сетевой доступ**
(проверено: доступны только GitHub, PyPI, npm-реестры). Сайты-источники
(Poly Haven, Quaternius, Kenney, Freesound, Pixabay, OpenGameArt) из
песочницы **недоступны**.

Стратегия снабжения (по приоритету):
1. **Процедурный/текстовый ассет** (см. §7) — создаётся кодом, без
   скачивания: primitive-модели, `.tres`-материалы, генерируемые
   текстуры (`.ctex`), генерируемые SFX-заглушки (см. ниже). Это
   основной путь развития в песочнице на всех фазах.
2. **GitHub-зеркала CC0-пакетов** — часть авторов публикует пакеты на
   GitHub (проверять лицензию в самом репо: LICENSE-файл/README).
   Кандидатов искать точечно под нужду фазы, не массово.
3. **Загрузка владельцем проекта** — владелец скачивает пакет на своей
   машине (с сайта-источника) и кладёт в `assets/inbox/` + заполняет
   лицензионную запись. Песочница принимает и встраивает.
4. Только если 1–3 не подходят — пересмотреть дизайн-потребность
   (может, ассет не нужен).

## 3. Источники и лицензии (реестр)

| Источник | Лицензия | Что берём | Примечание |
|---|---|---|---|
| Poly Haven (polyhaven.com) | CC0 | HDRI (forest dusk/night), PBR-текстуры (bark, stone, moss, wood, dirt), пропы (если CC0) | Каждый ассет — отдельная запись |
| Quaternius (quaternius.com) | CC0 | rigged-персонажи/твари, fantasy-пропы, анимации | Проверить наличие нужного набора анимаций (idle/walk/run/attack/dodge/hit/death) |
| Kenney (kenney.nl) | CC0 | UI-наборы, простые 3D-пропы, placeholder-окружение | Kenney UI — база для Phase-13 полиша |
| Freesound (freesound.org) | CC0 / CC-BY (per-item) | footsteps, hits, ambient | CC-BY → обязательная атрибуция в credits + запись |
| Kevin MacLeod (incompetech.com) | CC-BY 4.0 | музыка (exploration, combat, stinger) | Атрибуция: «Kevin MacLeod (incompetech.com)» |
| Pixabay Music (pixabay.com) | Pixabay License (free commercial, attribution not required) | музыка (резерв) | Лицензия проприетарная, но разрешает коммерческое использование без атрибуции — фиксировать версию лицензии на дату загрузки |
| OpenGameArt.org | смешанные (per-item) | запасные SFX/модели | Только per-item-лицензия CC0/CC-BY с записью |

## 4. Выбор персонажа (Phase 2, критичный актив)

Требования: rigged humanoid, CC0, анимации: idle, walk, run, dodge/roll,
attack (melee 1–2), hit, death. Риг совместим с Godot 4 (FBX → Godot
import, skeleton retarget-friendly).
Процедура выбора:
1. Кандидаты из Quaternius (персонажные пакеты) + Kenney (простой запас).
2. Импорт 2–3 кандидатов → проверка: skeleton (имена костей, scale),
   качество анимаций, retarget, визуальная совместимость со стилистикой
   (stylized realistic — не cartoon-flat, не hyper-real).
3. Финал: 1 персонаж + 1 запасной; запись в ASSET_LICENSES.md.
4. Fallback (если подходящий rigged-набор не найден): стилизованный
   low-poly персонаж из примитивов с процедурными анимациями (bone-
   tweening) — допустим ВРЕМЕННО (помечен ADR-005), финальный персонаж
   обязателен до Phase 13.

## 5. Environment-пайплайн (Forgotten Forest)

- Modular workflow: floor-плиты (paths/grass/moss), стены/обломки (ruins),
  rocks, trees (3–5 видов), bushes, props (log, barrel, brazier, shrine-
  parts), doors, furniture (cabin), landmarks (chapel, stone circle,
  dead lake).
- Каждый модуль: pivot на земле, ориентация Y-up, масштаб в метрах
  (человек ≈ 1.8m), collision — отдельный низкополигональный (не из
  визуальной модели), LOD0/LOD1 (дальние деревья — billboard/low),
  Multimesh-совместим (одна модель — инстансы).
- Текстуры: PBR от Poly Haven (bark/stone/moss/dirt/wood) → атласы/
  tile-наборы; density: 1024px (High) / 512px (Low); roughness-маппинг
  один на палитру биома.
- Палитра: единая color-grade (пост-Phase 13): desaturated greens/greys
  base + warm accent (firelight) + cool ghost-blue (memory). Все
  материалы проходят «palette pass» — ручной чек против референс-
  палитры (docs/refs/palette.png — создаётся в Phase 3).
- Свет: 1 DirectionalLight (луна/туманное солнце) + ambient (Sky/HDRI) +
  локальные PointLight'ы (факелы/костры — ≤6 на локацию, Low: 0,
  baked-альтернатива через emissive+decal). Volumetrics — туман
  (Fog + height-fog), не God-ray'ы (дорого).

## 6. Шаблон записи ASSET_LICENSES.md

```
## <asset_name> (<категория>)
Asset: models/quaternius/<file>.fbx
Creator: <имя>
Source: <URL страницы/файла>
License: CC0 1.0
Commercial use: Yes
Attribution required: No
Modification allowed: Yes
Notes: <дату загрузки, хэш sha256 файла, что модифицировано>
```
+ `docs/ASSET_LICENSES.md` ведётся с первого внешнего ассета (Phase 2/3).

## 7. Text-first asset policy (песочница, ADR-005)

Чтобы проект развивался И протестирован был в песочнице (без редактора
Godot, без импорта бинарных ассетов — импортные продукты `.ctex`/`.scn`
создаёт редактор, которого в песочнице нет), MVP-арт строится на:
- **Primitive-модели** (BoxMesh, CylinderMesh, SphereMesh, CapsuleMesh,
  QuadMesh, CSG) — чистые `.tscn/.tres` (текст);
- **`.tres`-материалы** (StandardMaterial3D: color/emissive/roughness/
  normal-из-текстур-генерации) — текст;
- **Генерируемые текстуры**: `tools/utils/gen_ctex.py` создаёт валидные
  `.ctex` (container format, base64-встроенные данные) — solid/gradient/
  noise-паттерны для prototype; `tools/utils/wav_to_strm.py` конвертирует
  WAV→`.strm` (imported audio format) — аудио в headless-риге;
- **Визуальный «запас»**: stylized-видимость достигается композицией
  (свет/туман/палитра) даже на примитивах.
- Замена на импортированные ассеты (GLTF/textures/audio) — инкрементальна:
  модель сцены не меняется (SceneRef-интерфейс: `model_scene` в
  RoomData/EnemyData/ItemData), владелец проекта делает импорт в редакторе
  (на ПК), песочница-риг продолжает работать (файлы импорта —
  текстовые ссылки; отсутствующие `.ctex` в риге — fallback-материал +
  push_warning, не crash).

Это НЕ «fake features»: это реальный артворкфлоу с явным prototype/
production-статусом материалов; каждый визуальный элемент либо финальный
(генеративный, стилистически осознанный), либо помечен как prototype-
заглушка в docs (статус-трекер ASSET_STATUS.md — создаётся в Phase 3).

## 8. Аудио-пайплайн

- SFX: WAV 44.1k stereo (≤2s) → `.strm` (конвертер tools/utils).
- Music/ambience: OGG Vorbis (44.1k stereo).
- Генерируемые заглушки (пока нет финальных): tone-based SFX
  (синус/шум, огибающая) через `tools/utils/gen_sfx.py` → WAV → `.strm`.
  Помечены prototype (ASSET_STATUS.md).
- Финальные: Freesound (CC0/CC-BY) / Kevin MacLeod — по §2/§3.

## 9. Контроль качества (чеклист на каждый ассет, перед коммитом)

- [ ] Лицензия проверена и записана (ASSET_LICENSES.md)
- [ ] Scale/pivot/orientation по конвенции §5
- [ ] Collision — отдельный, валидный
- [ ] Текстура: разрешение по бюджету, компрессия, mipmaps
- [ ] Материал: roughness/metalness — по палитре биома (palette pass)
- [ ] Анимации: retarget, тайминги по геймплей-данным
- [ ] Производительность: triangles < бюджета (враг ≤ 8k, проп ≤ 1k,
      дерево ≤ 2k), textures < бюджета
- [ ] Видимость в сцене (не «парит» в воздухе, не Z-fighting)
