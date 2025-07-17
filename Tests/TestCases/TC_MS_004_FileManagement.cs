using System;
using System.IO;

namespace Dropleton.Tests.MainScriptFileManagement
{
    /// <summary>
    /// 测试类 - 用于验证主脚本的文件管理功能
    /// </summary>
    /// <remarks>
    /// 此类专门用于测试主入口脚本对以下功能的处理：
    /// - 临时项目文件的创建与清理
    /// - 日志文件的生成与管理
    /// - 文件系统异常的处理
    /// </remarks>
    public class TestFileManagementClass
    {
        public string TempFilePath;
        
        public void CreateTempFile(string path)
        {
            TempFilePath = path;
        }
        
        public void CleanupTempFile()
        {
            if (File.Exists(TempFilePath))
            {
                File.Delete(TempFilePath);
            }
        }
    }
    
    public struct TestFileStruct
    {
        public string FileName;
        public DateTime CreatedTime;
        
        public void InitializeFile(string name)
        {
            FileName = name;
            CreatedTime = DateTime.Now;
        }
    }
} 