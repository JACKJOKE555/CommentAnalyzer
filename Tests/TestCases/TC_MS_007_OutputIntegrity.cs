using System;

/// <summary>
/// TC_MS_007_OutputIntegrity - 输出完整性测试用例
/// </summary>
/// <remarks>
/// 功能: 用于测试CommentAnalyzer.ps1的输出完整性，确保无重复输出
/// 架构层级: 测试层
/// 模块: 主入口脚本测试
/// 继承/实现关系: 无
/// 依赖: 无
/// 扩展点: 无
/// 特性: 包含多种注释问题以产生足够的输出用于重复检测
/// 重要逻辑: 验证每条输出信息只出现一次
/// 数据流: 测试文件 -> CommentAnalyzer.ps1 -> 输出完整性验证
/// 使用示例: 与Run_TC_MS_007_OutputIntegrity.ps1配合使用
/// </remarks>
namespace Dropleton.Tests.OutputIntegrity
{
    // 完全没有注释的类 - 触发多个诊断
    public class NoCommentClass
    {
        public string Field1;
        public int Field2;
        public bool Field3;
        
        public void Method1() { }
        public void Method2(string param) { }
        public int Method3(int a, string b) { return a; }
        
        public string Property1 { get; set; }
        public int Property2 { get; set; }
    }
    
    // 部分注释的类 - 混合触发诊断
    public class PartialCommentClass
    {
        /// <summary>DocumentedField - 有注释的字段</summary>
        public string DocumentedField;
        
        // 无注释字段
        public string UndocumentedField;
        
        /// <summary>DocumentedMethod - 有注释的方法</summary>
        public void DocumentedMethod() { }
        
        // 无注释方法
        public void UndocumentedMethod(int param) { }
        
        // 缺少remarks的方法
        /// <summary>IncompleteMethod - 不完整注释的方法</summary>
        public string IncompleteMethod(string input)
        {
            return input;
        }
    }
    
    // 嵌套类型 - 触发设计诊断
    public class OuterClass
    {
        public class NestedClass
        {
            public void NestedMethod() { }
        }
        
        public enum NestedEnum
        {
            Value1,
            Value2
        }
    }
    
    // 泛型类 - 触发typeparam相关诊断
    public class GenericClass<T, U>
    {
        public T GenericMethod<V>(U param, V genericParam)
        {
            return default(T);
        }
    }
} 