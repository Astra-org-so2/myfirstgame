# QA Phase 4 — Combat (BLADE)

Цель: «бой ощущается хорошо» (exit-criterion — чек-лист, не мнение):
hit-stop/shake/impact по каждому типу удара читаемы, combo-цепочка
«хрустит», Riposte — тайминг-действие, урон по игроку читаем
(vignette + shake + hitstun). Риг-покрытие: 325 проверок (37 из них —
integration combat_scene: одиночный удар 25, full combo 80, урон по
игроку с hitstun/vignette, i-frame block, Riposte (stun 1.5 s + 15 dmg
+ CD 30 s), смерть → EventBus → auto-respawn, stun-блок атак; unit:
weapon_data 14, weapon_logic 13, damage_resolver 11, combat_utils
(hitstop/vfx-pool/процедурные SFX) 14). Риг без рендера/физики/звука
(ADR-002/022/023): feel, звук, 60 fps — только редактор/устройство.

## A. ПК-редактор (Godot 4.7.2, F5)

Вход в бой: тестовые мишени не в игре (по ROADMAP) — для feel-чека
используй debugger (пока без DebugTools-фаза): в Scene-панели или
через «remote debug» создать тестовую цель, ЛИБО вставь временную
`TestDummy` (капсула + CombatTarget + register в DamageResolver) —
код-референс: tests/integration/combat_scene_test.gd (`_dummy`).

- [ ] Запуск без ошибок в Output (вкл. отсутствие скрипт-ошибок).
- [ ] Игрок стартует на точке спавна (кромка тропы, столб A2 впереди).
- [ ] LMB — U1 (прямой): 0.25 s windup → arc-hit; звук swing; при
      попадании — hit-flash + «thud» + микро-фриз (~0.05 s) +
      лёгкий shake камеры. Урон 25.
- [ ] U1→U2→U3 (цепочка в окне 0.5 s): U2 — дуга 120°, U3 — длинный
      выпад (range 2.6 m, 30 dmg). Полная цепочка = 80.
- [ ] Celah (пауза > 0.5 s) — комбо сбрасывается на U1.
- [ ] Не хватает stamina (10/удар, sprint-косты) — удар не стартует
      (нет «пустого» windup).
- [ ] R — Riposte: пинг-подготовка, окно 0.5 s. Удар по игроку В
      окне: игрок всё равно получает урон, атакующий — stun 1.5 s +
      15 dmg (counter-вспышка холодная, ping-звук). Вне окна —
      окно закрывается тихо. CD 30 s.
- [ ] Урон ПО игроку: red-vignette flash, shake сильнее, hitstun
      0.35 s + knockback (контроль потеряно), звук hurt. HP-счёт —
      пока нет UI (Phase 8+): для чека — debugger (player.combat.hp).
- [ ] Dodge (Space) — i-frames [0.05, 0.25] блокуют урон (атака в
      окне не снимает HP, не даёт hitstun).
- [ ] Смерть (0 HP): смерть → ~2 s → respawn на точке спавна, HP
      полный, combo/CD сброшены. EventBus.player_died/player_spawned
      (debugger: слушатели).
- [ ] Regression Phase 2/3: движение/камера/touch, лагерь,
      интеракты-прототипы — не сломаны.

## B. Android-устройство (debug-экспорт)

- [ ] Тач: ATK-кнопка — удары/комбо (нажатия-дурочки без
      задержек), SPC-кнопка — Riposte, DODGE — i-frames;
      джойстик + ATK одновременно (мульти-тач).
- [ ] 60 fps в бою (серия ударов + движение), просадок на
      hit-stop нет (это логика, не физ).
- [ ] Звук: swing/hit/riposte/hurt слышны, без клиппинга, не
      «затопляют» (пока нет музыки).
- [ ] 5 минут боя: температура не ощутимо растёт (VFX-пул 8
      инстансов, 1 OmniLight).
- [ ] Aspect 20:9: SPC-кнопка в safe area, не перекрыта.

## C. Feel-матрица (фиксация в PERF_REPORT Phase 16)

| Действие          | Ожидание (baseline)                                        | OK? |
|---|---|---|
| Hit-stop (hit)   | 0.05 s — ощущается как «взвешенность», не «лаг»           |     |
| Hit-stop (kill)  | 0.1 s — акцент, без «фриза игры»                          |     |
| Shake (hit)      | 0.08 — камера «подрагивает», не тошнит                    |     |
| Shake (hurt)     | 0.15 — ощутимо, читаемо                                    |     |
| Vignette (hurt)  | 0.45 alpha, fade 0.35 s — «красный пульс», не заслоняет   |     |
| Swing-звук       | 0.3 s whoosh — до удара (anticipation)                    |     |
| Hit-звук         | 0.18 s thud — одновременно с hit-stop                     |     |
| Combo-темп       | 1.2/1.2/1.5 s — цепочка «хрустит», U3 — акцент            |     |
| Riposte-окно     | 0.5 s — «очный» тайминг, промах не наказывается (CD есть) |     |

Тюнинг: цифры — baseline (data: blade.tres, hitstop в weapon_data) —
корректировать ПО матрице, не наугор (Phase 16 фиксирует финал).

## KNOWN (осознанные ограничения фазы)
- Сторонники (мишени) — только test-объекты в tests/ (ROADMAP:
  «не временные враги — test-объекты в tests/, не в игре»);
  живые враги — Phase 5 (FSM + nav + 5 архетипов).
- UI-фидбек урона игрока (HP-бар, death screen) — Phase 8 (run) /
  Phase 13 (UI polish); пока — vignette + debugger.
- SFX — процедурные заглушки (prototype-статус, ADR-023; финал —
  Phase 14). VFX-пул — примитивные flash-сферы (final particles —
  Phase 13).
- DebugTools (F2 spawn, F5 kill) — отдельная фаза (ARCHITECTURE §4);
  feel-чек A выше — через debugger.
- Cannon/staff — Phase 6–8 (data-driven: новое оружие = .tres,
  WeaponLogic уже покрывает combo-модель).
