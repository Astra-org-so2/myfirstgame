# AFTER YOU — Character Bible

Версия: 1.0 (Phase 0, креативный дизайн). Все персонажи проходят
quality bar (GDD §13): интересно / связано с темой / тянет узнать больше.

Единые правила (все персонажи):
- Диалоги: 1–3 реплики за взаимодействие, без exposition (DIALOGUE_GUIDELINES).
- Каждый NPC имеет: 1 дом-локацию, trust 0–2, 1 «trust gift» (наследие),
  1 перманентное последствие смерти, 1 «смертельную» реплику-последствие.
- NPC никогда не объясняют мир — они **живут в нём** (странность их
  знания — часть дизайна).
- Убийство NPC = осознанный выбор игрока; игра не подсказывает, что это
  можно делать (но и не блокирует).

---

## 1. ELI (игрок)

### 1.1 Концепт
~25–30. Просыпается в Veyra без воспоминаний о себе, но с мышечной
памятью (умеет ходить, бегать, драться) — само по себе загадка. Наблюдательный,
осторожный, иногда саркастичный. Не герой-выбранный — **одна из многих
версий**. Становится одержим тайной: от «кто я?» к «почему мир помнит
меня за меня?» к «а если мои прошлые жизни были не мной?».

### 1.2 Внешность (нейтральная, ассоциативная)
- Стройное/среднее телосложение, короткая стрижка (оба варианта пола).
- Одежда: практичный «бродячий» комплект — тёмно-зелёно-серый (палитра
  биома), потёртости, один яркий акцент (красная нить на запястье —
  «нить памяти»: визуально связывает с memory-слоем; светится faintly
  в memory-моменты).
- Silhouette: читаемый на фоне леса (контраст 20% по brightness).
- **Технически:** 2 варианта пола = 2 скин-набора на одном скелете
  (text-first: один low-poly-модельный шаблон, материалы/маски). Анимации:
  idle/walk/run/sprint/dodge/attack×2-3/hit/dead/pickup/examine/talk.
- **The First** использует ЭТУ ЖЕ модель + «worn»-материал (выцветший,
  треснувший) + FIRST BLADE (BOSS_DESIGN) — нарративная синергия: босс
  выглядит как «уставший вы».

### 1.3 Голос (одноречие, 5 слов или меньше; пул ~25, триггер-данные)
Примеры (триггер → реплика):
- После странного события: *«Okay... that's new.»*
- Видит своё прошлое (Echo): *«I don't remember doing that.»*
- После смерти/возрождения: *«Again?»* (однажды — и больше не повторять;
  далее тишина — «мир уже сказал это за тебя»)
- Замечает изменение мира: *«That wasn't there.»*
- Увидев The First: *«You're old. You're me. ...you're old.»*
- На записку, написанную «самим собой»: *«My handwriting. ...no. Not yet mine.»*
- The Child рядом: *«How old are you?»* — (Child отвечает — см. §5)
Пул ведётся как data (line_id, trigger_event, cooldown) — DIALOGUE_GUIDELINES §6.

### 1.4 Телесность/язык тела
Останавливается перед важными объектами (авто-pose), поворачивает голову
на звуках (head-look), при приближении Watcher — чуть замедляется
(игрок это чувствует телом персонажа).

### 1.5 Что нельзя
Eli не говорит о Veyra «извне» (он не знает), не цитирует лор, не
комментирует сюжетные механизмы. Реакции — только «здесь и сейчас».

### 1.6 Имя
**Eli** — рабочее (по ТЗ). Кандидаты на замену (предлагаются, НЕ
применяются): **Wren** (древняя, «птица-строитель» — пересмещение
цикла), **Ash** (пепел/след), **Noor** (свет в темноте — связь с
memory-светом). Решение — владелец (GDD §15 Q3).

## 2. MARA (хаб-лагерь)

- **Роль:** хозяйка маленького лагеря у дороги. Точка возрождения.
  «Очаг» мира: её костёр — единственное постоянное тёплое пятно.
- **Внешность:** ~45, тёплые цвета (одеяло, фартук), седая коса;
  силуэт — «дом» (низкий, широкий).
- **Характер:** добрая без наивности. Готовит, чинит, молчит о странностях.
  Первой замечает: *«You look different this time.»* (RUN 03+).
- **Арка:** RUN 1 «чужая, но тёплая» → RUN 03 узнаёт → RUN 05+ не
  задаёт вопросов, просто оставляет у костра то, что «пригодится»
  (trust gifts) → post-boss: *«The fire is brighter. I don't like it.»*
- **Gameplay:** respawn-зона; «note stand» у её стола (игрок оставляет
  записки); EMBER-наследие (полное лечение у костра) — trust≥1.
