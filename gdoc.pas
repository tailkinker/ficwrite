unit gdoc;

{$mode objfpc}{$H+}{$R+}

interface

uses
  dcommon;
  
type
  TParagraph = class
  public
    Text: String;
    function TextWithCR : string;
    function Insert(const C: char; var Cursor: TCursor): Boolean;
    function Overwrite(const C: char; var Cursor: TCursor): Boolean;
    function DeleteChar(var Cursor: TCursor): Boolean;
    function DeleteChar(const Count: UInt32; var Cursor: TCursor): Boolean;
    function Split(const Position: SizeInt; out Remainder: TParagraph): Boolean;  
  end;  
  
  TDocument = class
  private
    FParagraphs: array of TParagraph;
    FParagraphCount: SizeInt;
    FDirty : boolean;
    FFilename : string;
    procedure Grow;
    function GetParagraph(const Index: SizeInt): TParagraph;
    procedure SetFileName (aFilename : string);
  public
    property Dirty : boolean read FDirty;
    property ParagraphCount: SizeInt read FParagraphCount;
    property Paragraph[Index: SizeInt]: TParagraph read GetParagraph;
    property Filename : string read FFileName write SetFileName;
    constructor Create;
    destructor Destroy; override;
    function ValidCursor(const Cursor: TCursor): Boolean;
    function Insert(const C: char; var Cursor: TCursor): Boolean;
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
  end;

var
  Document : tDocument;

implementation

uses
  SysUtils, doption;

// === tParagraph =============================================================

function TParagraph.TextWithCR : string;
begin
  Result := Text + PARAGRAPH_MARKER;
end;

function TParagraph.Insert(const C: Char; var Cursor: TCursor): Boolean;
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


