# QA Phase 13 — Visual polish (ручной pass владельца + mobile-чек)

Дата: 2026-09-20. Состояние: headless-тесты зелёные (unit 819 /
integration 451); ручные чек-листы — для владельца на реальных
устройствах (рендер headless-риг не валидирует — ADR-032 #9).

## A. Визуальный pass (на ПК/Godot, 5+ сцен подряд)

- [ ] **Лагерь:** путь/палатки/монументы/деревья — ткань
      (cloth-текстура) читается, не «мыло»; костёр — единственный
      тёплый источник (ember); палатки: Mara (ember-шарф+hood),
      Orren (grey-blue), Nia (moss), Cartographer (ink) — акценты
      различимы с 10 м.
- [ ] **Комнаты (3 разных run):** пол/стены/рамы — stone/ground
      текстуры; sealed-двери (кольцо+3 зарубки) читаются; роль-
      пропы (disc/beam/table/slab/crate) видны с порога; свет —
      только в комнатах до бюджета (medium = 4), глубинные —
      солнце.
- [ ] **Подвал/арена:** те же материалы; печать (torus) + emission
      в окне ядра; босс — «усталый Eli»: выцветший cloak, hood,
      rust-шарф, фонарь (rust); Remnant — Eli-white + клинок.
- [ ] **Каст:** Eli (hood/scarf/cold-visor) читается сзади и
      спереди; Child — бледный, маленький, «не одет по погоде»;
      THE FIGURE (gate, 30 м) — FRESH-копия Eli (hood/scarf,
      белый); враги: Watcher (высокий, один холодный глаз),
      Forgotten (выбеленный, тёмная «не-лицо»), Mimic (echo-тон,
      emissive-ободок), Hollow (тёмный, красное ядро), Remnant
      (белый, клинок).
- [ ] **Свет/градиент:** мир muted (не «сырой», не «кислотный»);
      туман серый-синий; до босса тёплый свет только у костра;
      после K7 — мир теплее (fog factor, паттерн P10).
- [ ] **UI (все экраны):** toast/notes/inventory/death — единый
      kit (dark matte + parchment + campfire-акцент); нет
      Godot-дефолтных панелей; 20:9 (смартфон) — вёрстка не
      ломается (touch_layout + FULL_RECT); thumb-зоны (joystick
      слева, действия справа, cam-зона свободна).
- [ ] **Камера:** 16:9 → 60°, 20:9 → ~68° (портрет шире);
      sprint — лёгкое приближение (+6°, демпф); стена — FOV-
      компенсация (шире при сближении); shake после hit.
- [ ] **Consistency 5+ сцен:** лагерь → деревня → руины → шахта →
      подвал — один визуальный язык (примитивы+ткань+палитра).

## B. Mobile-чек (Android, §12 — device QA, P16)

- [ ] **Пресеты:** F8 (debug) Low/Medium/High — переключение
      без рестарта; Low: тени off, lights 3, particles 0.5,
      render_scale 0.75; High: тени + 4x4 atlas, lights 6, MSAA 4x.
- [ ] **Свет:** в active-level не больше 4 OmniLight (medium) /
      6 (high) — overlay-проверка (P16 F1-overlay); костёр+комнаты
      не превышают бюджет.
- [ ] **Draw calls:** ≤150 на экран (env ≤90 / chars ≤30 / vfx ≤30,
      §12) — рендер-профайлер на референсе (Snapdragon 7-class).
- [ ] **Текстуры:** ASTC (export preset), 64×64 tileable, 15 КБ
      набора; нет мусорных mip-артефактов на 10 м.
- [ ] **Пост:** только MSAA ≤4x (High), filmic tonemap, лёгкий
      adjustment; нет bloom/SSAO — §12 «no heavy post».
- [ ] **Терм/батарея:** 15-мин сессия — без троттлинга на Medium;
      FPS ≥ 45 (старт), ≥ 30 (пик: подвал+босс, High).
- [ ] **Вёрстка 16:9–20:9 + safe area:** toast/панели не уходят
      под notch/жестовую полосу; touch-зены в thumb-зонах.

## C. Что headless-риг НЕ проверяет (честно, ADR-032 #9)

- Рендер-свойства: Environment.msaa, Viewport.render_scale,
  DirectionalLight3D.shadow_atlas_4x4, Light3D.enabled —
  production-only (сеттеры в rig no-op). Проверяется device-чеком B.
- Визуальное качество материалов/света (только структура:
  «у нода есть material с albedo_texture», tint-математика —
  unit-тестами).
- ASTC/диффузия draw calls — только реальный GPU (P16).

## D. Регенерация и инварианты

- `python3 tools/utils/gen_textures.py` — byte-идентичная
  регенерация (seed зашит); текстуры детерминированы.
- ASSET_STATUS.md — реестр: все визуальные элементы `final`
  (генеративный) или «явно принят» (Ghost); prototype = 0.
- Палитра: grep-чек — нет ad-hoc `_mat(r,g,b)` в room_node /
  camp_world (кроме осознанных исключений — листва).
