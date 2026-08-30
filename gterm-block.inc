procedure SwapCursors (var aCursor, bCursor : tCursor);
var
  cCursor : tCursor;
begin
  cCursor := aCursor;
  aCursor := bCursor;
  bCursor := cCursor;
end;

function  CompareCursors(const A, B: tCursor): integer;
begin
  if A.Paragraph < B.Paragraph then
    Exit(-1);
  if A.Paragraph > B.Paragraph then
    Exit(1);

  { Same paragraph: compare position within the paragraph }
  if A.Position < B.Position then
    Exit(-1);
  if A.Position > B.Position then
    Exit(1);

  Result := 0;
end;

function  SetBlockStart : boolean;
begin
  Result := TRUE;
  if (Document.ValidCursor(Cursor)) then begin
    BlockStart := Cursor;
    if (BlockEnd.Paragraph > -1) then
      if CompareCursors (BlockStart, BlockEnd) > 0 then
        SwapCursors (BlockStart, BlockEnd);
    if (CompareCursors (BlockStart, BlockEnd) = 0) then
      Result := FALSE;
  end;
end;

function  SetBlockEnd : boolean;
begin
  Result := TRUE;
  if (Document.ValidCursor(Cursor)) then begin
    BlockEnd := Cursor;
    if (BlockStart.Paragraph > -1) then
      if CompareCursors (BlockStart, BlockEnd) > 0 then
        SwapCursors (BlockStart, BlockEnd);
    if (CompareCursors (BlockStart, BlockEnd) = 0) then
      Result := FALSE;
  end;
end;

procedure BlockClear;
begin
  BlockStart.Paragraph := -1;
  BlockEnd.Paragraph := -1;
end;

function  BlockValid : boolean;
begin
  if (BlockStart.Paragraph = -1) or (BlockEnd.Paragraph = -1) then
    Result := FALSE
  else
    Result := TRUE
end;

function  InBlock (aCursor : tCursor) : boolean; 
begin
  Result := FALSE;
  if (not BlockValid) then
    Exit;
  if (CompareCursors(aCursor, BlockStart) >= 0) and
   (CompareCursors(aCursor, BlockEnd) < 0) then
    Result := TRUE
end;

function BlockCopy : SizeInt;
var
  StartCursor,
  EndCursor : TCursor;
  P, Pos    : SizeInt;
  Size      : SizeInt;
  Offset    : SizeInt;
begin
  Result := 0;
  if (not BlockValid) then Exit;
  StartCursor := BlockStart;
  EndCursor   := BlockEnd;

  { Put the cursors in document order. }
  if (StartCursor.Paragraph > EndCursor.Paragraph) or
     ((StartCursor.Paragraph = EndCursor.Paragraph) and
      (StartCursor.Position > EndCursor.Position)) then begin
    StartCursor := BlockEnd;
    EndCursor   := BlockStart;
  end;

  { Determine clipboard size. }
  Size := 0;

  for P := StartCursor.Paragraph to EndCursor.Paragraph do begin
    if (P = StartCursor.Paragraph) and
       (P = EndCursor.Paragraph) then
      Inc(Size, EndCursor.Position - StartCursor.Position)
    else if (P = StartCursor.Paragraph) then
      Inc(Size, Length(Document.Paragraph[P].Text)
             - StartCursor.Position + 1)
    else if (P = EndCursor.Paragraph) then
      Inc(Size, EndCursor.Position - 1)
    else
      Inc(Size, Length(Document.Paragraph[P].Text));

    { Paragraph separator. }
    if (P < EndCursor.Paragraph) then
      Inc(Size);
  end;

  SetLength(Clipboard, Size);

  { Copy characters. }
  Offset := 0;

  for P := StartCursor.Paragraph to EndCursor.Paragraph do begin

    if (P = StartCursor.Paragraph) and
       (P = EndCursor.Paragraph) then begin

      for Pos := StartCursor.Position to EndCursor.Position - 1 do begin
        Clipboard[Offset] := Document.Paragraph[P].Text[Pos];
        Inc(Offset);
      end;

    end else if (P = StartCursor.Paragraph) then begin

      for Pos := StartCursor.Position to Length(Document.Paragraph[P].Text) do begin
        Clipboard[Offset] := Document.Paragraph[P].Text[Pos];
        Inc(Offset);
      end;

    end else if (P = EndCursor.Paragraph) then begin

      for Pos := 1 to EndCursor.Position - 1 do begin
        Clipboard[Offset] := Document.Paragraph[P].Text[Pos];
        Inc(Offset);
      end;

    end else begin

      for Pos := 1 to Length(Document.Paragraph[P].Text) do begin
        Clipboard[Offset] := Document.Paragraph[P].Text[Pos];
        Inc(Offset);
      end;

    end;

    if (P < EndCursor.Paragraph) then begin
      Clipboard[Offset] := #13;
      Inc(Offset);
    end;
  end;

  Result := Size;
end;

function BlockDelete : SizeInt;
begin
  Result := 0;
  if not BlockValid then
    Exit;

  Result := Document.DeleteRange(BlockStart, BlockEnd);
  Cursor := BlockStart;
  BlockClear;
  Scr.Repaginate(Document);
end;

function BlockInsert : SizeInt;
var
  I : SizeInt;
begin
  Result := 0;
  if (not BlockValid) then
    exit;
  if (length(Clipboard) = 0) then
    exit;

  BlockStart := Cursor;
  for I := 0 to High(Clipboard) do begin
    if (Clipboard[I] = #13) then begin
      if Document.ParagraphBreak(Cursor) then
        Inc(Result)
      else
        Break;
    end else begin
      Document.Insert(Clipboard[I], Cursor);
      Inc(Result);
    end;
  end;
  BlockEnd := Cursor;
  Scr.Repaginate(Document);
end;

function BlockMove : SizeInt;
var
  I : SizeInt;
  NewBlockStart,
  NewBlockEnd : tCursor;
begin
  Result := 0;
  if (not BlockValid) then
    exit;
  if (InBlock (Cursor)) then
    exit;
    
  // Copy
  BlockCopy;

  // Insert
  NewBlockStart := Cursor;
  for I := 0 to High(Clipboard) do begin
    if (Clipboard[I] = #13) then begin
      if Document.ParagraphBreak(Cursor) then
        Inc(Result)
      else
        Break;
    end else begin
      Document.Insert(Clipboard[I], Cursor);
      Inc(Result);
    end;
  end;
  NewBlockEnd := Cursor;

  // Delete
  BlockDelete;
  
  BlockStart := NewBlockStart;
  BlockEnd := NewBlockEnd;
  Cursor := NewBlockEnd;
  
  Scr.Repaginate(Document);
end;