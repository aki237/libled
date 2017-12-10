private import std.format;
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
  LedType getType();
  string  toString();
}

class LedInt : Type {
public:
  int value;
  
  override string  toString() {
    return format("%d", value);
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
  
  LedType getType() {
    return LedType.NULL;
  }
}

class LedNull : Type {
  this() {}

  override string  toString() {
    return "null";
  }
  
  LedType getType() {
    return LedType.NULL;
  }
}
