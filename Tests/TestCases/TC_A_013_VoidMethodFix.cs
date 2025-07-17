using System;

namespace TestCases
{
    /// <summary>
    /// 测试类用于验证void方法不被错误要求returns标签
    /// </summary>
    /// <remarks>
    /// <description>测试void方法的returns标签检查逻辑</description>
    /// <architecture>验证分析器正确识别void返回类型</architecture>
    /// <dependencies>无</dependencies>
    /// <extensions>可扩展测试其他返回类型</extensions>
    /// <examples>
    /// 这个类包含各种void方法，应该不会被要求添加returns标签
    /// </examples>
    /// </remarks>
    public class VoidMethodTestClass
    {
        /// <summary>
        /// 公共void方法 - 不应该要求returns标签
        /// </summary>
        /// <param name="message">消息参数</param>
        public void PublicVoidMethod(string message)
        {
            // 实现
        }
        
        /// <summary>
        /// 私有void方法 - 不应该要求returns标签
        /// </summary>
        private void PrivateVoidMethod()
        {
            // 实现
        }
        
        /// <summary>
        /// 受保护void方法 - 不应该要求returns标签
        /// </summary>
        /// <param name="value">值参数</param>
        protected void ProtectedVoidMethod(int value)
        {
            // 实现
        }
        
        /// <summary>
        /// 内部void方法 - 不应该要求returns标签
        /// </summary>
        internal void InternalVoidMethod()
        {
            // 实现
        }
        
        /// <summary>
        /// 静态void方法 - 不应该要求returns标签
        /// </summary>
        /// <param name="data">数据参数</param>
        public static void StaticVoidMethod(string data)
        {
            // 实现
        }
        
        /// <summary>
        /// 泛型void方法 - 不应该要求returns标签
        /// </summary>
        /// <typeparam name="T">泛型类型参数</typeparam>
        /// <param name="item">泛型参数</param>
        public void GenericVoidMethod<T>(T item)
        {
            // 实现
        }
        
        // 对比：有返回值的方法应该要求returns标签
        public string NonVoidMethod()
        {
            return "test";
        }
        
        public int AnotherNonVoidMethod(string input)
        {
            return input.Length;
        }
    }
} 