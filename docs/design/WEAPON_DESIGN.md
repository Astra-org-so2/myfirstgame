# AFTER YOU — Weapon Design

Версия: 1.0 (Phase 0, креативный дизайн).

> Точка ТЗ: **ровно 3 архетипа оружия** (не 50). Каждое оружие —
> «способ говорить с памятью» (blade = сила, cannon = расстояние,
> staff = память). + 1 «нарративное» оружие (THE FIRST BLADE —
> не «4-е оружие», а «ключ» к боссу).
> Правило: оружие **меняет геймплей**, а не «+5%» (GDD §14:
> upgrades must mostly change gameplay).

## 0. Общие правила (все оружия)

- **Урон/статы:** data-driven (`data/weapons/*.tres`, ROADMAP Phase 5).
- **Комбо:** 2–3 удара + 1 «специальное» (per weapon). No infinite
  combos (cooldown 0.3 с между ударами).
- **Скорость:** melee (blade) — быстрый (1.2 с/удар), ranged (cannon)
  — медленный (2.0 с/выстрел, ограниченный патрон), staff — средний
  (1.5 с/каст).
- **Звук:** каждое оружие — 3 звука (swing/fire/cast, hit, pickup).
  (TECHNICAL_DESIGN: audio-данные.)
- **Appearance:** 3 модели + 3 «worn»-варианта (для Remnant/The First).
  Silhouette: blade (короткая, 1 рука), cannon (средняя, 2 руки),
  staff (длинная, 1 рука).
- **Drop/pickup:** оружие **не дропается** — **находится** (scripted
  location, 1 раз навсегда, WORLD_STATE: `weapon_X_found`). (GDD §11:
  3 weapons, scripted.)
- **Player-behavior-as-story:** Remnant использует оружие игрока
  (ENEMY_DESIGN §2). (Зеркало.)

## 1. BLADE (ближний бой, «сила»)

### 1.1 Концепт
Короткий меч. «Первое», что игрок берёт (RUN 1, 0:45 — K1 «Оружие в руке»).
**Геймплей:** быстрый, ближний, «очный». Комбо: 3 удара (1.2 с/удар).
**«Говорит с памятью»:** «сила» — «ты здесь, ты бьёшь, ты существуешь».

### 1.2 Статы (base)
```
blade: { dmg: 25, speed: 1.2s/удар, range: 2.0m, combo: 3,
  stamina: 10/удар, special: "Riposte" (0.5s window, counter, 30s CD) }
```

### 1.3 Комбо
- **U1 (1.2 с):** прямой (forward). Dmg 25.
- **U2 (1.2 с):** дуга (arc). Dmg 25. (U1+U2 = 50 за 2.4 с.)
- **U3 (1.5 с):** «выпад» (thrust, длинный). Dmg 30. (Full combo: 80.)
- **Special — Riposte (30 с CD):** 0.5 с окно. Если игрок «в окне»
  (attack incoming) → «отражение» (enemy stunned 1.5 с, +15 dmg).
  (Геймплей: «очный», «timing».)

### 1.4 Finding (scripted)
- RUN 1, 0:45: «рука сама» берёт (K1: *«I don't remember learning
  this.»*). WORLD_STATE: `blade_found = true`.

### 1.5 Upgrades (PROGRESSION_DESIGN — «меняет геймплей»)
- **Inheritance: SHARP** (1 из 3 при смерти): «выпад бьёт глубже»
  (U3 dmg 30→45 — не «+5%», а «выпад сильнее»).
- **Inheritance: FLOW** (1 из 3): «четвёртый удар ждёт» (combo 3→4:
  1.5 с, 20 dmg). (Геймплей: «больше комбо».)

### 1.6 Mystery (несёт)
- K1: «рука знает». (Mystery 1, stage 1: «мышечная память».)
- The First использует FIRST BLADE (BOSS_DESIGN) — «его версия».

## 2. HAND CANNON (дальний бой, «расстояние»)

### 2.1 Концепт
Одноручный пистолет-«рука». **Ограниченный патрон** (5 на забег,
не «инфинити»). **Геймплей:** медленный (2.0 с/выстрел), «один
выстрел = одно решение». **«Говорит с памятью»:** «расстояние» —
«ты не обязан быть рядом».

### 2.2 Статы (base)
```
hand_cannon: { dmg: 60, speed: 2.0s/выстрел, range: 15m, ammo: 5/забег,
  spread: 3°, special: "Break" (2 выстрела, 1 цель, 120 dmg, 60s CD) }
```

