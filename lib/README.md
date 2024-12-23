# 核心库模块

包含 RaE 语言的ast模块，文件定义和脚本两部分的解释器模块，以及二进制格式工具库。

## RaE 语言规范

RaE (RaE) 是一个声明式的二进制文件描述语言，用于定义和解析复杂的二进制文件格式和协议。它的设计理念是：

- 声明式优于命令式
- 简洁性和表达力的平衡
- 强大的依赖关系表达
- 灵活的验证机制

### 基础结构

#### 文件定义

```
file IDENTIFIER {
    // 文件结构定义
}
```

#### 类型系统

```
基本类型:
- I8, I16, I32, I64    // 有符号整数
- U8, U16, U32, U64    // 无符号整数
- F32, F64             // 浮点数

特殊类型:
- STRING(encoding)      // 字符串
- BYTES                 // 字节序列
- BITFIELD             // 位域
- ARRAY<T>             // 数组
- ENUM                 // 枚举
```

#### 结构定义

```
// 结构体
struct IDENTIFIER {
    field_name : type [attributes] @ offset;
}

// 位域
bitfield IDENTIFIER {
    field1: 3;    // 3位
    field2: 5;    // 5位
}

// 枚举
enum IDENTIFIER : U8 {
    VALUE1 = 0x01,
    VALUE2 = 0x02
}
```

### 字段声明语法

#### 基本语法

```
name : type [attributes] @ offset;

位置指定:
@ 0x00              // 固定偏移
@ after(field)      // 相对偏移
@ align(8)          // 对齐偏移
@ offset(expr)      // 动态偏移
```

#### 字段属性

```
// 数据表示
endian = (little|big|dynamic)     // 字节序
encoding = (ascii|utf8|utf16|custom) // 字符串编码
radix = (hex|dec|oct|bin)        // 数值表示基数

// 内存布局
align = number                    // 对齐要求
padding = (none|zero|custom)      // 填充方式
pack = number                     // 压缩对齐

// 数组和重复
size = expression                 // 字段大小
count = expression               // 数组长度
stride = expression              // 数组元素间距

// 条件和验证
if = condition                    // 条件存在
validate = expression            // 验证规则
range = (min..max)               // 值范围
set = [value1, value2, ...]      // 有效值集合
```

### 高级特性

#### 条件结构

```
// 条件结构体
struct DataBlock if=(header.type == 0x01) {
    type : U8 @ 0x00;
    data : BYTES @ 0x01;
}

// 结构体变体
struct Packet {
    type : U8 @ 0x00;
    variant(type) {
        0x01 => { v1_data : U32 @ 0x01; }
        0x02 => { v2_data : U64 @ 0x01; }
    }
}
```

#### 模板和泛型

```
template<T> HeaderBlock {
    magic : U32 @ 0x00;
    length : U32 @ 0x04;
    data : T @ 0x08 size=length;
}
```

#### 递归结构

```
struct Node {
    value : U32 @ 0x00;
    next_offset : U32 @ 0x04;
    next : Node @ offset(next_offset) if=(next_offset != 0);
}
```

### 表达式系统

#### 内置函数

```
// 基础操作
size_of(type|field)        // 获取大小
offset_of(field)          // 获取偏移
align_to(value, align)    // 对齐计算
after(field)              // 后续偏移

// 数据验证
checksum(range, algorithm) // 校验和计算
hash(data, algorithm)      // 哈希计算
validate_pattern(data, pattern) // 模式验证

// 数据处理
lookup_table(index, table) // 查表操作
map_value(value, mapping)  // 值映射
find_pattern(data, pattern) // 模式查找
```

#### 路径引用

```
// 绝对路径
root.header.length

// 相对路径
parent.size
siblings.data_length

// 数组访问
array[0]
array[index_field]
```

#### 表达式和条件

```
// 比较操作
field == value
field != value
field > value
field < value

// 逻辑操作
condition1 && condition2
condition1 || condition2
!condition

// 范围检查
field in range(0x00..0xFF)
field in set(0x01, 0x02, 0x05)
```

### 完整示例

#### 简单文件格式

```
file SimpleFile {
    struct Header {
        magic : U32 @ 0x00 validate=(magic == 0x1234);
        version : U16 @ 0x04 validate=in_range(1..5);
        data_size : U32 @ 0x06;
    }
    
    struct DataSection {
        type : U8 @ 0x00;
        data : BYTES size=parent.parent.header.data_size @ 0x01
            padding=zero align=4;
    }
    
    header : Header @ 0x00;
    data : DataSection @ after(header);
}
```

