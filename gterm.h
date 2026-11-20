function MaxX : integer;
begin
  Result := ScreenWidth - 1;
end;

function MaxY : integer;
begin
  Result := ScreenHeight - 1;
end;

function BottomLine : integer;
begin
  Result := TopLine + (MaxY - 1);
end;

function  BlockCopy : SizeInt; forward;
function  BlockDelete : SizeInt; forward;
procedure BlockClear; forward;
function  BlockInsert : SizeInt; forward;
function BlockMove : SizeInt; forward;
function  BlockValid : boolean; forward;
procedure ClrScr; forward;
function  CompareCursors(const A, B: tCursor): integer; forward;
function  CompareDirEntries(const A, B: tDirEntry): Integer; forward;
function  CursorMoveDown (delta : SizeInt) : boolean; overload; forward;
function  CursorMoveDownOne : boolean; overload; forward;
function  CursorMoveEnd : boolean; forward;
function  CursorMoveHome : boolean; forward;
function  CursorMoveLeft (delta : SizeInt) : boolean; forward;
function  CursorMoveLeftOne : boolean; forward;
function  CursorMoveRight (delta : SizeInt) : boolean; forward;
function  CursorMoveRightOne : boolean; forward;
function  CursorMoveUp (delta : SizeInt) : boolean; forward;
function  CursorMoveUpOne : boolean; forward;
procedure DoRedo; forward;
procedure DoUndo; forward;
procedure DrawBottomLine (Text : string); forward;
function  DrawBox(const Box : tRect) : boolean; forward;
procedure DrawScreen; forward;
procedure DrawStatusBar; forward;
function  EditDelete : boolean; forward;
function  FindNextMatch : boolean; forward;
procedure GetKCommandKey; forward;
procedure GetTCommandKey; forward;
procedure GetTerminalMode; forward;
procedure GetTheme; forward;
function  GetFilename (var aFilename: string) : boolean; forward;
procedure HandleKeyboard; forward;
function  Help : boolean; forward;
function  InBlock (aCursor : tCursor) : boolean; forward;
function  InputString(X1, X2, Y: Integer; var S: string): Boolean; forward;
function  LoadFile : boolean; forward;
function  NewFile : boolean; forward;
procedure PutCharAt (const YPos, X : integer; C : cardinal); forward;
procedure PutChar (X, Y : integer; C : cardinal); forward;
procedure PutString (X, Y : integer; s : string); forward;
function  QueryExit : boolean; forward;
procedure ReadDirectoryContents(const Path: string; out Entries: tDirArray); forward;
function  SearchReplace : boolean; forward;
function  SelectionBox(const Items: array of string; const Box: tRect; var Index: SizeInt): Boolean; forward;
function  SetBlockEnd : boolean; forward;
function  SetBlockStart : boolean; forward;
procedure ShowCursor; forward;
procedure SortDirectory(var Entries: tDirArray); forward;
procedure SwapCursors (var aCursor, bCursor : tCursor); forward;
procedure TranslateDirectoryContents(const Entries : tDirArray; out Lines: tStringArray); forward;
function  YesNoCancel : byte; forward;
function  YesOrNo : boolean; forward;
