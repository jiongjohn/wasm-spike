# Smoke Test: Critical Paths — 像素魔塔·无尽塔

**Purpose**: 在 QA hand-off 前 ≤15 分钟跑完这些检查。
**Run via**: `/smoke-check`（读取本文件）
**Update**: 每实现一个核心系统就更新对应条目。

## Core Stability（始终运行）

1. 游戏启动到标题/主场景无崩溃
2. Foundation 启动链无 assertion failed（TuningConfig→EntityDB→FloorDB→GameBootstrap 顺序，ADR-0002）
3. 数据库启动校验通过（D1/D3 实体校验 + F-REF 楼层校验）；校验失败显示 inline 错误屏（非 OS.quit，WASM 兼容）

## Core Mechanic（按 sprint 更新）

<!-- 核心循环：点格移动 → 开门 → 确定性战斗 → 数值跳涨 → 上楼 -->
4. [#6] 点 EMPTY 格 → 寻路移动到位（即点即达，无确认弹窗）
5. [#6] 点可达 MONSTER 格 → 战斗预演覆盖层出现；再点同格 → 确认进攻
6. [#5] 确定性战斗结算结果与预演一致（同入参可复算，零 RNG — ADR-0006）
7. [#7] 持钥匙点门 → 开门；门格变可穿
8. [#9] 踩楼梯 → 切楼层；网格重载正确（TileMapLayer set_cell — ADR-0009）
9. [#11] 拾道具 → 属性跳涨飘字 + HUD 同帧刷新（stat_changed）

## Data Integrity

10. 存档完成无错误（存档系统实现后 — Alpha）
11. 读档恢复正确状态（存档系统实现后 — Alpha）

## Performance（抖音小游戏目标）

12. 目标设备无可见掉帧（30fps；楼层切换 <2ms — ADR-0009）
13. 网格 draw call < 50（单 atlas TileSet 合并 — ADR-0009）
14. 5 分钟游玩内存无明显增长（< 256MB — 核心循环实现后）

## Platform（导出 spike 后）

15. WASM 导出包 ≤ 50MB 或分块加载方案确认（ADR-0007 spike QQ-01）
