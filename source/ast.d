module ast;

private import asttypes;
private import errors;
private import std.string;
private import std.stdio;

enum AstExpressionType
  {
   SIMPLE,
   FUNCTION,
   IF,
   FOR,
   WHILE
  }

interface AstExpression {
  AstExpressionType getExpressionType();
}

class Ast : AstType {
public:
  AstType left, right;
  string operator;

  this() {
    left = new LedNullToken();
    operator = "";
    right = new LedNullToken();
  }

  LedAstType getAstType() {
    return LedAstType.EXPRESSION;
  }

  string getString() {
    string ret = "{\"operator\" : \"";
    ret ~= operator;
    ret ~= "\", \"left\" : " ~ left.getString() ~ ",";
    ret ~= "\"right\" : " ~ right.getString() ~ "}";
    return ret;
  }

  AstExpressionType getExpressionType() {
    return AstExpressionType.SIMPLE;
  }
}

class FunctionAst : AstType {
public:
  string        functionName;
  string[]      params;
  AstType[]   bodyStatements;
  
  this(string name, string[] params) {
    this.functionName = name;
    this.params = params; 
  }

  LedAstType getAstType() {
    return LedAstType.EXPRESSION;
  }

  string getString() {
    return "\"<function>" ~ functionName ~ "\"";
  }

  AstExpressionType getExpressionType() {
    return AstExpressionType.FUNCTION;
  }
}

class IfAst : AstType {
public:
  AstType condition;
  AstType[] successClause;
  AstType[] failureClause;

  this(AstType booleval, AstType[] sc, AstType[] fc) {
    this.condition = booleval;
    this.successClause = sc;
    this.failureClause = fc;
  }

  LedAstType getAstType() {
    return LedAstType.EXPRESSION;
  }

  string getString() {
    return "\"<if>conditional\"";
  }

  AstExpressionType getExpressionType() {
    return AstExpressionType.IF;
  }
}

class WhileAst : AstType {
public:
  AstType condition;
  AstType[] bodyStatements;

  this(AstType booleval, AstType[] bodyStatements) {
    this.condition = booleval;
    this.bodyStatements = bodyStatements;
  }

  LedAstType getAstType() {
    return LedAstType.EXPRESSION;
  }

  string getString() {
    return "\"<while>loop\"";
  }

  AstExpressionType getExpressionType() {
    return AstExpressionType.WHILE;
  }
}

class ForAst : AstType {
public:
  AstType   iteratorStatement;
  AstType[] bodyStatements;

  this(AstType istmt, AstType[] bodyStatements) {
    this.iteratorStatement = istmt;
    this.bodyStatements = bodyStatements;
  }

  LedAstType getAstType() {
    return LedAstType.EXPRESSION;
  }

  string getString() {
    return "\"<for>loop\"";
  }

  AstExpressionType getExpressionType() {
    return AstExpressionType.FOR;
  }
}
