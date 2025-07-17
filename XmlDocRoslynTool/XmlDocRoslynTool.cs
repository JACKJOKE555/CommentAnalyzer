/*
 * 文件名: XmlDocRoslynTool.cs
 * 功能: C# XML文档注释自动修复工具 - 基于Roslyn语法分析的注释合规化工具
 * 架构逻辑链(数据流): 
 *   1. Roslynator分析 → 诊断问题识别
 *   2. DocumentationAnalyzer → 语法节点遍历和问题定位
 *   3. XmlDocRewriter → 增量修复和注释生成  
 *   4. XmlDocCleaner → 批量清理XML文档注释
 *   5. 修复报告生成 → JSON格式输出
 * 依赖: 
 *   - Microsoft.CodeAnalysis.CSharp (Roslyn语法分析)
 *   - Roslynator.CommandLine (静态代码分析CLI)
 *   - System.Text.Json (报告序列化)
 * 扩展点:
 *   - WriteDebugInfo: 调试输出控制机制
 *   - DocumentationAnalyzer: 自定义诊断规则扩展
 *   - XmlDocRewriter: 自定义注释模板和修复策略
 * 使用示例:
 *   XmlDocRoslynTool --projectPath="MyProject.csproj" --analyzerPath="ProjectCommentAnalyzer.dll" 
 *                   --msbuildPath="C:\MSBuild\Current\Bin" --xmlLogPath="output.xml"
 *                   --files="File1.cs;File2.cs" --debugType="Fixer,Analyzer"
 */

using System;
using System.IO;
using System.Linq;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.MSBuild;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Text;
using System.Diagnostics;
using System.Xml.Linq;
using System.Text.Json;

namespace XmlDocRoslynTool
{
    /// <summary>
    /// XmlDocRoslynTool - A dedicated .NET tool for fixing C# XML documentation comments.
    /// This tool is the core of the 'fix' mode in the CommentAnalyzer toolchain.
    /// It operates in a self-contained, verifiable "Analyze -> Fix -> Re-analyze -> Report" workflow.
    /// </summary>
    public class Program
    {
        // 移除硬编码的调试开关，改为使用动态的EnabledDebugTypes

        /// <summary>
        /// Application entry point.
        /// Orchestrates the entire fix and verification workflow.
        /// </summary>
        /// <param name="args">Command-line arguments.</param>
        // Debug control - will be set by command line parameters
        private static HashSet<string> EnabledDebugTypes = new HashSet<string>();
        
        // Log verbosity control - will be set by command line parameters
        private static string FileLogVerbosity = "normal";
        private static string ConsoleVerbosity = "minimal";

        /// <summary>
        /// 公共静态方法，供其他类调用
        /// </summary>
        public static void WriteDebugInfo(string debugType, string message)
        {
            if (EnabledDebugTypes.Contains(debugType) || EnabledDebugTypes.Contains("All"))
            {
                Console.WriteLine($"[DEBUG-{debugType}] {message}");
            }
        }
        
        /// <summary>
        /// 输出日志信息，根据日志级别控制输出详细程度
        /// </summary>
        private static void WriteLog(string level, string message, bool isConsole = true)
        {
            var verbosity = isConsole ? ConsoleVerbosity : FileLogVerbosity;
            
            // 根据日志级别决定是否输出
            bool shouldOutput = false;
            switch (verbosity.ToLower())
            {
                case "quiet":
                    shouldOutput = level == "ERROR";
                    break;
                case "minimal":
                    shouldOutput = level == "ERROR" || level == "WARNING" || level == "INFO";
                    break;
                case "normal":
                    shouldOutput = level != "DETAILED";
                    break;
                case "detailed":
                case "diagnostic":
                    shouldOutput = true;
                    break;
                default:
                    shouldOutput = true;
                    break;
            }
            
            if (shouldOutput)
            {
                Console.WriteLine($"[{level}] {message}");
            }
        }

        /// <summary>
        /// 检查指定的调试类型是否启用
        /// </summary>
        public static bool IsDebugEnabled(string debugType)
        {
            return EnabledDebugTypes.Contains(debugType) || EnabledDebugTypes.Contains("All");
        }

        static async Task Main(string[] args)
        {
            // 参数解析
            string? projectPath = null;
            string? analyzerPath = null;
            string? msbuildPath = null;
            string? xmlLogPath = null;
            string? files = null;
            string? debugTypes = null;
            // Add log verbosity parameters support
            string fileLogVerbosity = "normal";
            string consoleVerbosity = "minimal";

            foreach (var arg in args)
            {
                if (arg.StartsWith("--projectPath="))
                    projectPath = arg.Substring("--projectPath=".Length).Trim('"');
                else if (arg.StartsWith("--analyzerPath="))
                    analyzerPath = arg.Substring("--analyzerPath=".Length).Trim('"');
                else if (arg.StartsWith("--msbuildPath="))
                    msbuildPath = arg.Substring("--msbuildPath=".Length).Trim('"');
                else if (arg.StartsWith("--xmlLogPath="))
                    xmlLogPath = arg.Substring("--xmlLogPath=".Length).Trim('"');
                else if (arg.StartsWith("--files="))
                    files = arg.Substring("--files=".Length).Trim('"');
                else if (arg.StartsWith("--debugType="))
                    debugTypes = arg.Substring("--debugType=".Length).Trim('"');
                else if (arg.StartsWith("--file-log-verbosity="))
                    fileLogVerbosity = arg.Substring("--file-log-verbosity=".Length).Trim('"');
                else if (arg.StartsWith("--verbosity="))
                    consoleVerbosity = arg.Substring("--verbosity=".Length).Trim('"');
            }

            // 设置日志级别控制
            FileLogVerbosity = fileLogVerbosity;
            ConsoleVerbosity = consoleVerbosity;
            
            // 解析调试类型
            if (!string.IsNullOrEmpty(debugTypes))
            {
                var types = debugTypes.Split(',', ';').Select(t => t.Trim()).Where(t => !string.IsNullOrEmpty(t));
                foreach (var type in types)
                {
                    EnabledDebugTypes.Add(type);
                }
                WriteDebugInfo("Fixer", $"Enabled debug types: {string.Join(", ", EnabledDebugTypes)}");
            }
            
            WriteLog("DETAILED", $"Log verbosity settings - Console: {ConsoleVerbosity}, File: {FileLogVerbosity}");

            if (string.IsNullOrEmpty(projectPath) || string.IsNullOrEmpty(analyzerPath) || string.IsNullOrEmpty(msbuildPath) || string.IsNullOrEmpty(xmlLogPath))
            {
                Console.WriteLine("Usage: XmlDocRoslynTool --projectPath=<csproj> --analyzerPath=<dll> --msbuildPath=<msbuild_dir> --xmlLogPath=<output.xml> [--files=<file1;file2>]");
                return;
            }

            try
            {
                WriteLog("INFO", "Starting XmlDocRoslynTool workflow...");
                // 预处理流程（如有）
                WriteLog("DETAILED", "[预处理] 内置分析/格式修复流程（占位，后续可扩展）");
                // 预处理后不return，继续主流程

                // Phase 1: Pre-analysis - Generate initial diagnostics
                WriteLog("INFO", "[PHASE 1] Running pre-analysis...");
                var preAnalysisLog = xmlLogPath.Replace(".xml", "_pre.xml");
                await RunRoslynatorAnalysis(projectPath, analyzerPath, msbuildPath, preAnalysisLog);

                if (!File.Exists(preAnalysisLog))
                {
                    WriteLog("WARNING", "Pre-analysis failed - no diagnostics log generated");
                    return;
                }

                // Phase 2: Parse diagnostics and identify files to fix
                WriteLog("INFO", "[PHASE 2] Parsing diagnostics...");
                var diagnostics = ParseDiagnosticsXml(preAnalysisLog);
                var filesToFix = GetFilesToFix(diagnostics, files);

                if (!filesToFix.Any())
                {
                    WriteLog("INFO", "No issues found that require fixing");
                    WriteLog("INFO", "[PASS] 所有诊断已修复");
                    
                    // 生成简化的报告，显示没有问题需要修复
                    var noIssuesReport = new
                    {
                        Timestamp = DateTime.UtcNow,
                        Summary = new
                        {
                            IssuesBefore = 0,
                            IssuesAfter = 0,
                            IssuesFixed = 0,
                            FilesProcessed = 0,
                            FilesSuccessful = 0
                        },
                        FileResults = new List<object>(),
                        RemainingIssues = new List<object>()
                    };
                    
                    var noIssuesReportPath = xmlLogPath.Replace(".xml", "_report.json");
                    var json = System.Text.Json.JsonSerializer.Serialize(noIssuesReport, new JsonSerializerOptions { WriteIndented = true });
                    await File.WriteAllTextAsync(noIssuesReportPath, json);
                    
                    WriteLog("INFO", $"Fix workflow completed. Report: {noIssuesReportPath}");
                    return;
                }

                WriteLog("INFO", $"Found {diagnostics.Count} diagnostics across {filesToFix.Count} files");

                // Phase 3: Fix the code files
                WriteLog("INFO", "[PHASE 3] Applying fixes...");
                var fixResults = await ApplyFixes(projectPath, filesToFix, diagnostics);

                // Phase 4: Post-analysis - Generate final diagnostics
                WriteLog("INFO", "[PHASE 4] Running post-analysis...");
                var postAnalysisLog = xmlLogPath.Replace(".xml", "_post.xml");
                await RunRoslynatorAnalysis(projectPath, analyzerPath, msbuildPath, postAnalysisLog);

                // Phase 5: Generate fix report
                WriteLog("INFO", "[PHASE 5] Generating fix report...");
                var reportPath = xmlLogPath.Replace(".xml", "_report.json");
                await GenerateFixReport(preAnalysisLog, postAnalysisLog, fixResults, reportPath);

                WriteLog("INFO", $"Fix workflow completed. Report: {reportPath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] Fix workflow failed: {ex.Message}");
                Console.WriteLine(ex.StackTrace);
            }
        }

        // clean子流程，批量清理XML注释
        private static async Task RunCleanSubprocess(string projectPath, string files)
        {
            Console.WriteLine("[INFO] [clean] 执行clean子流程，批量清理XML文档注释...");
            var fileList = new List<string>();
            if (!string.IsNullOrEmpty(files))
            {
                fileList.AddRange(files.Split(';').Select(f => f.Trim()).Where(f => !string.IsNullOrEmpty(f)));
            }
            else
            {
                var projDir = Path.GetDirectoryName(projectPath);
                if (!string.IsNullOrEmpty(projDir))
                {
                    fileList.AddRange(Directory.GetFiles(projDir, "*.cs", SearchOption.AllDirectories));
                }
                else
                {
                    WriteLog("WARNING", "项目路径无效，无法确定项目目录");
                }
            }
            int cleanCount = 0;
            foreach (var file in fileList)
            {
                WriteDebugInfo("FileOp", $"处理文件: {file}");
                try
                {
                    var code = File.ReadAllText(file);
                    var tree = CSharpSyntaxTree.ParseText(code);
                    var root = tree.GetRoot();
                    
                    WriteDebugInfo("FileOp", $"解析文件完成: {file} | rootType={root.GetType()}");
                    if (IsDebugEnabled("NodeMatch"))
                    {
                        var codePreview = code.Substring(0, Math.Min(200, code.Length)).Replace("\n", " ");
                        WriteDebugInfo("NodeMatch", $"文件内容预览: {codePreview}");
                    }
                    
                    var cleaner = new XmlDocCleaner();
                    var newRoot = cleaner.Visit(root);
                    WriteDebugInfo("FileOp", $"清理完成: {file} | ChangesMade={cleaner.ChangesMade}");
                    
                    // 只在特定调试模式下输出详细节点信息
                    if (!cleaner.ChangesMade && IsDebugEnabled("NodeMatch"))
                    {
                        WriteDebugInfo("NodeMatch", "Visit未递归，手动遍历所有节点:");
                        foreach (var node in root.DescendantNodesAndSelf().Take(10)) // 限制输出数量避免日志泛滥
                        {
                            WriteDebugInfo("NodeMatch", $"节点类型: {node.Kind()} | 内容: {node.ToString().Split('\n')[0].Trim()}...");
                            var leading = node.GetLeadingTrivia();
                            foreach (var trivia in leading.Take(5)) // 限制输出数量
                            {
                                WriteDebugInfo("NodeMatch", $"  LeadingTrivia: {trivia.Kind()} | 内容: {trivia.ToFullString().Trim()}");
                            }
                        }
                    }
                    
                    if (cleaner.ChangesMade)
                    {
                        WriteDebugInfo("FileOp", $"写回文件: {file}");
                        File.WriteAllText(file, newRoot.ToFullString());
                        cleanCount++;
                        WriteLog("INFO", $"Cleared XML doc comments in: {file}");
                    }
                    else
                    {
                        WriteDebugInfo("FileOp", $"无需写回: {file}");
                    }
                }
                catch (Exception ex)
                {
                    WriteLog("ERROR", $"Failed to clean {file}: {ex.Message}");
                    if (IsDebugEnabled("FileOp"))
                    {
                        WriteDebugInfo("FileOp", $"详细错误信息: {ex.StackTrace}");
                    }
                }
            }
            Console.WriteLine($"[CLEAN] XML文档注释清理完成，共处理{cleanCount}个文件。");
            await Task.CompletedTask;
        }

