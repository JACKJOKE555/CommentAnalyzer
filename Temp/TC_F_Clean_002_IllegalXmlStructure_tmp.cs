// TC_F_Clean_002_IllegalXmlStructure.cs
// 用于测试clean对非法/未闭合/嵌套XML注释、普通注释、块注释的处理

// 普通注释应保留
// 创建时间：2025-06-29

public class LegalXmlComment { }

public class UnclosedXmlComment { }

public class NestedXmlComment { }

public class IllegalTagXmlComment { }

// 普通注释
public class NormalComment { }

/* 块注释 */
public class BlockComment { }

// 空行测试

public class EmptyLineTest { } 