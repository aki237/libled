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

class Scope {
public:
  Type[string] mem;
  Type function(Type[])[string] dfunctions;
  FunctionAst[string] lfunctions;
  Scope global;

  this() {
    global = null;
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
    if (lt == LedType.STRING && rt == LedType.STRING) {
      return new LedBoolean(((cast(LedString)(a)).value > (cast(LedString)(b)).value));
    }
    float lnum, rnum;

    switch (a.getType()) {
    case LedType.INTEGER:
      lnum = float((cast(LedInt)(a)).value);
      break;
    case LedType.FLOAT:
      lnum = (cast(LedFloat)(a)).value;
      break;
    default:
      throw new Exception("LedEngineScope::ERROR : cannot compare in compatible types, " ~ format("%s %s", lt, rt));
    }

    switch (b.getType()) {
    case LedType.INTEGER:
      rnum = float((cast(LedInt)(b)).value);
      break;
    case LedType.FLOAT:
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

    bool isFloat = (lt == LedType.FLOAT || rt == LedType.FLOAT);
    float sum = 0;
    switch (lt) {
    case LedType.INTEGER:
      sum += (cast(LedInt)(a)).value;
      break;
    case LedType.FLOAT:
      sum += (cast(LedFloat)(a)).value;
      break;
    default:
      throw new Exception("LedEngineScope::ERROR : unable to add in compatible types : " ~ format("%s, %s", lt, rt));
    }

    switch (rt) {
    case LedType.INTEGER:
      if (reciprocal) {
        sum = sum / (cast(LedInt)(b)).value;
      } else {
        sum *= (cast(LedInt)(b)).value;
      }
      break;
    case LedType.FLOAT:
      if (reciprocal) {
        sum = sum / (cast(LedFloat)(b)).value;
      } else {
        sum *= (cast(LedFloat)(b)).value;
      }
      break;
    default:
      throw new Exception("LedEngineScope::ERROR : unable to add in compatible types : " ~ format("%s, %s", lt, rt));
    }

    if (isFloat) {
      return new LedFloat(sum);
    }
    return new LedInt(cast(int)(sum));
  }
  
  Type add(Type a, Type b, int factor) {
    auto lt = a.getType();
    auto rt = b.getType();

      

    if (lt == LedType.STRING && rt == LedType.STRING) {
      if (factor > 0) {
        return new LedString((cast(LedString)(a)).value ~ (cast(LedString)(b)).value);
      } else {
        throw new Exception("LedEngineScope::ERROR : can only add or subtract 2 numeric values");
      }
    }

    bool isFloat = (lt == LedType.FLOAT || rt == LedType.FLOAT);
    float sum = 0;
    switch (lt) {
    case LedType.INTEGER:
      sum += (cast(LedInt)(a)).value;
      break;
    case LedType.FLOAT:
      sum += (cast(LedFloat)(a)).value;
      break;
    default:
      throw new Exception("LedEngineScope::ERROR : unable to perform arithmetic in compatible types : " ~ format("%s, %s", lt, rt));
    }

    switch (rt) {
    case LedType.INTEGER:
      sum += factor*(cast(LedInt)(b)).value;
      break;
    case LedType.FLOAT:
      sum += factor*(cast(LedFloat)(b)).value;
      break;
    default:
      throw new Exception("LedEngineScope::ERROR : unable to perform arithmetic in compatible types : " ~ format("%s, %s", lt, rt));
    }

    if (isFloat) {
      return new LedFloat(sum);
    }
    return new LedInt(cast(int)(sum));
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
      /*
      Yet to implement the modulus.
      case "%":
        return;
      */
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
    if (conditionEval.getType() != LedType.BOOLEAN) {
      throw new Exception("LedEngineScope::ERROR : while expected an expression evaluating to a boolean value");
    }
    while((cast(LedBoolean)(conditionEval)).value) {
      foreach(exp; a.bodyStatements) {
        Eval(exp);
      }
      conditionEval = Eval(a.condition);
      if (conditionEval.getType() != LedType.BOOLEAN) {
        throw new Exception("LedEngineScope::ERROR : while expected an expression evaluating to a boolean value");
      }
    }
    return new LedNull();
  }
  
  Type EvalIfExpression(IfAst a) {
    Type conditionEval = Eval(a.condition);
    if (conditionEval.getType() != LedType.BOOLEAN)
      throw new Exception("LedEngineScope::ERROR : if expected an expression evaluating to a boolean value");

    bool evalValue = (cast(LedBoolean)(conditionEval)).value;

    if (evalValue) {
      Type evalRet;
      foreach(ax; a.successClause) {
        evalRet = Eval(ax);
      }
      return evalRet;
    }
    Type evalRet;
    foreach(ax; a.failureClause) {
      evalRet = Eval(ax);
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
    default: return new LedNull();
    }
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
  
  Type handleSymbol(string sym){
    string[] ss = tokenizeSymbol(sym);
    auto functionCall = regex("^[a-zA-Z_][a-zA-Z0-9]*\\(.*\\)$");
    auto listRep = regex("^\\[(\\s*.*,\\s*)+\\s*[[^,].*]\\s*\\]$");
    if (ss.length != 1) {
      throw new Exception("LedEngineScope::ERROR : method call not implemented yet. '" ~ sym ~ "'");
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

string[] tokenizeSymbol(string sym) {
  // TODO : tokenize and return instead of blindly splitting at every "."
  return sym.split(".");
}