        // fix主流程，分析-修复-再分析-报告
        private static async Task RunFixMainProcess(string projectPath, string analyzerPath, string msbuildPath, string xmlLogPath, string files)
        {
            WriteLog("INFO", "[fix] 执行fix主流程: 分析 → 修复 → 再分析 → 报告");
            
            try
            {
                // 步骤1: 修复前分析
                WriteLog("INFO", "[fix] 步骤1: 执行修复前分析...");
                var preAnalysisLog = xmlLogPath.Replace(".xml", "_pre.xml");
                await RunRoslynatorAnalysis(projectPath, analyzerPath, msbuildPath, preAnalysisLog);
                
                var preDiagnostics = ParseDiagnosticsXml(preAnalysisLog);
                WriteLog("INFO", $"[fix] 修复前发现 {preDiagnostics.Count} 个问题");
                
                if (preDiagnostics.Count == 0)
                {
                    WriteLog("INFO", "[fix] 没有发现需要修复的问题，跳过修复步骤");
                    return;
                }
                
                // 步骤2: 执行修复
                WriteLog("INFO", "[fix] 步骤2: 执行自动修复...");
                var filesToFix = GetFilesToFix(preDiagnostics, files);
                WriteLog("INFO", $"[fix] 需要修复的文件数: {filesToFix.Count}");
                
                var fixResults = await ApplyFixes(projectPath, filesToFix, preDiagnostics);
                var successfulFixes = fixResults.Values.Count(r => r.Success);
                var totalFixes = fixResults.Values.Sum(r => r.FixesApplied);
                WriteLog("INFO", $"[fix] 修复完成: {successfulFixes}/{fixResults.Count} 个文件成功，共应用 {totalFixes} 个修复");
                
                // 步骤3: 修复后再分析
                WriteLog("INFO", "[fix] 步骤3: 执行修复后验证分析...");
                var postAnalysisLog = xmlLogPath.Replace(".xml", "_post.xml");
                await RunRoslynatorAnalysis(projectPath, analyzerPath, msbuildPath, postAnalysisLog);
                
                var postDiagnostics = ParseDiagnosticsXml(postAnalysisLog);
                WriteLog("INFO", $"[fix] 修复后还剩 {postDiagnostics.Count} 个问题");
                
                // 步骤4: 生成修复报告
                WriteLog("INFO", "[fix] 步骤4: 生成修复报告...");
                var reportPath = xmlLogPath.Replace(".xml", "_fix_report.json");
                await GenerateFixReport(preAnalysisLog, postAnalysisLog, fixResults, reportPath);
                WriteLog("INFO", $"[fix] 修复报告已生成: {reportPath}");
                
                // 输出修复总结
                var fixedIssues = Math.Max(0, preDiagnostics.Count - postDiagnostics.Count);
                WriteLog("INFO", $"[fix] 修复总结: 修复前 {preDiagnostics.Count} 个问题 → 修复后 {postDiagnostics.Count} 个问题 (修复了 {fixedIssues} 个)");
                
                if (postDiagnostics.Count == 0)
                {
                    WriteLog("INFO", "[fix] ✅ 所有问题已成功修复!");
                }
                else if (fixedIssues > 0)
                {
                    WriteLog("WARNING", $"[fix] ⚠️ 还有 {postDiagnostics.Count} 个问题需要人工处理");
                }
                else
                {
                    WriteLog("WARNING", "[fix] ⚠️ 未能自动修复任何问题，可能需要人工介入");
                }
            }
            catch (Exception ex)
            {
                WriteLog("ERROR", $"[fix] 修复流程执行失败: {ex.Message}");
                if (IsDebugEnabled("Fixer"))
                {
                    WriteLog("ERROR", $"[fix] 详细错误信息: {ex.StackTrace}");
                }
                throw;
            }
        }

        private static async Task RunRoslynatorAnalysis(string projectPath, string analyzerPath, string msbuildPath, string outputPath)
        {
            // Roslynator CLI 路径 - 使用相对于当前exe的路径
            var exeDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
            if (string.IsNullOrEmpty(exeDir))
            {
                throw new InvalidOperationException("无法确定当前程序的执行目录");
            }
            var roslynatorPath = Path.Combine(exeDir, "..", "..", "..", "..", ".nuget", "packages", "roslynator.commandline", "0.10.1", "tools", "net48", "Roslynator.exe");
            roslynatorPath = Path.GetFullPath(roslynatorPath);
            
            if (!File.Exists(roslynatorPath))
            {
                throw new FileNotFoundException($"Roslynator CLI not found at {roslynatorPath}");
            }

            // 根据日志级别决定Roslynator的verbosity
            string roslynatorVerbosity;
            switch (ConsoleVerbosity.ToLower())
            {
                case "quiet":
                    roslynatorVerbosity = "q";
                    break;
                case "minimal":
                    roslynatorVerbosity = "m";
                    break;
                case "normal":
                    roslynatorVerbosity = "n";
                    break;
                case "detailed":
                    roslynatorVerbosity = "d";
                    break;
                case "diagnostic":
                    roslynatorVerbosity = "diag";
                    break;
                default:
                    roslynatorVerbosity = "q"; // 默认使用quiet模式减少输出
                    break;
            }

            // 组装命令行参数
            var roslynatorArgs = $"analyze \"{projectPath}\" -a \"{analyzerPath}\" -o \"{outputPath}\" -m \"{msbuildPath}\" --verbosity {roslynatorVerbosity}";
            WriteLog("DETAILED", $"Running: {roslynatorPath} {roslynatorArgs}");

            var process = new Process();
            process.StartInfo.FileName = roslynatorPath;
            process.StartInfo.Arguments = roslynatorArgs;
            process.StartInfo.UseShellExecute = false;
            process.StartInfo.RedirectStandardOutput = true;
            process.StartInfo.RedirectStandardError = true;
            process.StartInfo.CreateNoWindow = true;

            process.Start();
            string output = await process.StandardOutput.ReadToEndAsync();
            string error = await process.StandardError.ReadToEndAsync();
            process.WaitForExit();

            // 只在详细模式下输出Roslynator的完整输出
            if (!string.IsNullOrWhiteSpace(output) && (ConsoleVerbosity == "detailed" || ConsoleVerbosity == "diagnostic"))
                WriteLog("DETAILED", $"Roslynator Output: {output}");
            if (!string.IsNullOrWhiteSpace(error))
                WriteLog("WARNING", $"Roslynator Error: {error}");

            if (!File.Exists(outputPath))
            {
                WriteLog("WARNING", $"Analysis completed but no XML log generated at: {outputPath}");
            }
        }

        private static List<DiagnosticInfo> ParseDiagnosticsXml(string xmlPath)
        {
            var diagnostics = new List<DiagnosticInfo>();
            
            try
            {
                var doc = XDocument.Load(xmlPath);
                var diagnosticElements = doc.Descendants("Diagnostic")
                    .Where(d => d.Attribute("Id")?.Value?.StartsWith("PROJECT_") == true);

                foreach (var element in diagnosticElements)
                {
                    var id = element.Attribute("Id")?.Value ?? "";
                    var message = element.Element("Message")?.Value ?? "";
                    var filePathElement = element.Element("FilePath");
                    var locationElement = element.Element("Location");
                    
                    if (!string.IsNullOrEmpty(id) && id.StartsWith("PROJECT_") && filePathElement != null && locationElement != null)
                    {
                        var diagnostic = new DiagnosticInfo
                        {
                            Id = id,
                            File = filePathElement.Value,
                            Line = int.TryParse(locationElement.Attribute("Line")?.Value, out var line) ? line : 0,
                            Column = int.TryParse(locationElement.Attribute("Character")?.Value, out var column) ? column : 0,
                            Message = message
                        };
                        
                        diagnostics.Add(diagnostic);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] Failed to parse diagnostics XML: {ex.Message}");
            }
            
            return diagnostics;
        }

        private static Dictionary<string, List<DiagnosticInfo>> GetFilesToFix(List<DiagnosticInfo> diagnostics, string? filesFilter)
        {
            var filesToFix = new Dictionary<string, List<DiagnosticInfo>>();
            
            Console.WriteLine($"[DEBUG-Fixer] GetFilesToFix: 输入诊断数量 = {diagnostics.Count}");
            Console.WriteLine($"[DEBUG-Fixer] GetFilesToFix: 文件过滤器 = {filesFilter ?? "null"}");
            
            HashSet<string> allowedFiles = null;
            if (!string.IsNullOrEmpty(filesFilter))
            {
                allowedFiles = new HashSet<string>(filesFilter.Split(';'), StringComparer.OrdinalIgnoreCase);
                Console.WriteLine($"[DEBUG-Fixer] GetFilesToFix: 允许的文件数量 = {allowedFiles.Count}");
            }
            
            foreach (var diagnostic in diagnostics)
            {
                Console.WriteLine($"[DEBUG-Fixer] GetFilesToFix: 处理诊断 {diagnostic.Id} (文件: {diagnostic.File})");
                
                if (allowedFiles != null && !allowedFiles.Any(f => diagnostic.File.Equals(f, StringComparison.OrdinalIgnoreCase)))
                {
                    Console.WriteLine($"[DEBUG-Fixer] GetFilesToFix: 跳过文件 {diagnostic.File} (不在允许列表中)");
                    continue;
                }
                
                if (!filesToFix.ContainsKey(diagnostic.File))
                {
                    filesToFix[diagnostic.File] = new List<DiagnosticInfo>();
                }
                filesToFix[diagnostic.File].Add(diagnostic);
                Console.WriteLine($"[DEBUG-Fixer] GetFilesToFix: 添加诊断 {diagnostic.Id} 到修复列表");
            }
            
            Console.WriteLine($"[DEBUG-Fixer] GetFilesToFix: 最终结果 = {filesToFix.Count} 个文件需要修复");
            return filesToFix;
        }

        private static async Task<Dictionary<string, FixResult>> ApplyFixes(string projectPath, Dictionary<string, List<DiagnosticInfo>> filesToFix, List<DiagnosticInfo> allDiagnostics)
        {
            var results = new Dictionary<string, FixResult>();
            foreach (var kvp in filesToFix)
            {
                var filePath = kvp.Key;
                var diagnostics = kvp.Value;
                try
                {
                    // 只对诊断列表中的节点修复，且节点已有合规注释时不再重复修复
                    var fixResult = await FixSingleFileSimple(filePath, diagnostics);
                    results[filePath] = fixResult;
                }
                catch (Exception ex)
                {
                    results[filePath] = new FixResult { FilePath = filePath, Success = false, ErrorMessage = ex.Message };
                }
            }
            return results;
        }

        private static async Task<FixResult> FixSingleFileSimple(string filePath, List<DiagnosticInfo> diagnostics)
        {
            var code = await File.ReadAllTextAsync(filePath);
            var tree = CSharpSyntaxTree.ParseText(code);
            var mscorlib = MetadataReference.CreateFromFile(typeof(object).Assembly.Location);
            var compilation = CSharpCompilation.Create("Temp", new[] { tree }, new[] { mscorlib });
            var model = compilation.GetSemanticModel(tree);
            var analyzer = new DocumentationAnalyzer(model, diagnostics);
            analyzer.Visit(tree.GetRoot());
            
            // 🔧 重要调试：输出NodesToFix的内容
            Console.WriteLine($"[DEBUG-Fixer] DocumentationAnalyzer完成，NodesToFix数量: {analyzer.NodesToFix.Count}");
            if (IsDebugEnabled("Fixer"))
            {
                foreach (var kvp in analyzer.NodesToFix)
                {
                    var nodeType = kvp.Key.GetType().Name;
                    var symbolName = kvp.Value.Name;
                    var symbolKind = kvp.Value.Kind;
                    var nodeLocation = kvp.Key.GetLocation().GetLineSpan().StartLinePosition.Line + 1;
                    Console.WriteLine($"[DEBUG-Fixer] NodesToFix: {nodeType} (line {nodeLocation}) -> {symbolName} ({symbolKind})");
                }
            }
            
            var rewriter = new XmlDocRewriter(analyzer.NodesToFix, diagnostics, analyzer);
            Console.WriteLine($"[DEBUG-Fixer] XmlDocRewriter创建完成，开始遍历语法树");
            var newRoot = rewriter.Visit(tree.GetRoot());
            Console.WriteLine($"[DEBUG-Fixer] XmlDocRewriter遍历完成，ChangesMade: {rewriter.ChangesMade}");
            
            // 🔧 TC_F_003 专项调试：修复完成后的统计信息
            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 修复完成统计:");
            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 原始待修复节点数: {analyzer.NodesToFix.Count}");
            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 修复器报告变更: {rewriter.ChangesMade}");
            
            var testClass3WasInList = analyzer.NodesToFix.Values.Any(s => s.Name == "TestClass3");
            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3是否在待修复列表中: {testClass3WasInList}");
            
            if (testClass3WasInList)
            {
                var testClass3Symbol = analyzer.NodesToFix.Values.First(s => s.Name == "TestClass3");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3符号信息: {testClass3Symbol.Name} ({testClass3Symbol.Kind})");
            }
            
            if (!rewriter.ChangesMade)
                return new FixResult { FilePath = filePath, Success = true, FixesApplied = 0 };
            await File.WriteAllTextAsync(filePath, newRoot.ToFullString());
            return new FixResult { FilePath = filePath, Success = true, FixesApplied = analyzer.NodesToFix.Count };
        }

        private static async Task GenerateFixReport(string preAnalysisLog, string postAnalysisLog, Dictionary<string, FixResult> fixResults, string reportPath)
        {
            var preDiagnostics = File.Exists(preAnalysisLog) ? ParseDiagnosticsXml(preAnalysisLog) : new List<DiagnosticInfo>();
            var postDiagnostics = File.Exists(postAnalysisLog) ? ParseDiagnosticsXml(postAnalysisLog) : new List<DiagnosticInfo>();
            
            var report = new
            {
                Timestamp = DateTime.UtcNow,
                Summary = new
                {
                    IssuesBefore = preDiagnostics.Count,
                    IssuesAfter = postDiagnostics.Count,
                    IssuesFixed = Math.Max(0, preDiagnostics.Count - postDiagnostics.Count),
                    FilesProcessed = fixResults.Count,
                    FilesSuccessful = fixResults.Values.Count(r => r.Success)
                },
                FileResults = fixResults.Values.ToList(),
                RemainingIssues = postDiagnostics.Select(d => new { d.Id, d.File, d.Line, d.Message }).ToList()
            };
            
            var json = System.Text.Json.JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true });
            await File.WriteAllTextAsync(reportPath, json);
        }

