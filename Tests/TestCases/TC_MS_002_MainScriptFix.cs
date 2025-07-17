using System;

namespace Dropleton.Tests.MainScriptFix
{
    // 测试类 - 完全无注释，适合测试修复功能
    public class TestFixClass
    {
        public string Name;
        
        public int Age { get; set; }
        
        public void Initialize(string name, int age)
        {
            Name = name;
            Age = age;
        }
        
        public string GetInfo()
        {
            return $"Name: {Name}, Age: {Age}";
        }
    }
    
    // 测试结构体
    public struct TestFixStruct
    {
        public double Value;
        
        public void Reset()
        {
            Value = 0.0;
        }
    }
    
    // 测试接口
    public interface ITestFix
    {
        void DoWork();
        string GetResult();
    }
} 