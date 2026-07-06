# Data — ресурсы сервера ExtractProServer

```
data/
  gameviewmain.castle-user-interface   — вьюпорт + UI для визуального режима (-dVISUAL)
  physics_scene.castle-transform       — физическая сцена (пол, коробки, свет)
  PlayerProto.castle-transform         — прототип игрока (цилиндр + коллайдер + RigidBody)
```

## Сборка сцен в редакторе CGE

### physics_scene.castle-transform

1. Открыть редактор CGE
2. `New → Transform Design` или открыть существующий
3. Добавить:
   - `TCastlePlane` + `TCastlePlaneCollider` + `TCastleRigidBody` (Dynamic=false) — пол
   - `TCastleDirectionalLight` — солнце
   - `TCastleBox` + `TCastleBoxCollider` + `TCastleRigidBody` — коробки-стены
4. Сохранить как `physics_scene.castle-transform`

⚠ Корень файла — `TCastleTransform` (не `TCastleRootTransform`),
чтобы IDE не требовала `CastleScene`.

### gameviewmain.castle-user-interface

1. `New → User Interface (castle-user-interface)` — автосохраняется как `TCastleViewport`
2. В `Items` добавляется `TCastleRootTransform` — в него добавить:
   - `TCastleTransformDesign` с `Url = file:///.../physics_scene.castle-transform` — ссылка на сцену
   - `TCastleCamera` (Name = Camera1) — камера вьюпорта
3. В `$Children` вьюпорта добавить:
   - `TCastleLabel` (Name = LabelFps) — FPS
   - `TCastleLabel` (Name = LabelStatus) — статус сервера
4. Не дублировать содержимое `physics_scene.castle-transform` в этом файле

При открытии в редакторе ссылка `file:///абсолютный/путь` меняется автоматически.
Итоговый Url в репозитории: `castle-data:/physics_scene.castle-transform`.

### PlayerProto.castle-transform

Открывается как `TCastleTransform` (цилиндр + коллайдер + RigidBody).
Голова и управление добавляются только в клиенте (`TEntityManager.CreateMainPlayerEntity`).
На сервере загружается как есть, без поведений.

## Связь файлов

```
gameviewmain.castle-user-interface (TCastleViewport)
  └─ Items: TCastleRootTransform
       ├─ TCastleTransformDesign ──→ physics_scene.castle-transform (пол, коробки, свет)
       └─ TCastleCamera (Camera1)
  ├─ LabelFps
  └─ LabelStatus
```

Headless-режим загружает `physics_scene.castle-transform` напрямую,
визуальный — через `gameviewmain.castle-user-interface`, который ссылается на ту же сцену.
Править физику нужно в `physics_scene.castle-transform`.