### 2.3 Комбо (не «комбо» — «последовательность»)
- **Выстрел (2.0 с):** одиночный. Dmg 60. Ammo -1.
- **Reload (1.5 с):** не «reload» — «перезарядка» (5 патронов, 1 раз
  на забег). (Геймплей: «один reload».)
- **Special — Break (60 с CD):** 2 выстрела, 1 цель. Dmg 120.
  (Геймплей: «1 цель = 1 решение».)

### 2.4 Finding (scripted)
- The Mine, ярус 1 (свет, ящик). RUN 2+ (после первой смерти —
  «мир даёт оружие»). WORLD_STATE: `cannon_found = true`.
- **Note рядом:** *«It's heavy. Use it once. — E.»* (#2 «Своя записка» seed,
  «от себя».)

### 2.5 Upgrades (PROGRESSION_DESIGN)
- **Inheritance: SLOW BURN** (1 из 3): «два выстрела — чаще»
  (Break CD 60→40 с).
- **Inheritance: QUIET STEP** (1 из 3): «выстрел не слышен»
  (геймплей: «скрытность», не «+dmg»).

### 2.6 Mystery (несёт)
- Note «от себя» (#2 «Своя записка»-линия, M2 seed).
- The First: «у него тоже» (BOSS_DESIGN: его cannon — «сломанный»).
  (Mystery: «он был мной».)

## 3. ECHO STAFF (дальний, «память»)

### 3.1 Концепт
Жезл-«эхо». **Не «урон» — «память»**. 4 действия:
- **Read:** «видит» echo (passive: «подсветка» echo, 5 с).
- **Disrupt:** «ломает» echo (1 cast, 10 с CD, «растворяет» 1 echo).
- **Soothe:** «успокаивает» врага (1 cast, 15 с CD, враг «спит» 3 с).
- **Shatter:** «бьёт» echo (1 cast, 20 с CD, dmg 40, 1 цель).
**Геймплей:** средний (1.5 с/каст), «4 действия» (не «1 урон»).
**«Говорит с памятью»:** «память» — «ты не только бьёшь — ты
видишь, ломает, успокаивает».

### 3.2 Статы (base)
```
echo_staff: { cast: 1.5s, range: 10m,
  actions: { read: {cd: 5, range: 8m}, disrupt: {cd: 10, 1 echo},
    soothe: {cd: 15, 3s sleep}, shatter: {cd: 20, dmg: 40, 1 target} } }
```

### 3.3 Геймплей (4 действия)
- **Read (5 с CD):** «подсветка» echo (passive, 5 с). (Геймплей:
  «видишь echo раньше».)
- **Disrupt (10 с CD):** «растворяет» 1 echo (echo «исчезает»,
  no combat). (Геймплей: «обойти бой».)
- **Soothe (15 с CD):** враг «спит» 3 с (no damage). (Геймплей:
  «успокоить», не «убить».)
- **Shatter (20 с CD):** dmg 40, 1 цель. (Геймплей: «удар».)
- **Геймплей-связка:** Read → Disrupt (обойти echo) / Read →
  Soothe (успокоить врага) / Read → Shatter (удар). (Стратегия.)

### 3.4 Finding (scripted)
- Old Shrine, ниша (RUN 2–3). WORLD_STATE: `staff_found = true`.
- **Note рядом:** *«It sees what you left. Use it gently. — E.»*
  (#2 «Своя записка» seed, M3: «кто создаёт Echo» — «он знал о staff».)

### 3.5 Upgrades (PROGRESSION_DESIGN)
- **Inheritance: DEEP SIGHT** (1 из 3): «вишь дальше»
  (Read range 8→12 м).
- **Inheritance: GENTLE HAND** (1 из 3): «сон дольше»
  (Soothe 3→5 с).
- **(post-MVP) Inheritance: BREAKER** (1 из 3): «ломает двоих»
  (Disrupt: 1→2 echo).

### 3.6 Mystery (несёт)
- Note «от себя» (#2 «Своя записка», M3 seed).
- Shrine: «зеркальный круг» (scripted memory echo) — staff «видит»
  (ENV_STORYTELLING: «здесь память — не в прошлом, а вокруг»).

## 4. THE FIRST BLADE (нарративное оружие, «ключ»)

### 4.1 Концепт
**Не «4-е оружие» — «ключ» к боссу.** Длинный меч (1.5× blade).
«Его» (The First). **Геймплей:** в бою с The First — «слабость»
(BOSS_DESIGN §3: core-hit, только FIRST BLADE). Вне боя — «blade»
(чуть сильнее: dmg 35, speed 1.3 с).

**Echo реагируют иначе (GDD §6.4):** пока игрок несёт FIRST BLADE,
все Echo «уважают» его (не атакуют первыми, «отходят» на 2 с при
подходе; Remnant: *«...that was mine.»*). Это «ключ» — мир «узнаёт»
оружие первой версии. (Дизайн: «оружие = нарратив».)

### 4.2 Статы (base)
```
first_blade: { dmg: 35, speed: 1.3s/удар, range: 2.5m, combo: 2,
  special: "Core Hit" (в бою с The First: 1 hit, 50 dmg, «weakness») }
```

### 4.3 Take/Leave (нарративный выбор)
- **Pre-boss:** перед дверью Undercroft — FIRST BLADE на «стенде»
  (3 записки The First — pre-boss read). **Выбор:** взять / не взять.
  - **Взять:** The First: *«...that was mine. I left it for you. I
    didn't know which you.»* (Сила: «core hit».)
  - **Не взять:** The First: *«You left it. (soft) ...he left it too.
    One of you will.»* (Слабость: «no core hit», но «нарратив» —
    «ты отказался от его силы».)
- **WORLD_STATE:** `first_blade_taken = true/false`. (Влияет на
  epilogue, BOSS_DESIGN §6.)

### 4.4 Mystery (несёт)
- BOSS_DESIGN §3 (core-hit, weakness).
- The First death: *«...that was mine.»* (Mystery: «он был мной»).
- **Seed C-ending:** *«Tell her I said: let them go.»* (NARRATIVE_
  STRUCTURE §6.)

## 5. Сводная таблица (для data)

| Оружие | DMG | Speed | Range | Special | Finding | Inheritances (MVP) |
|---|---|---|---|---|---|---|
| Blade | 25–30 | 1.2–1.5 с | 2 м | Riposte (30 с) | RUN 1, 0:45 (K1) | SHARP, FLOW |
| Hand Cannon | 60–120 | 2.0 с | 15 м | Break (60 с) | Mine, RUN 02+ | SLOW BURN, QUIET STEP |
| Echo Staff | 0–40 | 1.5 с | 10 м | Read/Disrupt/Soothe/Shatter | Shrine, RUN 02–3 | DEEP SIGHT, GENTLE HAND |
| First Blade | 35 | 1.3 с | 2.5 м | Core Hit (boss) | Undercroft, pre-boss | (нарративный choice) |

**Итого: 3 архетипа + 1 нарративное.** GDD §11: 3 weapons.

## 6. Правила (все оружия)

1. **Оружие не дропается** — находится (scripted, 1 раз навсегда).
2. **Оружие меняет геймплей** — не «+5%» (GDD §14).
3. **Оружие несёт mystery** — 1 записка/1 seed (#2 «Своя записка»).
4. **Оружие = «язык»:** blade (сила), cannon (расстояние), staff
   (память). (3 «способа говорить».)
5. **Remnant использует оружие игрока** (ENEMY_DESIGN §2) — зеркало.

## 7. Связи с системами
- **PROGRESSION_DESIGN** — Inheritances (upgrades, 1 из 3).
- **BOSS_DESIGN** — FIRST BLADE (core-hit, weakness, take/leave).
- **ECHO_SYSTEM_DESIGN** — Echo Staff (Read/Disrupt/Soothe/Shatter
  vs Echo).
- **WORLD_STATE_DESIGN** — `weapon_X_found`, `first_blade_taken`.

## 8. Open questions (weapon)
- Q-WE1: Cannon «5 патронов» — не «слишком мало» ли? (Митигция:
  «1 выстрел = 1 решение» — геймплей. Reload 1 раз — «растянуть».)
- Q-WE2: Echo Staff «4 действия» — не «слишком много» ли для MVP?
  (Митигция: 4 действия = 4 «способа» — «память». Data-driven,
  легко «отключить» 1 (MVP: Read+Shatter, Post-MVP: Disrupt+Soothe).)
- Q-WE3: First Blade «take/leave» — не «слишком нарративно» ли
  для оружия? (Митигция: это «ключ», не «оружие». Выбор — нарратив,
  сила — геймплей.)
