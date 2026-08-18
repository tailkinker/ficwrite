unit gdoc;

{$mode objfpc}{$H+}

interface

type
  { 
  A logical position within the document.
  Both fields are zero-based.

  Position is measured in Unicode code points, not UTF-8 bytes
  and not terminal display columns. It identifies a boundary
  between code points, so Position may range from zero through
  the number of code points in the paragraph. 
  }  
  TCursor = record
    Paragraph: SizeInt;
    Position: SizeInt;
  end;

  TParagraph = class
  private
    function BytePosition(const Position: SizeInt): SizeInt;
    function CodePointLength(const BytePos: SizeInt): SizeInt;
  public
    Text: RawByteString;
    function CodePointCount: SizeInt;
    function Insert(const CodePoint: Cardinal; var Cursor: TCursor): Boolean;
    function Overwrite(const CodePoint: Cardinal; var Cursor: TCursor): Boolean;
    function DeleteChar(var Cursor: TCursor): Boolean;
    function DeleteChar(const Count: UInt32; var Cursor: TCursor): Boolean;
    function Split(const Position: SizeInt; out Remainder: TParagraph): Boolean;  
  end;  
  
  TDocument = class
  private
    FParagraphs: array of TParagraph;
    FParagraphCount: SizeInt;
    function ValidCursor(const Cursor: TCursor): Boolean;
    procedure Grow;
    function GetParagraph(const Index: SizeInt): TParagraph;    
  public
    property ParagraphCount: SizeInt read FParagraphCount;
    property Paragraph[Index: SizeInt]: TParagraph read GetParagraph;
    constructor Create;
    destructor Destroy; override;
    function Insert(const c: Cardinal; var Cursor: TCursor): Boolean;
    function Overwrite(const c: Cardinal; var Cursor: TCursor): Boolean;
    function DeleteChar(var Cursor: TCursor): Boolean;
    function DeleteChar(const Count: UInt32; var Cursor: TCursor): Boolean;
    function ParagraphBreak(var Cursor: TCursor): Boolean;
    function DeleteParagraph(const aParagraph: SizeInt): Boolean;  
    function CombineWithNext (var Cursor : tCursor) : boolean;
    function LoadFromFile(const FileName: string): Boolean;
    function SaveToFile(const FileName: string): Boolean;
  end;
    
implementation

uses
  cutf8;

// === tParagraph =============================================================

function TParagraph.CodePointCount: SizeInt;
var
  BytePos: SizeInt;
  Length: SizeInt;
begin
  Result := 0;
  BytePos := 1;

  while BytePos <= System.Length(Text) do begin
    Length := CodePointLength(BytePos);
    if Length = 0 then 
      Exit;

    Inc(BytePos, Length);
    Inc(Result);
  end;
end;


function TParagraph.BytePosition(const Position: SizeInt): SizeInt;
var
  Current: SizeInt;
  Length: SizeInt;
begin
  Result := 1;
  Current := 0;

  while Current < Position do begin
    if Result > System.Length(Text) then begin
      Result := -1;
      Exit;
    end;
    Length := CodePointLength(Result);
    if Length = 0 then begin
      Result := -1;
      Exit;
    end;
    Inc(Result, Length);
    Inc(Current);
  end;
end;


function TParagraph.CodePointLength(const BytePos: SizeInt): SizeInt;
var
  CodePoint: Cardinal;
begin
  if DecodeUTF8(Text, BytePos, CodePoint, Result) then Exit;
  Result := 0;
end;

function TParagraph.Insert(const CodePoint: Cardinal; var Cursor: TCursor): Boolean;
var
  BytePos: SizeInt;
  Encoded: RawByteString;
begin
  Result := False;

  if (CodePoint > $10FFFF) or ((CodePoint >= $D800) and (CodePoint <= $DFFF)) 
    then Exit;
  if (Cursor.Position < 0) or (Cursor.Position > CodePointCount) then Exit;
  BytePos := BytePosition(Cursor.Position);
  if BytePos < 1 then Exit;

  Encoded := EncodeUTF8(CodePoint);
  if Encoded = '' then Exit;
  System.Insert(Encoded, Text, BytePos);

  Inc(Cursor.Position);
  Result := True;
