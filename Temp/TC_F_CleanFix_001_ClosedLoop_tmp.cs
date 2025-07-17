// TC_F_CleanFix_001_ClosedLoop.cs
// 用于测试--fix --clean闭环，所有类型/成员均应先清理XML注释再批量补全

// 普通注释应被保留
// 创建时间：2025-06-29

public class CleanFixTestClass
{
        public int Field;
    // 普通成员注释
        public void Method() { }
}

public struct CleanFixTestStruct { }

public interface ICleanFixTestInterface { }

public enum CleanFixTestEnum { A, B }

public delegate void CleanFixTestDelegate(int x); 