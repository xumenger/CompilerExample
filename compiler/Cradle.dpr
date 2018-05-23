program Cradle;

{$APPTYPE CONSOLE}

uses
  SysUtils;
  
{----------------------Declaration----------------------------}

{ Constant Declarations }
const
  TAB = ^I;
  CR = #13;
  LF = #10;

{ Variable Declarations }
var
  Look: Char;          //Lookahead Character
  LCount: Integer;     //Label Counter
  Token: string[16];


{--------------------Basic Function-------------------------}
{ Read New Character From Input Stream}
procedure GetChar;
begin
  Read(Look);
end;

{ Report an Error }
procedure Error(s: string);
begin
  Writeln;
  Writeln(^G, 'Error: ', s, '.');
end;

{ Report Error and Halt }
procedure Abort(s: string);
begin
  Error(s);
  Halt;
end;

{ Report What Was Expected }
procedure Expected(s: string);
begin
  Abort(s + ' Expected');
end;

{ Match a Specific Input Character }
procedure Match(x: Char);
begin
  if Look = x then GetChar()
  else Expected('''' + x + '''');
end;

{ Recognize an Alpha Character }
function IsAlpha(c: Char): Boolean;
begin
  IsAlpha := UpCase(c) in ['A'..'Z'];
end;

{ Recognize a Decimal Digit }
function IsDigit(c: Char): Boolean;
begin
  IsDigit := c in ['0'..'9'];
end;

{ Recognize an Alphanumeric Character }
function IsAlNum(c: Char): Boolean;
begin
  IsAlNum := IsAlpha(c) or IsDigit(c);
end;

{ Recognize an Addop }
function IsAddop(c: Char): Boolean;
begin
  IsAddop := (c in ['+', '-']);
end;

{ Recognize a Boolean Orop }
function IsOrop(c: Char): Boolean;
begin
  IsOrop := (c in ['|', '~']);
end;

{ Recognize a Relop }
function IsRelop(c: Char): Boolean;
begin
  IsRelop := (c in ['=', '#', '<', '>']);
end;

{ Recognize Any Operator }
function IsOp(c: Char): Boolean;
begin
  IsOp := (c in ['+', '-', '*', '/', '<', '>', ':', '='])
end;

{ Recognize White Space }
function IsWhite(c: Char): Boolean;
begin
  IsWhite := (c in [' ', TAB]);
end;

{ Recognize a Boolean Literal }
function IsBoolean(c: Char): Boolean;
begin
  IsBoolean := (UpCase(c) in ['T', 'F']);
end;

{ Skip Over Leading White Space }
procedure SkipWhite;
begin
  while IsWhite(Look) do
    GetChar();
end;

{ Get an Identifier }
function GetName: string;
var
  x: string[8];
begin
  x := '';
  if not IsAlpha(Look) then Expected('Name');
  while IsAlNum(Look) do begin
    x := x + UpCase(Look);
    GetChar();
  end;
  GetName := x;
end;

{ Get a Number }
function GetNum: string;
var
  x: string[16];
begin
  x := '';
  if not IsDigit(Look) then Expected('Integer');
  while IsDigit(Look) do begin
    x := x + Look;
    GetChar();
  end;
  GetNum := x;
end;

{ Get an Operatort }
function GetOp: string;
var
  x: string[1];
begin
  x := '';
  if not IsOp(Look) then Expected('Operator');
  x := x + Look;
  GetChar();
  GetOp := x;
end;

{ Get a Boolean Literal }
function GetBoolean: Boolean;
begin
  if not IsBoolean(Look) then Expected('Boolean Literal');
  GetBoolean := (UpCase(Look) = 'T');
  GetChar();
end;

{ Generate a Unique Label }
function NewLabel: string;
var
  S: string;
begin
  Str(LCount, S);
  NewLabel := 'L' + S;
  Inc(LCount);
end;

{ Post a Label to Output }
procedure PostLabel(L: string);
begin
  WriteLn(L, ':');
end;

{ Output a String with Tab }
procedure Emit(s: string);
begin
  Write(TAB, s);
end;

{ Output a String with Tab and CRLF }
procedure EmitLn(s: string);
begin
  Emit(s);
  Writeln;
end;

{ Skip a CRLF }
procedure Fin;
begin
  if Look = CR then GetChar();
  if Look = LF then GetChar();
end;

{---------------------Arithmetic Expression------------------}
procedure Expression; forward;

{ Parse and Translate an Identifier }
procedure Ident;
var
  Name: string;
begin
  Name := GetName();
  if Look = '(' then begin
    Match('(');
    Match(')');
    EmitLn('BSR ' + Name);
  end
  else
    EmitLn('MOVE ' + Name + '(PC),D0');
end;

procedure Factor;
begin
  if Look = '(' then begin
    Match('(');
    Expression();
    Match(')');
  end
  else if IsAlpha(Look) then
    Ident()
  else
    EmitLn('MOVE #' + GetNum + ',D0');
end;

{ Parse and Translate the First Math Factor }
procedure SignedFactor;
begin
  if Look = '+' then
    GetChar();
  if Look = '-' then begin
    GetChar();
    if IsDigit(Look) then
      EmitLn('MOVE #-' + GetNum() + ',D0')
    else begin
      Factor();
      EmitLn('NEG D0');
    end;
  end
  else
    Factor();
end;

{ Recognize and Translate a Multiply }
procedure Multiply;
begin
  Match('*');
  Factor();
  EmitLn('MULS (SP)+,D0');
end;

{ Recognize and Translate a Divide }
procedure Divide;
begin
  Match('/');
  Factor();
  EmitLn('MOVE (SP)+,D1');
  EmitLn('EXS.L D0');
  EmitLn('DIVS D1,D0');
end;

{ Parse and Translate a Math Term }
procedure Term;
begin
  SignedFactor();
  while Look in ['*', '/'] do begin
    EmitLn('MOVE D0,-(SP)');
    case Look of
      '*': Multiply();
      '/': Divide();
    end;
  end;
end;

{ Recognize and Translate Add }
procedure Add;
begin
  Match('+');
  Term();
  EmitLn('ADD (SP)+,D0');
end;

{ Recognize and Translate a Subtract }
procedure Subtract;
begin
  Match('-');
  Term();
  EmitLn('SUB (SP)+,D0');
  EmitLn('NEG D0');
end;

{ Parse and Translate a Math Expression }
procedure Expression;
begin
  Term();
  while IsAddop(Look) do begin
    EmitLn('MOVE D0,-(SP)');
    case Look of
      '+': Add();
      '-': Subtract();
    end;
  end;
end;

{-----------------------Bool Expression----------------------}

{ Recognize and Translate a Relational "Equals" }
procedure Equals;
begin
  Match('=');
  Expression();
  EmitLn('CMP (SP)+,D0');
  EmitLn('SEQ D0');
end;

{ Recognize and Translate a Relational "Not Equals" }
procedure NotEquals;
begin
  Match('#');
  Expression();
  EmitLn('CMP (SP)+,D0');
  EmitLn('SNE D0');
end;

{ Recognize and Translate a Relational "Less Than" }
procedure Less;
begin
  Match('<');
  Expression();
  EmitLn('CMP (SP)+,D0');
  EmitLn('SGE D0');
end;

{ Recognize and Translate a Relational "Greater Than" }
procedure Greater;
begin
  Match('>');
  Expression();
  EmitLn('CMP (SP)+,D0');
  EmitLn('SLE D0');
end;

{ Parse and Translate a Relation }
procedure Relation;
begin
  Expression();
  if IsRelop(Look) then begin
    EmitLn('MOVE D0,-(SP)');
    case Look of
      '=': Equals();
      '#': NotEquals();
      '<': Less();
      '>': Greater();
    end;
    EmitLn('TST D0');
  end;
end;

{ Parse and Translate a Boolean Factor }
procedure BoolFactor;
begin
  if IsBoolean(Look) then
    if GetBoolean() then
      EmitLn('MOVE #-1,D0')
    else
      EmitLn('CLR D0')
  else
    Relation();
end;

{ Parse and Translate a Boolean Factor with NOT }
procedure NotFactor;
begin
  if Look = '!' then begin
    Match('!');
    BoolFactor();
    EmitLn('EOR #-1,D0');
  end
  else
    BoolFactor();
end;

{ Parse and Translate a Boolean Term}
procedure BoolTerm;
begin
  NotFactor();
  while Look = '&' do begin
    EmitLn('MOVE D0,-(SP)');
    Match('&');
    NotFactor();
    EmitLn('AND (SP)+,D0');
  end;
end;

{Recoginze and Translate a Boolean OR}
procedure BoolOr;
begin
  Match('|');
  BoolTerm();
  EmitLn('OR (SP)+,D0');
end;

{ Recognize and Translate an Exclusive Or }
procedure BoolXor;
begin
  Match('~');
  BoolTerm();
  EmitLn('EOR (SP)+,D0');
end;

{ Parse and Translate a Boolean Expression }
procedure BoolExpression;
begin
  BoolTerm();
  while IsOrOp(Look) do begin
    EmitLn('MOVE D0,-(SP)');
    case Look of
      '|': BoolOr();
      '~': BoolXor();
    end;
  end;
end;

{-----------------------Logic Construct----------------------}

procedure Block(L: string); forward;

{ Parse and Translate an Assignment Statement }
procedure Assignment;
var
  Name: string;
begin
  Name := GetName();
  Match('=');
  BoolExpression();
  EmitLn('LEA ' + Name + '(PC),A0');
  EmitLn('MOVE D0,(A0)');
end;

{ Recognize and Translate an IF Construct }
procedure DoIf(L: string);
var
  L1, L2: string;
begin
  Match('i');
  BoolExpression();
  L1 := NewLabel();
  L2 := L1;
  EmitLn('BEQ ' + L1);
  Block(L);
  if Look = 'l' then begin
    Match('l');
    L2 := NewLabel();
    EmitLn('BRA ' + L2);
    PostLabel(L1);
    Block(L);
  end;
  Match('e');
  PostLabel(L2);
end;

{ Parse and Translate a WHILE Statement }
procedure DoWhile;
var
  L1, L2: string;
begin
  Match('w');
  L1 := NewLabel();
  L2 := NewLabel();
  PostLabel(L1);
  BoolExpression();
  EmitLn('BEQ ' + L2);
  Block(L2);
  Match('e');
  EmitLn('BRA ' + L1);
  PostLabel(L2);
end;

{ Parse and Translate a LOOP Statement }
procedure DoLoop;
var
  L1, L2: string;
begin
  Match('p');
  L1 := NewLabel();
  L2 := NewLabel();
  PostLabel(L1);
  Block(L2);
  Match('e');
  EmitLn('BRA ' + L1);
  PostLabel(L2);
end;

{ Parse and Translate a REPEAT Statement }
procedure DoRepeat;
var
  L1, L2: string;
begin
  Match('r');
  L1 := NewLabel();
  L2 := NewLabel();
  PostLabel(L1);
  Block(L2);
  Match('u');
  BoolExpression();
  EmitLn('BEQ ' + L1);
  PostLabel(L2);
end;

{ Parse and Translate a FOR Statement }
procedure DoFor;
var
  L1, L2: string;
  Name: string;
begin
  Match('f');
  L1 := NewLabel();
  L2 := NewLabel();
  Name := GetName();
  Match('=');
  Expression();
  EmitLn('SUB! #1,D0');
  EmitLn('LEA ' + Name + '(PC),A0');
  EmitLn('MOVE D0,(A0)');
  Expression();
  EmitLn('MOVE D0,-(SP)');
  PostLabel(L1);
  EmitLn('LEA ' + Name + '(PC),A0');
  EmitLn('MOVE (A0),D0');
  EmitLn('ADDQ #1,D0');
  EmitLn('MOVE D0,(A0)');
  EmitLn('CMP (SP),D0');
  EmitLn('BGT ' + L2);
  Block(L2);
  Match('e');
  EmitLn('BRA ' + L1);
  PostLabel(L2);
  EmitLn('ADDQ #2,SP');
end;

{ Parse and Translate a DO Statement }
procedure DoDo;
var
  L1, L2: string;
begin
  Match('d');
  L1 := NewLabel();
  L2 := NewLabel();
  Expression();
  EmitLn('SUBQ #1,D0');
  PostLabel(L1);
  EmitLn('MOVE D0,-(SP)');
  Block(L2);
  EmitLn('MOVE (SP)+,D0');
  EmitLn('DBRA D0,' + L1);
  EmitLn('SUBQ #2,SP');
  PostLabel(L2);
  EmitLn('ADDQ #2,SP');
end;

{ Recognize and Translate a BREAK }
procedure DoBreak(L: string);
begin
  Match('b');
  EmitLn('BRA ' + L);
end;

{ Recognize and Translate an "Other" }
procedure Other;
begin
  EmitLn(GetName());
end;

{ Recognize and Translate a Statement Block }
procedure Block(L: string);
begin
  while not (Look in ['e','l','u']) do begin
    Fin();
    case Look of
      'i': DoIf(L);
      'w': DoWhile();
      'p': DoLoop();
      'r': DoRepeat();
      'f': DoFor();
      'd': DoDo();
      'b': DoBreak(L);
    else
      Other();
    end;
    Fin();
  end;
end;

{ Parse and Translate a Program }
procedure DoProgram;
begin
  Block('');
  if Look <> 'e' then Expected('End');
  EmitLn('END');
end;

{ Initialize }
procedure Init;
begin
  LCount := 0;
  GetChar();
end;

{--------------------------Lexical Scanner----------------------}
{ Lexical Scanner }
function Scan: string;
begin
  while Look = CR do
    Fin();
    
  if IsAlpha(Look) then
    Scan := GetName()
  else if IsDigit(Look) then
    Scan := GetNum()
  else if IsOp(Look) then
    Scan := GetOp()
  else begin
    Scan := Look;
    GetChar();
  end;
  SkipWhite();
end;

{-------------------------Main Program--------------------------}
begin
  Init();
  repeat
    Token := Scan;
    Writeln(Token);
    if Token = CR then Fin();
  until Token = '.';
end.
