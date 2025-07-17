using System;

namespace Dropleton.Tests.MainScript
{
    // 测试类 - 缺少所有注释
    public class TestClassNoComments
    {
        public string TestField;
        
        public string TestProperty { get; set; }
        
        public void TestMethod(string param1, int param2)
        {
            Console.WriteLine("Test method");
        }
        
        public event Action TestEvent;
        
        public TestClassNoComments(string value)
        {
            TestField = value;
        }
    }
    
    // 测试结构体 - 缺少注释
    public struct TestStruct
    {
        public int Value;
        
        public void DoSomething()
        {
            Value = 42;
        }
    }
    
    // 测试接口 - 缺少注释
    public interface ITestInterface
    {
        string GetValue();
        void SetValue(string value);
    }
    
    // 测试枚举 - 缺少注释
    public enum TestEnum
    {
        None,
        Value1,
        Value2
    }
    
    // 测试委托 - 缺少注释
    public delegate string TestDelegate(int input, bool flag);
} 