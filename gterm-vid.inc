procedure ClrScr;
var
  index,
  Limit : integer;
begin
  Limit := (ScreenWidth * ScreenHeight) - 1;
  for index := 0 to Limit do
    VideoBuf^[index] := BackgroundColour + TextColour + 32;
end;

{
procedure Repaginate (const aParagraph, aPosition, aFrom : SizeInt);
// Overloaded version starts at ScreenLine[aFrom]
var
  Paragraph,
  Position,
  index,
  BreakAt,
  Line : SizeInt;
  PFrag : string;
begin
  DebugLog('Entered Repaginate:  aParagraph=' + IntToStr(aParagraph) +
    ', aPosition=' + IntToStr(aPosition));

  if (aParagraph < 1) then
    Paragraph := 1
  else
    Paragraph := aParagraph;
  if (aPosition < 1) then
    Position := 1
  else
    Position := aPosition;
  Line := aFrom;
  if (aFrom > 1) then begin
    Line := aFrom;
    Paragraph := ScreenLines [Line].Paragraph;
    Position := ScreenLines [Line].Position;
  end else
    Line := 1;
  if (Document.Paragraph[Paragraph] <> nil) then
    PFrag := Document.Paragraph[Paragraph].TextWithCR
  else
    PFrag := '';
  if (length (PFrag) > 0) then
    PFrag := Copy(PFrag, Position, MaxInt);
  repeat
    ScreenLines [Line].Paragraph := Paragraph;
    ScreenLines [Line].Position := Position;
    BreakAt := ScreenWidth;

    for index := 1 to ScreenWidth do begin
      if (index > length (PFrag)) then begin
        BreakAt := length (PFrag);
        Break;
      end;
      if (PFrag [index] in [#9, #32]) then
        BreakAt := index;
    end;

    ScreenLines [Line].TextOf := Copy (PFrag, 1, BreakAt);
    ScreenLines [Line].IsParagraphBreak := FALSE;
    Delete (Pfrag, 1, BreakAt);
    Position := Position + BreakAt;
    if (length (PFrag) = 0) then begin
      inc (Paragraph);
      Position := 1;
      inc (Line);
      If (line <= ScreenHeight) then begin
        ScreenLines [Line].Paragraph := Paragraph;
        ScreenLines [Line].Position := 0;
        ScreenLines [Line].TextOf := '';
        ScreenLines [Line].IsParagraphBreak := TRUE;
        if (Paragraph <= Document.ParagraphCount) then begin
          PFrag := Document.Paragraph[Paragraph].TextWithCR
        end else begin
          PFrag := '';
          ScreenLines [Line].Paragraph := -1; // Sentinel value for "EoF"
        end;
      end;  // else we're at the last displayable line already
    end;
    inc (Line);
  until (Line > ScreenHeight);

  // Line Zero is a special case
  if ((aParagraph = 1) and (aPosition = 1)) then begin // At the top of the document
    ScreenLines [0].Paragraph := 0;
    ScreenLines [0].Position := 0;
  end else begin // Anywhere else
    if (aPosition = 1) then begin // Was Line 1 the start of a paragraph?
      Paragraph := aParagraph - 1; // If so, go to the previous one
      PFrag := Copy(Document.Paragraph[Paragraph].TextWithCR, // and get its text
        Max(1, Length(Document.Paragraph[Paragraph].TextWithCR) - ScreenWidth + 1), ScreenWidth);
      Position := length (PFrag); // And set our position at the end
    end else begin // Otherwise...
      Paragraph := aParagraph; // ...we're still in the same paragraph;
      PFrag := Copy(Document.Paragraph[Paragraph].TextWithCR, 1, aPosition - 1);
      PFrag := Copy(PFrag, Max (1, Length(PFrag) - ScreenWidth + 1), ScreenWidth);
      Position := aPosition;
    end;

    BreakAt := 1;
    for index := Min(ScreenWidth, Length(PFrag)) downto 1 do
      if PFrag[index] in [#9, #32] then
        BreakAt := index;
    PFrag := Copy (PFrag, Max (1, length(PFrag) - BreakAt + 1), BreakAt);
    DebugLog('PFrag=''' + PFrag + '''');

    ScreenLines [0].Paragraph := Paragraph;
    ScreenLines [0].Position := Position - length(PFrag) + 1;
  end;
  
  DebugLog('Line Zero:  Paragraph=' + IntToStr(ScreenLines [0].Paragraph) +
    ', Position=' + IntToStr(ScreenLines [0].Position));
  DebugLog('');
end;

procedure Repaginate (const aParagraph, aPosition : SizeInt);
begin
  Repaginate (aParagraph, aPosition, 1);
end;
}

procedure DrawStatusBar;
var
  XPos,
  YPos,
  index : integer;
  LineBuf : array of word;
  s : string;
begin
  SetLength (LineBuf, ScreenWidth);
  for index := 0 to MaxX do
    LineBuf [index] := StatusBackgroundColour + StatusTextColour;

  XPos := 0;
  s := 'Paragraph ';
  for index := 1 to length (s) do begin
    LineBuf [XPos] := LineBuf [XPos] or ord(s [index]);
    inc (XPos);
  end;
  str (Cursor.Paragraph, s);
  for index := 1 to length (s) do begin
    LineBuf [XPos] := LineBuf [XPos] or ord(s [index]);
    inc (XPos);
  end;
  s := ', Position ';
  for index := 1 to length (s) do begin
    LineBuf [XPos] := LineBuf [XPos] or ord(s [index]);
    inc (XPos);
  end;
  str (Cursor.Position, s);
  for index := 1 to length (s) do begin
    LineBuf [XPos] := LineBuf [XPos] or ord(s [index]);
    inc (XPos);
  end;
  s := 'F1 = Help, F12 = Exit';
  XPos := MaxX - (length (s) - 1);
  for index := 1 to length (s) do begin
    LineBuf [XPos] := LineBuf [XPos] or ord(s [index]);
    inc (XPos);
  end;

  // Blit the status bar
  YPos := MaxY * ScreenWidth;
  for index := 0 to MaxX do
    VideoBuf^[index + YPos] := LineBuf [index];
  SetLength (LineBuf,0);
end;

procedure DrawScreen;
var
  index,
  XPos,
  YPos : integer;
  s : string;
  Cell : word;
begin
  ClrScr;
  CursorX := -1;

  // Status Bar
  DrawStatusBar;

  // Blit the screen lines
  YPos := 0;
  for index := 0 to (MaxY - 1) do
    if Assigned (Scr.Line [TopLine + index]) then begin 
      if (Scr.Line [TopLine + index].Relative (Cursor) = 0) then begin
        CursorX := Cursor.Position - Scr.Line[TopLine + index].Start.Position;
        CursorY := index;
      end;
      s := Scr.Line[TopLine + index].Text;
      if (length (s) > 0) then
        for XPos := 0 to Min (MaxX, length (s) - 1) do begin
          Cell := BackgroundColour;
          if (s [XPos + 1] = PARAGRAPH_MARKER) then
            Cell := Cell + TextColourDim + ord('<')
          else
            Cell := Cell + TextColour + ord (s [XPos + 1]);
          VideoBuf^[XPos + YPos] := Cell;
        end;
      YPos := YPos + ScreenWidth;
    end;

  UpdateScreen (FALSE);
  if (CursorX > -1) then
    SetCursorPos (CursorX, CursorY);
end;
