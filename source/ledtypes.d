private import std.format;
private import std.array;
private import std.string;
enum LedType
  {
   INTEGER,
   FLOAT,
   BOOLEAN,
   STRING,
   FUNCTION,
   OBJECT,
   NULL,
  }

interface Type {
  LedType               getType();
  Type delegate(Type[]) getMethod(string);
  string                toString();
}

class LedInt : Type {
public:
  int value;
  
  override string  toString() {
    return format("%d", value);
  }

  Type delegate(Type[]) getMethod(string) {
    return null;
  }
  
  this(int v) {
    value = v;
  }
  
  LedType getType() {
    return LedType.INTEGER;
  }
}

class LedFloat : Type {
public:
  float value;
  override string  toString() {
    return format("%f", value);
  }

  Type delegate(Type[]) getMethod(string) {
    return null;
  }
  
  this(float v) {
    value = v;
  }
  
  LedType getType() {
    return LedType.FLOAT;
  }
}

class LedString : Type {
public:
  string value;
  override string  toString() {
    return format("%s", value);
  }

  Type replace(Type[] args) {
    if (args.length != 3) {
      throw new Exception("string : replace method requires 3 arguments, (STRING, STRING, INT)");
    }

    auto oldStr = cast(LedString)(args[0]);
    auto newStr = cast(LedString)(args[1]);
    auto times  = cast(LedInt)(args[2]);

    if (oldStr is null || newStr is null || times is null) {
      throw new Exception("string : replace method requires 3 arguments : (STRING, STRING, INT), got : " ~
                          format("(%s, %s, %s)", args[0].getType(), args[1].getType(), args[2].getType()));
    }
    int i = 1;
    string temp = value;
    while (i <= times.value || times.value < 0) {
      string old = temp;
      temp = temp.replaceFirst(oldStr.value, newStr.value);
      if (temp == old) {
        break;
      }
      i++;
    }
    return new LedString(temp);
  }
  
  Type delegate(Type[]) getMethod(string method) {
    switch (method) {
    case "replace":
      return &this.replace;
    default : break;
    }
    return null;
  }
  
  this(string v) {
    value = v;
  }
  
  LedType getType() {
    return LedType.STRING;
  }
}

class LedBoolean : Type {
public:
  bool value;
  override string  toString() {
    return format("%s", value);
  }

  Type delegate(Type[]) getMethod(string) {
    return null;
  }
  
  this(bool v) {
    value = v;
  }
  
  LedType getType() {
    return LedType.BOOLEAN;
  }

}

class LedList : Type {
  Type[] value;
  
  this() {}

  override string  toString() {
    string ret = "[";
    for(int x = 0; x < value.length; x++) {
      ret ~= format("%s", value[x]);
      if (x < value.length - 1) {
        ret ~= ", ";
      }
    }
    ret ~= "]";
    return ret;
  }

  Type delegate(Type[]) getMethod(string) {
    return null;
  }
  
  LedType getType() {
    return LedType.NULL;
  }
}

class LedNull : Type {
  this() {}

  override string  toString() {
    return "null";
  }

  Type delegate(Type[]) getMethod(string) {
    return null;
  }
  
  LedType getType() {
    return LedType.NULL;
  }
}
