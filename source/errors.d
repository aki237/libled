private import asttypes;

interface error {
  string Error();
  bool   IsErr();
  bool   IsNull();
}

class AstError : error , AstType {
private:
  string errorString;
  bool isErr;
  
public:
  this() {
    isErr = false;
  }

  this(string estr) {
    errorString = estr;
    isErr = true;
  }

  string Error() {
    return errorString;
  }

  bool IsErr() {
    return isErr;
  }

  bool IsNull() {
    return !isErr;
  }

  LedAstType getAstType() {
    return LedAstType.PARSE_ERROR;
  }

  string getString() {
    if (isErr) {
      return "\"<error>" ~ errorString ~ "\"";
    }
    return "\"<error>null\"";
  }
}