```
file ImageFormat {
    struct Header {
        signature : BYTES size=4 @ 0x00 
            validate = (signature == [0x89, 0x50, 0x4E, 0x47]);
        
        width : U32 @ 0x04 endian=big 
            validate = (width > 0 && width <= 65535);
        
        height : U32 @ 0x08 endian=big
            validate = (height > 0 && height <= 65535);
        
        bit_depth : U8 @ 0x0C 
            validate = in_set(1, 2, 4, 8, 16);
        
        color_type : U8 @ 0x0D
            validate = in_set(0, 2, 3, 4, 6);
    }

    struct Chunk {
        length : U32 @ 0x00 endian=big;
        type : BYTES size=4 @ 0x04;
        data : BYTES size=length @ 0x08 
            padding=zero align=4;
        crc : U32 @ after(data) endian=big
            validate = (crc == checksum(
                concat(type, data), "crc32"
            ));
    }

    header : Header @ 0x00;
    chunks : ARRAY<Chunk> @ after(header)
        repeat = while(peek(U32) != 0) // 直到遇到结束标记
        validate = (last().type == "IEND");
}
```

#### 复杂协议包

```
file ProtocolPacket {
    enum PacketType : U8 {
        DATA = 0x01,
        CONTROL = 0x02,
        ERROR = 0xFF
    }
    
    struct Header {
        type : PacketType @ 0x00;
        length : U16 @ 0x01 endian=big;
        checksum : U16 @ 0x03 validate=(
            checksum == checksum(parent.payload, "crc16")
        );
    }
    
    struct DataPacket if=(header.type == PacketType.DATA) {
        sequence : U32 @ 0x00;
        data : BYTES size=(parent.header.length - 4) @ 0x04
            validate=validate_pattern(this, "data_pattern");
    }
    
    struct ControlPacket if=(header.type == PacketType.CONTROL) {
        command : U8 @ 0x00 validate=in_set(0x01, 0x02, 0x05);
        params : BYTES size=(parent.header.length - 1) @ 0x01;
    }
    
    struct ErrorPacket if=(header.type == PacketType.ERROR) {
        code : U16 @ 0x00;
        message : STRING(utf8) size=(parent.header.length - 2) @ 0x02;
    }
    
    header : Header @ 0x00;
    variant(header.type) {
        PacketType.DATA => payload : DataPacket @ after(header);
        PacketType.CONTROL => payload : ControlPacket @ after(header);
        PacketType.ERROR => payload : ErrorPacket @ after(header);
    }
}
```

#### 数据结构示例

```
file DataStructure {
    template<T> List {
        count : U32 @ 0x00;
        items : ARRAY<T> count=count @ 0x04 stride=size_of(T);
    }

    struct Point {
        x : F32 @ 0x00;
        y : F32 @ 0x04;
    }

    struct Data {
        header : U32 @ 0x00 validate=(header == 0x12345678);
        points : List<Point> @ 0x04;
    }

    data : Data @ 0x00;
}
```

### RaE-脚本部分

脚本部分语言的定义。

该部分用于执行对于RaE解析后的二进制文件的实际操作，并提供部分语言内置库函数来增强实际操作能力。

#### 文件模型声明与加载

```plaintext
file a { ... } // 参考上一部分

f1, f2 = a.load("file1", "file2");
f1.save("output1.bin");
```

#### 变量定义和数据访问

```plaintext
let var = expr;  // 定义一个变量并赋值
file1.a.b.c = 42;  // 修改字段c
file2.c.d.e[2] = 100;  // 修改数组中的元素
file2.header.type="${expr}";    // 修改该field为该字符模板解析后的内容
file2.c=a.struct1{
    field1: xxx,
    field2: bitfield1 {
        field1: 0b101, ...
    }...
}; // 利用file a {struct struct1{}} 中的定义的结构体来创建一个实际的数据体并赋值给file2的域c，需要保证类型一致
file1.[a,b,c.[d,e]]=file2.[a,b,c.[d,f]] // 树状赋值，注意的是每个域的类型必须一致
```

#### 流程控制

```plaintext
if (condition) {
    // block
} else { //optional
    // block
}

match (expr) {
    pattern1 -> { block1 }
    pattern2 -> { block2 }
    _ -> { block3 }
}

// for will call its {} with every item in return value of expr with alias of i
// return value can be [] or single item, then item will be [item]
for(let i = expr){
    expr    // variant i can be used in this scope
}
```

#### 函数系统

```plaintext
[].sum(func);
[].max(func);
[].map(func);
[].reduce(func)
[].filter(func);
echo("The value of var is: ${var}"); // 模板字符串"${item}"在程序何处都会被自动替换为变量值
let increment = (x) => x + 1;
let result = [a,b,c].map(increment);
let result = [a,b,c].map((x)=>{expr});
```

## binlib

二进制文件工具库。包含二进制文件/流读写，二进制数据序列化为基本类型，二进制校验和相关计算，二进制文件生成等功能。

### 二进制文件读写

各种粒度的读写和保存函数

### 序列化/反序列化

基本数据类型的序列化和反序列化

### 二进制运算库

## rae_engine

位运算，校验等函数

### 预处理

导入文件定义和外部so库

### 二进制序列化引擎

根据rae解析得到的ast和基础二进制库解析和创建文件

### RaE脚本执行引擎

执行RaE脚本代码，调用上面的库函数和解析得到的ast列表执行操作