- **Смерть:** лагерь холоднеет (костёр гаснет, respawn переносится на
  «мёртвое» поле — мир без дома: сильный, осознанный выбор). Одна
  реплика от Nia: *«She's in the book now. Page four.»*
- **Ключевые реплики (8):**
  1. *«You've been walking a long time. Eat something.»* (RUN 1)
  2. *«The road eats people. This fire doesn't.»*
  3. *«You left a kettle last time. I washed it.»* (RUN 02+, если был kettle)
  4. *«You look different this time.»* (RUN 03+)
  5. *«I'm not going to ask where you've been. Ask me what to do.»* (RUN 05)
  6. *«The tower man counts footprints. So do I.»*
  7. (death-последствие, от Nia) — см. выше.
  8. post-boss: *«The fire is brighter. I don't like it.»*

## 3. ORREN (watchtower)

- **Роль:** старый охотник, «никогда не покидал лес» (ложь — знает о
  Run-ах). Переходная фигура между « NPC» и «мудрецом», но без мудрости:
  он **устал** и считает.
- **Внешность:** ~70, сутулый, лук и следящие глаза; башня = его дом.
- **Характер:** лаконичный, ироничный, сухой (его юмор — самый частый в игре).
  Знает слишком много, говорит слишком мало.
- **Арка:** RUN 1 *«You haven't left the forest. Have you?»* → считает
  следы (число растёт с каждым RUN — игрок может отслеживать: след
  механики) → RUN 05+ предупреждает о The First (без объяснений) →
  post-boss: уходит с башни (пустая башня = сильный визуальный beat).
- **Gameplay:** виден из лагеря (landmark); с башни — обзор (landmark-
  reveal: город за вратами виден отсюда после босса); THE TRACK-наследие
  (маркеры последних врагов) — trust≥1.
- **Смерть:** башня темнеет, «следы» остаются на земле и **никогда не
  исчезают** (мир, где следы не стирают — визуальный horror-beat).
  Реплика от Mara: *«He was coming down for dinner. He never came down.»*
