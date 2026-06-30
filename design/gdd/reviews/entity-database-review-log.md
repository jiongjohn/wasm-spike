# Review Log — entity-database.md

## Review — 2026-06-23 — Verdict: MAJOR REVISION NEEDED → REVISED (pending re-review)
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director (senior)
Blocking items: 13 | Recommended: 6
Summary: 30+ 条专家发现收敛为 3 个根因——(1) schema 无类型判别 + KeyEntry 继承在 GDScript 不可建(entities.yaml 已写非法 KEY);(2) MVP 数据集夹带 VS 越界内容(skeleton/beast_king/sword_great/fragment),且 +20 Boss 掉落违背 Pillar 1 滚雪球;(3) 校验只覆盖易例、漏掉危险例(无 ATK 上限/D2 除零/gold≥1 自相矛盾/5 个不可测 AC)。已全部修订:扁平 schema+entity_type、KEY 入枚举、新增 D3 ATK 上限、MVP/VS 拆表、AC 9→14、新增 is_boss/stack_rule。
Prior verdict resolved: First review

### 修订决策(供复评核对)
- Key 模型:扁平 schema + `entity_type` 判别字段,KEY 纳入 effect_type 枚举(放弃子类继承)
- 数据集:拆分 MVP 表(slime+goblin+基础道具)与「VS 数据追加」节(skeleton/beast_king/sword_great/fragment)
- gold_drop:统一 ≥1,移除「陷阱怪 gold=0」边界
- 道具语义:MAXHP_BOOST 抬上限并回满当前 HP;HP_RESTORE 封顶不溢出(规则 C10)

### 复评须重点核对的阻塞项
1. KeyEntry 扁平化 + KEY 入枚举(原继承不可建)
2. `entity_type` 判别字段(原缺失)
3. Entry 构造/格式/只读强制合并为单一 ADR(Open Q2)
4. 规则 C7 只读强制(作废 `@export` 假声明)
5. KeyEntry effect_value=0 不报缺失
6. 新增 D3 怪物 ATK 上限约束 + AC-04(死墙防护)
7. D2 除零保护 + round/钳制顺序
8. D1 HP=1 漏洞 / N_max 越界 / ATK 预期越界校验
9. gold_drop ≥1(消解自相矛盾)
10. 缺失校验:重复 ID / ATK=0 / 负 effect_value / 颜色不匹配 / 两遍加载
11. FRAGMENT 在 MVP 拦截(规则 C9 + AC-14)
12. beast_king/skeleton/sword_great 移出 MVP(MVP/VS 拆表)
13. AC-02/04/06/09 重写为可观测;AC 9→14

### 未处理(留待复评通过后或下个会话)
- `design/registry/entities.yaml` 未对齐:仍含非法 `effect_type: KEY`,缺 `entity_type`/`is_boss`/`stack_rule` 字段,未标记 VS 实体。 → **已于 2026-06-24 二轮修订中解决(registry v2)。**

## Review — 2026-06-24 — Verdict: NEEDS REVISION → REVISED (pending re-review)
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director (senior)
Blocking items: 5 | Recommended: 6
Summary: 二轮对抗式复评。上轮 MAJOR 三根因(继承不可建/缺死墙约束/越界内容)两个根治、一个正面处理 — CD 判定为健康收敛,降级为 NEEDS REVISION。本轮 30+ 发现收敛为 5 个 blocker:(1) 8 条 Integration AC「不进入主界面」GUT 不可断言 + AC-06 测了个寂寞 + AC-09 在 .tres 下不可能通过;(2) `entity_type=ITEM`+`effect_type=KEY` 非法组合无联合校验;(3) `stack_rule=ONCE` 命名与语义相反;(4) D3 逐怪 ≠ 层安全;(5) 3 条遗留 AC(DEF 上限/普通怪稀有掉落/负 effect_value)。全部已修订。
Prior verdict resolved: Yes — 上轮 13 项 blocker 经核对,继承/拆表/D3/校验补全均已处理;唯一遗留(entities.yaml)本轮解决。