        // Data classes for diagnostics and results
        internal class DiagnosticInfo
        {
            public string Id { get; set; } = "";
            public string File { get; set; } = "";
            public int Line { get; set; }
            public int Column { get; set; }
            public string Message { get; set; } = "";
        }

        internal class FixResult
        {
            public string FilePath { get; set; } = "";
            public bool Success { get; set; }
            public int FixesApplied { get; set; }
            public string ErrorMessage { get; set; } = "";
        }
        /// <summary>
        /// First pass: Walks the tree with a valid SemanticModel to find nodes that need fixing based on diagnostics.
        /// Does NOT modify the tree.
        /// </summary>
        internal class DocumentationAnalyzer : CSharpSyntaxWalker
    {
        private readonly SemanticModel _semanticModel;
        private readonly List<DiagnosticInfo> _diagnostics;
        private readonly HashSet<int> _diagnosticLines;
        private readonly HashSet<string> _diagnosticMessages;
        public Dictionary<SyntaxNode, ISymbol> NodesToFix { get; } = new Dictionary<SyntaxNode, ISymbol>();
        private readonly bool _debug;

        public DocumentationAnalyzer(SemanticModel semanticModel, List<DiagnosticInfo>? diagnostics = null)
        {
            _semanticModel = semanticModel;
            _diagnostics = diagnostics ?? new List<DiagnosticInfo>();
            _diagnosticLines = new HashSet<int>(_diagnostics.Select(d => d.Line));
            _diagnosticMessages = new HashSet<string>(_diagnostics.Select(d => d.Message), StringComparer.OrdinalIgnoreCase);
            _debug = IsDebugEnabled("NodeMatch");
            
            // 🔧 TC_F_003 专项调试：详细输出所有诊断信息
            Console.WriteLine($"[DEBUG-TC_F_003] ===== DocumentationAnalyzer 构造完成 =====");
            Console.WriteLine($"[DEBUG-TC_F_003] 总诊断数量: {_diagnostics.Count}");
            Console.WriteLine($"[DEBUG-TC_F_003] 诊断行号集合: [{string.Join(", ", _diagnosticLines)}]");
            
            foreach (var diag in _diagnostics)
            {
                var isTestClass3 = diag.Message.Contains("TestClass3");
                var isValueField = diag.Message.Contains("Value");
                var marker = isTestClass3 ? "🎯TestClass3" : (isValueField ? "📍Value" : "");
                Console.WriteLine($"[DEBUG-TC_F_003] {marker} 诊断: {diag.Id} at line {diag.Line} - {diag.Message}");
            }
            Console.WriteLine($"[DEBUG-TC_F_003] ===== 诊断信息输出完毕 =====");
            
            // 添加调试输出
            if (IsDebugEnabled("NodeMatch"))
            {
                Console.WriteLine($"[DEBUG-NodeMatch] DocumentationAnalyzer created with {_diagnostics.Count} diagnostics");
                foreach (var diag in _diagnostics)
                {
                    Console.WriteLine($"[DEBUG-NodeMatch] Diagnostic: {diag.Id} at {diag.File}:{diag.Line}:{diag.Column} - {diag.Message}");
                }
            }
        }

        public override void VisitClassDeclaration(ClassDeclarationSyntax node)
        {
            // 🔧 TC_F_003 专项调试：跟踪TestClass3的访问过程
            var className = node.Identifier.ValueText;
            var isTestClass3 = className == "TestClass3";
            
            if (isTestClass3)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 访问TestClass3类声明");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点位置: line {node.GetLocation().GetLineSpan().StartLinePosition.Line + 1}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点类型: {node.Kind()}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 开始CheckAndAddNode处理...");
            }
            
            CheckAndAddNode(node);
            
            // 🔧 TC_F_003 专项调试：检查TestClass3是否被添加到NodesToFix
            if (isTestClass3)
            {
                var wasAdded = NodesToFix.ContainsKey(node);
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3 CheckAndAddNode完成");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3 是否被添加到NodesToFix: {wasAdded}");
                if (wasAdded)
                {
                    var mappedSymbol = NodesToFix[node];
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3 映射符号: {mappedSymbol.Name} ({mappedSymbol.Kind})");
                }
                
