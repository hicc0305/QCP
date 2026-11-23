# QCP LiteOS 案例运行与验证

## QCP 是什么，第六题要做什么

QCP 是验证 C 程序的工具。输入是带规格注解的 C 文件，输出是可以交给 Coq 检查的验证条件及证明文件。注解中的 `Require` 描述调用前需要哪些条件或内存访问权限，`Ensure` 描述函数结束时必须保证什么。

以初始化为例，代码只把哨兵节点的前后两个指针都指回自己。QCP 从前置条件出发，逐句记录写入后的指针关系，这一步叫符号执行。随后它产生一条验证条件，要求从这两个具体的指针事实推出「该哨兵表示一条空的双向循环链表」。验证条件可以理解为程序正确性证明中的一道小题。

QCP 用分离逻辑描述字段权限和链表的堆结构，借助规则匹配和轻量 SMT 处理可自动化的证明。SAT 问一组布尔条件能否同时成立，SMT 把这个问题扩展到整数等带有运算规则的对象。比如整数条件 `x > 0` 与 `x + 1 <= 0` 无法同时成立。QCP 的 SMT 部分处理这类纯条件，链表段的拆分、拼接等则涉及分离逻辑推理。日志能区分自动义务与手工义务，未记录每条义务具体由 SMT 还是哪条空间规则解决。Coq/Rocq 后端负责检查证明。

