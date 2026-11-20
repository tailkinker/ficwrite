unit gdoc;

{$mode objfpc}{$H+}{$R+}

interface

uses
  dcommon;
  
const
  UndoCap      = 1024;               { history slots; must be a power of two }
  UndoMask     = UndoCap - 1;
  UndoMaxBytes = 1024 * 1024;        { cap on text held by the undo history }

type
  { Every change to the text is one of two primitives, and each is the
    inverse of the other.  #13 in Text stands for a paragraph boundary. }
  tEditKind = (ekInsert, ekDelete);

  pEdit = ^tEdit;
  tEdit = record
    Kind  : tEditKind;
    At    : TCursor;     { where the text was inserted / removed }
    After : TCursor;     { cursor once the edit has been (re)applied }
    Text  : string;
    Group : SizeInt;     { records sharing a Group undo as one step }
  end;

  tParagraph = class
  public
    Text: String;
    function TextWithCR : string;
    function Insert(const C: char; var Cursor: TCursor): Boolean;
    function Overwrite(const C: char; var Cursor: TCursor): Boolean;
    function DeleteChar(var Cursor: TCursor): Boolean;
    function DeleteChar(const Count: UInt32; var Cursor: TCursor): Boolean;
    function Split(const Position: SizeInt; out Remainder: tParagraph): Boolean;  
    function Search(var Cursor, BlockStart, BlockEnd: TCursor; const Term: string): Boolean;
    end;  
  
  tDocument = class
  private
    FParagraphs: array of tParagraph;
    FParagraphCount: SizeInt;
    FDirty : boolean;
    FFilename : string;

    { Undo history: one ring.  Undoable records sit in
      FHead-FUndoCount .. FHead-1, redoable ones in FHead .. FHead+FRedoCount-1
      (indices masked with UndoMask).  FHead only ever counts upwards. }
    FRing       : array[0..UndoCap - 1] of tEdit;
    FHead       : SizeInt;
    FUndoCount  : SizeInt;
    FRedoCount  : SizeInt;
    FBytes      : SizeInt;     { text held by the undoable records }
    FGroupDepth : SizeInt;
    FGroupId    : SizeInt;
    FRunOpen    : Boolean;     { the newest record may still absorb typing }
    FReplaying  : Boolean;     { Undo/Redo in progress: do not record }
    FSavePoint  : SizeInt;     { FHead value at the last save, -1 if lost }

    procedure Grow;
    procedure RecordEdit(Kind: tEditKind; const At: TCursor; const S: string);
    function  TryMerge(Kind: tEditKind; const At: TCursor; const S: string): Boolean;
    procedure DropOldest;
    procedure EvictOldest(const ProtectGroup: SizeInt);
    procedure TrimBytes;
    procedure RawInsert(const At: TCursor; const S: string);
    procedure RawDelete(const At: TCursor; const S: string);
    function  RawDeleteParagraph(const aParagraph: SizeInt): Boolean;
    function GetParagraph(const Index: SizeInt): tParagraph;
    procedure SetFileName (aFilename : string);
  public
    property Dirty : boolean read FDirty;
    property ParagraphCount: SizeInt read FParagraphCount;
    property Paragraph[Index: SizeInt]: tParagraph read GetParagraph;
    property Filename : string read FFileName write SetFileName;
    constructor Create;
    destructor Destroy; override;
    function ValidCursor(const Cursor: TCursor): Boolean;
    function Insert(const C: char; var Cursor: TCursor): Boolean;
    function Insert(const s: string; var Cursor: TCursor): Boolean;
    function Overwrite(const C: char; var Cursor: TCursor): Boolean;
    function DeleteChar(var Cursor: TCursor): Boolean;
    function DeleteChar(const Count: UInt32; var Cursor: TCursor): Boolean;
    function ParagraphBreak(var Cursor: TCursor): Boolean;
    function DeleteParagraph(const aParagraph: SizeInt): Boolean;  
    function CombineWithNext (var Cursor : tCursor) : boolean;
    function DeleteRange(const StartCursor, EndCursor: TCursor): SizeInt;
    function LoadFromFile(const aFileName: string): Boolean;
    function SaveToFile(const aFileName: string): Boolean;
    function Load : boolean;
    function Save : boolean;
    procedure MarkDirty;
    function Search(var Cursor, BlockStart, BlockEnd: TCursor; const Term: string): Boolean;
    { The text between two cursors, with #13 between paragraphs. }
    function ExtractRange(const StartCursor, EndCursor: TCursor): string;

    { Undo / redo.  Both move Cursor to where the change happened. }
    function Undo(var Cursor: TCursor): Boolean;
    function Redo(var Cursor: TCursor): Boolean;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    { Everything recorded between BeginGroup and EndGroup undoes as one
      step.  Calls nest.  Use try..finally. }
    procedure BeginGroup;
    procedure EndGroup;
    { Stop later typing being merged into the previous undo step.  Call it
      from cursor-movement keys. }
    procedure CloseUndoRun;
    procedure ClearUndo;
  end;

var
  Document : tDocument;

implementation

uses
  SysUtils, StrUtils, doption;

{ Where the cursor ends up after S is inserted at At. }
function CursorAfter(const At: TCursor; const S: string): TCursor;
var
  I: SizeInt;
begin
  Result := At;
  for I := 1 to Length(S) do
    if S[I] = #13 then begin
      Inc(Result.Paragraph);
      Result.Position := 1;
    end else
      Inc(Result.Position);
end;

// === tParagraph =============================================================

function tParagraph.TextWithCR : string;
begin
  Result := Text + PARAGRAPH_MARKER;
end;

function tParagraph.Insert(const C: Char; var Cursor: TCursor): Boolean;
begin
  Result := False;

  { Valid insertion positions are 1..Length(Text)+1. }
  if (Cursor.Position < 1) or
     (Cursor.Position > Length(Text) + 1) then
    Exit;

  System.Insert(C, Text, Cursor.Position);
  Inc(Cursor.Position);

  Result := True;
end;


function tParagraph.Overwrite(const C: Char;
  var Cursor: TCursor): Boolean;
begin
  Result := False;

  { Valid positions are 1..Length(Text)+1. }
  if (Cursor.Position < 1) or
     (Cursor.Position > Length(Text) + 1) then
    Exit;

  { At the end of the paragraph, overwrite becomes insert. }
  if Cursor.Position = Length(Text) + 1 then begin
    Result := Insert(C, Cursor);
    Exit;
  end;

  Text[Cursor.Position] := C;
  Inc(Cursor.Position);

  Result := True;
end;


function tParagraph.DeleteChar(var Cursor: TCursor): Boolean;
begin
  Result := DeleteChar(UInt32(1), Cursor);
end;


function tParagraph.DeleteChar(const Count: UInt32;
  var Cursor: TCursor): Boolean;
var
  ActualCount: UInt32;
begin
  Result := False;

  { Cursor may point immediately after the final character,
    but there is nothing to delete there. }
  if (Cursor.Position < 1) or
     (Cursor.Position > Length(Text)) then begin
    { Deleting zero characters is still a successful no-op,
      provided the cursor itself is valid. }
    if (Count = 0) and
       (Cursor.Position = Length(Text) + 1) then
      Result := True;
    Exit;
  end;

  if Count = 0 then begin
    Result := True;
    Exit;
  end;

  ActualCount := Count;

  { Don't delete beyond the end of the paragraph. }
  if ActualCount > UInt32(Length(Text) - Cursor.Position + 1) then
    ActualCount := UInt32(Length(Text) - Cursor.Position + 1);

  System.Delete(Text, Cursor.Position, ActualCount);

  Result := True;
end;


function tParagraph.Split(const Position: SizeInt; out Remainder: tParagraph): Boolean;
begin
  Result := False;
  Remainder := nil;

  { Position is the point at which the split occurs.
    1 = before the first character.
    Length(Text)+1 = after the final character. }
  if (Position < 1) or
     (Position > Length(Text) + 1) then
    Exit;

  Remainder := tParagraph.Create;

  { Copy everything from Position onward. }
  Remainder.Text :=
    Copy(Text, Position, Length(Text) - Position + 1);

  { Keep everything before Position. }
  Delete(Text, Position, Length(Text) - Position + 1);

  Result := True;
end;

function tParagraph.Search(var Cursor, BlockStart, BlockEnd: TCursor; const Term: string): Boolean;
var
  P: SizeInt;
begin
  Result := False;

  if Term = '' then
    Exit;

  if Cursor.Position < 1 then
    Exit;

  if Cursor.Position > Length(Text) then
    Exit;

  P := PosEx(UpperCase(Term), UpperCase(Text), Cursor.Position);
  if P = 0 then
    Exit;

  Cursor.Position := P;

  BlockStart := Cursor;
  BlockEnd := Cursor;
  Inc(BlockEnd.Position, Length(Term));

  Result := True;
end;

// === tDocument ==============================================================

constructor tDocument.Create;
begin
  inherited Create;
  SetLength(FParagraphs, 1);
  FParagraphs[0] := tParagraph.Create;
  FParagraphs[0].Text := '';
  FParagraphCount := 1;
  FDirty := FALSE;
  FHead := 0;
  FUndoCount := 0;
  FRedoCount := 0;
  FBytes := 0;
  FGroupDepth := 0;
  FGroupId := 0;
  FRunOpen := FALSE;
  FReplaying := FALSE;
  FSavePoint := 0;
end;

destructor tDocument.Destroy;
var
  index : SizeInt;
begin
  for index := 0 to (Length(FParagraphs) - 1) do
    FParagraphs[index].Free;
  SetLength (FParagraphs, 0);
  inherited Destroy;
end;

procedure tDocument.SetFileName (aFilename : string);
begin
  FFilename := aFilename;
end;

function tDocument.GetParagraph(const Index: SizeInt): tParagraph;
begin
  if (Index < 1) or (Index > FParagraphCount) then
    Result := nil
  else
    Result := FParagraphs[Index - 1];
end;

procedure tDocument.Grow;
var
  NewCapacity: SizeInt;
begin
  NewCapacity := Length(FParagraphs) * 2;

  if NewCapacity = 0 then
    NewCapacity := 1;

  SetLength(FParagraphs, NewCapacity);
  FDirty := TRUE;
end;

function tDocument.ValidCursor(const Cursor: TCursor): Boolean;
begin
  Result := False;
  if (Cursor.Paragraph < 1) or
     (Cursor.Paragraph > FParagraphCount) then
    Exit;
  if FParagraphs[Cursor.Paragraph - 1] = nil then
    Exit;
  Result := (Cursor.Position >= 1) and
    (Cursor.Position <= Length(FParagraphs[Cursor.Paragraph - 1].Text) + 1);
end;

function tDocument.Insert(const c: char; var Cursor: TCursor): Boolean;
var
  At: TCursor;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  At := Cursor;
  Result := FParagraphs[Cursor.Paragraph - 1].Insert(c, Cursor);
  if (Result = TRUE) then begin
    FDirty := TRUE;
    RecordEdit(ekInsert, At, c);
  end;
end;

function tDocument.Insert(const s: string; var Cursor: TCursor): Boolean;
var
  index : integer;
  Done  : integer;
  At    : TCursor;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  At := Cursor;
  Done := 0;
  for index := 1 to length (s) do begin
    Result := FParagraphs[Cursor.Paragraph - 1].Insert(s [index], Cursor);
    if (Result = FALSE) then
      Break;
    Inc(Done);
    end;
  if (Done > 0) then begin
    FDirty := TRUE;
    RecordEdit(ekInsert, At, Copy(s, 1, Done));
  end;
end;

function tDocument.Overwrite(const c: char; var Cursor: TCursor): Boolean;
var
  At  : TCursor;
  Old : string;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  At := Cursor;
  { Empty at the end of a paragraph, where overwrite becomes insert. }
  Old := Copy(FParagraphs[Cursor.Paragraph - 1].Text, Cursor.Position, 1);
  Result := FParagraphs[Cursor.Paragraph - 1].Overwrite(c, Cursor);
  if (Result = TRUE) then begin
    FDirty := TRUE;
    BeginGroup;
    try
      if Old <> '' then
        RecordEdit(ekDelete, At, Old);
      RecordEdit(ekInsert, At, c);
    finally
      EndGroup;
    end;
  end;
end;

function tDocument.DeleteChar(var Cursor: TCursor): Boolean;
var
  At      : TCursor;
  Removed : string;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  At := Cursor;
  Removed := Copy(FParagraphs[Cursor.Paragraph - 1].Text, Cursor.Position, 1);
  Result := FParagraphs[Cursor.Paragraph - 1].DeleteChar(Cursor);
  if (Result = TRUE) then begin
    FDirty := TRUE;
    RecordEdit(ekDelete, At, Removed);
  end;
end;

function tDocument.DeleteChar(const Count: UInt32; var Cursor: TCursor): Boolean;
var
  At      : TCursor;
  Removed : string;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  At := Cursor;
  { Copy clips at the end of the paragraph, as the deletion does. }
  Removed := Copy(FParagraphs[Cursor.Paragraph - 1].Text, Cursor.Position, SizeInt(Count));
  Result := FParagraphs[Cursor.Paragraph - 1].DeleteChar(Count, Cursor);
  if (Result = TRUE) then begin
    FDirty := TRUE;
    RecordEdit(ekDelete, At, Removed);
  end;
end;

function tDocument.ParagraphBreak(var Cursor: TCursor): Boolean;
var
  NewParagraph: tParagraph;
  NewIndex: SizeInt;
  I: SizeInt;
  At: TCursor;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  At := Cursor;

  { Make room for the new paragraph if necessary. }
  if FParagraphCount = Length(FParagraphs) then
    Grow;

  { The new paragraph goes immediately after the current one. }
  NewIndex := Cursor.Paragraph;

  { Split the current paragraph. }
  if not FParagraphs[Cursor.Paragraph - 1].Split(Cursor.Position, NewParagraph) then begin
    if (Assigned (NewParagraph)) then 
      NewParagraph.Destroy;
    Exit;
  end;
  
  { Move following paragraphs down by one. }
  for I := FParagraphCount - 1 downto NewIndex do
    FParagraphs[I + 1] := FParagraphs[I];

  { Insert the second half of the split paragraph. }
  FParagraphs[NewIndex] := NewParagraph;

  Inc(FParagraphCount);

  { Put the cursor at the beginning of the new paragraph. }
  Cursor.Paragraph := NewIndex + 1;
  Cursor.Position := 1;

  Result := True;
  FDirty := TRUE;
  RecordEdit(ekInsert, At, #13);
end;

{ Removes a paragraph from the array.  Does not record anything. }
function tDocument.RawDeleteParagraph(const aParagraph: SizeInt): Boolean;
var
  index: SizeInt;
begin
  Result := False;

  if FParagraphCount <= 1 then
    Exit;

  if (aParagraph < 0) or (aParagraph > FParagraphCount - 1) then
    Exit;

  FParagraphs[aParagraph].Free;

  { Move following paragraphs up. }
  if aParagraph < FParagraphCount - 1 then
    for index := aParagraph to FParagraphCount - 2 do
      FParagraphs[index] := FParagraphs[index + 1];

  { Clear the now-unused paragraph slot. }
  FParagraphs[FParagraphCount - 1] := nil;
  Dec(FParagraphCount);

  Result := True;
  FDirty := TRUE;
end;

{ aParagraph is zero-based, as it always was. }
function tDocument.DeleteParagraph(const aParagraph: SizeInt): Boolean;
var
  At: TCursor;
  S: string;
begin
  Result := False;

  if FParagraphCount <= 1 then
    Exit;

  if (aParagraph < 0) or (aParagraph > FParagraphCount - 1) then
    Exit;

  { Record the paragraph together with one boundary, as text. }
  if aParagraph < FParagraphCount - 1 then begin
    At.Paragraph := aParagraph + 1;
    At.Position := 1;
    S := FParagraphs[aParagraph].Text + #13;
  end else begin
    At.Paragraph := aParagraph;
    At.Position := Length(FParagraphs[aParagraph - 1].Text) + 1;
    S := #13 + FParagraphs[aParagraph].Text;
  end;

  Result := RawDeleteParagraph(aParagraph);
  if Result then
    RecordEdit(ekDelete, At, S);
end;

function tDocument.CombineWithNext(var Cursor: TCursor): Boolean;
var
  Current: SizeInt;
  Next: SizeInt;
  At: TCursor;
begin
  Result := False;

  if not ValidCursor(Cursor) then
    Exit;

  Current := Cursor.Paragraph - 1;
  Next := Current + 1;

  if Next >= FParagraphCount then
    Exit;

  { The boundary being removed sits at the end of the current paragraph. }
  At.Paragraph := Cursor.Paragraph;
  At.Position := Length(FParagraphs[Current].Text) + 1;

  FParagraphs[Current].Text :=
    FParagraphs[Current].Text +
    FParagraphs[Next].Text;

  RawDeleteParagraph(Next);

  Result := True;
  FDirty := TRUE;
  RecordEdit(ekDelete, At, #13);
end;

function tDocument.DeleteRange(const StartCursor,
  EndCursor: TCursor): SizeInt;
var
  StartParagraph: SizeInt;
  EndParagraph: SizeInt;
  StartPosition: SizeInt;
  EndPosition: SizeInt;
  StartText: String;
  EndText: String;
  Removed: String;
  I: SizeInt;
  Count: SizeInt;
begin
  Result := 0;

  if not ValidCursor(StartCursor) then
    Exit;

  if not ValidCursor(EndCursor) then
    Exit;

  { The range must proceed forward. }
  if (StartCursor.Paragraph > EndCursor.Paragraph) or
     ((StartCursor.Paragraph = EndCursor.Paragraph) and
      (StartCursor.Position > EndCursor.Position)) then
    Exit;

  { Keep the text, for undo, before it is destroyed. }
  if not FReplaying then
    Removed := ExtractRange(StartCursor, EndCursor);

  StartParagraph := StartCursor.Paragraph;
  EndParagraph := EndCursor.Paragraph;
  StartPosition := StartCursor.Position;
  EndPosition := EndCursor.Position;

  { Same paragraph. }
  if StartParagraph = EndParagraph then begin
    Count := EndPosition - StartPosition;

    if Count > 0 then begin
      System.Delete(
        FParagraphs[StartParagraph - 1].Text,
        StartPosition,
        Count
      );

      Result := Count;
      FDirty := True;
      RecordEdit(ekDelete, StartCursor, Removed);
    end;

    Exit;
  end;

  { Save the portions which survive the deletion. }
  StartText :=
    Copy(FParagraphs[StartParagraph - 1].Text,
         1, StartPosition - 1);

  EndText :=
    Copy(FParagraphs[EndParagraph - 1].Text,
         EndPosition,
         Length(FParagraphs[EndParagraph - 1].Text) -
         EndPosition + 1);

  { Count the deleted characters. }
  Result :=
    (Length(FParagraphs[StartParagraph - 1].Text) -
     Length(StartText)) +
    (Length(FParagraphs[EndParagraph - 1].Text) -
     Length(EndText));

  { Delete the paragraphs between the endpoints,
    including the original end paragraph. }
  for I := StartParagraph to EndParagraph - 1 do
    FParagraphs[I].Free;

  { The start paragraph survives and receives the tail
    of the end paragraph. }
  FParagraphs[StartParagraph - 1].Text :=
    StartText + EndText;

  { Shift the remaining paragraphs down. }
  for I := EndParagraph to FParagraphCount - 1 do
    FParagraphs[I - (EndParagraph - StartParagraph)] :=
      FParagraphs[I];

  { Clear the now-unused slots. }
  for I := FParagraphCount -
           (EndParagraph - StartParagraph)
           to FParagraphCount - 1 do
    FParagraphs[I] := nil;

  Dec(FParagraphCount, EndParagraph - StartParagraph);

  FDirty := True;
  RecordEdit(ekDelete, StartCursor, Removed);
end;

function tDocument.LoadFromFile(const aFileName: string): Boolean;
var
  F: File;
  FileSize: Int64;
  Data: String;
  BytesRead: Integer;

  P: SizeInt;
  LineStart: SizeInt;

  NewParagraphs: array of tParagraph;
  NewCount: SizeInt;
  NewCapacity: SizeInt;

  I: SizeInt;
  CurrentParagraph: tParagraph;

  Norm: String; 
  N: SizeInt;

  { Single LFs inside a paragraph are just soft wraps in the file:
    turn them into spaces. Stray LFs left at either end (from three or
    more in a row) are discarded. }
  function CleanText(const S: String): String;
  var
    First, Last, K: SizeInt;
  begin
    First := 1;
    Last := Length(S);

    while (First <= Last) and (S[First] = #10) do Inc(First);
    while (Last >= First) and (S[Last] = #10) do Dec(Last);

    Result := Copy(S, First, Last - First + 1);

    for K := 1 to Length(Result) do
      if Result[K] = #10 then Result[K] := ' ';
  end;
  
  procedure AddParagraph(const S: String);
  begin
    if NewCount = NewCapacity then begin
      if NewCapacity = 0 then
        NewCapacity := 1
      else
        NewCapacity := NewCapacity * 2;

      SetLength(NewParagraphs, NewCapacity);
    end;

    CurrentParagraph := tParagraph.Create;
    CurrentParagraph.Text := S;

    NewParagraphs[NewCount] := CurrentParagraph;
    Inc(NewCount);
  end;

begin
  Result := False;

  { Read the complete file as raw bytes. }
  AssignFile(F, aFileName);

  {$I-}
  Reset(F, 1);

  if IOResult <> 0 then begin
    {$I+}
    Exit;
  end;

  FileSize := System.FileSize(F);

  if FileSize < 0 then begin
    CloseFile(F);
    {$I+}
    Exit;
  end;

  if FileSize > MaxInt then begin
    CloseFile(F);
    {$I+}
    Exit;
  end;

  SetLength(Data, SizeInt(FileSize));

  if FileSize > 0 then begin
    BlockRead(F, Data[1], Length(Data), BytesRead);

    if BytesRead <> Length(Data) then begin
      CloseFile(F);
      {$I+}
      Exit;
    end;
  end;

  CloseFile(F);
  {$I+}

  { Build the new paragraph array. }
 NewCount := 0;
  NewCapacity := 0;
  SetLength(NewParagraphs, 0);

  { Normalize line endings: CRLF and bare CR both become LF. }
  SetLength(Norm, Length(Data));
  N := 0;
  P := 1;

  while P <= Length(Data) do begin
    Inc(N);

    if Data[P] = #13 then begin
      Norm[N] := #10;
      if (P < Length(Data)) and (Data[P + 1] = #10) then
        Inc(P);
    end
    else
      Norm[N] := Data[P];

    Inc(P);
  end;

  SetLength(Norm, N);

  { Split on a blank line (two consecutive LFs). }
  LineStart := 1;
  P := 1;

  while P < Length(Norm) do begin
    if (Norm[P] = #10) and (Norm[P + 1] = #10) then begin
      AddParagraph(CleanText(Copy(Norm, LineStart, P - LineStart)));
      Inc(P, 2);
      LineStart := P;
    end
    else
      Inc(P);
  end;

  { The text after the last separator is always a paragraph. This also
    covers an empty file, so the "at least one paragraph" rule is
    satisfied automatically. }
  AddParagraph(CleanText(Copy(Norm, LineStart, MaxInt)));
  
  { Everything succeeded. Replace the existing document. }
  for I := 0 to FParagraphCount - 1 do
    FParagraphs[I].Free;

  SetLength(FParagraphs, Length(NewParagraphs));

  for I := 0 to NewCount - 1 do
    FParagraphs[I] := NewParagraphs[I];

  FParagraphCount := NewCount;

  { Ownership has been transferred to the document. }
  for I := 0 to NewCount - 1 do
    NewParagraphs[I] := nil;

  SetLength(NewParagraphs, 0);

  { A freshly loaded document has no history. }
  ClearUndo;

  Result := True;
  FDirty := FALSE;
  FSavePoint := FHead;
  FFilename := aFilename;
end;

function tDocument.SaveToFile(const aFileName: string): Boolean;
var
  F: File;
  I: SizeInt;
  BytesWritten: Integer;
  LineEnding: String;
begin
  Result := False;
  LineEnding := #10#10;

  AssignFile(F, aFileName);

  {$I-}
  Rewrite(F, 1);

  if IOResult <> 0 then begin
    {$I+}
    Exit;
  end;

  for I := 0 to FParagraphCount - 1 do begin

    if Length(FParagraphs[I].Text) > 0 then begin
      BlockWrite(
        F,
        FParagraphs[I].Text[1],
        Length(FParagraphs[I].Text),
        BytesWritten
      );

      if BytesWritten <> Length(FParagraphs[I].Text) then begin
        CloseFile(F);
        {$I+}
        Exit;
      end;
    end;

    { Separate paragraphs with a blank line (two LFs), but do not add
      a final separator after the last paragraph. }
    if I < FParagraphCount - 1 then begin
      BlockWrite(
        F,
        LineEnding[1],
        Length(LineEnding),
        BytesWritten
      );

      if BytesWritten <> Length(LineEnding) then begin
        CloseFile(F);
        {$I+}
        Exit;
      end;
    end;
  end;

  CloseFile(F);

  if IOResult <> 0 then begin
    {$I+}
    Exit;
  end;

  {$I+}

  Result := True;
  FDirty := FALSE;
  FSavePoint := FHead;     { this history position is what is on disk }
  FRunOpen := FALSE;       { ...so later typing must not merge into it }
end;

function tDocument.Load : boolean;
begin
  Result := FALSE;
  if (FFilename <> '') then
    Result := LoadFromFile (FFilename);
end;

function tDocument.Save : boolean;
begin
  Result := FALSE;
  if (FFilename <> '') then
    Result := SaveToFile (FFilename);
end;

procedure tDocument.MarkDirty;
begin
  FDirty := TRUE
end;

function tDocument.Search(var Cursor, BlockStart, BlockEnd: TCursor; const Term: string): Boolean;
var
  P: SizeInt;
  SearchCursor: TCursor;
begin
  Result := False;

  if Term = '' then
    Exit;

  if not ValidCursor(Cursor) then
    Exit;

  SearchCursor := Cursor;

  for P := Cursor.Paragraph to FParagraphCount do
  begin
    SearchCursor.Paragraph := P;

    if P <> Cursor.Paragraph then
      SearchCursor.Position := 1;

    if FParagraphs[P - 1].Search(SearchCursor, BlockStart, BlockEnd, Term) then
    begin
      Cursor := SearchCursor;
      Result := True;
      Exit;
    end;
  end;
end;


// === undo / redo ============================================================

function tDocument.ExtractRange(const StartCursor,
  EndCursor: TCursor): string;
var
  P, Lo, Hi, Total, Offset: SizeInt;

  procedure RangeOf(const Para: SizeInt);
  begin
    if Para = StartCursor.Paragraph then
      Lo := StartCursor.Position
    else
      Lo := 1;
    if Para = EndCursor.Paragraph then
      Hi := EndCursor.Position - 1
    else
      Hi := Length(FParagraphs[Para - 1].Text);
  end;

begin
  Result := '';

  if not ValidCursor(StartCursor) then Exit;
  if not ValidCursor(EndCursor) then Exit;

  { The range must proceed forward. }
  if (StartCursor.Paragraph > EndCursor.Paragraph) or
     ((StartCursor.Paragraph = EndCursor.Paragraph) and
      (StartCursor.Position > EndCursor.Position)) then
    Exit;

  { Measure first, so a large range is built in one allocation. }
  Total := EndCursor.Paragraph - StartCursor.Paragraph;  { one #13 per boundary }
  for P := StartCursor.Paragraph to EndCursor.Paragraph do begin
    RangeOf(P);
    Inc(Total, Hi - Lo + 1);
  end;

  SetLength(Result, Total);
  Offset := 0;
  for P := StartCursor.Paragraph to EndCursor.Paragraph do begin
    RangeOf(P);
    if Hi >= Lo then begin
      Move(FParagraphs[P - 1].Text[Lo], Result[Offset + 1], Hi - Lo + 1);
      Inc(Offset, Hi - Lo + 1);
    end;
    if P < EndCursor.Paragraph then begin
      Inc(Offset);
      Result[Offset] := #13;
    end;
  end;
end;

{ Raw insert: puts S in at At, #13 being a paragraph break.  Whole
  segments go in at once, so restoring a large deletion is not quadratic. }
procedure tDocument.RawInsert(const At: TCursor; const S: string);
var
  C: TCursor;
  Start, P: SizeInt;
  Seg: string;
begin
  if not ValidCursor(At) then Exit;
  C := At;
  Start := 1;
  for P := 1 to Length(S) + 1 do
    if (P > Length(S)) or (S[P] = #13) then begin
      if P > Start then begin
        Seg := Copy(S, Start, P - Start);
        System.Insert(Seg, FParagraphs[C.Paragraph - 1].Text, C.Position);
        Inc(C.Position, Length(Seg));
        FDirty := TRUE;
      end;
      if P <= Length(S) then
        ParagraphBreak(C);
      Start := P + 1;
    end;
end;

procedure tDocument.RawDelete(const At: TCursor; const S: string);
begin
  DeleteRange(At, CursorAfter(At, S));
end;

procedure tDocument.BeginGroup;
begin
  if FGroupDepth = 0 then begin
    Inc(FGroupId);
    FRunOpen := FALSE;
  end;
  Inc(FGroupDepth);
end;

procedure tDocument.EndGroup;
begin
  if FGroupDepth > 0 then
    Dec(FGroupDepth);
  if FGroupDepth = 0 then
    FRunOpen := FALSE;
end;

procedure tDocument.CloseUndoRun;
begin
  FRunOpen := FALSE;
end;

function tDocument.CanUndo: Boolean;
begin
  Result := FUndoCount > 0;
end;

function tDocument.CanRedo: Boolean;
begin
  Result := FRedoCount > 0;
end;

procedure tDocument.ClearUndo;
var
  I: SizeInt;
begin
  for I := 0 to UndoCap - 1 do
    FRing[I].Text := '';
  FHead := 0;
  FUndoCount := 0;
  FRedoCount := 0;
  FBytes := 0;
  FRunOpen := FALSE;
  { The history position that matched the file is gone. }
  if FDirty then
    FSavePoint := -1
  else
    FSavePoint := 0;
end;

procedure tDocument.DropOldest;
var
  Slot: SizeInt;
begin
  Slot := (FHead - FUndoCount) and UndoMask;
  Dec(FBytes, Length(FRing[Slot].Text));
  FRing[Slot].Text := '';
  Dec(FUndoCount);
end;

{ Forget the oldest undo step.  Steps are dropped whole, unless that step is
  ProtectGroup (an enormous group still being recorded), in which case only
  its oldest record goes. }
procedure tDocument.EvictOldest(const ProtectGroup: SizeInt);
var
  G: SizeInt;
begin
  if FUndoCount = 0 then Exit;
  G := FRing[(FHead - FUndoCount) and UndoMask].Group;
  DropOldest;
  if G = ProtectGroup then Exit;
  while (FUndoCount > 0) and
        (FRing[(FHead - FUndoCount) and UndoMask].Group = G) do
    DropOldest;
end;

procedure tDocument.TrimBytes;
var
  G: SizeInt;
begin
  if FUndoCount = 0 then Exit;
  G := FRing[(FHead - 1) and UndoMask].Group;
  while (FBytes > UndoMaxBytes) and (FUndoCount > 1) do
    EvictOldest(G);
end;

{ Typing and deleting one character at a time should not make one undo step
  per keystroke.  Try to fold the edit into the newest record. }
function tDocument.TryMerge(Kind: tEditKind; const At: TCursor;
  const S: string): Boolean;
var
  PE: pEdit;
  Last: char;
begin
  Result := False;
  if (FUndoCount = 0) or (Length(S) <> 1) then Exit;

  PE := @FRing[(FHead - 1) and UndoMask];
  if PE^.Kind <> Kind then Exit;

  if FGroupDepth > 0 then begin
    { Inside a group: only continue the group's own record. }
    if PE^.Group <> FGroupId then Exit;
  end else begin
    if not FRunOpen then Exit;
  end;

  case Kind of
    ekInsert:
      begin
        { Must continue exactly where the last insert stopped. }
        if (At.Paragraph <> PE^.After.Paragraph) or
           (At.Position <> PE^.After.Position) then Exit;
        if FGroupDepth = 0 then begin
          { A typed run ends at Enter and after each space, so undo goes
            word by word. }
          if S[1] = #13 then Exit;
          Last := PE^.Text[Length(PE^.Text)];
          if (Last = #13) or (Last = ' ') then Exit;
        end;
        PE^.Text := PE^.Text + S;
        PE^.After := CursorAfter(PE^.After, S);
      end;

    ekDelete:
      begin
        if FGroupDepth > 0 then Exit;
        if (S[1] = #13) or (PE^.Text[1] = #13) then Exit;
        if At.Paragraph <> PE^.At.Paragraph then Exit;
        if At.Position + 1 = PE^.At.Position then begin
          { Backspacing: the new character lies just before the run. }
          PE^.Text := S + PE^.Text;
          PE^.At := At;
          PE^.After := At;
        end else if At.Position = PE^.At.Position then
          { Delete key: the next character slid into the same place. }
          PE^.Text := PE^.Text + S
        else
          Exit;
      end;
  end;

  Inc(FBytes, Length(S));
  Result := True;
end;

procedure tDocument.RecordEdit(Kind: tEditKind; const At: TCursor;
  const S: string);
var
  I, Slot, G: SizeInt;
begin
  if FReplaying or (S = '') then Exit;

  if TryMerge(Kind, At, S) then begin
    TrimBytes;
    Exit;
  end;

  { A new edit starts a new branch of history: the redo tail is gone. }
  if FRedoCount > 0 then begin
    if FSavePoint > FHead then
      FSavePoint := -1;      { the saved state was in the discarded tail }
    for I := 0 to FRedoCount - 1 do
      FRing[(FHead + I) and UndoMask].Text := '';
    FRedoCount := 0;
  end;

  if FGroupDepth > 0 then
    G := FGroupId
  else begin
    Inc(FGroupId);
    G := FGroupId;
  end;

  { The ring is full: the slot about to be reused holds the oldest step. }
  if FUndoCount = UndoCap then
    EvictOldest(G);

  Slot := FHead and UndoMask;
  FRing[Slot].Kind := Kind;
  FRing[Slot].At := At;
  FRing[Slot].Text := S;
  FRing[Slot].Group := G;
  if Kind = ekInsert then
    FRing[Slot].After := CursorAfter(At, S)
  else
    FRing[Slot].After := At;

  Inc(FHead);
  Inc(FUndoCount);
  Inc(FBytes, Length(S));

  { Only a lone character can start a run that further typing may join. }
  FRunOpen := (FGroupDepth = 0) and (Length(S) = 1);

  TrimBytes;
end;

function tDocument.Undo(var Cursor: TCursor): Boolean;
var
  Slot, G: SizeInt;
begin
  Result := FUndoCount > 0;
  if not Result then Exit;

  FRunOpen := FALSE;
  FReplaying := TRUE;
  try
    G := FRing[(FHead - 1) and UndoMask].Group;
    while (FUndoCount > 0) and
          (FRing[(FHead - 1) and UndoMask].Group = G) do begin
      Dec(FHead);
      Dec(FUndoCount);
      Inc(FRedoCount);
      Slot := FHead and UndoMask;
      case FRing[Slot].Kind of
        ekInsert: RawDelete(FRing[Slot].At, FRing[Slot].Text);
        ekDelete: RawInsert(FRing[Slot].At, FRing[Slot].Text);
      end;
      Dec(FBytes, Length(FRing[Slot].Text));
      Cursor := FRing[Slot].At;
    end;
  finally
    FReplaying := FALSE;
  end;

  FDirty := (FHead <> FSavePoint);
end;

function tDocument.Redo(var Cursor: TCursor): Boolean;
var
  Slot, G: SizeInt;
begin
  Result := FRedoCount > 0;
  if not Result then Exit;

  FRunOpen := FALSE;
  FReplaying := TRUE;
  try
    G := FRing[FHead and UndoMask].Group;
    while (FRedoCount > 0) and
          (FRing[FHead and UndoMask].Group = G) do begin
      Slot := FHead and UndoMask;
      case FRing[Slot].Kind of
        ekInsert: RawInsert(FRing[Slot].At, FRing[Slot].Text);
        ekDelete: RawDelete(FRing[Slot].At, FRing[Slot].Text);
      end;
      Inc(FBytes, Length(FRing[Slot].Text));
      Cursor := FRing[Slot].After;
      Inc(FHead);
      Dec(FRedoCount);
      Inc(FUndoCount);
    end;
  finally
    FReplaying := FALSE;
  end;

  FDirty := (FHead <> FSavePoint);
end;

end.
