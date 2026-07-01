# Tech Debt Register

- **2026-07-01** (EntityDB story-001 数据类型): `sprite_id` 必填性延后 — GDD 规则 C3/C4/C5 标 sprite_id 非空必填，但 MVP 数据表（Tuning Knobs）无 sprite_id 列。当前三实体类型的 from_dict 保持 sprite_id 可选（空串默认）。待美术 Atlas 规范定义 sprite 键名后，将 sprite_id 转为 from_dict 必填字段并补校验。tracked from production/epics/entity-database/story-001-entity-types-deserializer.md
