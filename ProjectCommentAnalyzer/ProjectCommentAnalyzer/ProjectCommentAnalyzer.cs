/*
 * 文件名: ProjectCommentAnalyzer.cs  
 * 功能: 基于Roslyn的C# XML文档注释合规性静态分析器
 * 
 * 架构逻辑链(数据流):
 *   1. MSBuild编译时集成 → Roslyn语法树分析
 *   2. 双重门控逻辑 → 存在性检查 + 结构完整性验证
 *   3. 语法节点遍历 → 精确诊断定位和报告生成
 *   4. 诊断输出 → Roslynator CLI → 修复工具消费
 * 
 * 依赖:
 *   - Microsoft.CodeAnalysis.CSharp (Roslyn编译器API)
 *   - Microsoft.CodeAnalysis.Analyzers (分析器框架)
 * 
 * 扩展点:
 *   - RegisterSyntaxNodeAction: 新语法节点类型支持
 *   - 诊断规则系统: 可配置的XML注释规范要求
 *   - 双重门控机制: 指导下游修复工具的策略选择
 * 
 * 使用示例:
 *   - MSBuild集成: <Analyzer Include="ProjectCommentAnalyzer.dll" />
 *   - Roslynator CLI: roslynator analyze --analyzer ProjectCommentAnalyzer.dll
 *   - CommentAnalyzer工具链: 与XmlDocRoslynTool配合的端到端解决方案
 * 
 * Copyright (c) 2025 Dropleton Studios. All rights reserved.
 */

using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Diagnostics;
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;

namespace ProjectCommentAnalyzer
{
    /// <summary>
    /// ProjectCommentAnalyzer - Roslyn分析器
    /// </summary>
    /// <remarks>
    /// ---
    /// 设计理念:
    /// 本分析器的核心设计哲学是**"语法优先，结构为王"**。它严格避免任何基于纯文本（如 string.Contains() 或正则表达式）的注释分析，
    /// 因为这种方法脆弱且无法准确理解代码的上下文。相反，本分析器完全依赖 Roslyn API 提供的抽象语法树（AST）和语义模型，
    /// 将 XML 注释视为一等公民（`DocumentationCommentTriviaSyntax`），对其进行结构化的查询和验证。
    ///
    /// ---
    /// 核心功能与运用原理:
    /// 1.  **双层门控逻辑 (Two-Gate Logic)**: 这是指导下游修复工具（Fixer）的关键。
    ///     -   **第一道门 (存在性检查)**: 分析器首先检查一个类型或成员声明的 `leading trivia` 中是否存在 `///` 注释块。
    ///         - 若**不存在**，则触发 `..._NO_COMMENT_BLOCK` 规则，并**立即停止**对该节点的进一步分析。
    ///         - 若**存在**，则通过第一道门，进入下一层检查。
    ///     -   **第二道门 (结构完整性检查)**: 在确认注释块存在后，分析器会将其解析为结构化的 `DocumentationCommentTriviaSyntax` 对象，
    ///       并利用 LINQ 查询其内部的 XML 元素（如 `<summary>`, `<param>` 等），检查其是否缺失。
    ///
    /// 2.  **指导修复策略 (Guiding the Fixer)**:
    ///     -   `..._NO_COMMENT_BLOCK` 规则明确告知修复工具："这里什么都没有，请**插入 (Insert)** 一个全新的标准模板。"
    ///     -   `..._MISSING_...` 规则则告知修复工具："这里已有注释块，但缺少某些部分，请**修改 (Modify)** 现有内容，不要创建新块。"
    ///
    /// ---
    /// 最佳实践参考:
    /// -   **不可变性**: 所有Roslyn分析都应是纯函数式的。本分析器不修改任何状态，仅报告诊断信息。
    /// -   **性能**: 通过 `ConfigureGeneratedCodeAnalysis` 和 `EnableConcurrentExecution` 启用标准性能优化。
    /// -   **精确性**: 通过直接操作语法节点 (`SyntaxNode`) 和符号 (`ISymbol`)，确保诊断报告的位置 (`Location`) 绝对精确，
    ///     例如，缺少参数的警告会准确指向参数声明本身，而不是整个方法。
    /// </remarks>
    [DiagnosticAnalyzer(LanguageNames.CSharp)]
    public class XmlDocAnalyzer : DiagnosticAnalyzer
    {
        #region Rules

        // --- 规则定义 ---
        // 规则ID是分析器与外部工具（如测试脚本、修复工具）沟通的契约。
        // 'Category' 用于在IDE中对警告进行分类。
        // 'DefaultSeverity' 统一设置为 Warning，因为注释问题不应阻断编译。

        // Gate 1: 检查是否存在注释块
        public const string TypeNoCommentBlockId = "PROJECT_TYPE_NO_COMMENT_BLOCK";
        public const string MemberNoCommentBlockId = "PROJECT_MEMBER_NO_COMMENT_BLOCK";

        // Gate 2: 如果注释块存在，检查其内容是否完整
        public const string MissingTypeSummaryId = "PROJECT_TYPE_MISSING_SUMMARY";
        public const string MissingTypeRemarksId = "PROJECT_TYPE_MISSING_REMARKS";
        public const string MissingTypeRemarksTagId = "PROJECT_TYPE_MISSING_REMARKS_TAG";
        public const string MissingMemberSummaryId = "PROJECT_MEMBER_MISSING_SUMMARY";
        public const string MissingMemberParamId = "PROJECT_MEMBER_MISSING_PARAM";
        public const string MissingMemberReturnsId = "PROJECT_MEMBER_MISSING_RETURNS";
        public const string MissingMemberTypeParamId = "PROJECT_MEMBER_MISSING_TYPEPARAM";
        public const string MissingMemberRemarksId = "PROJECT_MEMBER_MISSING_REMARKS";

