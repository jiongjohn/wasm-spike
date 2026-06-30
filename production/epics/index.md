# Epics Index

Last Updated: 2026-06-29
Engine: Godot 4.5.2（Compatibility / WebGL2；2026-06-30 re-pinned from 4.6.3）
Manifest Version: 2026-06-29

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [game-tuning-config](game-tuning-config/EPIC.md) | Foundation | #3 调参配置 | design/gdd/game-tuning-config.md | 3 stories | ✅ Complete |
| [entity-database](entity-database/EPIC.md) | Foundation | #1 实体数据库 | design/gdd/entity-database.md | Not yet created | Ready |
| [floor-layout-data](floor-layout-data/EPIC.md) | Foundation | #2 楼层数据 | design/gdd/floor-layout-data.md | Not yet created | Ready |

## 说明

- **实现顺序**：TuningConfig → EntityDB → FloorDB（Autoload 启动依赖序，ADR-0002）。建议按此顺序 `/create-stories` 并实现。
- **覆盖缺口（建史诗时已标）**：
  - `floor-layout-data`：TR-floor-004 BFS 算法未形式化（部分覆盖）+ **Design Constraints 节 GDD 缺口**（#4→#2 成长分布，关卡内容 story 前须补）
  - `game-tuning-config`：TR-tuning-002 TuningFormulas 归属部分覆盖（ADR-0003 隐含）
- **Core 层史诗**（#4 PlayerStats / #5 CombatSystem / #6 GridMovement / #7 KeyDoor）待 Foundation 推进后 `/create-epics layer:core`。
- **Pending ADR**：ADR-0007（导出，spike-gated）/ ADR-0009（GridMovement 渲染）仍 Proposed，不影响 Foundation 实现。

## Next Step

按顺序对每个史诗运行 `/create-stories [epic-slug]`，建议从 `game-tuning-config` 起。
