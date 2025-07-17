using System;

/// <summary>
/// TC_MS_006_DebugControl - Debug输出控制测试用例
/// </summary>
/// <remarks>
/// 功能: 用于测试CommentAnalyzer.ps1的debug输出控制机制
/// 架构层级: 测试层
/// 模块: 主入口脚本测试
/// 继承/实现关系: 无
/// 依赖: 无
/// 扩展点: 无
/// 特性: 包含故意的注释问题以触发分析
/// 重要逻辑: 验证在不同debug参数下的输出行为
/// 数据流: 测试文件 -> CommentAnalyzer.ps1 -> 输出验证
/// 使用示例: 与Run_TC_MS_006_DebugControl.ps1配合使用
/// </remarks>
namespace Dropleton.Tests.DebugControl
{
    // 故意缺少XML注释的类，用于触发诊断
    public class TestClassNoComment
    {
        // 故意缺少注释的字段
        public string TestField;
        
        // 故意缺少注释的方法
        public void TestMethod(string param)
        {
            Console.WriteLine("Test method");
        }
        
        // 故意缺少注释的属性
        public int TestProperty { get; set; }
    }
    
    /// <summary>
    /// TestClassWithPartialComment - 部分注释的测试类
    /// </summary>
    public class TestClassWithPartialComment
    {
        // 缺少注释的成员
        public string IncompleteField;
        
        /// <summary>
        /// CompleteMethod - 完整注释的方法
        /// </summary>
        /// <remarks>
        /// 功能: 测试方法
        /// </remarks>
        /// <param name="value">测试参数</param>
        /// <returns>测试返回值</returns>
        public string CompleteMethod(string value)
        {
            return value;
        }
    }
} 