### 本轮修订决策(供三轮复评核对)
- AC 断言契约:全部改断言 `validate_database()→ValidationResult{is_valid,errors[code]}`,AC-19 单独承载「不进入游戏」装配契约
- 数据格式硬约束:禁止 .tres,必须 JSON(Open Q2 ①)
- `stack_rule` 改名 HIGHEST_WINS;补「拾取更弱装备→消失无效果」契约
- D3 取向裁定(CD):保留为 Foundation 死墙兜底,豁免机制留 VS;补「过 D3 ≠ 层安全」
- BUG-8 scope-gate:CD 准予本 Foundation GDD 豁免(显式标注)
- @abstract 与扁平 schema 矛盾修正(限定查询接口层);C7+OpenQ2③ 补 duplicate_deep 性能分支
- AC 14→19;entities.yaml v1→v2(全字段 + tier 标记 + goblin floor 4→3)

### 三轮复评须重点核对
1. AC-03/04/06/07~10/13~19 在 headless GUT 下能否全部 PASS/FAIL(断言代理是否落地)
2. AC-18:`entity_type=ITEM`+`effect_type=KEY` 必报 `ILLEGAL_TYPE_EFFECT_COMBO`
3. `HIGHEST_WINS` 字段名是否自解释(未读 C8 的实现者不会写错叠加)
4. entities.yaml v2 与 GDD 数据表是否逐字段一致

## Review — 2026-06-24 — Verdict: NEEDS REVISION → REVISED (pending re-review)
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (senior)
Blocking items: 3 | Recommended: 7
Summary: 三轮对抗式复评。前两轮三个原始根因（继承不可建/缺死墙约束/越界内容）本轮无一复发；3 个真 blocker 全部为二轮引入断言契约留下的测试接缝：(1) ValidationResult 缺 computed 字段，AC-02/04 无法整数断言 D1/D3 算法精度；(2) validate_database() 签名缺 build_scope 参数，AC-14 无法构造 MVP/VS 区分测试；(3) C7 守卫静默失败+两遍加载未明确重复ID在第一遍捕获，威胁 WASM Release 可观测性。CD 判定收敛为 NEEDS REVISION（非 MAJOR），已全部修订完成。7 条 Recommended 亦一并修订（HIGHEST_WINS NO_EFFECT 契约/API 路径澄清/AC-20/跨类型ID/JSON float/MVP 怪物表注/守卫注释）。
Prior verdict resolved: Yes — 上轮 5 项 blocker 经核对全部处理。4 项发现被 CD 裁定为误报（MVP 2 怪/药水占位/duplicate_deep 矛盾/get_item 无 AC）。

### 本轮修订决策（供四轮复评核对）
- ValidationResult 增加 `computed: Dictionary`(按 entry_id 存 D1/D3 中间值)
- 签名改为 `validate_database(entries, build_scope: String = "MVP") -> ValidationResult`
- AC-02/04 THEN 改为整数断言 `computed[entry_id][field]`
- AC-14 WHEN 明确 `build_scope="MVP"` 参数
- C7 守卫方案补 DEBUG push_error 要求 + 两套深拷贝 API 分路径说明
- States and Transitions 明确重复 ID 在第一遍建表时捕获
- C8 HIGHEST_WINS 补 `NO_EFFECT` 接口契约 + 字段内联注释
- Edge Cases 补跨 entity_type 重名 ID 建议说明
- Open Q2 ③ 重写 + 补 ⑤ JSON 整数 float 化注意
- MVP 怪物表加「最小验证集」取向注
- 新增 AC-20（gold_drop < 1 报错）；AC 总数 19 → 20

### 四轮复评须重点核对
1. AC-02/04 的 `computed[entry_id][…]` 断言：ValidationResult 实现时 computed 字段格式是否与 GDD 期望一致
2. `validate_database(entries, build_scope)` 签名在 AC-14/AC-02/AC-04 中的调用是否一致
3. C8 `effect_result=NO_EFFECT` 返回契约：#4 玩家属性 GDD 编写时需反向声明对此契约的消费
