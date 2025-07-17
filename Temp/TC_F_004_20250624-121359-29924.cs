using System;

namespace TestNamespace
{
    // Class without any documentation
    public class TestClass
    {
        // Field without documentation
        public string TestField;
        
        // Property without documentation  
        public string TestProperty { get; set; }
        
        // Method without documentation
        public void TestMethod(string param1, int param2)
        {
        }
        
        // Generic method without documentation
        public T GenericMethod<T>(T input) where T : class
        {
            return input;
        }
        
        // Event without documentation
        public event Action TestEvent;
        
        // Event field without documentation
        public event Action<string> TestEventField;
        
        // Constructor without documentation
        public TestClass()
        {
        }
        
        // Destructor without documentation
        ~TestClass()
        {
        }
        
        // Operator without documentation
        public static TestClass operator +(TestClass left, TestClass right)
        {
            return new TestClass();
        }
        
        // Conversion operator without documentation
        public static implicit operator string(TestClass obj)
        {
            return obj.ToString();
        }
        
        // Indexer without documentation
        public string this[int index]
        {
            get { return ""; }
            set { }
        }
    }
    
    // Delegate without documentation
    public delegate void TestDelegate(string message);
    
    // Generic delegate without documentation
    public delegate T GenericDelegate<T>(T input);
    
    // Struct without documentation
    public struct TestStruct
    {
        public int Value;
    }
    
    // Interface without documentation
    public interface ITestInterface
    {
        void TestMethod();
    }
    
    // Enum without documentation
    public enum TestEnum
    {
        Value1,
        Value2
    }
} 