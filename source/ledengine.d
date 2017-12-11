private import std.variant;
private import std.stdio;
private import std.format;
private import std.array;
private import std.regex;

private import asttypes;
private import tokenizer;
private import ast;
private import builder;
private import ledtypes;

enum state
  {
   GOON,
   CONTINUE,
   BREAK,
  };

class Scope {
public:
  Type[string] mem;
  Type function(Type[])[string] dfunctions;
  FunctionAst[string] lfunctions;
  Scope global;
  state[] loopStack;
  bool isReturned;
  Type retval;
  
  this() {
    global = null;
    retval = new LedNull();
  }

  Type Eval(string contents) {
    Tokenizer tk = new Tokenizer(contents);

    auto tokens = tk.tokenize();
    
    Type ret;

    
    auto blocks = unBlockify(tokens);
    for (int i = 0; i < blocks.length; i++) {
      string blocktype = blocks[i][0];
      if (blocktype == "for") {
        writeln("Not implemented : for, function");
        continue;
      }
      if (blocktype == "for" || blocktype == "def" || blocktype == "if" || blocktype == "while") {
        try {
          auto tree = buildBlock(blocks[i]);
          if (tree.getAstType() == LedAstType.EXPRESSION) {
            ret = Eval(tree);
          }
        } catch (Exception e) {
          writeln("Line 48 : ", e.msg);
          break;
        }
        continue;
      }

      try {
        auto astlist = buildAstList(blocks[i]);
        foreach (f; astlist) {
          ret = Eval(f);
          if (isReturned) {
            return retval;
          }
        }
      } catch (Exception e) {
        writeln(e.msg);
        break;
      }
    }
    return ret;
  }

  Type gtInEquality(Type a, Type b) {
    auto lt = a.getType();
    auto rt = b.getType();
    if (lt == LedString.type() && rt == LedString.type()) {
      return new LedBoolean(((cast(LedString)(a)).value > (cast(LedString)(b)).value));
    }
    float lnum, rnum;

    switch (a.getType()) {
    case LedInt.type():
      lnum = float((cast(LedInt)(a)).value);
      break;
    case LedFloat.type():
      lnum = (cast(LedFloat)(a)).value;
      break;
    default:
      throw new Exception("LedEngineScope::ERROR : cannot compare in compatible types, " ~ format("%s %s", lt, rt));
    }

    switch (b.getType()) {
    case LedInt.type():
      rnum = float((cast(LedInt)(b)).value);
      break;
    case LedFloat.type():
      rnum = (cast(LedFloat)(b)).value;
      break;
    default:
      throw new Exception("LedEngineScope::ERROR : cannot compare in compatible types, " ~ format("%s %s", lt, rt));
    }

    return new LedBoolean(lnum > rnum);
  }
  
  Type product(Type a, Type b, bool reciprocal) {
    auto lt = a.getType();
    auto rt = b.getType();

    switch (lt) {
    case LedInt.type():
      if (reciprocal)
        return cast(LedInt)(a) / b;
      return cast(LedInt)(a) * b;
    case LedFloat.type():
      if (reciprocal)
        return cast(LedFloat)(a) / b;
      return cast(LedFloat)(a) * b;
    default:
      throw new Exception("LedEngineScope::ERROR : unable to perform arithmetic in compatible types : " ~ format("%s, %s", lt, rt));
    }
  }

  Type modulo(Type a, Type b) {
    auto lt = a.getType();
    auto rt = b.getType();

    if ((lt != LedInt.type() && lt != LedFloat.type()) || (rt != LedInt.type() && rt != LedFloat.type())) {
      throw new Exception(format("LedEngineScope::ERROR : cannot perform modulus for incompatible types : (%s, %s)", lt, rt));
    }

    final switch (lt) {
    case LedInt.type():
      return cast(LedInt)(a) % b;
    case LedFloat.type():
      return cast(LedFloat)(a) % b;
    }
  }
  