- **Ключевые реплики (8):**
  1. *«You haven't left the forest. Have you?»* (RUN 1)
  2. *«I counted seven footprints today. Yours are the newest.»* (RUN 1)
  3. *«Eight. (pause) ...you didn't hear that.»* (RUN 02 — счёт продолжился)
  4. *«Runners live longer. Slayers get remembered differently.»*
  5. *«The tall one in the mine. ...don't be kind to it. Be quick.»* (RUN 05, о The First)
  6. *«Maps lie. He knows it. He draws them anyway.»* (о Cartographer)
  7. post-boss: *(башня пуста; на перилах — лук и записка: «I'm going down. For once.»*)
  8. (humor) на «привет»: *«Still alive. Suspicious.»*

## 4. NIA (деревня, книги)

- **Роль:** девушка-записчик. Ведёт книги о людях, которых никто не
  помнит. **Главный доставщик mystery** (мягко, без лора).
- **Внешность:** ~20, светлая одежда, всегда с книгой/пером; сидит у
  стола в деревне; вокруг — полки (visual: «архив в миниатюре» — seed
  Archivist).
- **Характер:** тихая, уклончивая, но внимательная. Задаёт вопросы,
  которые игрок не может ответить.
- **Арка:** RUN 1: *«You already asked me that.» / «When?» / «Yesterday.»*
  (первый «память»-диалог) → RUN 03: игрок находит **своё имя** в её
  книге (signature moment) → RUN 05: книга с «жизнью до» (страница
  profession/дом — Mystery 1, stage 3) → post-boss: начинает новую
  книгу: *«Page one. Again.»*
- **Gameplay:** THE PAGE-наследие (мгновенное прочтение 1 записки за
  забег) — trust≥1; её полки = «readable»-объекты (страницы-fragments).
- **Смерть:** незакрытая книга остаётся открытой на странице игрока
  (player находит: сильный момент, без слов); полки начинают
  «терять» страницы (визуально: пустые полки).
- **Ключевые реплики (8):**
  1. *«You already asked me that.» — «When?» — «Yesterday.»* (RUN 1)
  2. *«I write the ones nobody remembers. It keeps them... sorted.»*
  3. *«Your page is short so far. That's not a bad thing.»*
  4. (RUN 03, когда игрок у стола) *«...I was worried you wouldn't find it. It's on the third shelf.»*
  5. *«Names are a kind of door. Don't open all of them.»*
  6. (RUN 05) *«The mine man kept a page too. I think it's him who wrote your first note.»*
  7. post-boss: *«Page one. Again. (smiles) ...I'm glad.»*
  8. (humor) если игрок читает впопыхах: *«It's a book, not a body. Breathe.»*

## 5. THE CHILD (роуминг)

- **Роль:** странный ребёнок, появляющийся в разных местах (scripted
  spawn'и на ключевых моментах + редкий роуминг). «Голос системы» —
  говорит сложное простыми, детски-буквальными словами.
- **Внешность:** ~8, не по погоде одет, глаза «слишком спокойные»;
  силуэт маленький — легко заметить в лесу (по design: его видно, но
  не к нему).
- **Характер:** ни злой, ни добрый — **буквальный**. Знает: сколько раз
  умер игрок, какое оружие, какие решения. Никогда не объясняет откуда.
- **Неуязвим** (дизайн-решение, GDD §15 Q4): оружие проходит сквозь;
  при попытке удара — одна реплика: *«It doesn't hurt anymore. I've been
  hit more times than that.»* + world_flag `child_hit` (последствия:
  в следующих RUN-ах Child появляется **реже** — мир «забирает» его;
  soft-penalty за насилие к сущности, без хард-наказания).
- **Арка/функция:** доставляет 2 самых «тёхких» факта (Mystery 4,
  stage 2: *«You're number two-one-seven. I counted. You're slower than
  the others.»*; и post-boss: *«She's waiting. She always waits. She
  brought a chair.»*).
- **Gameplay:** не даёт предметы; даёт **информацию** (1 факт на
  encounter); его «роуминг» = 2–3 scripted-позиции на RUN (не рандом).
- **Ключевые реплики (12):**
  1. *«You died again. I watched. It was the third time.»*
  2. *«You're number two-one-seven. I counted. You're slower than the others.»*
  3. *«The tall one in the mine is you. He's been you for a long time.»*
  4. *«The lady in the white remembers you best. That's not a good thing.»*
  5. *«Your notes are easier to read than the others. You press harder.»*
  6. *«Some of you stayed. They're quieter now. The trees like them best.»* (seed твиста 2)
  7. *«Don't ask where I am. I'm where you almost were.»*
  8. *«The door only opens for the ones who stopped. You stopped. Good.»*
  9. (на удар) *«It doesn't hurt anymore. I've been hit more times than that.»*
  10. post-boss: *«She's waiting. She always waits. She brought a chair.»*
  11. (humor-единственный) на «кто ты?»: *«I'm the one who remembers which way is left.»*
  12. *(RUN 04+, если игрок «всегда убежал»)*: *«You always run. The forest likes runners. They leave more footprints.»*

## 6. THE CARTOGRAPHER (broken bridge)

- **Роль:** создаёт карты мира. Его карты иногда показывают места,
  которых ещё нет. «Мета»-фигура: видит мир как **данные**.
- **Внешность:** ~50, точные движения, чернильные пальцы, мост = его
  смотровая (мост — лучшая точка обзора леса).
- **Характер:** увлечённый, точный, слегка одержимый. Единственный, кто
  называет вещи как есть: *«This forest is a mistake that learned to
  draw itself.»*
- **Арка:** RUN 1: даёт «карту» (объект; на ней — лес без врат) → RUN 03:
  вторая карта (на ней — врата, но за ними — **«smudge»**: *«The gate is
  in the map. The other side is a smudge. I don't like smudges.»*) →
  RUN 05: третья карта (на ней — **город** + **сожжённый второй лес**
  «Veyra B»; *«I drew the city yesterday. I haven't been there yet.
  (pause) ...yet.»* — M4.3, MYSTERY_REVEAL_MAP) → post-boss: исчезает
  с моста (на мосту — только карты и одна фраза на доске).
- **Gameplay:** карты = «readable»-объекты (сравнение карт между RUN-ами —
  интерактив: «compare maps» — игрок сам замечает изменения = discovery);
  THE COMPASS-наследие (разметка 1 скрытой локации) — trust≥1.
- **Смерть:** карты перестают обновляться (новое не размечается); последняя
  карта остаётся «в будущем» (показывает место, которого никогда не
  будет — visual: мост пуст, карта на ветру).
- **Ключевые реплики (8):**
  1. *«I map what is. The rest is weather.»* (RUN 1)
  2. *«This forest is a mistake that learned to draw itself.»* (RUN 03)
  3. *«Second forest. Burned. (points at map) I haven't seen it. I've mapped it.»*
  4. *«I drew the city yesterday. I haven't been there yet. (pause) ...yet.»*
  5. *«Your routes are all the same. Draw them on me and I'll tell you what you'll do next.»* (если игрок повторяет маршрут)
  6. *«Some of you mapped your way out. I kept the map. Page nine. Don't look at it yet.»*
  7. post-boss: *(доска на мосту: «The gate is a door. Doors open both ways. I'm going through. — C.»)*
  8. (humor) на «а врата?»: *«The gate is in the map. The other side is a smudge. I don't like smudges.»*

## 7. THE ARCHIVIST (антагонист; MVP — присутствие)

- **Роль:** сущность, сохраняющая память Veyra. Не злодей: её принцип —
  *«Nothing should ever truly disappear.»* Смерть для неё — ошибка
  системы; поэтому прошлое не исчезает: Echo, повторы, копии, версии.
- **Внешность (MVP — только силуэты/seeds):** почти монохромная фигура
  (белый в сером мире), «архивная» архитектура вокруг (полки-стены,
  бесконечные ряды). В MVP игрок видит её: (а) в отражении озера (1 раз,
  RUN 05+), (б) в проёме за вратами (после босса, 2 секунды), (в) в
  шёпоте (audio, без визуала). Полная встреча — Act V (post-MVP).
- **Голос (MVP-реплики — 5, только seedy):**
  1. *(шёпот, shrine)*: *«Nothing should ever truly disappear.»*
  2. *(шёпот, при первом Echo)*: *«He is kept. He is counted.»*
  3. *(отражение, RUN 05)*: *«You call it death because you cannot remember.»*
  4. *(за вратами, post-boss)*: *«Welcome back, two-one-seven. I saved your seat.»*
  5. *(шёпот, если игрок убивает NPC)*: *«Remembered. Kept. Always.»*
- **Поведение-правила:** никогда не атакует в MVP; никогда не
  объясняет; всегда «уже знала»; её присутствие = смена audio-слоя
  (reverb + distant voices) и цветовой (monochrome accent).
- **Тема:** она — «память, которая не умеет отпускать». Финальный выбор
  (A/B/C) — это спор с её принципом (NARRATIVE_STRUCTURE §6).

## 8. THE FIRST (boss; персонаж, а не монстр)

- **Роль:** первая версия Eli. «Живая» (reveal M7). Провела в Veyra
  огромное количество времени; знает мир, Echo system, Archivist.
  Считает, что новый Eli должен умереть: *«Every time you reach the end,
  you restart everything.»*
- **Внешность:** модель Eli + «worn»-материал + FIRST BLADE; движения —
  **ваши** (игрок узнаёт собственные анимации — «он двигается как я,
  только уставший»).
- **Характер:** не злой — **уставший и решительный**. Садиста в нём нет;
  есть усталость от цикла. Его жестокость — «милосердие» (закончить
  цикл до вас).
- **Мотивация:** остановить цикл, убивая каждую новую версию до финала.
  Знает мир, цикл, сущность «Хранящую». Его **ошибка** (драматургия):
  он думает, что **он сам** «умер и вернулся» (первый, «оригинал» —
  вернувшийся мёртвый), а **не** что он — одна из 217 «хранимых»
  версий (он не знает, что его «хранят»). Единственный, кто ошибается
  в правиле мира — и единственный, кто «устал» (не «злодей»).
- **Ключевые реплики (10; pre-boss + в бою + death):**
  1. *(вход)*: *«You came back. Good. This time I'll be quick.»*
  2. *«I was you. I was everyone. That's the trick. That's the trap.»*
  3. *«You fight like me. Of course you do. (smiles) ...I taught you, in a way.»*
  4. *(когда игрок повторяет комбо)*: *«Again? I've had this swing a hundred times.»*
  5. *(на FIRST BLADE)*: *«...that was mine. I left it for you. I didn't know which you.»*
  6. *(phase 2)*: *«She keeps us all. You think that's mercy? It's a cellar. And we are in it.»*
  7. *(если игрок не берёт FIRST BLADE)*: *«You left it. (soft) ...he left it too. One of you will.»*
  8. *(core-hit)*: *«— (gasps) ...you felt that. It's real. That's the only part of me that's real.»*
  9. *(death)*: *«You reached the end. You always do. ...don't make me proud of it.»*
  10. *(последнее, в dissolve)*: *«Tell her I said: let them go.»* (seed финала, C)
- **Death sequence и трансформация мира:** BOSS_DESIGN §6.

---

## 9. Сводная таблица (для data)

| Персонаж | Локация | Killable | Trust gifts | Смерть-последствие (1 строка для «Что изменилось») |
|---|---|---|---|---|
| Mara | camp (hub) | да | EMBER | «Лагерь вымер. Костёр гаснет.» |
| Orren | watchtower | да | THE TRACK | «Башня пуста. Следы не исчезают.» |
| Nia | village | да | THE PAGE | «Книга открыта на вашей странице.» |
| The Child | роуминг (scripted) | **нет** | — | (child_hit: Child исчезает чаще) |
| The Cartographer | bridge | да | THE COMPASS | «Карта на мосту указывает на несуществующее.» |
| The Archivist | отражение/врата/шёпот | нет | — | — |
| The First | mine (undercroft) | да (boss) | — | «Врата светятся. Туман над озером поднимается.» |