        // Gate 3: 检查XML注释块的质量和重复性
        public const string DuplicateTypeSummaryId = "PROJECT_TYPE_DUPLICATE_SUMMARY";
        public const string DuplicateTypeRemarksId = "PROJECT_TYPE_DUPLICATE_REMARKS";
        public const string DuplicateMemberSummaryId = "PROJECT_MEMBER_DUPLICATE_SUMMARY";
        public const string DuplicateMemberRemarksId = "PROJECT_MEMBER_DUPLICATE_REMARKS";

        // 结构约束规则
        public const string NestedTypeDiagnosticId = "PROJECT_TYPE_NESTED_TYPE";
        public const string NestedEnumDiagnosticId = "PROJECT_TYPE_NESTED_ENUM";
        public const string MultiEnumFileDiagnosticId = "PROJECT_TYPE_MULTI_ENUM_FILE";
        
        // 条件编译告警规则
        public const string ConditionalCompilationWarningId = "PROJECT_CONDITIONAL_COMPILATION_WARNING";
        
        // --- 规则描述符 ---
        // 每个规则都需要一个 'DiagnosticDescriptor' 来定义其在IDE和日志中的表现形式。
        // 消息格式 "{0}" 是一个占位符，将在报告诊断时被实际的错误信息填充。

        private static readonly DiagnosticDescriptor TypeNoCommentBlockRule = new DiagnosticDescriptor(
            TypeNoCommentBlockId, "类型缺少XML注释块", "{0} '{1}' 完全没有XML注释块", "Documentation", DiagnosticSeverity.Warning, true);
        
