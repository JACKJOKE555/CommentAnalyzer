using System;

namespace AccessibilityTest
{
    public class TestClass
    {
        // 公共字段 - 应该被检测
        public string PublicField;
        
        // 私有字段 - 不应该被检测
        private string privateField;
        
        // 公共属性 - 应该被检测
        public string PublicProperty { get; set; }
        
        // 私有属性 - 不应该被检测
        private string PrivateProperty { get; set; }
        
        // 公共方法 - 应该被检测
        public void PublicMethod(string param)
        {
        }
        
        // 私有方法 - 不应该被检测
        private void PrivateMethod()
        {
        }
        
        // 受保护的方法 - 应该被检测
        protected void ProtectedMethod()
        {
        }
    }
    
    // 私有类 - 不应该被检测
    class PrivateClass
    {
        public void PublicMethodInPrivateClass()
        {
        }
    }
} 