end;


function TParagraph.Overwrite(const CodePoint: Cardinal; var Cursor: TCursor): Boolean;
var
  BytePos: SizeInt;
  OldLength: SizeInt;
  Encoded: RawByteString;
begin
  Result := False;

  if (CodePoint > $10FFFF) or ((CodePoint >= $D800) and (CodePoint <= $DFFF)) 
    then Exit;
  if (Cursor.Position < 0) or (Cursor.Position > CodePointCount) then Exit;

  { At the end of the paragraph, overwrite becomes insert. }
  if Cursor.Position = CodePointCount then begin
    Result := Insert(CodePoint, Cursor);
    Exit;
  end;

  BytePos := BytePosition(Cursor.Position);

  if BytePos < 1 then Exit;

  OldLength := CodePointLength(BytePos);
  if OldLength = 0 then Exit;

  Encoded := EncodeUTF8(CodePoint);
  if Encoded = '' then Exit;

  System.Delete(Text, BytePos, OldLength);
  System.Insert(Encoded, Text, BytePos);

  Inc(Cursor.Position);
  Result := True;
end;


function TParagraph.DeleteChar(var Cursor: TCursor): Boolean;
begin
  Result := DeleteChar(UInt32(1), Cursor);
end;


function TParagraph.DeleteChar(const Count: UInt32; var Cursor: TCursor): Boolean;
var
  BytePos: SizeInt;
  EndBytePos: SizeInt;
  Current: SizeInt;
  Length: SizeInt;
begin
  Result := False;

  if Cursor.Position < 0 then Exit;
  if Cursor.Position > CodePointCount then Exit;

  if Count = 0 then begin
    Result := True;
    Exit;
  end;

  BytePos := BytePosition(Cursor.Position);
  if BytePos < 1 then Exit;
  Current := 0;
  EndBytePos := BytePos;

  while Current < Count do begin
    if EndBytePos > System.Length(Text) then Exit;
    Length := CodePointLength(EndBytePos);
    if Length = 0 then Exit;
    Inc(EndBytePos, Length);
    Inc(Current);
  end;

  System.Delete(Text, BytePos, EndBytePos - BytePos);
  Result := True;
end;

function TParagraph.Split(const Position: SizeInt; out Remainder: TParagraph): Boolean;
var
  BytePos: SizeInt;
begin
  Result := False;
  Remainder := nil;
  if (Position < 0) or (Position > CodePointCount) then Exit;
  BytePos := BytePosition(Position);
  if BytePos < 1 then Exit;

  Remainder := TParagraph.Create;
  Remainder.Text := Copy(Text, BytePos, Length(Text) - BytePos + 1);
  Delete(Text, BytePos, Length(Text) - BytePos + 1);
  Result := True;
end;

// === tDocument ==============================================================

constructor TDocument.Create;
begin
  SetLength(FParagraphs, 1);
  FParagraphs[0] := tParagraph.Create;
  FParagraphs[0].Text := '';
  FParagraphCount := 1;
end;

destructor TDocument.Destroy;
var
  index : SizeInt;
begin
  for index := 0 to (Length(FParagraphs) - 1) do
    FParagraphs[index].Free;
  SetLength (FParagraphs, 0);
end;

function TDocument.GetParagraph(const Index: SizeInt): TParagraph;
begin
  if (Index < 0) or (Index >= FParagraphCount) then
    Result := nil
  else
    Result := FParagraphs[Index];
end;

procedure TDocument.Grow;
var
  NewCapacity: SizeInt;
begin
  NewCapacity := Length(FParagraphs) * 2;

  if NewCapacity = 0 then
    NewCapacity := 1;

  SetLength(FParagraphs, NewCapacity);
end;

function TDocument.ValidCursor(const Cursor: TCursor): Boolean;
begin
  Result := FALSE;
  if (Cursor.Paragraph < 0) or (Cursor.Paragraph >= FParagraphCount) then Exit;
  if FParagraphs[Cursor.Paragraph] = nil then Exit;

  Result := (Cursor.Position >= 0) and 
    (Cursor.Position <= FParagraphs[Cursor.Paragraph].CodePointCount);
