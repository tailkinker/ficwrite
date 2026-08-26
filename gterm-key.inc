function CursorMoveRightOne : boolean;
begin
  Result := TRUE;
  if (Cursor.Position < length (Document.Paragraph[Cursor.Paragraph].TextWithCR)) then
    inc (Cursor.Position)
  else if (Cursor.Paragraph < Document.ParagraphCount) then begin
    Cursor.Position := 1;
    inc (Cursor.Paragraph)
  end else
    Result := FALSE;

  while (Scr.Line[BottomLine].Relative (Cursor) > 0) do
    inc (TopLine);
end;

function CursorMoveRight (delta : SizeInt) : boolean;
var
  index : integer;
begin
  Result := TRUE;
  for index := 1 to delta do
    if not CursorMoveRightOne then begin
      Result := FALSE;
      Break;
    end;
end;

function CursorMoveLeftOne : boolean;
begin
  Result := TRUE;
  if Cursor.Position > 1 then
    dec (Cursor.Position)
  else if Cursor.Paragraph > 1 then begin
    dec (Cursor.Paragraph);
    Cursor.Position := length (Document.Paragraph[Cursor.Paragraph].TextWithCR);
  end else
    Result := FALSE;

  while (Scr.Line[TopLine].Relative (Cursor) < 0) do
    if (TopLine > 0) then
      dec (TopLine)
    else
      raise ERangeError.CreateFmt('TopLine out of range: %d', [TopLine]);
end;

function CursorMoveLeft (delta : SizeInt) : boolean;
var
  index : integer;
begin
  Result := TRUE;
  for index := 1 to delta do
    if not CursorMoveLeft then begin
      Result := FALSE;
      Break;
    end;
end;

function CursorMoveDownOne : boolean; overload;
begin
  Result := TRUE;
  if not Assigned (Scr.Line [TopLine + CursorY + 1]) then
    Result := FALSE
  else begin
    inc (CursorY);
    if (CursorX > length (Scr.Line [TopLine + CursorY].Text)) then
      CursorX := length (Scr.Line [TopLine + CursorY].Text);
    Cursor.Paragraph := Scr.Line [TopLine + CursorY].Start.Paragraph;
    Cursor.Position  := Scr.Line [TopLine + CursorY].Start.Position + CursorX;
    while (CursorY >= MaxY) do begin
      dec (CursorY);
      inc (TopLine);
    end;
  end;
end;

function CursorMoveDown (delta : SizeInt) : boolean; overload;
var
  index : integer;
begin
  Result := TRUE;
  for index := 1 to delta do begin
    Result := CursorMoveDownOne;
    if not Result then 
      Break;
  end;
end;

function CursorMoveUpOne : boolean;
begin
  Result := TRUE;
  if (CursorY = 0) and
     (Scr.Line[TopLine].Start.Paragraph = 1) and
     (Scr.Line[TopLine].Start.Position = 1) then
    Result := FALSE
  else begin
    dec (CursorY);
    if (CursorX > length (Scr.Line[TopLine + CursorY].Text)) then
      CursorX := length (Scr.Line[TopLine + CursorY].Text);
    Cursor.Paragraph := Scr.Line[TopLine + CursorY].Start.Paragraph;
    Cursor.Position  := Scr.Line[TopLine + CursorY].Start.Position + CursorX;

    while (CursorY < 0) do begin
      inc (CursorY);
      if (TopLine > 0) then
        dec (TopLine)
      else
        raise ERangeError.CreateFmt('TopLine out of range: %d', [TopLine]);
    end;
  end;
end;

function CursorMoveUp (delta : SizeInt) : boolean;
var
  index : integer;
begin
  Result := TRUE;
  for index := 1 to delta do begin
    Result := CursorMoveUpOne;
    if not Result then 
      Break;
  end;
end;

function CursorMoveHome : boolean;
begin
  if (CursorX = 0) then
    Result := FALSE
  else begin
    CursorX := 0;
    Cursor.Position := Scr.Line [TopLine + CursorY].Start.Position;
    Result := TRUE;
  end;
end;

function CursorMoveEnd : boolean;
begin
  if ((CursorX + 1) >= length (Scr.Line [TopLine + CursorY].Text)) then
    Result := FALSE
  else begin
    CursorX := length (Scr.Line [TopLine + CursorY].Text) - 1;
    if (CursorX < 0) then
      raise ERangeError.CreateFmt('CursorX out of range: %d', [CursorX]);
    Cursor.Position := Scr.Line [TopLine + CursorY].Start.Position + CursorX;
    Result := TRUE;
  end;
end;

function EditDelete : boolean;
begin
  if (Cursor.Position > length(Document.Paragraph [Cursor.Paragraph].Text)) then
    Result := Document.CombineWithNext (Cursor)
  else
    Result := Document.DeleteChar (Cursor);
end;

procedure HandleKeyboard;
var
  K : TKeyEvent;
  C : char;
  SavedX : integer;
begin
  K := GetKeyEvent;
  K := TranslateKeyEvent (K);

  C := GetKeyEventChar (K);

  if (C = #8) then begin
    if CursorMoveLeftOne then
      EditDelete;
    Scr.Repaginate (Document, TopLine + CursorY);
  end;

  if (C in [' '..'~']) then begin
    Document.Insert (C, Cursor);
    Scr.Repaginate (Document, TopLine + CursorY);
  end;
  
  case GetKeyEventCode (K) of
    kbdF12:
      ExitProgram := TRUE;
    kbdLeft:
      CursorMoveLeftOne;
    kbdRight:
      CursorMoveRightOne;
    kbdDown:
      begin
        SavedX := CursorX;
        CursorMoveDownOne;
        if (Scr.Line [TopLine + CursorY].IsParagraphBreak) then begin
          CursorX := SavedX;
          CursorMoveDownOne;
        end;
      end;
    kbdUp:
      begin
        SavedX := CursorX;
        CursorMoveUpOne;
        if (Scr.Line [TopLine + CursorY].IsParagraphBreak) then begin
          CursorX := SavedX;
          CursorMoveUpOne;
        end;
      end;
    kbdHome:
      CursorMoveHome;
    kbdEnd:
      CursorMoveEnd;
    kbdDelete:
      begin
        EditDelete;
        Scr.Repaginate (Document, TopLine + CursorY);
        while (Scr.LineCount < BottomLine) and (TopLine > 0) do
          Dec(TopLine);
      end;
    kbdPgUp:
      CursorMoveUp (MaxY - 1);
    kbdPgDn:
      CursorMoveDown (MaxY - 1);
  end;
end;