  Type add(Type a, Type b, int factor) {
    auto lt = a.getType();
    auto rt = b.getType();

    if (lt == LedString.type() && rt == LedString.type()) {
      if (factor > 0) {
        return (cast(LedString)(a)) + (cast(LedString)(b));
      } else {
        throw new Exception("LedEngineScope::ERROR : can only add or subtract 2 numeric values");
      }
    }

    float sum = 0;
    switch (lt) {
    case LedInt.type():
      if (factor < 0)
        return (cast(LedInt)(a)) - b;
      else
        return (cast(LedInt)(a)) + b;
    case LedFloat.type():
      if (factor < 0)
        return (cast(LedFloat)(a)) - b;
      else
        return (cast(LedFloat)(a)) + b;
    default:
      throw new Exception("LedEngineScope::ERROR : unable to perform arithmetic in compatible types : " ~ format("%s, %s", lt, rt));
    }
  }

  Type EvalSimpleExpression(Ast a) {
    switch (a.operator) {
    case "+":
      return add(Eval(a.left), Eval(a.right),1);
    case "-":
      return add(Eval(a.left), Eval(a.right),-1);
    case "*":
      return product(Eval(a.left), Eval(a.right),false);
    case "/":
      return product(Eval(a.left), Eval(a.right),true);
    case "%":
      return modulo(Eval(a.left), Eval(a.right));
    case ">":
      return gtInEquality(Eval(a.left), Eval(a.right));
    case "<":
      return gtInEquality(Eval(a.right), Eval(a.left));
    case "=":
      if (a.left.getAstType() != LedAstType.SYMBOL) {
        throw new Exception("LedEngineScope::ERROR : cannot assign which is not a valid variable name");
      }
      auto varNameChecker = regex("^[a-zA-Z_][a-zA-Z0-9]*$");
      auto varName = (cast(LedSymbolToken)(a.left)).value;
      if (matchFirst(varName, varNameChecker).empty) {
        throw new Exception("LedEngineScope::ERROR : cannot assign which is not a valid variable name " ~ varName);
      }
      
      mem[varName] = Eval(a.right);
      return new LedNull();
    default:break;
    }
    throw new Exception("LedEngine::MYBAD : operator not implemented : '" ~ a.operator ~ "'");
  }

  Type EvalWhileExpression(WhileAst a) {
    Type conditionEval = Eval(a.condition);
    if (conditionEval.getType() != LedBoolean.type()) {
      throw new Exception("LedEngineScope::ERROR : while expected an expression evaluating to a boolean value");
    }

    loopStack ~= state.GOON;
    int loopId = cast(int)(loopStack.length) - 1;

    while((cast(LedBoolean)(conditionEval)).value && loopStack[loopId] != state.BREAK) {
      foreach (exp; a.bodyStatements) {
        Eval(exp);
        if (isReturned) {
          return retval;
        }
        if (loopStack[loopId] == state.CONTINUE) {
          loopStack[loopId] = state.GOON;
          break;
        }
      }
      conditionEval = Eval(a.condition);
      if (conditionEval.getType() != LedBoolean.type()) {
        throw new Exception("LedEngineScope::ERROR : while expected an expression evaluating to a boolean value");
      }
    }
    loopStack.popBack();
    return new LedNull();
  }
  
  Type EvalIfExpression(IfAst a) {
    Type conditionEval = Eval(a.condition);
    if (conditionEval.getType() != LedBoolean.type())
      throw new Exception("LedEngineScope::ERROR : if expected an expression evaluating to a boolean value");

    bool evalValue = (cast(LedBoolean)(conditionEval)).value;

    if (evalValue) {
      Type evalRet;
      foreach(ax; a.successClause) {
        evalRet = Eval(ax);
        if (isReturned) {
          return retval;
        }
      }
      return evalRet;
    }
    Type evalRet;
    foreach(ax; a.failureClause) {
      evalRet = Eval(ax);
      if (isReturned) {
        return retval;
      }
    }
    return evalRet;
  }

  Type EvalFunctionExpression(FunctionAst a) {
    lfunctions[a.functionName] = a;
    return new LedNull();
  }

