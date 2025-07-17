using System;

namespace TestNamespace
{
    // 测试用例：操作符和转换操作符注释检测
    // 这个文件包含各种操作符声明，用于测试分析器是否能正确检测操作符的注释问题

    public class OperatorTestClass
    {
        // 1. 完全没有注释的操作符重载 - 应该触发 PROJECT_MEMBER_NO_COMMENT_BLOCK
        public static OperatorTestClass operator +(OperatorTestClass left, OperatorTestClass right)
        {
            return new OperatorTestClass();
        }

        // 2. 有注释但缺少summary的操作符 - 应该触发 PROJECT_MEMBER_MISSING_SUMMARY
        /// <param name="left">左操作数</param>
        /// <param name="right">右操作数</param>
        /// <returns>运算结果</returns>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public static OperatorTestClass operator -(OperatorTestClass left, OperatorTestClass right)
        {
            return new OperatorTestClass();
        }

        // 3. 有注释但缺少remarks的操作符 - 应该触发 PROJECT_MEMBER_MISSING_REMARKS
        /// <summary>
        /// operator * —— [member职责简述]
        /// </summary>
        /// <param name="left">左操作数</param>
        /// <param name="right">右操作数</param>
        /// <returns>运算结果</returns>
        public static OperatorTestClass operator *(OperatorTestClass left, OperatorTestClass right)
        {
            return new OperatorTestClass();
        }

        // 4. 缺少参数注释的操作符 - 应该触发 PROJECT_MEMBER_MISSING_PARAM
        /// <summary>
        /// operator / —— [member职责简述]
        /// </summary>
        /// <param name="left">左操作数</param>
        /// <returns>运算结果</returns>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public static OperatorTestClass operator /(OperatorTestClass left, OperatorTestClass right)
        {
            return new OperatorTestClass();
        }

        // 5. 缺少返回值注释的操作符 - 应该触发 PROJECT_MEMBER_MISSING_RETURNS
        /// <summary>
        /// operator % —— [member职责简述]
        /// </summary>
        /// <param name="left">左操作数</param>
        /// <param name="right">右操作数</param>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public static OperatorTestClass operator %(OperatorTestClass left, OperatorTestClass right)
        {
            return new OperatorTestClass();
        }

        // 6. 完全没有注释的转换操作符 - 应该触发 PROJECT_MEMBER_NO_COMMENT_BLOCK
        public static implicit operator string(OperatorTestClass obj)
        {
            return obj.ToString();
        }

        // 7. 缺少summary的转换操作符 - 应该触发 PROJECT_MEMBER_MISSING_SUMMARY
        /// <param name="value">要转换的值</param>
        /// <returns>转换结果</returns>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public static explicit operator int(OperatorTestClass obj)
        {
            return 0;
        }

        // 8. 缺少remarks的转换操作符 - 应该触发 PROJECT_MEMBER_MISSING_REMARKS
        /// <summary>
        /// implicit operator bool —— [member职责简述]
        /// </summary>
        /// <param name="obj">要转换的对象</param>
        /// <returns>转换结果</returns>
        public static implicit operator bool(OperatorTestClass obj)
        {
            return obj != null;
        }

        // 9. 完全正确的操作符注释 - 不应该触发任何警告
        /// <summary>
        /// operator == —— [member职责简述]
        /// </summary>
        /// <param name="left">左操作数</param>
        /// <param name="right">右操作数</param>
        /// <returns>比较结果</returns>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public static bool operator ==(OperatorTestClass left, OperatorTestClass right)
        {
            return false;
        }

        // 10. 完全正确的转换操作符注释 - 不应该触发任何警告
        /// <summary>
        /// explicit operator double —— [member职责简述]
        /// </summary>
        /// <param name="obj">要转换的对象</param>
        /// <returns>转换结果</returns>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public static explicit operator double(OperatorTestClass obj)
        {
            return 0.0;
        }

        // 为了避免编译器警告，需要重载!=操作符
        public static bool operator !=(OperatorTestClass left, OperatorTestClass right)
        {
            return !(left == right);
        }

        public override bool Equals(object obj)
        {
            return base.Equals(obj);
        }

        public override int GetHashCode()
        {
            return base.GetHashCode();
        }
    }
} 