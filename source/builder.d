private import ast;
private import asttypes;
private import errors;
private import tokenizer;
private import std.string;
private import std.stdio;

AstType buildFrom(string[] tokens) {
  Ast ptree = new Ast();
  string lowpref = "+-";
  string highpref = "*/";
  string delims = "<>=+-*/";

  if( tokens.length < 1) {
    throw (new Exception("AST::Error : not enough tokens to be an expression"));
  }

  if (tokens[0].length > 2 && tokens[0][0] == '(' && tokens[0][$-1] == ')') {
    string parened = tokens[0][1..$-1];
    ptree.left = buildFrom((new Tokenizer(parened)).tokenize());
  } else {
    ptree.left = parseToken(tokens[0]);
  }

  if (ptree.left.getAstType() == LedAstType.INBUILT) {
    LedInbuiltToken x = cast(LedInbuiltToken)(ptree.left);
    switch (x.value) {
    case InbuiltToken.IF:
      return buildIfAst(tokens);
    case InbuiltToken.WHILE:
      return buildWhileAst(tokens);
    default:
      break;
    }
  }

  if (tokens.length % 2 != 0) {
    if (tokens[$-1] == ";")
      throw (new Exception("AST::Error : malformed expression" ~ format("%s",tokens)));
    else
      tokens ~= ";";
  }
  
  if (ptree.left.getAstType() == LedAstType.OPERATOR) {
    throw (new Exception("AST::Error : operator not expected"));
  }
  
  if (tokens[1] != ";" && !inOperatorList(tokens[1])) {
    throw (new Exception("AST::Error : operator expected" ~ format("%s", tokens)));
  }

  if (tokens[1] == ";") {
    return ptree.left;
  }
  
  ptree.operator = tokens[1];

  ptree.right = buildFrom(tokens[2..$]);

  if (ptree.right.getAstType() == LedAstType.EXPRESSION) {
    import std.stdio;
    if (find(highpref, ptree.operator) && find(lowpref, (cast(Ast)(ptree.right)).operator)) {
      Ast temp = cast(Ast)(ptree.right);
      ptree.right = temp.left;
      temp.left = ptree;
      return temp;
    }
  }

  return ptree;
}

AstType[] buildAstList(string[] tokens) {
  string[] subtokens = [];
  AstType[] asts = [];
  foreach(token; tokens) {
    subtokens ~= token;
    if (token == ";") {
      asts ~= buildFrom(subtokens);
      subtokens = [];
    }
  }
  if (subtokens.length > 0 && subtokens[$-1] != ";") {
    subtokens ~= ";";
    asts ~= buildFrom(subtokens);
  }

  return asts;
}

bool find(string s, string substr) {
  return (indexOf(s, substr) >= 0);
}

bool getFunctionParamsFromToken (string token, out string[] params) {
  if (token.length < 2) {
    return false;
  }

  if (token[0] != '(' || token[$-1] != ')') {
    return false;
  }
  
  return getCsvFromToken(token[1..$-1], params);
}

bool getCsvFromToken(string token, out string[] params) {
  if (token.strip() == "") {
    params = [];
    return true;
  }
  string csvparams = token;
	
  string[] splitted;
  string[] intokens = new Tokenizer(csvparams).tokenize();
  string temp;
  foreach (t; intokens) {
    if (t == ",") {
      if (temp != "") {
        splitted ~= temp;
        temp = "";
      }
      continue;
    }
    temp ~= t;
  }

  if (temp != "") {
    splitted ~= temp;
    temp = "";
  }

  for (int i  = 0; i < splitted.length; i++) {
    splitted[i] = splitted[i].strip();
  }
	
  params ~= splitted;
  
  return true;
}

string[] normalizeFunction(string token) {
  string[] temp = [];
  string rec = "";
  foreach(a; token) {
    if (a == '(') {
      temp ~= rec;
      rec = "";
    }
    rec ~= a;
  }
  temp ~= rec;
  return temp;
}

string[][] unBlockify(string[] tokens) {
  string[][] blocksotokens;
  string[] currentBlock;
  int endCount = 0;
  bool inBlock = false;
  bool inFunctionBlock = false;
  foreach (token; tokens) {
    if (inBlock) {
      if (token == "def" || token == "if" || token == "while" || token == "for") {
        endCount++;
      }
      currentBlock ~= token;
      if (token == "end") {
        endCount--;
      }
      if (endCount == 0) {
        if (currentBlock.length != 0) {
          blocksotokens ~= currentBlock;
          currentBlock = [];
        }
        inBlock = false;
      }
      continue;
    }

    if (token == "def" || token == "if" || token == "while" || token == "for") {
      inBlock = true;
      if (currentBlock.length != 0) {
        blocksotokens ~= currentBlock;
        currentBlock = [];
      }
      endCount++;
    }
    
    currentBlock ~= token;
    
  }

  if (currentBlock.length != 0) {
      blocksotokens ~= currentBlock;
  }
  
  return blocksotokens;
}

