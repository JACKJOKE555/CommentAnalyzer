/// <summary>
/// 这是一个完全没有注释问题的测试类
/// </summary>
public class TestNoIssues
{
    /// <summary>
    /// 这是一个有完整注释的属性
    /// </summary>
    public string TestProperty { get; set; }

    /// <summary>
    /// 这是一个有完整注释的方法
    /// </summary>
    /// <param name="parameter">方法参数</param>
    /// <returns>返回值说明</returns>
    public string TestMethod(string parameter)
    {
        return parameter;
    }
} 