using System.Threading.Tasks;

/// <summary>
/// TC_A_018_ConditionalCompilationComments —— 条件编译注释关联测试
/// </summary>
/// <remarks>
/// 功能: 测试条件编译环境下注释关联错误的问题
/// 架构层级: 测试用例
/// 模块: CommentAnalyzer测试
/// 依赖: 无
/// 扩展点: 可扩展为更多条件编译场景
/// 特性: 测试类
/// 重要逻辑: 验证悬空注释块的检测
/// 数据流: 源码→分析器→诊断报告
/// 使用示例: 用于验证多环境分析功能
/// </remarks>
namespace TestCases
{
    public class ConditionalCompilationTest
    {
        /// <summary>
        /// LoadFromResourcesAsync —— 这是一个悬空的注释块
        /// </summary>
        /// <remarks>
        /// 功能: 这个注释应该属于下面的LoadFromResourcesAsync方法，但由于条件编译可能被错误关联
        /// </remarks>
        /// <typeparam name="T">类型参数说明</typeparam>
        /// <param name="key">参数说明</param>
        /// <returns>返回值说明</returns>
#if ADDRESSABLES
        public async Task<T> LoadAddressableAsync<T>(string key) where T : class
        {
            // 这个方法"偷"了上面的注释
            await Task.Delay(1);
            return null;
        }
#endif

#if !ADDRESSABLES
        private async Task<T> LoadFromResourcesAsync<T>(string key) where T : class
        {
            // 这个方法实际上没有注释！
            await Task.Delay(1);
            return null;
        }
#endif

        /// <summary>
        /// 另一个测试方法，用于对比
        /// </summary>
        /// <remarks>
        /// 功能: 正常的注释，没有条件编译干扰
        /// </remarks>
        public void NormalMethod()
        {
            // 正常方法
        }
    }
} 