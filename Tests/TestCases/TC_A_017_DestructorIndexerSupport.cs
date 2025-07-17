using System;
using System.Collections.Generic;
using System.Linq;

namespace TestNamespace
{
    // 测试用例：析构函数和索引器注释检测
    // 这个文件包含各种析构函数和索引器声明，用于测试分析器是否能正确检测它们的注释问题

    public class DestructorIndexerTestClass
    {
        private Dictionary<string, object> _data = new Dictionary<string, object>();

        // 1. 完全没有注释的析构函数 - 应该触发 PROJECT_MEMBER_NO_COMMENT_BLOCK
        ~DestructorIndexerTestClass()
        {
            _data.Clear();
        }

        // 2. 完全没有注释的索引器 - 应该触发 PROJECT_MEMBER_NO_COMMENT_BLOCK
        public object this[string key]
        {
            get { return _data.ContainsKey(key) ? _data[key] : null; }
            set { _data[key] = value; }
        }

        // 3. 有注释但缺少summary的索引器 - 应该触发 PROJECT_MEMBER_MISSING_SUMMARY
        /// <param name="index">索引值</param>
        /// <returns>对应的值</returns>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public object this[int index]
        {
            get { return index < _data.Count ? _data.Values.ElementAt(index) : null; }
            set { /* 简化实现 */ }
        }

        // 4. 有注释但缺少remarks的索引器 - 应该触发 PROJECT_MEMBER_MISSING_REMARKS
        /// <summary>
        /// this[double] —— [member职责简述]
        /// </summary>
        /// <param name="key">键值</param>
        /// <returns>对应的值</returns>
        public object this[double key]
        {
            get { return _data.ContainsKey(key.ToString()) ? _data[key.ToString()] : null; }
            set { _data[key.ToString()] = value; }
        }

        // 5. 缺少参数注释的索引器 - 应该触发 PROJECT_MEMBER_MISSING_PARAM
        /// <summary>
        /// this[bool] —— [member职责简述]
        /// </summary>
        /// <returns>对应的值</returns>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public object this[bool key]
        {
            get { return _data.ContainsKey(key.ToString()) ? _data[key.ToString()] : null; }
            set { _data[key.ToString()] = value; }
        }

        // 6. 缺少返回值注释的索引器 - 应该触发 PROJECT_MEMBER_MISSING_RETURNS
        /// <summary>
        /// this[char] —— [member职责简述]
        /// </summary>
        /// <param name="key">键值</param>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public object this[char key]
        {
            get { return _data.ContainsKey(key.ToString()) ? _data[key.ToString()] : null; }
            set { _data[key.ToString()] = value; }
        }

        // 7. 完全正确的索引器注释 - 不应该触发任何警告
        /// <summary>
        /// this[byte] —— [member职责简述]
        /// </summary>
        /// <param name="key">键值</param>
        /// <returns>对应的值</returns>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        public object this[byte key]
        {
            get { return _data.ContainsKey(key.ToString()) ? _data[key.ToString()] : null; }
            set { _data[key.ToString()] = value; }
        }
    }

    public class AnotherTestClass
    {
        // 8. 有注释但缺少summary的析构函数 - 应该触发 PROJECT_MEMBER_MISSING_SUMMARY
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        ~AnotherTestClass()
        {
        }
    }

    public class ThirdTestClass
    {
        // 9. 有注释但缺少remarks的析构函数 - 应该触发 PROJECT_MEMBER_MISSING_REMARKS
        /// <summary>
        /// ~ThirdTestClass —— [member职责简述]
        /// </summary>
        ~ThirdTestClass()
        {
        }
    }

    public class FourthTestClass
    {
        // 10. 完全正确的析构函数注释 - 不应该触发任何警告
        /// <summary>
        /// ~FourthTestClass —— [member职责简述]
        /// </summary>
        /// <remarks>
        /// 功能: [待补充]
        /// </remarks>
        ~FourthTestClass()
        {
        }
    }
} 