function TParagraph.Overwrite(const C: Char;
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


function TParagraph.DeleteChar(var Cursor: TCursor): Boolean;
begin
  Result := DeleteChar(UInt32(1), Cursor);
end;


function TParagraph.DeleteChar(const Count: UInt32;
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


function TParagraph.Split(const Position: SizeInt; out Remainder: TParagraph): Boolean;
begin
  Result := False;
  Remainder := nil;

  { Position is the point at which the split occurs.
    1 = before the first character.
    Length(Text)+1 = after the final character. }
  if (Position < 1) or
     (Position > Length(Text) + 1) then
    Exit;

  Remainder := TParagraph.Create;

  { Copy everything from Position onward. }
  Remainder.Text :=
    Copy(Text, Position, Length(Text) - Position + 1);

  { Keep everything before Position. }
  Delete(Text, Position, Length(Text) - Position + 1);

  Result := True;
end;

// === tDocument ==============================================================

constructor TDocument.Create;
begin
  inherited Create;
  SetLength(FParagraphs, 1);
  FParagraphs[0] := tParagraph.Create;
  FParagraphs[0].Text := '';
  FParagraphCount := 1;
  FDirty := FALSE;
end;

destructor TDocument.Destroy;
var
  index : SizeInt;
begin
  for index := 0 to (Length(FParagraphs) - 1) do
    FParagraphs[index].Free;
  SetLength (FParagraphs, 0);
end;

procedure TDocument.SetFileName (aFilename : string);
begin
  FFilename := aFilename;
end;

function TDocument.GetParagraph(const Index: SizeInt): TParagraph;
begin
  if (Index < 1) or (Index > FParagraphCount) then
    Result := nil
  else
    Result := FParagraphs[Index - 1];
end;

procedure TDocument.Grow;
var
  NewCapacity: SizeInt;
begin
  NewCapacity := Length(FParagraphs) * 2;

  if NewCapacity = 0 then
    NewCapacity := 1;

  SetLength(FParagraphs, NewCapacity);
  FDirty := TRUE;
end;

function TDocument.ValidCursor(const Cursor: TCursor): Boolean;
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

function TDocument.Insert(const c: char; var Cursor: TCursor): Boolean;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  Result := FParagraphs[Cursor.Paragraph - 1].Insert(c, Cursor);
  if (Result = TRUE) then
    FDirty := TRUE;
end;

function TDocument.Overwrite(const c: char; var Cursor: TCursor): Boolean;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  Result := FParagraphs[Cursor.Paragraph - 1].Overwrite(c, Cursor);
  if (Result = TRUE) then
    FDirty := TRUE;
end;

function TDocument.DeleteChar(var Cursor: TCursor): Boolean;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  Result := FParagraphs[Cursor.Paragraph - 1].DeleteChar(Cursor);
  if (Result = TRUE) then
    FDirty := TRUE;
end;

function TDocument.DeleteChar(const Count: UInt32; var Cursor: TCursor): Boolean;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  Result := FParagraphs[Cursor.Paragraph - 1].DeleteChar(Count, Cursor);
  if (Result = TRUE) then
    FDirty := TRUE;
end;

function TDocument.ParagraphBreak(var Cursor: TCursor): Boolean;
var
  NewParagraph: TParagraph;
  NewIndex: SizeInt;
  I: SizeInt;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;

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
end;

function TDocument.DeleteParagraph(const aParagraph: SizeInt): Boolean;
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

function TDocument.CombineWithNext(var Cursor: TCursor): Boolean;
var
  Current: SizeInt;
  Next: SizeInt;
begin
  Result := False;

  if not ValidCursor(Cursor) then
    Exit;

  Current := Cursor.Paragraph - 1;
  Next := Current + 1;

  if Next >= FParagraphCount then
    Exit;

  FParagraphs[Current].Text :=
    FParagraphs[Current].Text +
    FParagraphs[Next].Text;

  DeleteParagraph(Next);

  Result := True;
  FDirty := TRUE;
end;

function TDocument.DeleteRange(const StartCursor,
  EndCursor: TCursor): SizeInt;
var
  StartParagraph: SizeInt;
  EndParagraph: SizeInt;
  StartPosition: SizeInt;
  EndPosition: SizeInt;
  StartText: String;
  EndText: String;
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
end;

function TDocument.LoadFromFile(const aFileName: string): Boolean;
var
  F: File;
  FileSize: Int64;
  Data: String;
  BytesRead: Integer;

  P: SizeInt;
  LineStart: SizeInt;
  LineEnd: SizeInt;

  NewParagraphs: array of TParagraph;
  NewCount: SizeInt;
  NewCapacity: SizeInt;

  I: SizeInt;
  CurrentParagraph: TParagraph;

  procedure AddParagraph(const S: String);
  begin
    if NewCount = NewCapacity then begin
      if NewCapacity = 0 then
        NewCapacity := 1
      else
        NewCapacity := NewCapacity * 2;

      SetLength(NewParagraphs, NewCapacity);
    end;

    CurrentParagraph := TParagraph.Create;
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

  LineStart := 1;
  P := 1;

  while P <= Length(Data) do begin

    { LF terminates a paragraph. }
    if Data[P] = #10 then begin

      { If preceded by CR, exclude the CR. }
      if (P > LineStart) and (Data[P - 1] = #13) then
        LineEnd := P - 2
      else
        LineEnd := P - 1;

      if LineEnd >= LineStart then
        AddParagraph(
          Copy(Data, LineStart, LineEnd - LineStart + 1)
        )
      else
        AddParagraph('');

      LineStart := P + 1;
      Inc(P);
      Continue;
    end;

    { Bare CR also terminates a paragraph.
      CRLF is handled when the LF is encountered. }
    if Data[P] = #13 then begin

      if (P = Length(Data)) or
         (Data[P + 1] <> #10) then begin

        LineEnd := P - 1;

        if LineEnd >= LineStart then
          AddParagraph(
            Copy(Data, LineStart, LineEnd - LineStart + 1)
          )
        else
          AddParagraph('');

        LineStart := P + 1;
      end;

      Inc(P);
      Continue;
    end;

    Inc(P);
  end;

  { Add the final paragraph if there is text after the
    final line ending. }
  if LineStart <= Length(Data) then
    AddParagraph(
      Copy(Data, LineStart, Length(Data) - LineStart + 1)
    )
  else if (Length(Data) = 0) or
          (Data[Length(Data)] = #10) or
          (Data[Length(Data)] = #13) then
    AddParagraph('');

  { The document must always contain at least one paragraph. }
  if NewCount = 0 then
    AddParagraph('');

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

  Result := True;
  FDirty := FALSE;
  FFilename := aFilename;
end;

function TDocument.SaveToFile(const aFileName: string): Boolean;
var
  F: File;
  I: SizeInt;
  BytesWritten: Integer;
  LineEnding: String;
begin
  Result := False;
  LineEnding := #10;

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

    { Separate paragraphs with LF, but do not add a final
      line ending after the last paragraph. }
    if I < FParagraphCount - 1 then begin
      BlockWrite(
        F,
        LineEnding[1],
        1,
        BytesWritten
      );

      if BytesWritten <> 1 then begin
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

end.
