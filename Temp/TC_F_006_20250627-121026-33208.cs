using System;

namespace TestNamespace
{
    /// <summary>
    /// TestClass —— 测试类
    /// </summary>
/// <remarks>
/// 功能: [待补充]
/// </remarks>
    // 缺少 remarks 标签
    public class TestClass
    {
        /// <summary>
        /// TestMethod —— 测试方法
        /// </summary>
        // 缺少 param 和 returns 标签
        public string TestMethod(string input, int count)
        {
            return input + count;
        }
        
        /// <summary>
        /// GenericMethod —— 泛型方法
        /// </summary>
        // 缺少 typeparam, param, returns 标签
        public T GenericMethod<T>(T input) where T : class
        {
            return input;
        }
        
        /// <summary>
        /// TestProperty —— 测试属性
        /// </summary>
        // 缺少 remarks 标签
        public string TestProperty { get; set; }
        
        /// <summary>
        /// TestField —— 测试字段
        /// </summary>
        // 缺少 remarks 标签
        public string TestField;
        
        /// <summary>
        /// TestEvent —— 测试事件
        /// </summary>
        // 缺少 remarks 标签
        public event Action TestEvent;
    }
    
    /// <summary>
    /// TestDelegate —— 测试委托
    /// </summary>
/// <remarks>
/// 功能: [待补充]
/// </remarks>
    // 缺少 param 和 returns 标签
    public delegate string TestDelegate(string message, int code);
    
    /// <summary>
    /// GenericDelegate —— 泛型委托
    /// </summary>
/// <remarks>
/// 功能: [待补充]
/// </remarks>
    // 缺少 typeparam, param, returns 标签
    public delegate T GenericDelegate<T>(T input, string key);
} 