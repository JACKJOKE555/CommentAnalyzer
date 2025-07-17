using System;

namespace TestCases
{
    // 公共类 - 应该被检测
    public class PublicTestClass
    {
        // 公共字段 - 应该被检测
        public string PublicField;
        
        // 受保护字段 - 应该被检测
        protected string ProtectedField;
        
        // 内部字段 - 应该被检测
        internal string InternalField;
        
        // 私有字段 - 应该被检测
        private string privateField;
        
        // 公共属性 - 应该被检测
        public string PublicProperty { get; set; }
        
        // 受保护属性 - 应该被检测
        protected string ProtectedProperty { get; set; }
        
        // 内部属性 - 应该被检测
        internal string InternalProperty { get; set; }
        
        // 私有属性 - 应该被检测
        private string PrivateProperty { get; set; }
        
        // 公共方法 - 应该被检测
        public void PublicMethod(string param)
        {
        }
        
        // 受保护方法 - 应该被检测
        protected void ProtectedMethod()
        {
        }
        
        // 内部方法 - 应该被检测
        internal void InternalMethod()
        {
        }
        
        // 私有方法 - 应该被检测
        private void PrivateMethod()
        {
        }
        
        // 公共构造函数 - 应该被检测
        public PublicTestClass()
        {
        }
        
        // 私有构造函数 - 应该被检测
        private PublicTestClass(string param)
        {
        }
        
        // 公共事件 - 应该被检测
        public event EventHandler PublicEvent;
        
        // 受保护事件 - 应该被检测
        protected event EventHandler ProtectedEvent;
        
        // 私有事件 - 应该被检测
        private event EventHandler PrivateEvent;
    }
    
    // 内部类 - 应该被检测
    internal class InternalTestClass
    {
        // 内部类中的公共成员 - 应该被检测
        public void PublicMethodInInternalClass()
        {
        }
        
        // 内部类中的私有成员 - 应该被检测
        private void PrivateMethodInInternalClass()
        {
        }
    }
    
    // 私有类 - 应该被检测
    class PrivateTestClass
    {
        // 私有类中的公共成员 - 应该被检测
        public void PublicMethodInPrivateClass()
        {
        }
        
        // 私有类中的私有成员 - 应该被检测
        private void PrivateMethodInPrivateClass()
        {
        }
    }
} 