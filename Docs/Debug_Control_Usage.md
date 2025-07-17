# CommentAnalyzer Debug 控制功能使用说明

## 概述

CommentAnalyzer 现在支持细粒度的 debug 控制，允许用户选择性地启用特定类型的调试信息。这样既可以在需要时获取详细的调试信息，又可以在日常使用时保持输出的简洁性。

## 功能特点

- **分层日志控制**：分离用户关心的信息和调试信息
- **类型化调试**：支持多种调试类型，便于针对性排查问题
- **组合使用**：可以同时启用多种调试类型
- **向后兼容**：不影响现有的日志控制参数

## Debug 类型说明

| 类型 | 用途 | 典型场景 |
|------|------|----------|
| `Workflow` | 工作流程跟踪 | 了解工具执行的整体流程 |
| `Analyzer` | 分析器调用 | 排查 Roslynator 分析问题 |
| `Fixer` | 修复器过程 | 调试代码修复逻辑 |
| `Parser` | 解析过程 | 调试日志文件解析问题 |
| `CodeGen` | 代码生成 | 调试 XML 文档注释生成 |
| `FileOp` | 文件操作 | 调试文件读写操作 |
| `NodeMatch` | 节点匹配 | 调试语法树节点匹配逻辑 |
| `Environment` | 环境分析 | 调试多环境分析过程 |
| `All` | 所有类型 | 全面调试（谨慎使用）|

## 使用方法

### 基本语法

```powershell
.\CommentAnalyzer.ps1 -DebugType <DebugType> [其他参数]
```

### 单个类型调试

```powershell
# 启用工作流程调试
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect -DebugType Workflow

# 启用分析器调试
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect -DebugType Analyzer

# 启用修复器调试
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode fix -DebugType Fixer
```

### 多类型组合调试

```powershell
# 同时启用工作流程和分析器调试
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect -DebugType Workflow,Analyzer

# 同时启用修复器和代码生成调试
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode fix -DebugType Fixer,CodeGen
```

### 全面调试

```powershell
# 启用所有调试类型（输出量大，建议仅在深度调试时使用）
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode fix -DebugType All
```

## 输出格式

### 用户信息（始终显示）
```
--- Running in DETECT mode ---
Analysis completed. 4 diagnostics found.
⚠️  Found 4 diagnostic issues:
  - CS1591: 4 issues
```

### 调试信息（按需显示）
```
[DEBUG-Workflow] Generated JobID: 20241224-143022-12345
[DEBUG-Analyzer] Running: C:\...\Roslynator.exe analyze "Project.csproj" ...
[DEBUG-Fixer] === 修复收敛轮次: 1 ===
[DEBUG-Parser] Parsed 4 diagnostics
[DEBUG-CodeGen] 写回文件: C:\...\TestClass.cs
[DEBUG-FileOp] 处理文件: C:\...\TestClass.cs
[DEBUG-NodeMatch] 节点类型: ClassDeclaration | 内容: public class TestClass...
[DEBUG-Environment] 分析环境: Default - 默认编译环境
```

## 常见使用场景

### 日常开发
```powershell
# 只关心结果，不需要调试信息
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect
```

### 分析工具运行缓慢
```powershell
# 查看工作流程和分析器信息
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect -DebugType Workflow,Analyzer
```

### 修复结果不正确
```powershell
# 查看修复器和代码生成过程
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode fix -DebugType Fixer,CodeGen
```

### 文件处理问题
```powershell
# 查看文件操作详情
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode fix -DebugType FileOp
```

### 语法树匹配问题
```powershell
# 查看节点匹配过程
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode fix -DebugType NodeMatch
```

### 条件编译问题
```powershell
# 查看多环境分析过程
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect -MultiEnvironment -DebugType Environment
```

## 性能建议

1. **按需启用**：只启用需要的调试类型，避免不必要的性能开销
2. **避免 All**：除非进行深度调试，否则不要使用 `All` 类型
3. **结合日志级别**：配合 `-ConsoleLogLevel` 和 `-FileLogLevel` 参数使用
4. **CI/CD 环境**：在自动化环境中通常不需要启用调试信息

## 最佳实践

### 推荐的调试组合

| 问题类型 | 推荐的调试组合 | 说明 |
|----------|---------------|------|
| 工具运行失败 | `Workflow,Analyzer` | 定位工具链问题 |
| 修复效果不佳 | `Fixer,CodeGen` | 调试修复逻辑 |
| 文件处理异常 | `FileOp,Parser` | 调试文件读写 |
| 语法分析问题 | `NodeMatch,CodeGen` | 调试语法树操作 |
| 环境兼容问题 | `Environment,Workflow` | 调试多环境分析 |

### 性能优化组合

```powershell
# 高性能 + 基本调试
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode detect -DebugType Workflow -ConsoleLogLevel minimal -FileLogLevel normal

# 详细调试 + 文件日志
.\CommentAnalyzer.ps1 -SolutionPath "Project.csproj" -Mode fix -DebugType Fixer,CodeGen -ConsoleLogLevel minimal -FileLogLevel diag
```

## 测试验证

### 运行调试测试

```powershell
# 测试单个调试类型
.\Tests\DebugTests\Test_Debug_Control.ps1 -DebugType Workflow

# 测试所有调试类型
.\Tests\DebugTests\Run_All_Debug_Tests.ps1
```

### 验证输出

1. **检查调试信息**：确认有相应的 `[DEBUG-类型]` 输出
2. **检查用户信息**：确认基本操作信息正常显示
3. **检查过滤效果**：确认只显示指定类型的调试信息

## 故障排除

### 常见问题

1. **没有调试输出**
   - 检查 `-DebugType` 参数是否正确指定
   - 确认调试类型名称拼写正确
   - 验证工具是否正常运行

2. **输出过多**
   - 避免使用 `All` 类型
   - 选择更具体的调试类型
   - 调整控制台日志级别

3. **性能影响**
   - 调试信息会增加 I/O 开销
   - 在生产环境中应谨慎使用
   - 考虑只在文件中记录详细信息

### 联系支持

如果遇到问题，请提供：
- 使用的调试参数
- 完整的输出日志
- 工具版本信息
- 问题重现步骤

---

*最后更新：2024-12-24* 