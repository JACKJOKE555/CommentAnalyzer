using System;

namespace Dropleton.Tests.MainScriptErrorHandling
{
    // 测试类 - 包含语法错误，用于测试主脚本的错误处理能力
    public class TestErrorHandlingClass
    {
        // 故意的语法错误 - 缺少分号
        // public string ErrorField = "test" 故意错误语法，测试时取消注释
        
        // 正常的成员用于对比
        public string NormalField;
        
        public void TestMethod()
        {
            // 故意的语法错误 - 未定义的变量
            UndefinedVariable = "test";
        }
        
        // 重复的方法名 - 编译错误
        public void TestMethod()
        {
            Console.WriteLine("Duplicate method");
        }
    }
    
    // 测试接口
    public interface ITestError
    {
        void DoWork();
    }
} 