FunctionAst buildFunction(string[] tokens) {
  if (indexOf(tokens[1], "(") > 0) {
    tokens = tokens[0..1] ~ normalizeFunction(tokens[1]) ~ tokens[2..$];
  }

  if (tokens.length < 5) {
    throw new Exception("wrong type function construct");
  }
      
  AstType funcName = parseToken(tokens[1]);
  if (funcName.getAstType() != LedAstType.SYMBOL) {
    throw new Exception("wrong type function name construct, " ~ format(", got : %s", funcName.getAstType()));
  }
  string[] params;
  if (!getFunctionParamsFromToken(tokens[2], params)) {
    throw new Exception("wrong type function name construct, required a parameter list, got " ~ tokens[2]);
  }
      
  auto func = new FunctionAst((cast(LedSymbolToken)(funcName)).value, params);
  int bcount = 1;
  int i = 3;
  for (; i < tokens.length; i++) {
    if (tokens[i] == "if" || tokens[i] == "while" || tokens[i] == "for")
      bcount++;
    if (tokens[i] == "end") {
      bcount--;
    }
    if (bcount == 0) {
      break;
    }
  }
  
  foreach(block; unBlockify(tokens[3..i])) {
    if (block[0] == "if" || block[0] == "while" || block[0] == "for" || block[0] == "def"){
      func.bodyStatements ~= buildBlock(block);
    } else {
      func.bodyStatements ~= buildAstList(block);
    }
  }
  
  return func;
}

AstType buildIfAst(string[] tokens) {
  import std.format;
  if (tokens.length < 4) {
    throw (new Exception("AST::Error : not a valid if construct" ~ format(" %s", tokens)));
  }

  auto parsedCondition = parseToken(tokens[1]);
  if (parsedCondition.getAstType() != LedAstType.BOOLEAN &&
      parsedCondition.getAstType() != LedAstType.SYMBOL &&
      parsedCondition.getAstType() != LedAstType.EXPRESSION) {
    throw (new Exception("AST::Error : not a valid condition"));
  }
      
  int bcount = 1;
  int i = 2;
  for (; i < tokens.length; i++) {
    if (tokens[i] == "if" || tokens[i] == "while" || tokens[i] == "for")
      bcount++;
    if (tokens[i] == "end") {
      bcount--;
    }
    if (bcount == 0) {
      break;
    }
  }
  string[] successTokens;
  string[] failureTokens;
  int ifs = 2;
  bool isElse;
  string[] iftokens = tokens[2..i];
  for (int w = 0 ; w < iftokens.length; w++) {
    if (iftokens[w] == "if") {
      ifs+=2;
    }
    if (iftokens[w] == "else") {
      ifs--;
      if (ifs == 1) {
        isElse = true;
        continue;
      }
    }
    
    if (iftokens[w] == "end") {
      if (ifs % 2 == 0) {
        ifs-=1;
      }
      ifs-=1;
    }
    
    if (!isElse) {
      successTokens ~= iftokens[w];
      continue;
    }
    failureTokens ~= iftokens[w];
  }
  import std.stdio;
  AstType[] successAsts = [];
  AstType[] failureAsts = [];
  foreach(block; unBlockify(successTokens)) {
    if (block[0] == "if" || block[0] == "while" || block[0] == "for" || block[0] == "def"){
      successAsts ~= buildBlock(block);
    } else {
      successAsts ~= buildAstList(block);
    }
  }

  foreach(block; unBlockify(failureTokens)) {
    if (block[0] == "if" || block[0] == "while" || block[0] == "for" || block[0] == "def"){
      failureAsts ~= buildBlock(block);
    } else {
      failureAsts ~= buildAstList(block);
    }
  }
  
  return new IfAst(parsedCondition, successAsts, failureAsts);
}

AstType buildWhileAst(string[] tokens) {
  if (tokens.length < 4) {
    throw (new Exception("AST::Error : not a valid while construct"));
  }

  auto parsedCondition = parseToken(tokens[1]);
  if (parsedCondition.getAstType() != LedAstType.BOOLEAN &&
      parsedCondition.getAstType() != LedAstType.SYMBOL &&
      parsedCondition.getAstType() != LedAstType.EXPRESSION) {
    throw (new Exception("AST::Error : not a valid condition"));
  }
      
  int bcount = 1;
  int i = 2;
  for (; i < tokens.length; i++) {
    if (tokens[i] == "if" || tokens[i] == "while" || tokens[i] == "for" || tokens[i] == "def")
      bcount++;
    if (tokens[i] == "end") {
      bcount--;
    }
    if (bcount == 0) {
      break;
    }
  }
  
  string[] loopTokens = tokens[2..i];
  import std.stdio;
  AstType[] loopAst = [];
  foreach(block; unBlockify(loopTokens)) {
    if (block[0] == "if" || block[0] == "while" || block[0] == "for" || block[0] == "def"){
      loopAst ~= buildBlock(block);
    } else {
      loopAst ~= buildAstList(block);
    }
  }
  
  return new WhileAst(parsedCondition, loopAst);
}

AstType buildBlock(string[] block) {
  if (block.length < 1) {
    return new LedNullToken();
  }
  switch(block[0]) {
  case "if":
    return buildIfAst(block);
  case "while":
    return buildWhileAst(block);
  case "def":
    return buildFunction(block);
  default:break;
  }

  writeln("BuildFrom : def case");
  return buildFrom(block);
}
