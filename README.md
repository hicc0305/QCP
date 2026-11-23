# 数理逻辑第六题 · QCP 论文复现

本项目复现 QCP v1.0 对 LiteOS 双向循环链表的三个案例。Windows 端已实际重新生成验证条件及证明文件，并与作者版本逐项核对。复现命令、结果判读和 Coq 后端复核步骤见 [README-运行与验证.md](README-运行与验证.md)。

## 小组成员

| 姓名 | 学号 |
| --- | --- |
| 卢宇程 | 26031212417 |
| 陈天祺 | 26031212445 |
| 庞博元 | 26031212495 |

## 论文和工具

- 论文为 *QCP: A Practical Separation Logic-based C Program Verification Tool*，TASE 2026。[论文](https://arxiv.org/abs/2505.12878)
- 本次使用作者发布的 v1.0，提交 `af71be03bdbfad353542c38013b1e69d124cb56c`。[项目 GitHub](https://github.com/QinxiangCao/QualifiedCProgramming) · [v1.0 发布页](https://github.com/QinxiangCao/QualifiedCProgramming/releases/tag/v1.0)
- 实现对照来自 OpenHarmony 的 LiteOS-A 链表头文件。[los_list.h](https://github.com/openharmony/kernel_liteos_a/blob/master/kernel/include/los_list.h)

## 案例和实测结果

输入位于 `QCP/QCP_examples/LiteOS/`。三组均退出 0，日志均出现 `Successfully finished symbolic execution`。新生成的 `goal`、`proof_auto` 和 `goal_check` 共九个文件在忽略空白后与 v1.0 自带文件一致。原始日志和文件见 [results](results/)。

- **初始化（`LOS_ListInit.c`）**。前置条件提供哨兵节点两个链接字段的可写权限。两次自指赋值对应 OpenHarmony 实现。后置条件是 `store_dll(storeA,list,nil)`，即以该哨兵为头的空循环链表。生成 1 条手工义务，需要将两个自指字段折叠成空链表谓词。
- **插入（`List_Add.c`）**。底层规格拥有插入位置与原后继的相邻字段及新节点链接字段，承诺四条新链接。高层规格由底层规格导出，头插得到 `cons(新节点, l)`，尾插得到 `app(l, [新节点])`。OpenHarmony 的 `LOS_ListAdd` 执行同样的四次指针写入，头插用哨兵作为插入位置，尾插用哨兵的前驱。生成 4 条自动和 4 条手工义务，手工部分包含规格派生及尾插的链表重组。
- **删除（`LOS_ListDelete.c`）**。高层前置条件将链表分为前缀、待删节点、后缀，后置条件把前缀和后缀接起来并交还被摘节点的资源。底层实现与 OpenHarmony 一样，先将相邻节点接回，再将被摘节点的两个链接置空。实验规格用 `undef_data_at` 表示调用方可重新使用这两个字段，规格本身只承诺字段权限。生成 5 条自动和 2 条手工义务，手工部分包含删除后的返回条件及规格派生。

## 搭建后的主要思考

1. 链表初始化只有两次赋值，仍会产生手工证明。字段赋值提供具体的堆事实，还需要借助链表谓词的定义把这些事实组织成抽象结构。分离逻辑中的 `*` 描述可分离的堆资源，有助于定位每一步需要拥有的字段。
2. QCP 的蕴含求解器同时使用空间规则和轻量 SMT。字段资源的匹配和链表谓词的展开依赖分离逻辑规则，SMT 用来处理纯条件，例如路径上的地址等式、非空约束和算术条件。这次只根据生成文件统计自动和手工义务，日志没有提供逐条 SMT 调用归因。[论文第 4.2 节](https://arxiv.org/html/2505.12878v3#S4.SS2)
3. 插入案例把底层指针操作和高层链表序列性质连接起来。证明高层规格可从底层规格导出后，调用者可复用高层规格，函数体只需按底层规格验证一次。
4. 复现实测覆盖符号执行和产物比对。作者随附的三个手工证明文件均使用 `Qed.` 完成对应义务。本机缺少可用的 Coq 8.20.1 环境，Docker Linux 引擎也未运行，因此本次尚未由 Coq 内核重新检查这些证明。
