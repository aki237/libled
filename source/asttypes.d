private import std.conv;
private import std.array;
private import std.string;
private import std.format;
private import builder;
private import tokenizer;

enum LedAstType
  {
   INTEGER,
   FLOATING,
   STRING,
   BOOLEAN,
   INBUILT,
   SYMBOL,
   OPERATOR,
   EXPRESSION,
   PARSE_ERROR,
   NULL
  }

enum InbuiltToken
  {
   BREAK,    ELSE,     SWITCH,
   CASE,     STRING,   FUNCTION,
   RETURN,   CONST,    FLOAT,
   CONTINUE, FOR,      NULL,
   IF,	      WHILE,    PUBLIC,
   PRIVATE,  CLASS,    BOOL
  }

interface AstType {
  LedAstType getAstType();
  string       getString();
}

class LedIntToken : AstType {
public:
  int value;

  this(int v) {
    this.value = v;
  }

  LedAstType getAstType() {
    return LedAstType.INTEGER;
  }

  string getString() {
    return to!string(value);
  }
}

class LedFloatingToken : AstType {
public:
  float value;

  this(float v) {
    this.value = v;
  }

  LedAstType getAstType() {
    return LedAstType.FLOATING;
  }

  string getString() {
    return to!string(value);
  }
}

class LedStringToken : AstType {
public:
  string value;

  this(string v) {
    this.value = v;
  }

  LedAstType getAstType() {
    return LedAstType.STRING;
  }

  string getString() {
    return value;
  }
}

class LedBooleanToken : AstType {
public:
  bool value;

  this (bool v) {
    this.value = v;
  }

  LedAstType getAstType() {
    return LedAstType.BOOLEAN;
  }

  string getString() {
    return to!string(value);
  }
}

class LedInbuiltToken : AstType {
public:
  InbuiltToken value;
  AstType      extra;
  
  this(InbuiltToken v) {
    value = v;
  }
  
  LedAstType getAstType() {
    return LedAstType.INBUILT;
  }

  string getString() {
    return format("\"<inbuilt>%s\"", value);
  }
}

class LedSymbolToken : AstType {
public:
  string value;

  this(string v) {
    value = v;
  }
  
  LedAstType getAstType() {
    return LedAstType.SYMBOL;
  }

  string getString() {
    return format("\"<symbol>%s\"", value);
  }
}

class LedOperatorToken : AstType {
public:
  string value;

  this(string v) {
    value = v;
  }
  
  LedAstType getAstType() {
    return LedAstType.OPERATOR;
  }

  string getString() {
    return format("%s", value);
  }
}

class LedNullToken : AstType {
public:
  LedAstType getAstType() {
    return LedAstType.NULL;
  }

  string getString() {
    return "NULL";
  }

}

AstType parseToken(string token) {
  if (token.length < 1) {
    return (new LedNullToken());
  }
  
  // check for integer
  try {
    int num;
    num = to!int(token);
    return new LedIntToken(num);
  } catch (Exception e) {}

  // Check for float
  try {
    float num;
    num = to!float(token);
    return new LedFloatingToken(num);
  } catch (Exception e) {}

  if (token.length >= 2 && token[0] == '"' && token[token.length - 1] == '"') {
    return new LedStringToken(token[1..$-1]);
  }

  if (token.length >= 3 && token[0] == '(' && token[$-1] == ')') {
    return buildFrom((new Tokenizer(token[1..$-1]~";")).tokenize());
  }
  
  if (token == "true" || token == "false") {
    if (token == "true") {
      return new LedBooleanToken(true);
    }
    return new LedBooleanToken(false);
  }

  string[] inbuilt_tokens = ["break",    "else",     "switch",
                             "case",     "string",   "def",
                             "return",   "const",    "float",
                             "continue", "for",      "null",
                             "if",       "while",    "public",
                             "private",  "class",    "bool"];

  if (find(inbuilt_tokens, token)) {
    return new LedInbuiltToken(cast(InbuiltToken)(indexIn(inbuilt_tokens, token)));
  }

  if (indexOf("<>=+-*/", token) > 0) {
    return new LedOperatorToken(token);
  }

  return new LedSymbolToken(token);
}

int indexIn(string[] arr, string element) {
  int index = -1;
  foreach(a; arr) {
    index++;
    if (a == element) {
      return index;
    }
  }
  return -1;
}

bool find(string[] arr, string element) {
  foreach(a; arr) {
    if (a == element) {
      return true;
    }
  }
  return false;
}
