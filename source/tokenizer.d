module tokenizer;
private import std.array;
private import std.string;
private import std.conv;

class Tokenizer {
public:
  string expression;

  this(string s) {
    this.expression = s;
    this.ops = "`!%^&*+-={}|',/<>;";
  }
    
  string[] tokenize(bool incdot=false) {
    if (incdot) {
      this.ops ~= ".";
    }
    string token = "", previous = "";
    string[] tokens = [];
    bool in_quotes = false;
    bool in_paren = false;
    bool in_sparen = false;
    int parenCount = 0;
    int sparenCount = 0;
    bool isFunctionCall = false;
    bool inComments = false;
    
    for (int i = 0; i < this.expression.length; i++) {
      char element = this.expression[i];
      if (inComments) {
        if (element == '\n')
          inComments = false;
        continue;
      }
      switch (element) {
      case '#':
        if (in_quotes) {
          token ~= element;
          continue;
        }
        inComments = true;
        break;
      case ' ','\n','\r','\t':
        if (in_quotes || in_paren || in_sparen) {
          token ~= element;
          continue;
        }
        if (token != "") {
          tokens ~= token;
          previous = token;
          token = "";
        }
        break;
      case '"':
        in_quotes = !in_quotes;
        token ~= element;
        if (!in_quotes && !in_sparen) {
          if (indexOf(ops, element) > 0) {
            tokens ~= token;
            previous = token;
            token = "";
          }
        }
        break;
      case '[':
        if (!in_quotes && !in_paren) {
          in_sparen = true;
          sparenCount++;
          token ~= element;
        }
        break;
      case ']':
        if (!in_quotes && !in_paren) {
          sparenCount--;
          token ~= element;
          if (parenCount != 0) {
            continue;
          }
          in_sparen = false;
          tokens ~= token;
          previous = token;
          token = "";
        }
        break;
      case '(':
        if (!in_quotes && !in_sparen) {
          in_paren = true;
          if (indexOf(ops, previous) < 0 && token == "" && !isFound(["if", "for", "def", "while"], previous)) {
            isFunctionCall = true;
          }
          parenCount++;
          token ~= element;
        }
        break;
      case ')':
        if (!in_quotes && !in_sparen) {
          parenCount--;
          token ~= element;
          if (parenCount != 0) {
            continue;
          }
          in_paren = false;
          if (isFunctionCall) {
            tokens[$-1] ~= token;
            token = "";
            isFunctionCall = false;
            continue;
          }
          if (i+1 < this.expression.length && this.expression[i+1] == '.' && !incdot) {
            continue;
          }
          tokens ~= token;
          previous = token;
          token = "";
        }
        break;
      default:
        if (in_quotes || in_paren || in_sparen) {
          token ~= element;
          continue;
        }
        if (indexOf(ops, element) > 0) {
          if (token != "") {
            tokens ~= token;
            previous = token;
            token = "";
          }
          token ~= element;
          tokens ~= token;
          previous = token;
          token = "";
          continue;
        }
        token ~= element;
      }
    }
    if (token != "") {
      tokens ~= token;
      previous = token;
    }

    return normalizeTokens(tokens);
  }

private:
  string ops;

  /*
    This function is used to group the tokens that are supposed to be together.
   */
  string[] normalizeTokens(string[] tokens) {
    string[] norm;
    string current = "";
    string limit = "";
    for (int i = 0; i < tokens.length; i++) {
      string element = tokens[i];
      if (indexOf(ops, element) < 0) {
        if (current != "") {
          if ((current == "!") ||
              ((current == "-" || current == "+") &&
               (norm.length == 0 || inOperatorList(norm[$-1])))) {
            element = current ~ element;
          } else {
            norm ~= current;
          }
          current = "";
        }
        limit = "";
        norm ~= element;
        continue;
      }

      switch (limit ~ element) {
      case ">=-","<=-", "==-", "!=-", ">=+","<=+", "==+", "!=+", "&&!", "||!":
        if (i+1 >= tokens.length) {
          throw new Exception("Tokenizer::ERROR : unexpected operator '"
                              ~ element ~ "' after '" ~ limit ~"'");
        }
        tokens[i+1] = element ~ tokens[i+1];
        continue;
      default: break;
      }
      
      switch (current ~ element) {
      case ">=", "&&", "||", "<=", "==", "!=":
        limit = (current~element);
        norm ~= limit;
        current = "";
        break;
      case "=+", "=!", "=-", ">+",">-", "<-", "<+":
        norm ~= current;
        limit = "";
        if (i+1 >= tokens.length) {
          throw new Exception("Tokenizer::ERROR : unexpected operator '"
                              ~ element ~ "' after '" ~ current ~"'");
        }
        tokens[i+1] = element ~ tokens[i+1];
        current = "";
        break;
      default:
        if (current != "") {
          throw new Exception("Tokenizer::ERROR : unexpected operator '"
                              ~ element ~ "' after '" ~ current ~"'");
        }
        current = element;
      }
    }
    return norm;
  }
  
}

bool isFound (string[] list, string en) {
  foreach (each; list) {
    if (en == each)
      return true;
  }
  return false;
}

bool inOperatorList(string token) {
  // TODO : improve the list
  string[] oplist = ["+","-","*","/","==","!=",">=","<=","&&","||","%",">","<","="];

  foreach(op; oplist) {
    if (op == token) {
      return true;
    }
  }
  return false;
}
