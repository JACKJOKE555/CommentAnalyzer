using System;

namespace TestNamespace
{
    // 测试用例：委托类型注释检测
    // 这个文件包含各种委托声明，用于测试分析器是否能正确检测委托的注释问题

    // 1. 完全没有注释的委托 - 应该触发 PROJECT_TYPE_NO_COMMENT_BLOCK
    public delegate void TestDelegate();

    // 2. 有注释但缺少summary的委托 - 应该触发 PROJECT_TYPE_MISSING_SUMMARY  
    /// <remarks>
    /// 功能: [待补充]
    /// </remarks>
    public delegate int TestDelegateWithoutSummary(string input);

    // 3. 有注释但缺少remarks的委托 - 应该触发 PROJECT_TYPE_MISSING_REMARKS
    /// <summary>
    /// TestDelegateWithoutRemarks —— [delegate职责简述]
    /// </summary>
    public delegate bool TestDelegateWithoutRemarks(int value);

    // 4. 泛型委托，缺少typeparam注释 - 应该触发 PROJECT_MEMBER_MISSING_TYPEPARAM
    /// <summary>
    /// GenericDelegate —— [delegate职责简述]
    /// </summary>
    /// <remarks>
    /// 功能: [待补充]
    /// </remarks>
    /// <param name="input">输入参数</param>
    /// <returns>返回值</returns>
    public delegate T GenericDelegate<T>(string input);

    // 5. 有参数但缺少param注释的委托 - 应该触发 PROJECT_MEMBER_MISSING_PARAM
    /// <summary>
    /// DelegateWithoutParam —— [delegate职责简述]
    /// </summary>
    /// <remarks>
    /// 功能: [待补充]
    /// </remarks>
    /// <returns>返回值</returns>
    public delegate string DelegateWithoutParam(int value, bool flag);

    // 6. 有返回值但缺少returns注释的委托 - 应该触发 PROJECT_MEMBER_MISSING_RETURNS
    /// <summary>
    /// DelegateWithoutReturns —— [delegate职责简述]
    /// </summary>
    /// <remarks>
    /// 功能: [待补充]
    /// </remarks>
    /// <param name="input">输入参数</param>
    public delegate int DelegateWithoutReturns(string input);

    // 7. 完整注释的委托 - 不应该触发任何警告
    /// <summary>
    /// CompleteDelegate —— [delegate职责简述]
    /// </summary>
    /// <remarks>
    /// 功能: [待补充]
    /// 架构层级: [待补充]
    /// 模块: [待补充]
    /// 继承/实现关系: [待补充]
    /// 依赖: [待补充]
    /// 扩展点: [待补充]
    /// 特性: [待补充]
    /// 重要逻辑: [待补充]
    /// 数据流: [待补充]
    /// 使用示例: [待补充]
    /// </remarks>
    /// <typeparam name="T">类型参数说明</typeparam>
    /// <param name="input">输入参数</param>
    /// <param name="callback">回调函数</param>
    /// <returns>返回值说明</returns>
    public delegate T CompleteDelegate<T>(string input, Action<T> callback);
} 