  Type EvalForExpression(ForAst a) {
    return new LedNull();
  }
  
  Type EvalExpression(AstType exp) {
    auto simple = cast(Ast)(exp);
    if (simple !is null) {
      return EvalSimpleExpression(simple);
    }
    auto funcexp = cast(FunctionAst)(exp);
    if (funcexp !is null) {
      return EvalFunctionExpression(funcexp);
    }
    auto ifexp = cast(IfAst)(exp);
    if (ifexp !is null) {
      return EvalIfExpression(ifexp);
    }
    auto whileexp = cast(WhileAst)(exp);
    if (whileexp !is null) {
      return EvalWhileExpression(whileexp);
    }
    auto forexp = cast(ForAst)(exp);
    if (forexp !is null) {
      return EvalForExpression(forexp);
    }
    throw new Exception("LedEngineScope::ERROR : not a valid expression");
  }
  
  Type Eval(AstType a) {
    if (isReturned) {
      return retval;
    }
    switch (a.getAstType()) {
    case LedAstType.EXPRESSION:
      return EvalExpression(a);
    case LedAstType.INTEGER:
      return new LedInt((cast(LedIntToken)(a)).value);
    case LedAstType.NULL:
      return new LedNull();
    case LedAstType.FLOATING:
      return new LedFloat((cast(LedFloatingToken)(a)).value);
    case LedAstType.STRING:
      return new LedString((cast(LedStringToken)(a)).value);
    case LedAstType.BOOLEAN:
      return new LedBoolean((cast(LedBooleanToken)(a)).value);
    case LedAstType.SYMBOL:
      auto sym = (cast(LedSymbolToken)(a)).value;
      return handleSymbol(sym);
    case LedAstType.INBUILT:
      return handleInbuiltKeyword(cast(LedInbuiltToken)(a));
    default: return new LedNull();
    }
  }

  Type handleInbuiltKeyword(LedInbuiltToken a) {
    switch (a.value) {
    case InbuiltToken.CONTINUE:
      if(loopStack.length < 1) {
        throw new Exception("LedEngineScope::ERROR : cannot 'continue' when not in a loop");
      }
      loopStack[$-1] = state.CONTINUE;
      break;
    case InbuiltToken.BREAK:
      if(loopStack.length < 1) {
        throw new Exception("LedEngineScope::ERROR : cannot 'break' when not in a loop");
      }
      loopStack[$-1] = state.BREAK;
      break;
    case InbuiltToken.RETURN:
      retval = Eval(a.extra);
      isReturned = true;
      return retval;
    default: break;
    }
    return new LedNull();
  }
  
  Type parseArray(string sym) {
    LedList ll = new LedList();

    if (sym.length < 2) {
      // Not possible...
      throw new Exception("LedEngineScope::ERROR : not a valid array representation : '" ~ sym ~ "'");
    }

    string[] rawlist = [];
    
    if (!getCsvFromToken(sym[1..$-1], rawlist)) {
      throw new Exception("LedEngineScope::ERROR : not a valid array representation : '" ~ sym ~ "'");
    }
    
    foreach (relem; rawlist) {
      auto y = Eval(relem);
      if (y !is null) {
        ll.value ~= y;
      }
    }
    return ll;
  }

  Type handleMethodCall(Type klass, string[] parts) {
    if (parts.length < 1 || parts.length % 2 != 0 || parts[0] != ".")
      throw new Exception("LedEngineScope::ERROR : not a valid method call for "
                          ~ format("'%s' (%s) ", klass.getType(), klass) ~ ", call : " ~ format("%s", parts) 
                          );
    string funcName;
    Type[] params = getFunctionParams(parts[1], funcName);

    auto func = klass.getMethod(funcName);
    if (func is null) {
      throw new Exception("LedEngineScope::ERROR : method not defined for "
                          ~ format("'%s' (%s) ", klass.getType(), klass) ~ ", call : " ~ format("%s", parts) 
                          );
    }

    Type ret = func(params);
    
    if (parts.length > 2) {
      return handleMethodCall(ret, parts[2..$]);
    }
    return ret;
  }
  