                // 输出当前NodesToFix的完整状态
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 当前NodesToFix字典内容 ({NodesToFix.Count} 项):");
                foreach (var kvp in NodesToFix)
                {
                    var nodeType = kvp.Key.GetType().Name;
                    var symbolName = kvp.Value.Name;
                    var symbolKind = kvp.Value.Kind;
                    var nodeLocation = kvp.Key.GetLocation().GetLineSpan().StartLinePosition.Line + 1;
                    var marker = symbolName == "TestClass3" ? "🎯" : (symbolName == "Value" ? "📍" : "");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯   {marker} {nodeType}(line {nodeLocation}) -> {symbolName} ({symbolKind})");
                }
            }
            
            base.VisitClassDeclaration(node);
        }

        public override void VisitStructDeclaration(StructDeclarationSyntax structDeclaration)
        {
            CheckAndAddNode(structDeclaration);
            base.VisitStructDeclaration(structDeclaration);
        }

        public override void VisitInterfaceDeclaration(InterfaceDeclarationSyntax interfaceDeclaration)
        {
            CheckAndAddNode(interfaceDeclaration);
            base.VisitInterfaceDeclaration(interfaceDeclaration);
        }

        public override void VisitEnumDeclaration(EnumDeclarationSyntax enumDeclaration)
        {
            CheckAndAddNode(enumDeclaration);
            base.VisitEnumDeclaration(enumDeclaration);
        }

        public override void VisitMethodDeclaration(MethodDeclarationSyntax methodDeclaration)
        {
            CheckAndAddNode(methodDeclaration);
            base.VisitMethodDeclaration(methodDeclaration);
        }

        public override void VisitPropertyDeclaration(PropertyDeclarationSyntax propertyDeclaration)
        {
            CheckAndAddNode(propertyDeclaration);
            base.VisitPropertyDeclaration(propertyDeclaration);
        }

        public override void VisitFieldDeclaration(FieldDeclarationSyntax node)
        {
            if (IsDebugEnabled("NodeMatch"))
            {
                var symbol = _semanticModel.GetDeclaredSymbol(node.Declaration.Variables.First());
                Console.WriteLine($"[DEBUG-NodeMatch] VisitFieldDeclaration: Processing field node");
                Console.WriteLine($"[DEBUG-NodeMatch] Field symbol: {symbol?.Name} ({symbol?.Kind})");
                Console.WriteLine($"[DEBUG-NodeMatch] Field location: {node.GetLocation().GetLineSpan().StartLinePosition}");
            }
            
            // 修复：统一使用CheckAndAddNode方法，避免特殊的字段处理逻辑导致映射错误
            CheckAndAddNode(node);
            base.VisitFieldDeclaration(node);
        }

        public override void VisitConstructorDeclaration(ConstructorDeclarationSyntax constructorDeclaration)
        {
            CheckAndAddNode(constructorDeclaration);
            base.VisitConstructorDeclaration(constructorDeclaration);
        }

        public override void VisitEventDeclaration(EventDeclarationSyntax eventDeclaration)
        {
            CheckAndAddNode(eventDeclaration);
            base.VisitEventDeclaration(eventDeclaration);
        }

        public override void VisitEventFieldDeclaration(EventFieldDeclarationSyntax eventFieldDeclaration)
        {
            CheckAndAddNode(eventFieldDeclaration);
            base.VisitEventFieldDeclaration(eventFieldDeclaration);
        }

        public override void VisitDelegateDeclaration(DelegateDeclarationSyntax delegateDeclaration)
        {
            CheckAndAddNode(delegateDeclaration);
            base.VisitDelegateDeclaration(delegateDeclaration);
        }

        public override void VisitDestructorDeclaration(DestructorDeclarationSyntax destructorDeclaration)
        {
            CheckAndAddNode(destructorDeclaration);
            base.VisitDestructorDeclaration(destructorDeclaration);
        }

        public override void VisitOperatorDeclaration(OperatorDeclarationSyntax operatorDeclaration)
        {
            CheckAndAddNode(operatorDeclaration);
            base.VisitOperatorDeclaration(operatorDeclaration);
        }

        public override void VisitConversionOperatorDeclaration(ConversionOperatorDeclarationSyntax conversionOperatorDeclaration)
        {
            CheckAndAddNode(conversionOperatorDeclaration);
            base.VisitConversionOperatorDeclaration(conversionOperatorDeclaration);
        }

        public override void VisitIndexerDeclaration(IndexerDeclarationSyntax indexerDeclaration)
        {
            CheckAndAddNode(indexerDeclaration);
            base.VisitIndexerDeclaration(indexerDeclaration);
        }

        private void CheckAndAddNode(SyntaxNode node)
        {
            // 🔧 TC_F_003 专项调试：跟踪CheckAndAddNode的处理过程
            ISymbol symbol = null;
            
            // 根据节点类型获取正确的符号
            if (node is FieldDeclarationSyntax fieldDecl)
            {
                // 对于字段声明，需要从Variables集合中获取符号
                var variable = fieldDecl.Declaration.Variables.FirstOrDefault();
                if (variable != null)
                {
                    symbol = _semanticModel.GetDeclaredSymbol(variable);
                }
            }
            else
            {
                // 对于其他节点类型，直接获取符号
                symbol = _semanticModel.GetDeclaredSymbol(node);
            }
            
            var isTestClass3Related = symbol?.Name == "TestClass3" || 
                                    (node is ClassDeclarationSyntax classNode && classNode.Identifier.ValueText == "TestClass3");
            
            if (isTestClass3Related)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 CheckAndAddNode 处理TestClass3相关节点");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点类型: {node.GetType().Name}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点位置: line {node.GetLocation().GetLineSpan().StartLinePosition.Line + 1}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号获取结果: {(symbol != null ? $"{symbol.Name} ({symbol.Kind})" : "NULL")}");
            }
            
            if (symbol == null)
            {
                if (isTestClass3Related)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3 符号获取失败，跳过处理");
                }
                return;
            }
            
            // 🔧 TC_F_003 专项调试：检查诊断匹配过程
            if (isTestClass3Related)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 开始检查TestClass3的诊断匹配...");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 总诊断数量: {_diagnostics.Count}");
            }
            
            // 遍历所有诊断，检查是否匹配当前节点
            foreach (var diagnostic in _diagnostics)
            {
                if (isTestClass3Related)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 检查诊断匹配: {diagnostic.Id} - {diagnostic.Message}");
                }
                
                if (IsDebugEnabled("NodeMatch"))
                {
                    Console.WriteLine($"[DEBUG-NodeMatch] CheckAndAddNode: 检查诊断 {diagnostic.Id} - {diagnostic.Message}");
                }
                
                // 使用结构化匹配方法
                var isMatch = IsNodeMatchByStructure(node, symbol, diagnostic);
                
                if (isTestClass3Related)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3 匹配结果: {isMatch}");
                }
                
                if (isMatch)
                {
                    if (IsDebugEnabled("NodeMatch"))
                    {
                        Console.WriteLine($"[DEBUG-NodeMatch] CheckAndAddNode: ✅ 匹配成功！添加节点 {node.Kind()} - {symbol.Name} 到处理队列");
                    }
                    
                    // 🔧 关键修复：在添加映射前再次验证一致性
                    if (CheckNodeSymbolConsistency(node, symbol))
                    {
                        // 添加到待处理映射
                        NodesToFix[node] = symbol;
                        if (IsDebugEnabled("NodeMatch"))
                        {
                            Console.WriteLine($"[DEBUG-NodeMatch] CheckAndAddNode: ✅ 映射已添加: {node.Kind()} -> {symbol.Name} ({symbol.Kind})");
                        }
                        
                        // 🔧 TC_F_003 专项调试：TestClass3被添加时的详细信息
                        if (isTestClass3Related)
                        {
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3 成功添加到NodesToFix!");
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 映射关系: {node.Kind()} -> {symbol.Name} ({symbol.Kind})");
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 触发诊断: {diagnostic.Id} - {diagnostic.Message}");
                        }
                    }
                    else
                    {
                        if (IsDebugEnabled("NodeMatch"))
                        {
                            Console.WriteLine($"[DEBUG-NodeMatch] CheckAndAddNode: ❌ 映射被拒绝，一致性检查失败: {node.Kind()} -> {symbol.Name} ({symbol.Kind})");
                        }
                        
                        // 🔧 TC_F_003 专项调试：TestClass3一致性检查失败
                        if (isTestClass3Related)
                        {
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3 一致性检查失败!");
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点类型: {node.Kind()}");
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号类型: {symbol.Kind}");
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号名称: {symbol.Name}");
                        }
                    }
                    break;
                }
            }
            
            // 🔧 TC_F_003 专项调试：如果TestClass3没有匹配到任何诊断
            if (isTestClass3Related && !NodesToFix.ContainsKey(node))
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3 没有匹配到任何诊断，不会被添加到NodesToFix");
            }
        }

        /// <summary>
        /// 基于语法树结构和符号信息的精确匹配，替代不可靠的行号匹配
        /// </summary>
        private bool IsNodeMatchByStructure(SyntaxNode node, ISymbol symbol, DiagnosticInfo diagnostic)
        {
            string symbolName = symbol.Name;
            string diagnosticMessage = diagnostic.Message ?? "";
            
            // 🔧 TC_F_003 专项调试：跟踪TestClass3的匹配过程
            var isTestClass3Related = symbolName == "TestClass3" || diagnosticMessage.Contains("TestClass3");
            
            if (isTestClass3Related)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 IsNodeMatchByStructure 处理TestClass3");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点类型: {node.Kind()}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号名称: {symbolName}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号类型: {symbol.Kind}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 诊断ID: {diagnostic.Id}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 诊断消息: {diagnosticMessage}");
            }
            
            // 添加详细的调试输出
            if (IsDebugEnabled("NodeMatch"))
            {
                Console.WriteLine($"[DEBUG-NodeMatch] IsNodeMatchByStructure: Node={node.Kind()}, Symbol={symbolName} ({symbol.Kind}), DiagnosticId={diagnostic.Id}");
                Console.WriteLine($"[DEBUG-NodeMatch] DiagnosticMessage: {diagnosticMessage}");
            }
            
            // 根据诊断类型进行具体的结构匹配
            switch (diagnostic.Id)
            {
                case "PROJECT_TYPE_NO_COMMENT_BLOCK":
                case "PROJECT_TYPE_MISSING_SUMMARY":
                case "PROJECT_TYPE_MISSING_REMARKS":
                case "PROJECT_TYPE_MISSING_REMARKS_TAG":
                case "PROJECT_TYPE_DUPLICATE_SUMMARY":
                case "PROJECT_TYPE_DUPLICATE_REMARKS":
                    // 类型级别诊断：必须是类型节点且符号也是类型
                    if (isTestClass3Related || IsDebugEnabled("NodeMatch"))
                    {
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 类型级别诊断匹配检查");
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点类型: {node.Kind()}");
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号类型: {symbol.Kind}");
                    }
                    
                    // 严格验证：必须是类型节点且符号是类型且消息包含符号名
                    bool isTypeNode = IsTypeDeclarationNode(node);
                    bool isTypeSymbol = symbol.Kind == SymbolKind.NamedType;
                    bool messageContainsSymbol = diagnosticMessage.Contains(symbolName);
                    
                    if (isTestClass3Related)
                    {
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 isTypeNode: {isTypeNode} (节点 {node.Kind()})");
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 isTypeSymbol: {isTypeSymbol} (符号 {symbol.Kind})");
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 messageContainsSymbol: {messageContainsSymbol}");
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 消息内容: \"{diagnosticMessage}\"");
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号名称: \"{symbolName}\"");
                    }
                    
                    // 🔧 关键修复：增加额外的安全检查，确保节点类型和符号类型一致
                    // 防止ClassDeclaration节点被错误映射到Field符号
                    bool nodeSymbolConsistency = CheckNodeSymbolConsistency(node, symbol);
                    
                    if (isTestClass3Related)
                    {
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 nodeSymbolConsistency: {nodeSymbolConsistency}");
                    }
                    
                    if (isTypeNode && isTypeSymbol && nodeSymbolConsistency)
                    {
                        if (isTestClass3Related)
                        {
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 ✅ 类型级别诊断匹配成功: {symbolName}");
                        }
                        if (IsDebugEnabled("NodeMatch"))
                        {
                            Console.WriteLine($"[DEBUG-NodeMatch] ✓ 类型级别诊断匹配成功: {symbolName}");
                        }
                        return true;
                    }
                    else
                    {
                        if (isTestClass3Related)
                        {
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 ❌ 类型级别诊断匹配失败: {symbolName}");
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯 失败原因: TypeNode={isTypeNode}, TypeSymbol={isTypeSymbol}, MessageContains={messageContainsSymbol}, Consistency={nodeSymbolConsistency}");
                        }
                        if (IsDebugEnabled("NodeMatch"))
                        {
                            Console.WriteLine($"[DEBUG-NodeMatch] ✗ 类型级别诊断匹配失败: {symbolName} (TypeNode:{isTypeNode}, TypeSymbol:{isTypeSymbol}, MessageContains:{messageContainsSymbol}, Consistency:{nodeSymbolConsistency})");
                        }
                        return false;
                    }
                    
                case "PROJECT_MEMBER_NO_COMMENT_BLOCK":
                case "PROJECT_MEMBER_MISSING_SUMMARY":
                case "PROJECT_MEMBER_MISSING_REMARKS":
                case "PROJECT_MEMBER_MISSING_PARAM":
                case "PROJECT_MEMBER_MISSING_RETURNS":
                case "PROJECT_MEMBER_MISSING_TYPEPARAM":
                case "PROJECT_MEMBER_DUPLICATE_SUMMARY":
                case "PROJECT_MEMBER_DUPLICATE_REMARKS":
                    // 成员级别诊断：必须是成员节点且符号也是成员
                    if (IsDebugEnabled("NodeMatch"))
                    {
                        Console.WriteLine($"[DEBUG-NodeMatch] 成员级别诊断匹配检查: Node={node.Kind()}, Symbol.Kind={symbol.Kind}");
                    }
                    
                    bool isMemberNode = IsMemberDeclarationNode(node);
                    bool isMemberSymbol = IsValidMemberSymbol(symbol);
                    bool memberMessageContainsSymbol = diagnosticMessage.Contains(symbolName);
                    
                    // 🔧 关键修复：确保成员节点和符号类型也一致
                    bool memberNodeSymbolConsistency = CheckNodeSymbolConsistency(node, symbol);
                    
                    if (isMemberNode && isMemberSymbol && memberNodeSymbolConsistency)
                    {
                        if (IsDebugEnabled("NodeMatch"))
                        {
                            Console.WriteLine($"[DEBUG-NodeMatch] ✓ 成员级别诊断匹配成功: {symbolName}");
                        }
                        return true;
                    }
                    else
                    {
                        if (IsDebugEnabled("NodeMatch"))
                        {
                            Console.WriteLine($"[DEBUG-NodeMatch] ✗ 成员级别诊断匹配失败: {symbolName} (MemberNode:{isMemberNode}, MemberSymbol:{isMemberSymbol}, MessageContains:{memberMessageContainsSymbol}, Consistency:{memberNodeSymbolConsistency})");
                        }
                        return false;
                    }
                    
                default:
                    if (isTestClass3Related)
                    {
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 未知诊断类型: {diagnostic.Id}");
                    }
                    return false;
            }
        }
        
        /// <summary>
        /// 检查节点类型与符号类型的一致性，防止错误映射
        /// </summary>
        private bool CheckNodeSymbolConsistency(SyntaxNode node, ISymbol symbol)
        {
            // 🔧 TC_F_003 专项调试：跟踪TestClass3的一致性检查
            var isTestClass3Related = symbol.Name == "TestClass3" || 
                                    (node is ClassDeclarationSyntax classNode && classNode.Identifier.ValueText == "TestClass3");
            
            if (isTestClass3Related)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 CheckNodeSymbolConsistency 检查TestClass3");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点类型: {node.GetType().Name}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号类型: {symbol.Kind}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号名称: {symbol.Name}");
            }
            
            // 类型节点应该对应NamedType符号
            if (node is ClassDeclarationSyntax || node is StructDeclarationSyntax || 
                node is InterfaceDeclarationSyntax || node is EnumDeclarationSyntax ||
                node is DelegateDeclarationSyntax)
            {
                var result = symbol.Kind == SymbolKind.NamedType;
                
                if (isTestClass3Related)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 类型节点一致性检查: {result}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 期望符号类型: NamedType, 实际: {symbol.Kind}");
                }
                
                return result;
            }
            
            // 字段节点应该对应Field符号
            if (node is FieldDeclarationSyntax)
            {
                var result = symbol.Kind == SymbolKind.Field;
                
                if (isTestClass3Related)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 字段节点一致性检查: {result}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 期望符号类型: Field, 实际: {symbol.Kind}");
                }
                
                return result;
            }
            
            // 方法节点应该对应Method符号
            if (node is MethodDeclarationSyntax || node is ConstructorDeclarationSyntax || 
                node is DestructorDeclarationSyntax || node is OperatorDeclarationSyntax ||
                node is ConversionOperatorDeclarationSyntax)
            {
                var result = symbol.Kind == SymbolKind.Method;
                
                if (isTestClass3Related)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 方法节点一致性检查: {result}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 期望符号类型: Method, 实际: {symbol.Kind}");
                }
                
                return result;
            }
            
            // 属性节点应该对应Property符号
            if (node is PropertyDeclarationSyntax || node is IndexerDeclarationSyntax)
            {
                var result = symbol.Kind == SymbolKind.Property;
                
                if (isTestClass3Related)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 属性节点一致性检查: {result}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 期望符号类型: Property, 实际: {symbol.Kind}");
                }
                
                return result;
            }
            
            // 事件节点应该对应Event符号
            if (node is EventDeclarationSyntax || node is EventFieldDeclarationSyntax)
            {
                var result = symbol.Kind == SymbolKind.Event;
                
                if (isTestClass3Related)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 事件节点一致性检查: {result}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 期望符号类型: Event, 实际: {symbol.Kind}");
                }
                
                return result;
            }
            
            // 默认情况：其他节点类型暂时认为一致
            if (isTestClass3Related)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 未知节点类型，默认一致性检查: true");
            }
            
            return true;
        }
        
        /// <summary>
        /// 检查节点是否为类型声明节点
        /// </summary>
        private bool IsTypeDeclarationNode(SyntaxNode node)
        {
            return node is ClassDeclarationSyntax ||
                   node is StructDeclarationSyntax ||
                   node is InterfaceDeclarationSyntax ||
                   node is EnumDeclarationSyntax ||
                   node is DelegateDeclarationSyntax;
        }
        
        /// <summary>
        /// 检查节点是否为成员声明节点
        /// </summary>
        private bool IsMemberDeclarationNode(SyntaxNode node)
        {
            return node is MethodDeclarationSyntax ||
                   node is PropertyDeclarationSyntax ||
                   node is FieldDeclarationSyntax ||
                   node is EventDeclarationSyntax ||
                   node is ConstructorDeclarationSyntax ||
                   node is DestructorDeclarationSyntax ||
                   node is OperatorDeclarationSyntax ||
                   node is ConversionOperatorDeclarationSyntax ||
                   node is IndexerDeclarationSyntax ||
                   node is EventFieldDeclarationSyntax;
        }

        /// <summary>
        /// 专门处理字段声明的结构匹配，因为字段声明可能包含多个变量
        /// </summary>
        private bool IsFieldDeclarationMatch(FieldDeclarationSyntax fieldNode, ISymbol fieldSymbol, DiagnosticInfo diagnostic)
        {
            string symbolName = fieldSymbol.Name;
            string diagnosticMessage = diagnostic.Message ?? "";
            
            // 检查诊断消息是否包含字段名称
            if (!diagnosticMessage.Contains(symbolName))
            {
                return false;
            }
            
            // 检查诊断类型是否适用于字段
            switch (diagnostic.Id)
            {
                case "PROJECT_MEMBER_NO_COMMENT_BLOCK":
                case "PROJECT_MEMBER_MISSING_SUMMARY":
                case "PROJECT_MEMBER_MISSING_REMARKS":
                    return fieldSymbol.Kind == SymbolKind.Field;
                    
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// 检查是否为有效的成员符号
        /// </summary>
        private bool IsValidMemberSymbol(ISymbol symbol)
        {
            return symbol.Kind == SymbolKind.Method ||
                   symbol.Kind == SymbolKind.Property ||
                   symbol.Kind == SymbolKind.Field ||
                   symbol.Kind == SymbolKind.Event ||
                   symbol.Kind == SymbolKind.NamedType; // 包括嵌套类型
        }



        private bool ShouldHaveDocumentation(SyntaxNode node)
        {
            var modifiers = GetModifiers(node);
            
            // 根据项目规则，所有成员都需要注释，包括private成员
            // 这与分析器的策略保持一致
            
            // For types, all types should have documentation
            if (node is TypeDeclarationSyntax)
            {
                return true;
            }

            // For interface members, they are implicitly public
            if (node.Parent is InterfaceDeclarationSyntax)
            {
                return true;
            }

            // For all other members (including private), require documentation
            // This matches the analyzer's policy of checking all accessibility levels
            return true;
        }

        private SyntaxTokenList GetModifiers(SyntaxNode node)
        {
            return node switch
            {
                ClassDeclarationSyntax classDecl => classDecl.Modifiers,
                StructDeclarationSyntax structDecl => structDecl.Modifiers,
                InterfaceDeclarationSyntax interfaceDecl => interfaceDecl.Modifiers,
                EnumDeclarationSyntax enumDecl => enumDecl.Modifiers,
                MethodDeclarationSyntax methodDecl => methodDecl.Modifiers,
                PropertyDeclarationSyntax propertyDecl => propertyDecl.Modifiers,
                FieldDeclarationSyntax fieldDecl => fieldDecl.Modifiers,
                ConstructorDeclarationSyntax constructorDecl => constructorDecl.Modifiers,
                EventDeclarationSyntax eventDecl => eventDecl.Modifiers,
                EventFieldDeclarationSyntax eventFieldDecl => eventFieldDecl.Modifiers,
                DelegateDeclarationSyntax delegateDecl => delegateDecl.Modifiers,
                DestructorDeclarationSyntax destructorDecl => destructorDecl.Modifiers,
                OperatorDeclarationSyntax operatorDecl => operatorDecl.Modifiers,
                ConversionOperatorDeclarationSyntax conversionDecl => conversionDecl.Modifiers,
                IndexerDeclarationSyntax indexerDecl => indexerDecl.Modifiers,
                _ => default
            };
        }

        private bool HasDocumentationComment(SyntaxNode node)
        {
            var leadingTrivia = node.GetLeadingTrivia();
            return leadingTrivia.Any(t => t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia) ||
                                         t.IsKind(SyntaxKind.MultiLineDocumentationCommentTrivia));
        }

        // 🚨 已弃用：此方法仅用于调试，正常情况应使用IsNodeMatchByStructure
        private bool IsNodeMatch(SyntaxNode node, DiagnosticInfo diagnostic, int lineFuzzy = 3)
        {
            // 🚨 强制返回false：防止弃用方法影响修复
            Program.WriteDebugInfo("NodeMatch", "❌ 警告：IsNodeMatch方法被调用，这是一个弃用方法！");
            
            // 输出调用堆栈
            var stackTrace = new System.Diagnostics.StackTrace();
            Console.WriteLine($"[WARNING] IsNodeMatch方法被调用，堆栈跟踪：");
            for (int i = 1; i < Math.Min(stackTrace.FrameCount, 5); i++)
            {
                var frame = stackTrace.GetFrame(i);
                Console.WriteLine($"[WARNING]   {i}: {frame.GetMethod().Name} in {frame.GetMethod().DeclaringType?.Name}");
            }
            
            // 强制返回false，防止弃用方法影响修复流程
            Console.WriteLine($"[WARNING] IsNodeMatch强制返回false，应使用IsNodeMatchByStructure方法。");
            return false;
        }
        // 获取节点名称
        private string GetNodeName(SyntaxNode node)
        {
            switch (node)
            {
                case ClassDeclarationSyntax c: return c.Identifier.Text;
                case StructDeclarationSyntax s: return s.Identifier.Text;
                case InterfaceDeclarationSyntax i: return i.Identifier.Text;
                case EnumDeclarationSyntax e: return e.Identifier.Text;
                case DelegateDeclarationSyntax d: return d.Identifier.Text;
                case MethodDeclarationSyntax m: return m.Identifier.Text;
                case PropertyDeclarationSyntax p: return p.Identifier.Text;
                case FieldDeclarationSyntax f: return f.Declaration.Variables.FirstOrDefault()?.Identifier.Text ?? "";
                case EventDeclarationSyntax ev: return ev.Identifier.Text;
                case EventFieldDeclarationSyntax ef: return ef.Declaration.Variables.FirstOrDefault()?.Identifier.Text ?? "";
                case ConstructorDeclarationSyntax ctor: return ctor.Identifier.Text;
                case DestructorDeclarationSyntax dtor: return dtor.Identifier.Text;
                case OperatorDeclarationSyntax op: return op.OperatorToken.Text;
                case ConversionOperatorDeclarationSyntax cop: return cop.Type.ToString();
                case IndexerDeclarationSyntax idx: return "this";
                default: return "";
            }
        }

        /// <summary>
        /// 获取与指定节点相关的诊断信息，使用结构化匹配而不是行号匹配
        /// </summary>
        public List<DiagnosticInfo> GetRelevantDiagnosticsForNode(SyntaxNode node)
        {
            if (_diagnostics == null) return new List<DiagnosticInfo>();
            
            var symbol = _semanticModel.GetDeclaredSymbol(node);
            if (symbol == null) return new List<DiagnosticInfo>();
            
            // 使用与CheckAndAddNode一致的结构化匹配，而不是行号匹配
            var relevantDiagnostics = new List<DiagnosticInfo>();
            
            foreach (var diagnostic in _diagnostics)
            {
                if (IsNodeMatchByStructure(node, symbol, diagnostic))
                {
                    relevantDiagnostics.Add(diagnostic);
                    if (IsDebugEnabled("Fixer"))
                    {
                        Console.WriteLine($"[DEBUG-Fixer] GetRelevantDiagnostics: 找到相关诊断 {diagnostic.Id} 对于 {symbol.Name}");
                    }
                }
            }
            
            return relevantDiagnostics;
        }
        }

        /// <summary>
        /// Second pass: Rewrites the tree based on the nodes identified by the DocumentationAnalyzer.
        /// Enhanced to support incremental fixes for existing comments with missing tags.
        /// </summary>
        internal class XmlDocRewriter : CSharpSyntaxRewriter
    {
        private readonly Dictionary<SyntaxNode, ISymbol> _nodesToFix;
        private readonly List<DiagnosticInfo>? _diagnostics;
        private readonly DocumentationAnalyzer _analyzer;
        public bool ChangesMade { get; private set; }

        public XmlDocRewriter(Dictionary<SyntaxNode, ISymbol> nodesToFix, List<DiagnosticInfo>? diagnostics = null, DocumentationAnalyzer analyzer = null)
        {
            _nodesToFix = nodesToFix;
            _diagnostics = diagnostics;
            _analyzer = analyzer;
            ChangesMade = false;
            
            // 🔧 DEBUG: 显示_nodesToFix字典的完整内容
            if (IsDebugEnabled("NodeMatch"))
            {
                Console.WriteLine($"[DEBUG-NodeMatch] === XmlDocRewriter 创建完成，待修复节点列表 ({_nodesToFix.Count}) ===");
                foreach (var kvp in _nodesToFix)
                {
                    var nodeType = kvp.Key.GetType().Name;
                    var symbolName = kvp.Value.Name;
                    var symbolKind = kvp.Value.Kind;
                    var nodeLocation = kvp.Key.GetLocation().GetLineSpan().StartLinePosition.Line + 1;
                    Console.WriteLine($"[DEBUG-NodeMatch] {nodeType}(line {nodeLocation}) -> {symbolName} ({symbolKind})");
                    
                    // 🔧 特别检查ClassDeclaration与Field符号的不匹配
                    if (kvp.Key is ClassDeclarationSyntax && kvp.Value.Kind == SymbolKind.Field)
                    {
                        Console.WriteLine($"[DEBUG-NodeMatch] *** 错误映射警告 ***: ClassDeclaration节点映射到Field符号！");
                        Console.WriteLine($"[DEBUG-NodeMatch] Class名称: {((ClassDeclarationSyntax)kvp.Key).Identifier.Text}");
                        Console.WriteLine($"[DEBUG-NodeMatch] Field名称: {kvp.Value.Name}");
                    }
                }
                Console.WriteLine($"[DEBUG-NodeMatch] === 待修复节点列表结束 ===");
            }
        }

        public override SyntaxNode? Visit(SyntaxNode? node)
        {
            if (node == null) return null;
            
            // 🔧 TC_F_003 专项调试：跟踪TestClass3的处理
            var isTestClass3Node = false;
            ISymbol mappedSymbol = null;
            
            if (node is ClassDeclarationSyntax classNode)
            {
                var className = classNode.Identifier.ValueText;
                isTestClass3Node = className == "TestClass3";
                
                if (isTestClass3Node)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 XmlDocRewriter.Visit 处理TestClass3类节点");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点位置: line {node.GetLocation().GetLineSpan().StartLinePosition.Line + 1}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 _nodesToFix字典大小: {_nodesToFix.Count}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3是否在_nodesToFix中: {_nodesToFix.ContainsKey(node)}");
                    
                    if (_nodesToFix.ContainsKey(node))
                    {
                        mappedSymbol = _nodesToFix[node];
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3映射符号: {mappedSymbol.Name} ({mappedSymbol.Kind})");
                    }
                    else
                    {
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3不在_nodesToFix中，列出所有映射:");
                        foreach (var kvp in _nodesToFix)
                        {
                            var nodeType = kvp.Key.GetType().Name;
                            var symbolName = kvp.Value.Name;
                            var symbolKind = kvp.Value.Kind;
                            var nodeLocation = kvp.Key.GetLocation().GetLineSpan().StartLinePosition.Line + 1;
                            var marker = symbolName == "TestClass3" ? "🎯" : (symbolName == "Value" ? "📍" : "");
                            Console.WriteLine($"[DEBUG-TC_F_003] 🎯   {marker} {nodeType}(line {nodeLocation}) -> {symbolName} ({symbolKind})");
                        }
                    }
                }
            }
            
            // Debug: 检查节点是否在待修复列表中
            if (IsDebugEnabled("Fixer") && node is ClassDeclarationSyntax)
            {
                var className = ((ClassDeclarationSyntax)node).Identifier.Text;
                var isInFixList = _nodesToFix.ContainsKey(node);
                Console.WriteLine($"[DEBUG-Fixer] Visit class {className}: InFixList={isInFixList}, TotalNodesInFixList={_nodesToFix.Count}");
                
                if (isInFixList)
                {
                    var mappedSymbol2 = _nodesToFix[node];
                    Console.WriteLine($"[DEBUG-Fixer] Class {className} 映射到符号: {mappedSymbol2.Name} ({mappedSymbol2.Kind})");
                }
                else
                {
                    Console.WriteLine($"[DEBUG-Fixer] Class {className} 不在修复列表中");
                    // 输出所有待修复节点的信息
                    Console.WriteLine($"[DEBUG-Fixer] 待修复节点列表 ({_nodesToFix.Count}):");
                    foreach (var kvp in _nodesToFix)
                    {
                        var nodeType = kvp.Key.GetType().Name;
                        var symbolName = kvp.Value.Name;
                        var symbolKind = kvp.Value.Kind;
                        Console.WriteLine($"[DEBUG-Fixer]   - {nodeType} -> {symbolName} ({symbolKind})");
                    }
                }
            }
            
            if (_nodesToFix.TryGetValue(node, out var symbol))
            {
                Console.WriteLine($"[DEBUG-Fixer] Processing node for symbol {symbol.Name} (Kind: {symbol.Kind})");
                
                // 🔧 TC_F_003 专项调试：TestClass3进入修复流程
                if (isTestClass3Node)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3进入修复流程!");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 修复符号: {symbol.Name} ({symbol.Kind})");
                }
                
                // 检查节点类型与符号类型是否匹配
                if (IsDebugEnabled("Fixer"))
                {
                    var nodeType = node.GetType().Name;
                    var symbolType = symbol.GetType().Name;
                    Console.WriteLine($"[DEBUG-Fixer] NodeType: {nodeType}, SymbolType: {symbolType}");
                    
                    // 特别检查ClassDeclaration与Field符号的不匹配
                    if (node is ClassDeclarationSyntax && symbol.Kind == SymbolKind.Field)
                    {
                        Console.WriteLine($"[DEBUG-Fixer] *** 错误映射检测 ***: ClassDeclaration节点映射到Field符号！");
                        Console.WriteLine($"[DEBUG-Fixer] Class名称: {((ClassDeclarationSyntax)node).Identifier.Text}");
                        Console.WriteLine($"[DEBUG-Fixer] Field名称: {symbol.Name}");
                    }
                }
                
                // 已有合规注释则不再修复
                var hasValidDoc = HasValidDocumentation(node);
                
                // 🔧 TC_F_003 专项调试：TestClass3的合规性检查
                if (isTestClass3Node)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3合规性检查结果: {hasValidDoc}");
                }
                
                if (hasValidDoc)
                {
                    Console.WriteLine($"[DEBUG-Fixer] Node {symbol.Name} has valid documentation, skipping");
                    
                    // 🔧 TC_F_003 专项调试：TestClass3被跳过
                    if (isTestClass3Node)
                    {
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3被跳过，因为HasValidDocumentation返回true");
                    }
                    
                    return base.Visit(node);
                }
                
                Console.WriteLine($"[DEBUG-Fixer] Node {symbol.Name} needs fixing");
                
                // 🔧 TC_F_003 专项调试：TestClass3开始修复
                if (isTestClass3Node)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3开始修复处理");
                }
                
                ChangesMade = true;
                return AddOrUpdateDocumentationIncremental(node, symbol);
            }
            
            // 🔧 TC_F_003 专项调试：TestClass3没有被修复
            if (isTestClass3Node)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3没有进入修复流程 - 不在_nodesToFix中");
            }
            
            return base.Visit(node);
        }

        private bool HasValidDocumentation(SyntaxNode node)
        {
            // 🔧 TC_F_003 专项调试：跟踪TestClass3的合规性检查
            var isTestClass3Node = false;
            if (node is ClassDeclarationSyntax classNode)
            {
                isTestClass3Node = classNode.Identifier.ValueText == "TestClass3";
            }
            
            if (isTestClass3Node)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 HasValidDocumentation 检查TestClass3");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点是否在_nodesToFix中: {_nodesToFix.ContainsKey(node)}");
            }
            
            // 如果节点在待修复列表中，说明存在问题，不应该被认为是合规的
            if (_nodesToFix.ContainsKey(node))
            {
                if (isTestClass3Node)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3在待修复列表中，返回false");
                }
                return false;
            }
            
            // 判断节点是否已有合规注释（存在三斜线注释且包含<summary>标签）
            var trivia = node.GetLeadingTrivia();
            var docComment = trivia.FirstOrDefault(t => t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia));
            
            if (isTestClass3Node)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3注释检查:");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 Leading trivia数量: {trivia.Count}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 找到文档注释: {docComment != default}");
                
                if (docComment != default)
                {
                    var text = docComment.ToFullString();
                    var containsSummary = text.Contains("<summary>");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 注释内容: {text}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 包含<summary>: {containsSummary}");
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 最终结果: {containsSummary}");
                    return containsSummary;
                }
                else
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 没有找到文档注释，返回false");
                    return false;
                }
            }
            
            if (docComment == default) return false;
            var text2 = docComment.ToFullString();
            return text2.Contains("<summary>");
        }

        private SyntaxNode AddOrUpdateDocumentationIncremental(SyntaxNode node, ISymbol symbol)
        {
            // 🔧 TC_F_003 专项调试：跟踪TestClass3的修复过程
            var isTestClass3 = symbol.Name == "TestClass3";
            
            if (isTestClass3)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 AddOrUpdateDocumentationIncremental 开始处理TestClass3");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 符号: {symbol.Name} ({symbol.Kind})");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 节点类型: {node.GetType().Name}");
            }
            
            if (IsDebugEnabled("Fixer"))
                Console.WriteLine($"[DEBUG-Fixer] AddOrUpdateDocumentationIncremental: {symbol.Name} 处理前注释:\n{ExtractExistingDocumentationComment(node)}");
            var existingComment = ExtractExistingDocumentationComment(node);
            
            // 🔧 TC_F_003 专项调试：TestClass3的现有注释情况
            if (isTestClass3)
            {
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3现有注释检查:");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 现有注释是否为空: {string.IsNullOrEmpty(existingComment)}");
                Console.WriteLine($"[DEBUG-TC_F_003] 🎯 现有注释内容: {existingComment}");
            }
            
            // 🔧 修复决策逻辑：更严格的检查是否有XML文档注释
            var hasDocumentationComment = node.GetLeadingTrivia().Any(t => 
                t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia) || 
                t.IsKind(SyntaxKind.MultiLineDocumentationCommentTrivia));
            
            if (string.IsNullOrEmpty(existingComment) && !hasDocumentationComment)
            {
                // No existing comment at all, generate a complete new one
                Console.WriteLine($"[FIX] No documentation found for {symbol.Name}, adding complete comment");
                
                // 🔧 TC_F_003 专项调试：TestClass3添加完整注释
                if (isTestClass3)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3完全没有注释，添加完整注释");
                }
                
                return AddCompleteDocumentation(node, symbol);
            }
            else
            {
                // Some form of documentation exists, apply incremental fixes
                Console.WriteLine($"[FIX] Documentation exists for {symbol.Name}, applying incremental fixes");
                
                // 🔧 TC_F_003 专项调试：TestClass3增量修复
                if (isTestClass3)
                {
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3存在注释，执行增量修复");
                    Console.WriteLine($"[DEBUG-DUPLICATE] 🔧 TestClass3走ApplyIncrementalFixes路径！");
                    
                    // 获取相关诊断信息
                    var relevantDiagnostics = _analyzer?.GetRelevantDiagnosticsForNode(node) ?? new List<DiagnosticInfo>();
                    Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3相关诊断数量: {relevantDiagnostics.Count}");
                    
                    foreach (var diag in relevantDiagnostics)
                    {
                        Console.WriteLine($"[DEBUG-TC_F_003] 🎯 TestClass3相关诊断: {diag.Id} - {diag.Message}");
                    }
                }
                
                return ApplyIncrementalFixes(node, symbol, existingComment);
            }
        }

        private SyntaxNode AddCompleteDocumentation(SyntaxNode node, ISymbol symbol)
        {
            Console.WriteLine($"[FIX] AddCompleteDocumentation for {symbol.Name} - replacing existing documentation");
            
            var idealCommentText = GenerateIdealComment(symbol);
            
            // 🔧 修复无限循环和空行问题：正确替换注释并确保无间隔
            // 1. 移除现有的文档注释trivia和多余的空白trivia
            var leadingTrivia = node.GetLeadingTrivia();
            var filteredTrivia = leadingTrivia.Where(t => 
                !t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia) && 
                !t.IsKind(SyntaxKind.MultiLineDocumentationCommentTrivia) &&
                !t.IsKind(SyntaxKind.EndOfLineTrivia) && // 移除换行符避免空行
                !t.IsKind(SyntaxKind.WhitespaceTrivia)).ToSyntaxTriviaList(); // 移除多余空白
            
            // 2. 生成新的文档注释trivia
            var idealTriviaList = SyntaxFactory.ParseLeadingTrivia(idealCommentText);
            
            // 3. 将新注释添加到过滤后的trivia前面，确保无间隔
            var newLeadingTrivia = idealTriviaList.AddRange(filteredTrivia);
            
            Console.WriteLine($"[FIX] AddCompleteDocumentation: Replaced documentation for {symbol.Name}");
            return node.WithLeadingTrivia(newLeadingTrivia);
        }

        private SyntaxNode ApplyIncrementalFixes(SyntaxNode node, ISymbol symbol, string existingComment)
        {
            if (IsDebugEnabled("Fixer"))
                Console.WriteLine($"[DEBUG-Fixer] ApplyIncrementalFixes: {symbol.Name} {symbol.Kind}");
            var modifiedComment = existingComment;
            var relevantDiagnostics = _analyzer?.GetRelevantDiagnosticsForNode(node) ?? new List<DiagnosticInfo>();
            
            foreach (var diagnostic in relevantDiagnostics)
            {
                Console.WriteLine($"[FIX] Processing diagnostic: {diagnostic.Id} for {symbol.Name}");
                
                if (diagnostic.Id.Contains("_MISSING_PARAM"))
                {
                    modifiedComment = AddMissingParamTags(modifiedComment, symbol);
                }
                else if (diagnostic.Id.Contains("_MISSING_RETURNS"))
                {
                    modifiedComment = AddMissingReturnsTag(modifiedComment, symbol);
                }
                else if (diagnostic.Id.Contains("_MISSING_REMARKS") || diagnostic.Id.Contains("_MISSING_REMARKS_TAG"))
                {
                    modifiedComment = AddMissingRemarksTag(modifiedComment, symbol);
                }
                else if (diagnostic.Id.Contains("_MISSING_SUMMARY"))
                {
                    modifiedComment = AddMissingSummaryTag(modifiedComment, symbol);
                }
                else if (diagnostic.Id.Contains("_MISSING_TYPEPARAM"))
                {
                    modifiedComment = AddMissingTypeParamTags(modifiedComment, symbol);
                }
                else if (diagnostic.Id.Contains("_DUPLICATE_SUMMARY"))
                {
                    modifiedComment = RemoveDuplicateSummaryTags(modifiedComment, symbol);
                }
                else if (diagnostic.Id.Contains("_DUPLICATE_REMARKS"))
                {
                    modifiedComment = RemoveDuplicateRemarksTags(modifiedComment, symbol);
                }
            }

            // 🔧 防止无限循环：检查是否所有诊断都是重复标签类型
            bool allDuplicateTagDiagnostics = true;
            foreach (var diagnostic in relevantDiagnostics)
            {
                if (!diagnostic.Id.Contains("_DUPLICATE_"))
                {
                    allDuplicateTagDiagnostics = false;
                    break;
                }
            }
            
            // 只有在非重复标签诊断时才执行结构化补全
            if (!allDuplicateTagDiagnostics && symbol.Kind == SymbolKind.NamedType)
            {
                Console.WriteLine($"[FIX] Executing EnsureRemarksStructured for {symbol.Name} (no duplicate tag diagnostics)");
                // 注意：这里暂时保持禁用状态，待确认无死循环后再启用
                // modifiedComment = EnsureRemarksStructured(modifiedComment, symbol);
            }
            else
            {
                Console.WriteLine($"[FIX] Skipping EnsureRemarksStructured for {symbol.Name} (duplicate tag diagnostics detected or not a type)");
            }

            if (modifiedComment != existingComment)
            {
                Console.WriteLine($"[FIX] Comment modified for {symbol.Name}");
                return ReplaceDocumentationComment(node, modifiedComment);
            }
            
            return node;
        }

        private string ExtractExistingDocumentationComment(SyntaxNode node)
        {
            var leadingTrivia = node.GetLeadingTrivia();
            var docCommentTrivia = leadingTrivia
                .Where(t => t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia) || 
                           t.IsKind(SyntaxKind.MultiLineDocumentationCommentTrivia))
                .LastOrDefault();

            if (docCommentTrivia.IsKind(SyntaxKind.None))
                return string.Empty;

            return docCommentTrivia.ToFullString();
        }

        /// <summary>
        /// 插入EndOfDocumentationCommentToken，确保注释分行。
        /// </summary>
        private SyntaxNode ReplaceDocumentationComment(SyntaxNode node, string newComment)
        {
            Console.WriteLine($"[FIX] ReplaceDocumentationComment: Replacing documentation with new content");
            
            // 🔧 修复重复标签和空行问题：正确替换注释并确保无间隔
            // 1. 移除现有的文档注释trivia和多余的空白trivia
            var leadingTrivia = node.GetLeadingTrivia();
            var filteredTrivia = leadingTrivia.Where(t => 
                !t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia) && 
                !t.IsKind(SyntaxKind.MultiLineDocumentationCommentTrivia) &&
                !t.IsKind(SyntaxKind.EndOfLineTrivia) && // 移除换行符避免空行
                !t.IsKind(SyntaxKind.WhitespaceTrivia)).ToSyntaxTriviaList(); // 移除多余空白
            
            // 2. 生成新的注释trivia（无额外换行）
            var docTrivia = SyntaxFactory.ParseLeadingTrivia(newComment);
            
            // 3. 正确组合：新注释 + 过滤后的非文档trivia，确保无间隔
            var newLeadingTrivia = docTrivia.AddRange(filteredTrivia);
            
            // 4. 若trivia中包含DocumentationCommentTriviaSyntax，插入EndOfDocumentationCommentToken
            var newLeadingTriviaWithEnd = newLeadingTrivia.Select(t =>
            {
                if (t.HasStructure && t.GetStructure() is DocumentationCommentTriviaSyntax doc)
                {
                    var docWithEnd = doc.WithEndOfComment(SyntaxFactory.Token(SyntaxKind.EndOfDocumentationCommentToken));
                    return SyntaxFactory.Trivia(docWithEnd);
                }
                return t;
            }).ToSyntaxTriviaList();
            
            // 5. 替换节点leading trivia
            Console.WriteLine($"[FIX] ReplaceDocumentationComment: Documentation replaced successfully");
            return node.WithLeadingTrivia(newLeadingTriviaWithEnd);
        }

        private string AddMissingParamTags(string existingComment, ISymbol symbol)
        {
            IReadOnlyList<IParameterSymbol> parameters = null;
            
            // Handle both methods and delegates
            if (symbol is IMethodSymbol methodSymbol)
            {
                parameters = methodSymbol.Parameters;
            }
            else if (symbol is INamedTypeSymbol namedTypeSymbol && namedTypeSymbol.TypeKind == TypeKind.Delegate)
            {
                var invokeMethod = namedTypeSymbol.DelegateInvokeMethod;
                if (invokeMethod != null)
                {
                    parameters = invokeMethod.Parameters;
                }
            }
            
            if (parameters == null || !parameters.Any())
                return existingComment;

            var existingParams = ExtractExistingParamNames(existingComment);
            var missingParams = parameters
                .Where(p => !existingParams.Contains(p.Name))
                .ToList();

            if (!missingParams.Any())
                return existingComment;

            Console.WriteLine($"[FIX] Adding {missingParams.Count} missing param tags for {symbol.Name}");

            var insertionPoint = FindInsertionPointForParams(existingComment);
            var paramTags = new StringBuilder();
            
            foreach (var param in missingParams)
            {
                paramTags.AppendLine($"/// <param name=\"{param.Name}\">[参数说明]</param>");
            }

            return existingComment.Insert(insertionPoint, paramTags.ToString());
        }

        private string AddMissingReturnsTag(string existingComment, ISymbol symbol)
        {
            bool hasReturnValue = false;
            
            // Handle both methods and delegates
            if (symbol is IMethodSymbol methodSymbol)
            {
                hasReturnValue = !methodSymbol.ReturnsVoid && methodSymbol.MethodKind != MethodKind.Constructor;
            }
            else if (symbol is INamedTypeSymbol namedTypeSymbol && namedTypeSymbol.TypeKind == TypeKind.Delegate)
            {
                var invokeMethod = namedTypeSymbol.DelegateInvokeMethod;
                if (invokeMethod != null)
                {
                    hasReturnValue = !invokeMethod.ReturnsVoid;
                }
            }
            
            if (!hasReturnValue)
                return existingComment;

            if (existingComment.Contains("<returns>"))
                return existingComment;

            Console.WriteLine($"[FIX] Adding missing returns tag for {symbol.Name}");

            var insertionPoint = FindInsertionPointForReturns(existingComment);
            var returnsTag = "/// <returns>[返回值说明]</returns>\n";

            return existingComment.Insert(insertionPoint, returnsTag);
        }

        /// <summary>
        /// 增量补全类型<remarks>结构化条目，保持原有内容，仅补全缺失部分。
        /// </summary>
        private string EnsureRemarksStructured(string existingComment, ISymbol symbol)
        {
            if (symbol.Kind != SymbolKind.NamedType)
                return existingComment;

            // 查找<remarks>块
            var remarksStart = existingComment.IndexOf("<remarks>");
            var remarksEnd = existingComment.IndexOf("</remarks>");
            if (remarksStart == -1 || remarksEnd == -1)
                return existingComment;

            // 提取<remarks>块内容
            var remarksContent = existingComment.Substring(remarksStart + "<remarks>".Length, 
                                                        remarksEnd - remarksStart - "<remarks>".Length);
            
            // 定义Dropleton类型注释的10个必需条目
            var requiredEntries = new[]
            {
                "功能:",
                "架构层级:",
                "模块:",
                "继承/实现关系:",
                "依赖:",
                "扩展点:",
                "特性:",
                "重要逻辑:",
                "数据流:",
                "使用示例:"
            };

            // 检查现有内容中缺失的条目
            var missingEntries = requiredEntries.Where(entry => !remarksContent.Contains(entry)).ToList();
            
            if (!missingEntries.Any())
            {
                // 所有条目都存在，无需修改
                if (IsDebugEnabled("Fixer"))
                    Console.WriteLine($"[DEBUG-Fixer] EnsureRemarksStructured: {symbol.Name} 的<remarks>块已完整");
                return existingComment;
            }

            // 构建增量内容
            var additionalContent = new StringBuilder();
            foreach (var entry in missingEntries)
            {
                additionalContent.AppendLine($"/// {entry} [待补充]");
            }

            // 在</remarks>之前插入缺失的条目
            var beforeRemarks = existingComment.Substring(0, remarksEnd);
            var afterRemarks = existingComment.Substring(remarksEnd);
            
            // 确保正确的格式化
            var newContent = beforeRemarks + additionalContent.ToString() + afterRemarks;
            
            Console.WriteLine($"[FIX] EnsureRemarksStructured: 为{symbol.Name}添加了{missingEntries.Count}个缺失条目");
            if (IsDebugEnabled("Fixer"))
            {
                Console.WriteLine($"[DEBUG-Fixer] 缺失条目: {string.Join(", ", missingEntries)}");
            }
            
            return newContent;
        }

        /// <summary>
        /// 移除XML注释中重复的summary标签，只保留第一个
        /// </summary>
        /// <remarks>
        /// 功能: 解决分析器检测到的重复标签问题
        /// 架构层级: 修复器核心逻辑
        /// 依赖: 无
        /// 扩展点: 可扩展支持其他标签类型
        /// </remarks>
        private string RemoveDuplicateSummaryTags(string existingComment, ISymbol symbol)
        {
            Console.WriteLine($"[FIX] Removing duplicate summary tags for {symbol.Name}");
            return RemoveDuplicateTags(existingComment, "summary");
        }

        /// <summary>
        /// 移除XML注释中重复的remarks标签，只保留第一个
        /// </summary>
        /// <remarks>
        /// 功能: 解决分析器检测到的重复标签问题
        /// 架构层级: 修复器核心逻辑  
        /// 依赖: 无
        /// 扩展点: 可扩展支持其他标签类型
        /// </remarks>
        private string RemoveDuplicateRemarksTags(string existingComment, ISymbol symbol)
        {
            Console.WriteLine($"[FIX] Removing duplicate remarks tags for {symbol.Name}");
            return RemoveDuplicateTags(existingComment, "remarks");
        }

        /// <summary>
        /// 通用方法：移除指定类型的重复标签，只保留第一个
        /// </summary>
        /// <remarks>
        /// 功能: 通用的重复标签移除逻辑
        /// 架构层级: 修复器核心逻辑
        /// 依赖: 正则表达式
        /// 扩展点: 可扩展支持更复杂的XML处理
        /// </remarks>
        private string RemoveDuplicateTags(string xmlComment, string tagName)
        {
            if (string.IsNullOrEmpty(xmlComment))
                return xmlComment;

            // 使用正则表达式找到所有的指定标签
            string pattern = $@"(<{tagName}>.*?</{tagName}>)";
            var matches = System.Text.RegularExpressions.Regex.Matches(xmlComment, pattern, 
                System.Text.RegularExpressions.RegexOptions.Singleline | 
                System.Text.RegularExpressions.RegexOptions.IgnoreCase);

            // 如果只有一个或没有标签，不需要处理
            if (matches.Count <= 1)
                return xmlComment;

            Console.WriteLine($"[FIX] Found {matches.Count} duplicate {tagName} tags, keeping only the first one");

            // 保留第一个标签，移除其余的
            string result = xmlComment;
            for (int i = matches.Count - 1; i >= 1; i--)
            {
                // 从后往前移除，避免索引变化
                var match = matches[i];
                result = result.Remove(match.Index, match.Length);
            }

            // 清理可能产生的多余空行
            result = System.Text.RegularExpressions.Regex.Replace(result, @"\n\s*\n\s*\n", "\n\n");
            
            return result;
        }

        // 在修复流程中调用EnsureRemarksStructured
        private string AddMissingRemarksTag(string existingComment, ISymbol symbol)
        {
            if (existingComment.Contains("<remarks>"))
            {
                // 🔧 修复无限循环：检查是否有重复的<remarks>标签
                var remarksMatches = System.Text.RegularExpressions.Regex.Matches(existingComment, @"<remarks>.*?</remarks>", 
                    System.Text.RegularExpressions.RegexOptions.Singleline | System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                
                if (remarksMatches.Count > 1)
                {
                    Console.WriteLine($"[PREVENT-LOOP] Detected {remarksMatches.Count} duplicate <remarks> tags for {symbol.Name}, returning unchanged to avoid infinite loop");
                    return existingComment; // 有重复标签时，直接返回，不做任何修改
                }
                
                // 🔧 全面禁用结构化条目补全 - 确保不会引发死循环
                Console.WriteLine($"[PREVENT-LOOP] <remarks> exists for {symbol.Name}, but EnsureRemarksStructured is disabled to prevent infinite loop");
                return existingComment;
            }
            
            // 如果完全没有<remarks>标签，添加一个
            Console.WriteLine($"[FIX] Adding missing remarks tag for {symbol.Name}");
            
            var insertionPoint = FindInsertionPointForRemarks(existingComment);
            var remarksTag = new StringBuilder();
            remarksTag.AppendLine("/// <remarks>");
            
            if (symbol.Kind == SymbolKind.NamedType)
            {
                // 类型级别的详细注释模板
                remarksTag.AppendLine("/// 功能: [待补充]");
                remarksTag.AppendLine("/// 架构层级: [待补充]");
                remarksTag.AppendLine("/// 模块: [待补充]");
                remarksTag.AppendLine("/// 继承/实现关系: [待补充]");
                remarksTag.AppendLine("/// 依赖: [待补充]");
                remarksTag.AppendLine("/// 扩展点: [待补充]");
                remarksTag.AppendLine("/// 特性: [待补充]");
                remarksTag.AppendLine("/// 重要逻辑: [待补充]");
                remarksTag.AppendLine("/// 数据流: [待补充]");
                remarksTag.AppendLine("/// 使用示例: [待补充]");
            }
            else
            {
                // 非类型成员只需功能
                remarksTag.AppendLine("/// 功能: [待补充]");
            }
            remarksTag.AppendLine("/// </remarks>");
            
            return existingComment.Insert(insertionPoint, remarksTag.ToString());
        }

        private string AddMissingSummaryTag(string existingComment, ISymbol symbol)
        {
            if (existingComment.Contains("<summary>"))
                return existingComment;

            Console.WriteLine($"[FIX] Adding missing summary tag");

            var symbolKind = GetSymbolKindString(symbol);
            var summaryTag = $"/// <summary>\n/// {symbol.Name} —— [{symbolKind}职责简述]\n/// </summary>\n";

            var firstLineEnd = existingComment.IndexOf('\n');
            if (firstLineEnd == -1) firstLineEnd = existingComment.Length;

            return existingComment.Insert(firstLineEnd + 1, summaryTag);
        }

        private string AddMissingTypeParamTags(string existingComment, ISymbol symbol)
        {
            IReadOnlyList<ITypeParameterSymbol> typeParameters = null;
            
            // Handle both methods and delegates
            if (symbol is IMethodSymbol methodSymbol)
            {
                typeParameters = methodSymbol.TypeParameters;
            }
            else if (symbol is INamedTypeSymbol namedTypeSymbol && namedTypeSymbol.TypeKind == TypeKind.Delegate)
            {
                typeParameters = namedTypeSymbol.TypeParameters;
            }
            
            if (typeParameters == null || !typeParameters.Any())
                return existingComment;

            var existingTypeParams = ExtractExistingTypeParamNames(existingComment);
            var missingTypeParams = typeParameters
                .Where(tp => !existingTypeParams.Contains(tp.Name))
                .ToList();

            if (!missingTypeParams.Any())
                return existingComment;

            Console.WriteLine($"[FIX] Adding {missingTypeParams.Count} missing typeparam tags for {symbol.Name}");

            var insertionPoint = FindInsertionPointForTypeParams(existingComment);
            var typeParamTags = new StringBuilder();
            
            foreach (var typeParam in missingTypeParams)
            {
                typeParamTags.AppendLine($"/// <typeparam name=\"{typeParam.Name}\">[类型参数说明]</typeparam>");
            }

            return existingComment.Insert(insertionPoint, typeParamTags.ToString());
        }

        private HashSet<string> ExtractExistingParamNames(string comment)
        {
            var paramNames = new HashSet<string>();
            var paramMatches = System.Text.RegularExpressions.Regex.Matches(comment, @"<param\s+name\s*=\s*[""']([^""']+)[""']");
            
            foreach (System.Text.RegularExpressions.Match match in paramMatches)
            {
                paramNames.Add(match.Groups[1].Value);
            }
            
            return paramNames;
        }

        private HashSet<string> ExtractExistingTypeParamNames(string comment)
        {
            var typeParamNames = new HashSet<string>();
            var typeParamMatches = System.Text.RegularExpressions.Regex.Matches(comment, @"<typeparam\s+name\s*=\s*[""']([^""']+)[""']");
            
            foreach (System.Text.RegularExpressions.Match match in typeParamMatches)
            {
                typeParamNames.Add(match.Groups[1].Value);
            }
            
            return typeParamNames;
        }

        private int FindInsertionPointForParams(string comment)
        {
            var summaryEnd = comment.LastIndexOf("</summary>");
            if (summaryEnd != -1)
            {
                var nextLine = comment.IndexOf('\n', summaryEnd);
                if (nextLine != -1) return nextLine + 1;
            }

            var remarksEnd = comment.LastIndexOf("</remarks>");
            if (remarksEnd != -1)
            {
                var nextLine = comment.IndexOf('\n', remarksEnd);
                if (nextLine != -1) return nextLine + 1;
            }

            return comment.TrimEnd().Length;
        }

        private int FindInsertionPointForTypeParams(string comment)
        {
            var summaryEnd = comment.LastIndexOf("</summary>");
            if (summaryEnd != -1)
            {
                var nextLine = comment.IndexOf('\n', summaryEnd);
                if (nextLine != -1) return nextLine + 1;
            }

            var firstLineEnd = comment.IndexOf('\n');
            if (firstLineEnd != -1) return firstLineEnd + 1;

            return 0;
        }

        private int FindInsertionPointForReturns(string comment)
        {
            var lastParamEnd = comment.LastIndexOf("</param>");
            if (lastParamEnd != -1)
            {
                var nextLine = comment.IndexOf('\n', lastParamEnd);
                if (nextLine != -1) return nextLine + 1;
            }

            var lastTypeParamEnd = comment.LastIndexOf("</typeparam>");
            if (lastTypeParamEnd != -1)
            {
                var nextLine = comment.IndexOf('\n', lastTypeParamEnd);
                if (nextLine != -1) return nextLine + 1;
            }

            return comment.TrimEnd().Length;
        }

        private int FindInsertionPointForRemarks(string comment)
        {
            var summaryEnd = comment.LastIndexOf("</summary>");
            if (summaryEnd != -1)
            {
                var nextLine = comment.IndexOf('\n', summaryEnd);
                if (nextLine != -1) return nextLine + 1;
            }

            var firstLineEnd = comment.IndexOf('\n');
            if (firstLineEnd != -1) return firstLineEnd + 1;

            return 0;
        }
        
        private string GenerateIdealComment(ISymbol symbol)
        {
            var sb = new StringBuilder();
            var symbolKind = GetSymbolKindString(symbol);
            
            sb.AppendLine("/// <summary>");
            sb.AppendLine($"/// {symbol.Name} —— [{symbolKind}职责简述]");
            sb.AppendLine("/// </summary>");
            
            sb.AppendLine("/// <remarks>");
            if (symbol.Kind == SymbolKind.NamedType)
            {
                // 类型级别的详细注释模板，顺序与项目注释规范一致
                sb.AppendLine("/// 功能: [待补充]");
                sb.AppendLine("/// 架构层级: [待补充]");
                sb.AppendLine("/// 模块: [待补充]");
                sb.AppendLine("/// 继承/实现关系: [待补充]");
                sb.AppendLine("/// 依赖: [待补充]");
                sb.AppendLine("/// 扩展点: [待补充]");
                sb.AppendLine("/// 特性: [待补充]");
                sb.AppendLine("/// 重要逻辑: [待补充]");
                sb.AppendLine("/// 数据流: [待补充]");
                sb.AppendLine("/// 使用示例: [待补充]");
            }
            else
            {
                // 非类型成员只需功能
                sb.AppendLine("/// 功能: [待补充]");
            }
            sb.AppendLine("/// </remarks>");

            // 方法级别的参数和返回值注释
            if (symbol is IMethodSymbol methodSymbol)
            {
                // 泛型类型参数
                foreach (var typeParam in methodSymbol.TypeParameters)
                {
                    sb.AppendLine($"/// <typeparam name=\"{typeParam.Name}\">[类型参数说明]</typeparam>");
                }
                // 方法参数
                foreach (var param in methodSymbol.Parameters)
                {
                    sb.AppendLine($"/// <param name=\"{param.Name}\">[参数说明]</param>");
                }
                // 返回值
                if (!methodSymbol.ReturnsVoid)
                {
                    sb.AppendLine("/// <returns>[返回值说明]</returns>");
                }
            }
            // 委托类型的参数和返回值注释
            else if (symbol is INamedTypeSymbol namedTypeSymbol && namedTypeSymbol.TypeKind == TypeKind.Delegate)
            {
                var invokeMethod = namedTypeSymbol.DelegateInvokeMethod;
                if (invokeMethod != null)
                {
                    foreach (var typeParam in namedTypeSymbol.TypeParameters)
                    {
                        sb.AppendLine($"/// <typeparam name=\"{typeParam.Name}\">[类型参数说明]</typeparam>");
                    }
                    foreach (var param in invokeMethod.Parameters)
                    {
                        sb.AppendLine($"/// <param name=\"{param.Name}\">[参数说明]</param>");
                    }
                    if (!invokeMethod.ReturnsVoid)
                    {
                        sb.AppendLine("/// <returns>[返回值说明]</returns>");
                    }
                }
            }
            return sb.ToString();
        }

        private string GetSymbolKindString(ISymbol symbol)
        {
            if (symbol is INamedTypeSymbol namedType)
            {
                return namedType.TypeKind.ToString().ToLower();
            }
            return symbol.Kind.ToString().ToLower();
        }

        /// <summary>
        /// 自动补全未闭合的<remarks>标签，并去除非法空行，提升修复健壮性。
        /// </summary>
        private string EnsureXmlWellFormedAndNoIllegalEmptyLines(string comment)
        {
            // 只处理常见的<remarks>未闭合情况
            if (comment.Contains("<remarks>") && !comment.Contains("</remarks>"))
            {
                comment += "\n/// </remarks>\n";
                Console.WriteLine("[FIX] 自动补全未闭合的 <remarks> 标签");
            }
            // 去除非法空行：只保留以///开头的行，且去除多余的空行
            var lines = comment.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            var cleanedLines = new List<string>();
            bool lastWasEmpty = false;
            foreach (var line in lines)
            {
                var trimmed = line.Trim();
                if (string.IsNullOrWhiteSpace(trimmed))
                {
                    if (!lastWasEmpty)
                    {
                        cleanedLines.Add("///"); // 保留单一空行
                        lastWasEmpty = true;
                    }
                    continue;
                }
                if (trimmed.StartsWith("///"))
                {
                    cleanedLines.Add(trimmed);
                    lastWasEmpty = false;
                }
                // 非///开头的非法行直接跳过
            }
            return string.Join("\n", cleanedLines);
        }
        }
    }
}