第六题要求复现作者已有的 2–3 个 LiteOS 链表案例，解释各自的前后置条件、SMT 自动化与证明后端的作用，并对照 OpenHarmony 的对应实现。本组选择初始化、插入、删除三组。实际运行的是作者随 QCP v1.0 发布的带注解案例。对照 OpenHarmony 时，逐句核对相应函数中的关键指针写入，再说明验证规格保证了哪些效果。[QCP 论文](https://arxiv.org/abs/2505.12878) · [OpenHarmony 链表实现](https://github.com/openharmony/kernel_liteos_a/blob/master/kernel/include/los_list.h)

## 到哪里找源码和实验结果

- [QCP/QCP_examples/LiteOS/](QCP/QCP_examples/LiteOS/) 是本次验证的输入。[LOS_ListInit.c](QCP/QCP_examples/LiteOS/LOS_ListInit.c) 验证空链表初始化，[List_Add.c](QCP/QCP_examples/LiteOS/List_Add.c) 包含基本插入、头插和尾插，[LOS_ListDelete.c](QCP/QCP_examples/LiteOS/LOS_ListDelete.c) 验证摘链及被摘节点的字段状态。
- [QCP/win-binary/](QCP/win-binary/) 里的 `symexec.exe` 是我们实际运行的 Windows 程序。`linux-binary/` 和 `mac-arm64-binary/` 提供相应平台的版本，`tutorial/` 是作者教程。
- [QCP/SeparationLogic/](QCP/SeparationLogic/) 放 Coq 证明库。`examples/LiteOS/` 放作者随附的参考目标和完整手工证明，`examples/LiteOS/lib/` 放链表谓词等定义。[Dockerfile](QCP/Dockerfile) 用于构建作者的 Coq 环境。
- [results/](results/) 是复现报告引用的本组实测目录，保留三组日志和生成文件。[run-liteos.ps1](run-liteos.ps1) 用来重新运行并核对三组案例。

## 16 条验证条件分别在检查什么

- **初始化 · 0 条自动、1 条手工。** 返回义务要求把两个字段都指回哨兵的事实整理成空链表谓词。[初始化目标](results/LOS_ListInit_goal.v)
- **插入 · 4 条自动、4 条手工。** 自动部分包括尾插时两次已有资源的排列、头插的调用条件和头插的返回条件。手工部分包括底层插入的返回条件、从完整链表中拆出尾端链接、尾插后重新拼起循环链表，以及由底层规格推出高层头插规格。[插入目标](results/List_Add_goal.v)
- **删除 · 5 条自动、2 条手工。** 自动部分包括两次写入空指针时对整数常量 `0` 的范围检查，以及三次字段资源的展开或访问权限匹配。手工部分包括确认摘链后的局部状态满足返回条件，以及从局部摘链推导出整条链表只去掉指定节点。[删除目标](results/LOS_ListDelete_goal.v)

阅读 `*_goal.v` 时，把 `|--` 左边理解为已知状态，右边理解为需要证明的结论。找到目标名后，可以去对应的 `*_proof_auto.v` 或 `*_proof_manual.v` 搜索以 `proof_of_` 加上目标名命名的证明。

## 在 Windows 上重跑

在包含 `QCP/` 和 `run-liteos.ps1` 的项目根目录打开 PowerShell。脚本使用 v1.0 随附的 Windows 可执行文件。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-liteos.ps1
```

脚本以作者脚本的参数运行三份带注解的 C 文件。复跑产物保存到脚本最后打印的目录，并自动与作者版本核对。预期终端摘要为 `LOS_ListInit auto=0 manual=1`、`List_Add auto=4 manual=4`、`LOS_ListDelete auto=5 manual=2`。

只演示初始化时，可以在项目根目录运行下面的命令。

```powershell
New-Item -ItemType Directory -Force demo | Out-Null
Set-Location QCP
.\win-binary\symexec.exe --input-file=QCP_examples/LiteOS/LOS_ListInit.c `
  -IQCP_examples/ -slp QCP_examples/ SimpleC.EE --no-logic-path `
  --goal-file=../demo/LOS_ListInit_goal.v `
  --proof-auto-file=../demo/LOS_ListInit_proof_auto.v `
  --proof-manual-file=../demo/LOS_ListInit_proof_manual.v --no-exec-info
Set-Location ..
```

`-I` 提供 C 头文件搜索目录，`-slp` 为策略提供目录和逻辑路径映射。`--no-exec-info` 减少符号执行的中间输出，需要观察中间状态时可省去。

## 观察什么

1. 先看日志中的 `Symbolic Execution into function ...`。插入案例应观察到 `LOS_ListAdd`、`LOS_ListTailInsert`、`LOS_ListHeadInsert` 三个入口。最后出现 `Successfully finished symbolic execution` 表示工具已完成该输入的符号执行与条件生成。
2. 打开 `*_goal.v`，搜索 `return_wit`、`safety_wit`、`derive_`。它们分别对应返回点对后置条件的证明义务、安全条件和规格派生义务。`VC_Correct` 是后端要求实现的模块接口。
3. 打开 `*_proof_auto.v` 查看已生成的自动证明，打开 `*_proof_manual.v` 查看待证明的义务。新生成文件里的 `Admitted.` 表示该步骤还需要证明。初始化案例有一条这样的义务，可对照作者手工证明中的 `unfold store_dll`、`unfold dllseg` 和两次 `Exists list_pre`。
4. 打开 `*_goal_check.v`。它将策略、自动证明和手工证明合并成 `VC_Correctness`。应在使用完整手工证明后编译此文件。Coq 可以接受含有 `Admitted.` 的文件，验收时也要检查证明体和所依赖的假设。

## 用作者的 Coq 环境复核

目前已完成 Windows 符号执行、16 条验证条件的统计，以及九份目标、自动证明和检查文件与作者发布版的比对。待做的是 Coq 后端复核。本次复核使用 `results/` 中生成的目标、自动证明和检查文件，以及作者完成的手工证明。需要保存三组检查模块的编译日志、Coq 版本和执行结果，供实验报告引用。

启动 Docker Desktop 并确认 Linux 引擎可用。在项目根目录运行作者的 Dockerfile。镜像使用 Coq 8.20.1，构建过程会编译分离逻辑库及随附案例。容器复核使用镜像内作者提供的手工证明。

```powershell
docker build --build-arg MAKE_JOBS=5 -t qcp-tase2026 ./QCP
$resultsPath = (Resolve-Path .\results).Path
docker run --rm -it --mount "type=bind,source=$resultsPath,target=/repro-results,readonly" --entrypoint /bin/bash qcp-tase2026
```

进入容器后运行下面的命令，强制重新编译三组目标、证明和检查模块。

```bash
set -e
cd /home/coq/qcp/SeparationLogic
coqc --version
for case in LOS_ListInit List_Add LOS_ListDelete; do
  prefix="examples/LiteOS/${case}"
  if grep -nE '(^|[^[:alnum:]_])(Admitted|admit)[[:space:]]*\.' "${prefix}_proof_manual.v"; then
    exit 1
  fi
  for part in goal proof_auto goal_check; do
    cp "/repro-results/${case}_${part}.v" "${prefix}_${part}.v"
  done
  for part in goal proof_auto proof_manual goal_check; do
    rm -f "${prefix}_${part}.vo"
  done
  for part in goal proof_auto proof_manual goal_check; do
    make "${prefix}_${part}.vo"
  done
done
```

每组的四个 `.vo` 文件都重新生成且命令成功退出时，表示 Coq 接受对应证明模块。本机此前未能连接 Docker Linux 引擎，以上容器复核步骤待组员实跑。[v1.0 构建说明](https://github.com/QinxiangCao/QualifiedCProgramming/blob/v1.0/README.md)

## 三人分工与提交

1. **xxx · 录制工具运行讲解视频。** 视频至少 5 分钟，建议安排 6–8 分钟。先讲题意和 QCP 的输入输出，再实际运行三组案例，展示日志与 16 条义务的分类。挑一条初始化的返回义务和一条删除的自动义务，说明分别在证明什么。最后指出 Coq 检查发生在哪一步，并按录制时的进度说明后端情况。
2. **xxx · 完成 Docker 和 Coq 后端复核。** 启动 Docker Linux 引擎，构建作者镜像，按上面的步骤复核三组生成文件。记录 Coq 版本和三个 `*_goal_check.v` 的实际编译结果。如果遇到失败，记录出错的命令和目标，并将最终结果交给报告负责人。
3. **xxx · 撰写 DOCX 实验报告。** 根据源码、Windows 实跑产物和 Coq 复核日志，写明实验环境、复现命令、三个案例的前后置条件、OpenHarmony 实现对照、16 条义务的分类及主要思考。后端结果以实测日志为准，随报告附上可定位的结果文件或截图。