  Type handleSymbol(string sym){
    string[] ss = (new Tokenizer(sym)).tokenize(true);
    auto functionCall = regex("^[a-zA-Z_][a-zA-Z0-9]*\\(.*\\)$");
    auto listRep = regex("^\\[(\\s*.*,\\s*)+\\s*[[^,].*]\\s*\\]$");
    // Handling method call
    if (ss.length > 1) {
      if (ss.length % 2  != 1) {
        throw new Exception("LedEngineScope::ERROR : not a valid method call");
      }
      auto klass = Eval(ss[0]);
      return handleMethodCall(klass, ss[1..$]);
    }
    
    if (ss[0].matchFirst(functionCall).empty) {
      if (!ss[0].matchFirst(listRep).empty) {
        return parseArray(ss[0]);
      }
      return handleMemVar(sym);
    }
    
    string funcName;
    Type[] params = getFunctionParams(sym, funcName);
    if ((funcName in dfunctions) !is null) {
      return dfunctions[funcName](params);
    }

    if ((funcName in lfunctions) !is null) {
      return runLedFunction(lfunctions[funcName],params);
    }

    if (global !is null) {
      if ((funcName in global.dfunctions) !is null) {
        return global.dfunctions[funcName](params);
      }

      if ((funcName in global.lfunctions) !is null) {
        return runLedFunction(global.lfunctions[funcName],params);
      }
    }
      
    throw new Exception("LedEngineScope::ERROR : function not found in scope : '" ~ sym ~ "'");
  }

  Type runLedFunction(FunctionAst as, Type[] params) {
    auto funcScope = NewSubScope();

    if (params.length != as.params.length) {
      throw new Exception(format("LedEngineScope::ERROR : not enough arguments for calling '%s', requires %d, got %d",
                                 as.functionName,
                                 as.params.length,
                                 params.length)
                          );
    }

    int index = -1;
    auto simpleVar = regex("^[a-zA-Z_][a-zA-Z0-9]*$");
    foreach (paramName; as.params) {
      index++;
      if (matchFirst(paramName, simpleVar).empty) {
        throw new Exception(format("LedEngineScope::ERROR : not a valid variable name : '%s' in function definition",
                                   paramName));
      }
      funcScope.mem[paramName] = params[index];
    }

    foreach(stmt; as.bodyStatements) {
      funcScope.Eval(stmt);
      if (funcScope.isReturned) {
        return funcScope.retval;
      }
    }
    
    return new LedNull();
  }
  
  Type handleMemVar(string sym) {
    auto simpleVar = regex("^[a-zA-Z_][a-zA-Z0-9]*$");
    if (matchFirst(sym, simpleVar).empty) {
      throw new Exception("LedEngineScope::ERROR : not a valid variable name : '" ~ sym ~ "'");
    }

    if (global !is null) {
      if ((sym in global.mem) !is null) {
        return global.mem[sym];
      }
    }

    if ((sym in mem) !is null) {
      return mem[sym];
    }
    
    throw new Exception("LedEngineScope::ERROR : cannot find '" ~ sym ~ "' in the scope.");
  }

  Type[] getFunctionParams(string sym, out string fnName) {
    int index = 0;
    foreach(x; sym) {
      if (x == '(')
        break;
      index++;
    }
    fnName = sym[0..index];
    string[] rawparams;
    if (!getFunctionParamsFromToken(sym[index..$], rawparams)) {
      throw new Exception("LedEngineScope::ERROR : not a valid function call : '" ~ sym ~ "'");
    }
    Type[] params;
    foreach(x; rawparams) {
      auto y = Eval(x);
      if (y is null) {
        params ~= new LedNull();
        continue;
      }
      params ~= y;
    }
    return params;
  }
  
  Scope NewSubScope() {
    auto ret = new Scope();
    if (this.global !is null) {
      ret.global = this.global;
    } else {
      ret.global = this;
    }
    return ret;
  }
}
