/// <summary>
/// TC_A_019_ConditionalCompilationDetection —— 条件编译检测测试
/// </summary>
/// <remarks>
/// 功能: 测试分析器对条件编译指令的检测能力
/// 架构层级: 测试用例
/// 模块: CommentAnalyzer测试
/// 依赖: 无
/// 扩展点: 可扩展为更多条件编译场景
/// 特性: 测试类
/// 重要逻辑: 验证条件编译告警的检测
/// 数据流: 源码→分析器→诊断报告
/// 使用示例: 用于验证条件编译检测功能
/// </remarks>
using System.Threading.Tasks;

namespace TestCases
{
    /// <summary>
    /// ConditionalCompilationTest —— 条件编译测试类
    /// </summary>
    /// <remarks>
    /// 功能: 包含多种条件编译指令的测试类
    /// 架构层级: 测试
    /// 模块: 测试模块
    /// 继承/实现关系: 无
    /// 依赖: 无
    /// 扩展点: 无
    /// 特性: 测试类
    /// 重要逻辑: 模拟真实项目中的条件编译场景
    /// 数据流: 测试数据→分析器→结果验证
    /// 使用示例: 用于验证条件编译检测和告警功能
    /// </remarks>
    public class ConditionalCompilationTest
    {
        /// <summary>
        /// TestField —— 测试字段
        /// </summary>
        /// <remarks>
        /// 功能: 用于测试的基础字段
        /// </remarks>
        public string TestField = "test";

#if UNITY_EDITOR
        /// <summary>
        /// EditorOnlyMethod —— 编辑器专用方法
        /// </summary>
        /// <remarks>
        /// 功能: 仅在Unity编辑器环境下可用的方法
        /// </remarks>
        public void EditorOnlyMethod()
        {
            // 编辑器专用代码
        }
#endif

#if ADDRESSABLES
        /// <summary>
        /// LoadAddressableAsync —— Addressable异步加载
        /// </summary>
        /// <remarks>
        /// 功能: 使用Addressable系统加载资源
        /// </remarks>
        /// <typeparam name="T">资源类型</typeparam>
        /// <param name="key">资源键值</param>
        /// <returns>加载的资源</returns>
        public async Task<T> LoadAddressableAsync<T>(string key) where T : class
        {
            await Task.Delay(1);
            return null;
        }
#else
        /// <summary>
        /// LoadFromResourcesAsync —— Resources异步加载
        /// </summary>
        /// <remarks>
        /// 功能: 使用Resources系统加载资源
        /// </remarks>
        /// <typeparam name="T">资源类型</typeparam>
        /// <param name="key">资源路径</param>
        /// <returns>加载的资源</returns>
        public async Task<T> LoadFromResourcesAsync<T>(string key) where T : class
        {
            await Task.Delay(1);
            return null;
        }
#endif

#if DEBUG
        /// <summary>
        /// DebugMethod —— 调试方法
        /// </summary>
        /// <remarks>
        /// 功能: 仅在调试模式下可用的方法
        /// </remarks>
        public void DebugMethod()
        {
            // 调试代码
        }
#elif RELEASE
        /// <summary>
        /// ReleaseMethod —— 发布方法
        /// </summary>
        /// <remarks>
        /// 功能: 仅在发布模式下可用的方法
        /// </remarks>
        public void ReleaseMethod()
        {
            // 发布代码
        }
#endif

        /// <summary>
        /// NormalMethod —— 普通方法
        /// </summary>
        /// <remarks>
        /// 功能: 不受条件编译影响的普通方法
        /// </remarks>
        public void NormalMethod()
        {
            // 普通代码
        }
    }
} 