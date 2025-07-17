using System;
using System.Diagnostics;

namespace Dropleton.Tests.MainScriptComponentInteraction
{
    // 测试类 - 用于验证主脚本与外部组件的交互
    public class TestComponentInteractionClass
    {
        public string RoslynatorPath;
        public string XmlDocToolPath;
        
        public void SetToolPaths(string roslynatorPath, string xmlDocPath)
        {
            RoslynatorPath = roslynatorPath;
            XmlDocToolPath = xmlDocPath;
        }
        
        public bool ValidateToolExistence()
        {
            return System.IO.File.Exists(RoslynatorPath) && 
                   System.IO.File.Exists(XmlDocToolPath);
        }
        
        public Process StartAnalysis()
        {
            return new Process();
        }
    }
    
    // 测试枚举 - 工具类型
    public enum ToolType
    {
        Roslynator,
        XmlDocTool,
        Unknown
    }
    
    // 测试委托 - 工具回调
    public delegate void ToolCallback(string result, bool success);
} 