end;

function TDocument.Insert(const c: Cardinal;
  var Cursor: TCursor): Boolean;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  Result := FParagraphs[Cursor.Paragraph].Insert(c, Cursor);
end;

function TDocument.Overwrite(const c: Cardinal;
  var Cursor: TCursor): Boolean;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  Result := FParagraphs[Cursor.Paragraph].Overwrite(c, Cursor);
end;

function TDocument.DeleteChar(var Cursor: TCursor): Boolean;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  Result := FParagraphs[Cursor.Paragraph].DeleteChar(Cursor);
end;

function TDocument.DeleteChar(const Count: UInt32;
  var Cursor: TCursor): Boolean;
begin
  Result := False;
  if not ValidCursor(Cursor) then Exit;
  Result := FParagraphs[Cursor.Paragraph].DeleteChar(Count, Cursor);
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
  NewIndex := Cursor.Paragraph + 1;

  { Split the current paragraph. }
  if not FParagraphs[Cursor.Paragraph].Split(Cursor.Position, NewParagraph) then begin
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
  Cursor.Paragraph := NewIndex;
  Cursor.Position := 0;

  Result := True;
end;

function TDocument.DeleteParagraph(const aParagraph: SizeInt): Boolean;
var
  I: SizeInt;
begin
  Result := False;

  { A document must always contain at least one paragraph. }
  if FParagraphCount <= 1 then
    Exit;

  { Check the paragraph index. }
  if (aParagraph < 0) or (aParagraph >= FParagraphCount) then Exit;
  
  { Destroy the target paragraph object}
  FParagraphs[aParagraph].Destroy;

  { Move following paragraphs up. }
  for I := aParagraph to FParagraphCount - 2 do
    FParagraphs[I] := FParagraphs[I + 1];

  { Clear the now-unused paragraph slot. }
  FParagraphs[FParagraphCount - 1] := nil;
  Dec(FParagraphCount);
  Result := True;
end;

function TDocument.CombineWithNext(var Cursor: TCursor): Boolean;
var
  Current: SizeInt;
  Next: SizeInt;
begin
  Result := False;

  if not ValidCursor(Cursor) then
    Exit;

  Current := Cursor.Paragraph;
  Next := Current + 1;

  if Next >= FParagraphCount then
    Exit;

  FParagraphs[Current].Text :=
    FParagraphs[Current].Text +
    FParagraphs[Next].Text;

  DeleteParagraph(Next);

  Result := True;
end;

function TDocument.LoadFromFile(const FileName: string): Boolean;
var
  F: File;
  FileSize: Int64;
  Data: RawByteString;
  BytesRead: Integer;

  P: SizeInt;
  ByteLength: SizeInt;
  CodePoint: Cardinal;
  LineStart: SizeInt;
  LineEnd: SizeInt;

  NewParagraphs: array of TParagraph;
  NewCount: SizeInt;
  NewCapacity: SizeInt;

  I: SizeInt;
  CurrentParagraph: TParagraph;

  procedure AddParagraph(const S: RawByteString);
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
  AssignFile(F, FileName);

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

  { Validate the entire file as UTF-8. }
  P := 1;

  while P <= Length(Data) do begin
    if not DecodeUTF8(Data, P, CodePoint, ByteLength) then
      Exit;

    Inc(P, ByteLength);
  end;

  { Build the new paragraph array. }
  NewCount := 0;
  NewCapacity := 0;
  SetLength(NewParagraphs, 0);

  LineStart := 1;
  P := 1;

  while P <= Length(Data) do begin

    { LF terminates a paragraph. }
    if Data[P] = #10 then begin

      { If preceded by CR, exclude the CR from the paragraph. }
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
      CRLF is handled above when its LF is encountered. }
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

  { Add the final paragraph. }
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
end;

function TDocument.SaveToFile(const FileName: string): Boolean;
var
  F: File;
  I: SizeInt;
  BytesWritten: Integer;
  LineEnding: RawByteString;
begin
  Result := False;
  LineEnding := #10;

  AssignFile(F, FileName);

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
end;

end.
