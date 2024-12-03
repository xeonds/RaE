# **RaE: A Domain-Specific Language for Binary File Parsing and Construction**

## **Overview**

**RaE** is a declarative and imperative domain-specific language (DSL) designed for the manipulation, parsing, and construction of binary file formats. It allows users to describe complex file formats, such as ELF, PE, ZIP, and others, using a clear and structured scheme. With built-in functions for parsing, checksum validation, and data manipulation, **RaE** simplifies the task of reading, modifying, and writing binary files.

## **Features**
- **Declarative File Descriptions**: Define file structures, metadata, and blocks (reusable components).
- **Imperative Actions**: Execute custom actions on files, such as validation, iteration, and modification.
- **Built-in Functions**: Built-in utilities for common operations, including checksum calculations, file manipulation, and reading/writing binary data.
- **Modularity**: Reusable blocks and variables allow you to build flexible, complex file schemes.
- **Human-readable Syntax**: Easy-to-read syntax inspired by languages like `awk`, allowing users to define file structures and actions concisely.

## **Table of Contents**
- [Installation](#installation)
- [Usage](#usage)
- [Language Design](#language-design)
  - [File Structure](#file-structure)
  - [Blocks](#blocks)
  - [Variables and Expressions](#variables-and-expressions)
  - [Actions](#actions)
  - [Built-in Functions](#built-in-functions)
- [Examples](#examples)
- [Advanced Features](#advanced-features)
- [Contributing](#contributing)

## **Installation**

To use **RaE**, you need to install the interpreter (`rae`) that executes the scripts. This can be done via package managers or from the source.

### **From Source**
1. Clone the repository:
   ```bash
   git clone https://github.com/xeonds/RaE.git
   cd RaE
   ```

2. Build the interpreter:
   ```bash
   dune build
   ```

3. Install:
   ```bash
   dune install
   ```

### **From Package Manager**
On systems with a package manager, **RaE** can be installed directly (if available):

```bash
sudo apt-get install RaE
```

## **Usage**

### **Running a RaE Script**
There are two ways to use **RaE** to process binary files:

1. **Specify Scheme and Actions in a Script:**
   You can write a full script that describes the file structure and includes actions. This script is then executed on a binary file.

   ```bash
   rae myscript.RaE <binary_file>
   ```

2. **Use Awk-like Syntax:**
   Similar to how `awk` works, you can provide a scheme and actions directly from the command line. The scheme can either be inline or loaded from an external file.

   **Command Syntax**:
   ```bash
   rae "<scheme or import scheme> <optional actions>" <binary_file>
   ```

   - **`<scheme or import scheme>`**: A string that either contains the full file scheme or references an external scheme file to be loaded.
   - **`<optional actions>`**: The actions to execute on the file, written as a script or in-line.
   - **`<binary_file>`**: The binary file to be processed.

   **Example 1: Running a Scheme Inline**
   ```bash
   rae "file ELF { header { magic: u32 @ 0x0 == 0x7F454C46; } } echo 'Valid ELF file!'" example.elf
   ```

   **Example 2: Importing a Scheme and Running Actions**
   ```bash
   rae "import 'elf_scheme.rae'; echo 'ELF file parsed successfully!'" example.elf
   ```

---

## **Language Design**

### **File Structure**
The `file` block defines the structure of the binary file. It can contain nested blocks and metadata about the file.

**Syntax:**
```dsl
file <name> {
    <metadata>
    <field_name> {
        <field_type> @ <offset> [<condition>];
    }
    ...
}
```

#### **Example: ELF File Definition**
```dsl
file ELF {
    metadata {
        endian: little;
        alignment: 4;
    }

    header {
        magic: u32 @ 0x0 == 0x7F454C46;  # ELF magic number
        version: u8 @ 0x6;
        num_sections: u16 @ 0x30;
        checksum: u32 @ 0x34 = checksum(body, md5);  # MD5 checksum of body
    }

    body {
        sections: section[header.num_sections] @ 0x40;
    }
}
```

---

### **Blocks**
Blocks define reusable components of the file structure. They allow you to define common data structures that can be referenced multiple times, like sections or headers.

**Syntax:**
```dsl
block <name> {
    <field_name>: <type>;
    ...
}
```

#### **Example: Section Block**
```dsl
block section {
    name: string(16);
    type: u32;
    offset: u32;
    size: u32;
    data: blob(size) @ offset;
}
```

---

### **Variables and Expressions**
Variables can store dynamic values, constants, or computed results. They are defined using the `let` keyword and can be used across the script.

**Syntax:**
```dsl
let <variable_name> = <expression>;
```

#### **Example: Variable Declaration**
```dsl
let valid_magic = 0x7F454C46;
let section_start = header.num_sections * 0x40;
```

---

### **Actions**
Actions are the imperative part of the script, written at the root level (outside of any blocks or file definitions). They control how the file is processed, validated, and modified.

Actions include:
- Conditionals (`if`)
- Loops (`for`)
- File operations (`seek`, `read`, `write`)
- Print functions (`echo`)

**Syntax:**
```dsl
if (<condition>) {
    <action>;
}
```

#### **Example: Actions**
```dsl
# Check if the ELF file is valid
if (header.magic == valid_magic) {
    echo "Valid ELF file!";
    echo "Number of Sections: " + header.num_sections;
} else {
    echo "Invalid ELF file!";
}

# Iterate over sections and print details
for (section in body.sections) {
    echo "Section: " + section.name;
    echo "Type: " + section.type;
    echo "Size: " + section.size;
}

# Write the modified file
writefile("modified_elf_file");
```

---

## **Built-in Functions**

### **File Navigation and Inspection**
- **`sizeof(field_or_block)`**: Returns the size of a field or block.
- **`offsetof(field)`**: Returns the offset of a field in the file.
- **`seek(offset)`**: Moves the cursor to the specified offset in the file.
- **`read(offset, size)`**: Reads data from a specific offset.
- **`write(offset, data)`**: Writes data to a specified offset.

### **Checksum and Validation**
- **`checksum(region, algorithm)`**: Computes a checksum (e.g., MD5, CRC32) for a given region of data.
- **`is_valid(field)`**: Validates if a field matches the expected value or condition.

### **General Utility**
- **`echo(value)`**: Prints a value to the console.
- **`writefile(filename)`**: Saves the modified file to a new file.
- **`debug(message)`**: Prints debugging messages.

---

## **Examples**

### **Example 1: ELF File Inspection**
```dsl
#!/bin/rae

file ELF {
    metadata {
        endian: little;
    }
    header {
        magic: u32 @ 0x0 == 0x7F454C46;
        version: u8 @ 0x6;
        num_sections: u16 @ 0x30;
    }
    body {
        sections: section[header.num_sections] @ 0x40;
    }
}

block section {
    name: string(16);
    type: u32;
    offset: u32;
    size: u32;
}

let valid_magic = 0x7F454C46;

# Action to check magic number and list sections
if (header.magic == valid_magic) {
    echo "Valid ELF file!";
} else {
    echo "Invalid ELF file!";
}

for (section in body.sections) {
    echo "Section: " + section.name;
    echo "Type: " + section.type;
    echo "Size: " + section.size;
}
```

### **Example 2: Modifying an ELF File**
```dsl
#!/bin/rae

file ELF {
    metadata {
        endian: little;
    }
    header {
        magic: u32 @ 0x0 == 0x7F454C46;
        version: u8 @ 0x6;
    }
    body {
        sections: section[header.num_sections] @ 0x40;
    }
}

block section {
   

 name: string(16);
    type: u32;
    offset: u32;
    size: u32;
}

# Modify the header version
header.version = 2;

# Modify section data
body.sections[0].name = "new_section_name";

# Write modified ELF file
writefile("modified_elf_file");
```

---

## **Contributing**

We welcome contributions to **RaE**! If you'd like to contribute, feel free to fork the repository, submit issues, or create pull requests.

1. Fork the repository
2. Clone your fork: `git clone https://github.com/xeonds/RaE.git`
3. Create a new branch: `git checkout -b feature-branch`
4. Commit your changes
5. Push to your branch: `git push origin feature-branch`
6. Open a pull request!

---

## **License**

**RaE** is released under the GNU General Public License V3. See [LICENSE](LICENSE) for more details.