// [删除] TypeDocRewriter类已删除 - 功能已被XmlDocRewriter完全覆盖，避免重复实现

/// <summary>
/// XmlDocCleaner - 用于批量移除所有XML文档注释（DocumentationCommentTriviaSyntax），保留其它注释。
/// </summary>
class XmlDocCleaner : CSharpSyntaxRewriter
{
    public XmlDocCleaner()
    {
        if (XmlDocRoslynTool.Program.IsDebugEnabled("CodeGen"))
        {
            Console.WriteLine("[DEBUG-CodeGen] XmlDocCleaner 初始化");
        }
    }
    public bool ChangesMade { get; private set; } = false;
    private SyntaxTriviaList CleanLeadingTrivia(SyntaxTriviaList leading)
    {
        var newLeading = new List<SyntaxTrivia>();
        foreach (var trivia in leading)
        {
            if (trivia.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia) ||
                trivia.IsKind(SyntaxKind.MultiLineDocumentationCommentTrivia))
            {
                ChangesMade = true;
                if (XmlDocRoslynTool.Program.IsDebugEnabled("CodeGen"))
                {
                    Console.WriteLine($"[DEBUG-CodeGen] 移除XML注释(leading): {trivia.ToFullString().Trim()}");
                }
                continue;
            }
            newLeading.Add(trivia);
        }
        return SyntaxFactory.TriviaList(newLeading);
    }
    public override SyntaxNode? Visit(SyntaxNode? node)
    {
        if (XmlDocRoslynTool.Program.IsDebugEnabled("CodeGen"))
        {
            Console.WriteLine($"[DEBUG-CodeGen] Visit called, node kind: {(node?.Kind().ToString() ?? "null")}");
        }
        
        if (node == null) return null;
        
        if (XmlDocRoslynTool.Program.IsDebugEnabled("CodeGen"))
        {
            Console.WriteLine($"[DEBUG-CodeGen] 处理节点: {node.Kind()} | 内容: {node.ToString().Split('\n')[0].Trim()}...");
            
            var leading = node.GetLeadingTrivia();
            foreach (var trivia in leading)
            {
                Console.WriteLine($"[DEBUG-CodeGen]   LeadingTrivia: {trivia.Kind()} | 内容: {trivia.ToFullString().Trim()}");
            }
        }
        
        var cleaned = node.WithLeadingTrivia(CleanLeadingTrivia(node.GetLeadingTrivia()));
        return base.Visit(cleaned);
    }
    // 兼容trivia级别的XML注释清理
    public override SyntaxTrivia VisitTrivia(SyntaxTrivia trivia)
    {
        if (trivia.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia) ||
            trivia.IsKind(SyntaxKind.MultiLineDocumentationCommentTrivia))
        {
            ChangesMade = true;
            if (XmlDocRoslynTool.Program.IsDebugEnabled("CodeGen"))
            {
                Console.WriteLine($"[DEBUG-CodeGen] 移除XML注释(trivia): {trivia.ToFullString().Trim()}");
            }
            return default;
        }
        return base.VisitTrivia(trivia);
    }
}