        private static readonly DiagnosticDescriptor MemberNoCommentBlockRule = new DiagnosticDescriptor(
            MemberNoCommentBlockId, "成员缺少XML注释块", "{0} '{1}' 完全没有XML注释块", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor MissingTypeSummaryRule = new DiagnosticDescriptor(
            MissingTypeSummaryId, "类型缺少 <summary>", "{0} '{1}' 的XML注释中缺少 <summary> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor MissingTypeRemarksRule = new DiagnosticDescriptor(
            MissingTypeRemarksId, "类型缺少 <remarks>", "{0} '{1}' 的XML注释中缺少 <remarks> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor MissingTypeRemarksTagRule = new DiagnosticDescriptor(
            MissingTypeRemarksTagId, "类型 <remarks> 缺少结构化标签", "{0} '{1}' 的 <remarks> 中缺少必需的结构化标签: '{2}'", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor MissingMemberSummaryRule = new DiagnosticDescriptor(
            MissingMemberSummaryId, "成员缺少 <summary>", "{0} '{1}' 的XML注释中缺少 <summary> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor MissingMemberParamRule = new DiagnosticDescriptor(
            MissingMemberParamId, "方法缺少 <param> 注释", "方法 '{0}' 的XML注释中缺少对参数 '{1}' 的 <param> 注释", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor MissingMemberReturnsRule = new DiagnosticDescriptor(
            MissingMemberReturnsId, "方法缺少 <returns> 注释", "方法 '{0}' 有返回值，但其XML注释中缺少 <returns> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor MissingMemberTypeParamRule = new DiagnosticDescriptor(
            MissingMemberTypeParamId, "方法缺少 <typeparam> 注释", "泛型方法 '{0}' 的XML注释中缺少对类型参数 '{1}' 的 <typeparam> 注释", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor MissingMemberRemarksRule = new DiagnosticDescriptor(
            MissingMemberRemarksId, "成员缺少 <remarks>", "{0} '{1}' 的XML注释中缺少 <remarks> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor DuplicateTypeSummaryRule = new DiagnosticDescriptor(
            DuplicateTypeSummaryId, "类型XML注释中存在重复的 <summary> 标签", "{0} '{1}' 的XML注释中存在重复的 <summary> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor DuplicateTypeRemarksRule = new DiagnosticDescriptor(
            DuplicateTypeRemarksId, "类型XML注释中存在重复的 <remarks> 标签", "{0} '{1}' 的XML注释中存在重复的 <remarks> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor DuplicateMemberSummaryRule = new DiagnosticDescriptor(
            DuplicateMemberSummaryId, "成员XML注释中存在重复的 <summary> 标签", "{0} '{1}' 的XML注释中存在重复的 <summary> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor DuplicateMemberRemarksRule = new DiagnosticDescriptor(
            DuplicateMemberRemarksId, "成员XML注释中存在重复的 <remarks> 标签", "{0} '{1}' 的XML注释中存在重复的 <remarks> 标签", "Documentation", DiagnosticSeverity.Warning, true);

        private static readonly DiagnosticDescriptor NestedTypeRule = new DiagnosticDescriptor(
            NestedTypeDiagnosticId, "不应嵌套定义类型", "不应在类型内部嵌套定义类型 '{0}'", "结构约束", DiagnosticSeverity.Warning, true);
            
        private static readonly DiagnosticDescriptor NestedEnumRule = new DiagnosticDescriptor(
            NestedEnumDiagnosticId, "不应嵌套定义枚举", "不应在类型内部嵌套定义枚举 '{0}'", "结构约束", DiagnosticSeverity.Warning, true);
        
        private static readonly DiagnosticDescriptor MultiEnumFileRule = new DiagnosticDescriptor(
            MultiEnumFileDiagnosticId, "单个文件定义了多个枚举", "文件 '{0}' 中定义了多个枚举，应将每个枚举置于其独立文件中", "Design", DiagnosticSeverity.Warning, true);
            
        private static readonly DiagnosticDescriptor ConditionalCompilationWarningRule = new DiagnosticDescriptor(
            ConditionalCompilationWarningId, "检测到条件编译指令", "文件 '{0}' 包含条件编译指令（{1}），可能存在注释关联BUG。建议使用 -MultiEnvironment 参数进行多环境分析以获得更准确的结果。", "ConditionalCompilation", DiagnosticSeverity.Info, true);
        
        public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics => ImmutableArray.Create(
            TypeNoCommentBlockRule,
            MemberNoCommentBlockRule,
            MissingTypeSummaryRule,
            MissingTypeRemarksRule,
            MissingTypeRemarksTagRule,
            MissingMemberSummaryRule,
            MissingMemberParamRule,
            MissingMemberReturnsRule,
            MissingMemberTypeParamRule,
            MissingMemberRemarksRule,
            DuplicateTypeSummaryRule,
            DuplicateTypeRemarksRule,
            DuplicateMemberSummaryRule,
            DuplicateMemberRemarksRule,
            NestedTypeRule,
            NestedEnumRule,
            MultiEnumFileRule,
            ConditionalCompilationWarningRule
        );

        #endregion

        /// <summary>
        /// 初始化分析器，注册要在其上执行操作的语法节点类型。
        /// 这是分析器的入口点。
        /// </summary>
        public override void Initialize(AnalysisContext context)
        {
            // 标准配置：禁止分析自动生成的代码，并允许并行执行以提高性能。
            context.ConfigureGeneratedCodeAnalysis(GeneratedCodeAnalysisFlags.None);
            context.EnableConcurrentExecution();

            // 注册对"类型声明"节点的操作。当Roslyn遍历语法树遇到这些类型的节点时，会调用 AnalyzeTypeDeclaration 方法。
            context.RegisterSyntaxNodeAction(AnalyzeTypeDeclaration, 
                SyntaxKind.ClassDeclaration, 
                SyntaxKind.StructDeclaration, 
                SyntaxKind.InterfaceDeclaration);

            // 为枚举声明注册一个专门的分析器
            context.RegisterSyntaxNodeAction(AnalyzeEnumDeclaration, SyntaxKind.EnumDeclaration);

            // 为委托声明注册一个专门的分析器
            context.RegisterSyntaxNodeAction(AnalyzeDelegateDeclaration, SyntaxKind.DelegateDeclaration);

            // 注册对"成员声明"节点的操作。
            context.RegisterSyntaxNodeAction(AnalyzeMemberDeclaration, 
                SyntaxKind.MethodDeclaration, 
                SyntaxKind.PropertyDeclaration, 
                SyntaxKind.FieldDeclaration, 
                SyntaxKind.EventDeclaration, 
                SyntaxKind.EventFieldDeclaration,
                SyntaxKind.ConstructorDeclaration,
                SyntaxKind.DestructorDeclaration,
                SyntaxKind.IndexerDeclaration,
                SyntaxKind.OperatorDeclaration,
                SyntaxKind.ConversionOperatorDeclaration);
                
            // 注册对整个语法树的操作。这对于需要文件级别上下文的检查（如一个文件定义多个枚举）是必需的。
            context.RegisterSyntaxTreeAction(AnalyzeMultiEnumFile);
            
            // 注册条件编译检测
            context.RegisterSyntaxTreeAction(AnalyzeConditionalCompilation);
        }

        #region Analyzers

        /// <summary>
        /// 分析枚举声明节点 (enum)。
        /// </summary>
        private void AnalyzeEnumDeclaration(SyntaxNodeAnalysisContext context)
        {
            var enumDecl = (EnumDeclarationSyntax)context.Node;

            // --- Gatekeeper 1: Ignore compiler-generated symbols ---
            var symbol = context.SemanticModel.GetDeclaredSymbol(enumDecl);
            if (symbol == null || symbol.IsImplicitlyDeclared)
            {
                return;
            }

            // --- Gate 1: Check for XML documentation trivia ---
            var trivia = enumDecl.GetLeadingTrivia()
                .Select(i => i.GetStructure())
                .OfType<DocumentationCommentTriviaSyntax>()
                .FirstOrDefault();

            if (trivia == null)
            {
                // For enums, the "TypeNoCommentBlock" rule is still applicable.
                var diagnostic = Diagnostic.Create(TypeNoCommentBlockRule, enumDecl.Identifier.GetLocation(), "Enum", enumDecl.Identifier.ValueText);
                context.ReportDiagnostic(diagnostic);
                return; // Stop analysis if there's no comment block.
            }

            // --- Gate 2: Check for <summary> tag ---
            var summaryElement = trivia.Content.OfType<XmlElementSyntax>().FirstOrDefault(el => el.StartTag.Name.LocalName.ValueText == "summary");
            if (summaryElement == null || summaryElement.Content.ToString().Trim() == string.Empty)
            {
                // Re-use the MissingTypeSummaryRule for consistency.
                var diagnostic = Diagnostic.Create(MissingTypeSummaryRule, enumDecl.Identifier.GetLocation(), "Enum", enumDecl.Identifier.ValueText);
                context.ReportDiagnostic(diagnostic);
            }
            
            // --- 结构约束检查: 嵌套枚举 ---
            // 这部分逻辑已移至 AnalyzeTypeDeclaration 中的 CheckForNestedEnums，以避免重复报告。
            // 检查的责任在于父类型，而不是枚举自身。
            // Check if the enum is nested inside another type.
            // if (enumDecl.Parent is BaseTypeDeclarationSyntax)
            // {
            //     var diagnostic = Diagnostic.Create(NestedEnumRule, enumDecl.Identifier.GetLocation(), enumDecl.Identifier.ValueText);
            //     context.ReportDiagnostic(diagnostic);
            // }
        }

        /// <summary>
        /// 分析委托声明节点 (delegate)。
        /// </summary>
        private void AnalyzeDelegateDeclaration(SyntaxNodeAnalysisContext context)
        {
            var delegateDecl = (DelegateDeclarationSyntax)context.Node;

            // --- Gatekeeper 1: Ignore compiler-generated symbols ---
            var symbol = context.SemanticModel.GetDeclaredSymbol(delegateDecl);
            if (symbol == null || symbol.IsImplicitlyDeclared)
            {
                return;
            }

            // --- Gatekeeper 2: Only analyze appropriate delegates ---
            if (!ShouldHaveDocumentation(symbol))
            {
                return;
            }

            // --- Gate 1: 存在性检查 ---
            var xmlTrivia = delegateDecl.GetLeadingTrivia().FirstOrDefault(t => t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia));

            if (xmlTrivia == default)
            {
                context.ReportDiagnostic(Diagnostic.Create(TypeNoCommentBlockRule, delegateDecl.Identifier.GetLocation(), "Delegate", delegateDecl.Identifier.Text));
                return; // 停止对此节点的进一步分析
            }

            // --- Gate 2: 结构完整性检查 ---
            if (xmlTrivia.GetStructure() is DocumentationCommentTriviaSyntax xmlStructure)
            {
                CheckDelegateCommentContent(context, xmlStructure, delegateDecl);
            }
        }

        /// <summary>
        /// 分析类型声明节点 (class, struct, interface, enum)。
        /// 这是"双层门控逻辑"的第一层实现。
        /// </summary>
        private void AnalyzeTypeDeclaration(SyntaxNodeAnalysisContext context)
        {
            var typeDecl = (TypeDeclarationSyntax)context.Node;

            // --- Gatekeeper 1: Ignore compiler-generated symbols ---
            var symbol = context.SemanticModel.GetDeclaredSymbol(typeDecl);
            if (symbol == null || symbol.IsImplicitlyDeclared)
            {
                return;
            }

            // --- Gatekeeper 2: Only analyze public types ---
            if (!ShouldHaveDocumentation(symbol))
            {
                return;
            }

            // --- Gate 1: 存在性检查 ---
            // 核心原理: `GetLeadingTrivia()` 获取节点之前的所有"琐事"（包括注释、空白等）。
            // 我们只关心 `SingleLineDocumentationCommentTrivia` (`///`)。
            var xmlTrivia = typeDecl.GetLeadingTrivia().FirstOrDefault(t => t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia));

            // 如果找不到 `///` 注释块 (xmlTrivia 是其默认值)，则报告缺少注释块的错误并立即返回。
            if (xmlTrivia == default)
            {
                context.ReportDiagnostic(Diagnostic.Create(TypeNoCommentBlockRule, typeDecl.Identifier.GetLocation(), typeDecl.Kind().ToString(), typeDecl.Identifier.Text));
                return; // **关键**: 停止对此节点的进一步分析。
            }

            // --- Gate 2: 结构完整性检查 ---
            // 核心原理: `GetStructure()` 将 trivia 解析为一个结构化的语法节点 (`DocumentationCommentTriviaSyntax`)。
            // 只有当成功通过第一道门，我们才进行到这一步。
            if (xmlTrivia.GetStructure() is DocumentationCommentTriviaSyntax xmlStructure)
            {
                CheckTypeCommentContent(context, xmlStructure, typeDecl);
                CheckForNestedTypes(context, typeDecl);
                CheckForNestedEnums(context, typeDecl);
            }
        }

        /// <summary>
        /// 分析成员声明节点 (method, property, etc.)。
        /// 同样实现了"双层门控逻辑"。
        /// </summary>
        private void AnalyzeMemberDeclaration(SyntaxNodeAnalysisContext context)
        {
            var memberDecl = (MemberDeclarationSyntax)context.Node;
            // 获取成员的标识符以用于报告。不同类型的成员，其Identifier的获取方式略有不同。
            var identifier = GetIdentifierForMember(memberDecl);
            if(identifier == default) return; // 无法识别的成员，跳过

            // --- Gatekeeper 1: Only analyze public members ---
            var symbol = GetSymbolForMember(context.SemanticModel, memberDecl);
            if (symbol == null || !ShouldHaveDocumentation(symbol))
            {
                return;
            }

            // --- Gate 1: 存在性检查 ---
            var xmlTrivia = memberDecl.GetLeadingTrivia().FirstOrDefault(t => t.IsKind(SyntaxKind.SingleLineDocumentationCommentTrivia));

            if (xmlTrivia == default)
            {
                context.ReportDiagnostic(Diagnostic.Create(MemberNoCommentBlockRule, identifier.GetLocation(), memberDecl.Kind().ToString(), identifier.Text));
                return; // **关键**: 停止对此节点的进一步分析。
            }

            // --- Gate 2: 结构完整性检查 ---
            if (xmlTrivia.GetStructure() is DocumentationCommentTriviaSyntax xmlStructure)
            {
                CheckMemberCommentContent(context, xmlStructure, memberDecl, identifier.Text);
            }
        }

        /// <summary>
        /// 对整个语法树进行分析，用于执行需要文件级别上下文的检查。
        /// </summary>
        private void AnalyzeMultiEnumFile(SyntaxTreeAnalysisContext context)
        {
            // 核心原理: 获取语法树的根节点，然后查询其下所有特定类型的子节点。
            var root = context.Tree.GetRoot(context.CancellationToken);
            var enumsInFile = root.DescendantNodes().OfType<EnumDeclarationSyntax>().ToList();

            if (enumsInFile.Count > 1)
            {
                // 如果找到多个枚举，就在第一个枚举的位置报告一个警告。
                // 这样可以避免在每个枚举上都报告一次，减少干扰。
                var firstEnum = enumsInFile.First();
                var fileName = System.IO.Path.GetFileName(context.Tree.FilePath);
                context.ReportDiagnostic(Diagnostic.Create(MultiEnumFileRule, firstEnum.GetLocation(), fileName));
            }
        }

        /// <summary>
        /// 检测文件中是否包含条件编译指令，如果包含则发出告警。
        /// </summary>
        /// <remarks>
        /// 功能: 检测条件编译指令的存在，并报告可能的注释关联BUG风险
        /// 架构逻辑: 遍历语法树中的所有预处理器指令，识别条件编译相关的指令
        /// 检测范围: #if, #ifdef, #ifndef, #elif, #else, #endif
        /// 告警策略: 在文件的第一个条件编译指令位置报告一次告警，避免重复干扰
        /// 使用场景: 提醒用户在条件编译环境下可能需要使用多环境分析功能
        /// </remarks>
        private void AnalyzeConditionalCompilation(SyntaxTreeAnalysisContext context)
        {
            // 获取语法树的根节点
            var root = context.Tree.GetRoot(context.CancellationToken);
            
            // 查找所有的预处理器指令
            var conditionalDirectives = root.DescendantTrivia()
                .Where(trivia => trivia.IsKind(SyntaxKind.IfDirectiveTrivia) ||
                               trivia.IsKind(SyntaxKind.ElifDirectiveTrivia) ||
                               trivia.IsKind(SyntaxKind.ElseDirectiveTrivia) ||
                               trivia.IsKind(SyntaxKind.EndIfDirectiveTrivia))
                .ToList();

            if (conditionalDirectives.Any())
            {
                // 获取第一个条件编译指令
                var firstDirective = conditionalDirectives.First();
                var fileName = System.IO.Path.GetFileName(context.Tree.FilePath);
                
                // 收集所有条件编译指令的类型，用于详细报告
                var directiveTypes = conditionalDirectives
                    .Select(d => d.Kind().ToString().Replace("DirectiveTrivia", "").ToLower())
                    .Distinct()
                    .ToList();
                var directiveList = string.Join(", ", directiveTypes);
                
                // 在第一个条件编译指令的位置报告告警
                var location = Location.Create(context.Tree, firstDirective.Span);
                context.ReportDiagnostic(Diagnostic.Create(ConditionalCompilationWarningRule, location, fileName, directiveList));
            }
        }

        #endregion

        #region Content Checkers

        /// <summary>
        /// 检查类型注释块的内部结构是否完整。
        /// </summary>
        private void CheckTypeCommentContent(SyntaxNodeAnalysisContext context, DocumentationCommentTriviaSyntax xml, TypeDeclarationSyntax typeDecl)
        {
            var typeName = typeDecl.Identifier.Text;
            var typeKind = typeDecl.Kind().ToString();

            // 检查 <summary>
            if (!HasTag(xml, "summary"))
            {
                context.ReportDiagnostic(Diagnostic.Create(MissingTypeSummaryRule, typeDecl.Identifier.GetLocation(), typeKind, typeName));
            }

            // 检查 <remarks>
            var remarksTag = GetTag(xml, "remarks");
            if (remarksTag == null)
            {
                context.ReportDiagnostic(Diagnostic.Create(MissingTypeRemarksRule, typeDecl.Identifier.GetLocation(), typeKind, typeName));
            }
            else
            {
                // 如果 <remarks> 存在，则检查其内部是否包含所有必需的结构化标签。
                var remarksContent = remarksTag.Content.ToString();
                var requiredTags = new[] { "功能:", "架构层级:", "模块:", "继承/实现关系:", "依赖:", "扩展点:", "特性:", "重要逻辑:", "数据流:", "使用示例:" };
                foreach (var tag in requiredTags)
                {
                    if (!remarksContent.Contains(tag))
                    {
                        context.ReportDiagnostic(Diagnostic.Create(MissingTypeRemarksTagRule, remarksTag.GetLocation(), typeKind, typeName, tag));
                    }
                }
            }

            // 检查重复标签
            CheckForDuplicateTags(context, xml, typeName, true);
        }

        /// <summary>
        /// 检查委托注释块的内部结构是否完整。
        /// </summary>
        private void CheckDelegateCommentContent(SyntaxNodeAnalysisContext context, DocumentationCommentTriviaSyntax xml, DelegateDeclarationSyntax delegateDecl)
        {
            var delegateName = delegateDecl.Identifier.Text;

            // 检查 <summary>
            if (!HasTag(xml, "summary"))
            {
                context.ReportDiagnostic(Diagnostic.Create(MissingTypeSummaryRule, delegateDecl.Identifier.GetLocation(), "Delegate", delegateName));
            }

            // 检查 <remarks>
            var remarksTag = GetTag(xml, "remarks");
            if (remarksTag == null)
            {
                context.ReportDiagnostic(Diagnostic.Create(MissingTypeRemarksRule, delegateDecl.Identifier.GetLocation(), "Delegate", delegateName));
            }

            // 检查委托特有的标签：参数、类型参数、返回值
            // 检查类型参数 <typeparam>
            if (delegateDecl.TypeParameterList != null)
            {
                foreach (var typeParam in delegateDecl.TypeParameterList.Parameters)
                {
                    if (!HasTypeParamTag(xml, typeParam.Identifier.ValueText))
                    {
                        context.ReportDiagnostic(Diagnostic.Create(MissingMemberTypeParamRule, typeParam.GetLocation(), "Delegate", delegateName, typeParam.Identifier.ValueText));
                    }
                }
            }

            // 检查参数 <param>
            if (delegateDecl.ParameterList != null)
            {
                foreach (var param in delegateDecl.ParameterList.Parameters)
                {
                    if (!HasParamTag(xml, param.Identifier.ValueText))
                    {
                        context.ReportDiagnostic(Diagnostic.Create(MissingMemberParamRule, param.GetLocation(), "Delegate", delegateName, param.Identifier.ValueText));
                    }
                }
            }

            // 检查返回值 <returns> (只有非void委托需要)
            if (delegateDecl.ReturnType != null)
            {
                // 检查是否为void返回类型
                var returnType = delegateDecl.ReturnType;
                var semanticModel = context.SemanticModel;
                var typeSymbol = semanticModel.GetTypeInfo(returnType).Type;
                
                bool isVoid = returnType.ToString().Trim() == "void" || 
                             (typeSymbol != null && typeSymbol.SpecialType == SpecialType.System_Void);

                if (!isVoid && !HasTag(xml, "returns"))
                {
                    context.ReportDiagnostic(Diagnostic.Create(MissingMemberReturnsRule, delegateDecl.Identifier.GetLocation(), "Delegate", delegateName));
                }
            }
        }

        /// <summary>
        /// 检查成员注释块的内部结构是否完整。
        /// </summary>
        private void CheckMemberCommentContent(SyntaxNodeAnalysisContext context, DocumentationCommentTriviaSyntax xml, MemberDeclarationSyntax memberDecl, string memberName)
        {
             var memberKind = memberDecl.Kind().ToString();

            // 检查 <summary>
            if (!HasTag(xml, "summary"))
            {
                context.ReportDiagnostic(Diagnostic.Create(MissingMemberSummaryRule, GetIdentifierForMember(memberDecl).GetLocation(), memberKind, memberName));
            }

            // 检查 <remarks>
            if (!HasTag(xml, "remarks"))
            {
                context.ReportDiagnostic(Diagnostic.Create(MissingMemberRemarksRule, GetIdentifierForMember(memberDecl).GetLocation(), memberKind, memberName));
            }

            // 仅对方法和构造函数检查参数和返回值
            if (memberDecl is BaseMethodDeclarationSyntax methodBase)
            {
                // 检查 <param>
                foreach (var parameter in methodBase.ParameterList.Parameters)
                {
                    // 核心原理: 使用LINQ查询XML节点，其name属性必须与参数标识符匹配。
                    if (!HasParamTag(xml, parameter.Identifier.Text))
                    {
                        // 在参数自己的位置报告错误，而不是在方法上。
                        context.ReportDiagnostic(Diagnostic.Create(MissingMemberParamRule, parameter.GetLocation(), memberName, parameter.Identifier.Text));
                    }
                }
                
                // 仅对方法检查类型参数和返回值
                if (memberDecl is MethodDeclarationSyntax methodDecl)
                {
                    // 检查 <typeparam>
                    if (methodDecl.TypeParameterList != null)
                    {
                        foreach (var typeParameter in methodDecl.TypeParameterList.Parameters)
                        {
                            if (!HasTypeParamTag(xml, typeParameter.Identifier.Text))
                            {
                                // 在类型参数自己的位置报告错误。
                                context.ReportDiagnostic(Diagnostic.Create(MissingMemberTypeParamRule, typeParameter.GetLocation(), memberName, typeParameter.Identifier.Text));
                            }
                        }
                    }

                    // 检查 <returns>
                    // 如果方法的返回类型不是 "void"，则它必须有 <returns> 标签。
                    var returnType = methodDecl.ReturnType;
                    
                    // 更可靠的void类型检查方法
                    bool isVoid = false;
                    
                    // 方法1: 检查语法文本 - 这是最直接的方法
                    var returnTypeText = returnType.ToString().Trim();
                    if (returnTypeText.Equals("void", StringComparison.OrdinalIgnoreCase))
                    {
                        isVoid = true;
                    }
                    
                    // 方法2: 如果方法1失败，通过语义模型检查
                    if (!isVoid)
                    {
                        var returnTypeSymbol = context.SemanticModel.GetSymbolInfo(returnType).Symbol;
                        if (returnTypeSymbol is ITypeSymbol typeSymbol)
                        {
                            isVoid = typeSymbol.SpecialType == SpecialType.System_Void;
                        }
                    }
                    
                    // 方法3: 如果前两种方法都失败，检查类型信息
                    if (!isVoid)
                    {
                        var typeInfo = context.SemanticModel.GetTypeInfo(returnType);
                        if (typeInfo.Type != null)
                        {
                            isVoid = typeInfo.Type.SpecialType == SpecialType.System_Void;
                        }
                    }
                    
                    // 调试输出 - 在生产环境中应该移除
                    #if DEBUG
                    if (memberName.Contains("Void"))
                    {
                        System.Diagnostics.Debug.WriteLine($"Debug: Method {memberName}, ReturnType: '{returnTypeText}', IsVoid: {isVoid}");
                    }
                    #endif

                    if (!isVoid && !HasTag(xml, "returns"))
                    {
                        context.ReportDiagnostic(Diagnostic.Create(MissingMemberReturnsRule, returnType.GetLocation(), memberName));
                    }
                }
            }

            // 检查重复标签
            CheckForDuplicateTags(context, xml, memberName, false);
        }

        private void CheckForNestedTypes(SyntaxNodeAnalysisContext context, TypeDeclarationSyntax typeDecl)
        {
            // 检查并报告嵌套的类、结构体或接口
            var nestedTypes = typeDecl.Members.OfType<TypeDeclarationSyntax>()
                .Where(m => !m.IsKind(SyntaxKind.EnumDeclaration)); // 排除枚举，它由下面的方法单独处理
            
            foreach (var nestedType in nestedTypes)
            {
                context.ReportDiagnostic(Diagnostic.Create(NestedTypeRule, nestedType.Identifier.GetLocation(), nestedType.Identifier.Text));
            }
        }

        private void CheckForNestedEnums(SyntaxNodeAnalysisContext context, TypeDeclarationSyntax typeDecl)
        {
            // 检查并报告嵌套的枚举
            var nestedEnums = typeDecl.Members.OfType<EnumDeclarationSyntax>();
            foreach (var nestedEnum in nestedEnums)
            {
                context.ReportDiagnostic(Diagnostic.Create(NestedEnumRule, nestedEnum.Identifier.GetLocation(), nestedEnum.Identifier.Text));
            }
        }

        #endregion

        #region Helpers

        /// <summary>
        /// 判断给定的符号是否应该有XML文档注释。
        /// 根据项目要求，所有成员（包括私有成员）都需要文档注释。
        /// </summary>
        /// <param name="symbol">要检查的符号，null时返回false</param>
        /// <returns>如果符号应该有文档注释则返回true，null符号返回false</returns>
        private bool ShouldHaveDocumentation(ISymbol? symbol)
        {
            // Null安全检查 - 避免NullReferenceException
            if (symbol == null) 
            {
                return false;
            }

            // 根据项目要求，所有成员都需要文档注释，包括私有成员
            // 检查符号的可访问性 - 优化为更简洁的逻辑
            switch (symbol.DeclaredAccessibility)
            {
                case Accessibility.Public:
                case Accessibility.Protected:
                case Accessibility.ProtectedOrInternal:
                case Accessibility.Internal:
                case Accessibility.Private:
                case Accessibility.ProtectedAndInternal:
                    return true; // 所有访问级别的成员都需要文档
                case Accessibility.NotApplicable:
                    // 特殊情况处理：接口成员、枚举成员等默认情况
                    break;
                default:
                    // 未知的访问级别，采用保守策略
                    return true;
            }

            // 特殊情况：接口成员没有显式访问修饰符，但默认是公共的
            if (symbol.ContainingType?.TypeKind == TypeKind.Interface)
            {
                return true;
            }

            // 特殊情况：枚举成员默认是公共的
            if (symbol.ContainingType?.TypeKind == TypeKind.Enum)
            {
                return true;
            }

            // 对于NotApplicable情况，默认需要文档
            return true; // 保守策略：默认情况下都需要文档注释
        }

        /// <summary>
        /// 从不同类型的成员声明中安全地获取其符号。
        /// 处理字段和事件字段的特殊情况，这些需要通过变量声明器获取符号。
        /// </summary>
        /// <param name="semanticModel">语义模型，用于符号解析</param>
        /// <param name="member">成员声明语法节点</param>
        /// <returns>对应的符号，如果无法解析则返回null</returns>
        private ISymbol? GetSymbolForMember(SemanticModel? semanticModel, MemberDeclarationSyntax? member)
        {
            // Null安全检查
            if (semanticModel == null || member == null)
            {
                return null;
            }

            try
            {
                switch (member)
                {
                    case FieldDeclarationSyntax fieldDecl:
                        // 字段声明可能包含多个变量，获取第一个
                        var fieldVariable = fieldDecl.Declaration?.Variables.FirstOrDefault();
                        return fieldVariable != null ? semanticModel.GetDeclaredSymbol(fieldVariable) : null;
                    
                    case EventFieldDeclarationSyntax eventFieldDecl:
                        // 事件字段声明也可能包含多个变量，获取第一个
                        var eventVariable = eventFieldDecl.Declaration?.Variables.FirstOrDefault();
                        return eventVariable != null ? semanticModel.GetDeclaredSymbol(eventVariable) : null;
                    
                    default:
                        // 其他成员类型可以直接获取符号
                        return semanticModel.GetDeclaredSymbol(member);
                }
            }
            catch (ArgumentException)
            {
                // 当语法节点无效或不在语义模型范围内时，可能会抛出ArgumentException
                // 这是正常情况，返回null即可
                return null;
            }
        }

        /// <summary>
        /// 从不同类型的成员声明中安全地获取其标识符Token。
        /// </summary>
        private SyntaxToken GetIdentifierForMember(MemberDeclarationSyntax member)
        {
            switch (member)
            {
                case MethodDeclarationSyntax m: return m.Identifier;
                case PropertyDeclarationSyntax p: return p.Identifier;
                case FieldDeclarationSyntax f: return f.Declaration.Variables.FirstOrDefault()?.Identifier ?? default;
                case EventDeclarationSyntax e: return e.Identifier;
                case EventFieldDeclarationSyntax ef: return ef.Declaration.Variables.FirstOrDefault()?.Identifier ?? default;
                case ConstructorDeclarationSyntax c: return c.Identifier;
                case DestructorDeclarationSyntax d: return d.Identifier;
                case IndexerDeclarationSyntax i: return i.ThisKeyword; // 索引器使用this关键字作为标识符
                case OperatorDeclarationSyntax op: return op.OperatorToken;
                case ConversionOperatorDeclarationSyntax conv: return conv.Type.GetFirstToken(); // 使用类型作为标识符
                default: return default;
            }
        }
        
        /// <summary>
        /// 检查一个XML注释块中是否存在指定名称的标签。
        /// </summary>
        private bool HasTag(DocumentationCommentTriviaSyntax xml, string tagName)
        {
            // 核心原理: 对注释块的内容进行LINQ查询。
            // 1. `OfType<XmlElementSyntax>()`: 只筛选出XML元素（如 <summary>...</summary>）。
            // 2. `Any(...)`: 检查是否存在任何一个元素满足条件。
            // 3. `e.StartTag.Name.ToString() == tagName`: 比较元素的开始标签名。
            return xml.Content.OfType<XmlElementSyntax>().Any(e => e.StartTag.Name.ToString().Equals(tagName, StringComparison.OrdinalIgnoreCase));
        }

        /// <summary>
        /// 获取一个XML注释块中指定名称的第一个标签。
        /// </summary>
        private XmlElementSyntax GetTag(DocumentationCommentTriviaSyntax xml, string tagName)
        {
            return xml.Content.OfType<XmlElementSyntax>().FirstOrDefault(e => e.StartTag.Name.ToString().Equals(tagName, StringComparison.OrdinalIgnoreCase));
        }

        /// <summary>
        /// 统计XML注释块中指定名称的标签数量。
        /// </summary>
        /// <remarks>
        /// 功能: 解决分析器重复标签检测缺失问题
        /// 架构层级: 分析器核心逻辑
        /// 依赖: DocumentationCommentTriviaSyntax, XmlElementSyntax
        /// 扩展点: 可用于各种标签的重复检测
        /// </remarks>
        private int CountTag(DocumentationCommentTriviaSyntax xml, string tagName)
        {
            return xml.Content.OfType<XmlElementSyntax>().Count(e => e.StartTag.Name.ToString().Equals(tagName, StringComparison.OrdinalIgnoreCase));
        }

        /// <summary>
        /// 检查XML注释块中是否存在重复标签。
        /// </summary>
        /// <remarks>
        /// 功能: 检测并报告XML注释块中的重复标签问题
        /// 架构层级: 分析器核心逻辑
        /// 依赖: DocumentationCommentTriviaSyntax, SyntaxNodeAnalysisContext
        /// 扩展点: 可以扩展支持更多标签类型的重复检测
        /// </remarks>
        private void CheckForDuplicateTags(SyntaxNodeAnalysisContext context, DocumentationCommentTriviaSyntax xml, string memberName, bool isTypeNode)
        {
            // 检查<summary>标签重复
            var summaryCount = CountTag(xml, "summary");
            if (summaryCount > 1)
            {
                var summaryRule = isTypeNode ? DuplicateTypeSummaryRule : DuplicateMemberSummaryRule;
                var memberType = isTypeNode ? "类型" : "成员";
                context.ReportDiagnostic(Diagnostic.Create(summaryRule, xml.GetLocation(), memberType, memberName));
            }

            // 检查<remarks>标签重复
            var remarksCount = CountTag(xml, "remarks");
            if (remarksCount > 1)
            {
                var remarksRule = isTypeNode ? DuplicateTypeRemarksRule : DuplicateMemberRemarksRule;
                var memberType = isTypeNode ? "类型" : "成员";
                context.ReportDiagnostic(Diagnostic.Create(remarksRule, xml.GetLocation(), memberType, memberName));
            }
        }

        /// <summary>
        /// 检查是否存在针对特定参数名称的 <param> 标签。
        /// </summary>
        private bool HasParamTag(DocumentationCommentTriviaSyntax xml, string paramName)
        {
            return xml.Content.OfType<XmlElementSyntax>()
                .Where(e => e.StartTag.Name.ToString().Equals("param", StringComparison.OrdinalIgnoreCase))
                .Select(e => e.StartTag.Attributes.OfType<XmlNameAttributeSyntax>().FirstOrDefault())
                .Any(attr => attr != null && attr.Identifier.Identifier.Text == paramName);
        }

        /// <summary>
        /// 检查是否存在针对特定类型参数名称的 <typeparam> 标签。
        /// </summary>
        private bool HasTypeParamTag(DocumentationCommentTriviaSyntax xml, string typeParamName)
        {
            return xml.Content.OfType<XmlElementSyntax>()
                .Where(e => e.StartTag.Name.ToString().Equals("typeparam", StringComparison.OrdinalIgnoreCase))
                .Select(e => e.StartTag.Attributes.OfType<XmlNameAttributeSyntax>().FirstOrDefault())
                .Any(attr => attr != null && attr.Identifier.Identifier.Text == typeParamName);
        }
        
        #endregion
    }
}