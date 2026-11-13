procedure PutCharAt (const YPos, X : integer; C : cardinal);
begin
  VideoBuf^[YPos + X] := C;
end;

procedure PutChar (X, Y : integer; C : cardinal);
begin
  PutCharAt(Y * ScreenWidth, X, C);
end;

procedure PutString (X, Y : integer; s : string);
var
  X1,
  YPos : integer;
  index : integer;
  Highlight : boolean = FALSE;
  Attribute : cardinal;
  c : byte;
begin
  YPos := Y * ScreenWidth;
  X1 := X;
  for index := 0 to (length (s) - 1) do begin    
    c := ord (s [index + 1]);
    if (c = 1) then
      Highlight := not Highlight
    else if (c = 2) then
      Highlight := TRUE
    else if (c = 3) then
      Highlight := FALSE;
    if (c in [32..126]) then begin
      if (Highlight) then
        Attribute := MenuHighlight.TextAttr + c
      else
        Attribute := Menu.TextAttr + c;
      VideoBuf^[YPos + X1] := Attribute;
      inc (X1)
    end;
  end;
end;

function DrawBox(const Box : tRect) : boolean;
var
  Left,
  Right,
  Top,
  Bottom,
  X,
  Y,
  YPos : integer;
  Attribute : Cardinal;
begin
  Attribute := Menu.TextAttr;
  // Standardize coordinates so Left <= Right and Top <= Bottom
  if Box.A.X <= Box.B.X then begin
    Left := Box.A.X;
    Right := Box.B.X;
  end else begin
    Left := Box.B.X;
    Right := Box.A.X;
  end;

  if Box.A.Y <= Box.B.Y then begin
    Top := Box.A.Y;
    Bottom := Box.B.Y;
  end else begin
    Top := Box.B.Y;
    Bottom := Box.A.Y;
  end;

  // Verify valid dimensions for a 7-bit ASCII box (at least 2x2 to fit corners)
  if (Right - Left < 1) or (Bottom - Top < 1) then begin
    DrawBox := false;
    Exit;
  end;

  // Draw a blank box
  for Y := Top to Bottom do begin
    YPos := Y * ScreenWidth;
    for X := Left to Right do
      PutCharAt (YPos, X, Attribute + 32);
  end;
  
  Attribute := Border.TextAttr; 
  // 1. Draw Corners
  PutChar(Left,  Top,    Attribute + 46);
  PutChar(Right, Top,    Attribute + 46);
  PutChar(Left,  Bottom, Attribute + 39);
  PutChar(Right, Bottom, Attribute + 39);

  // 2. Draw Top and Bottom Horizontal Edges
  for X := Left + 1 to Right - 1 do
  begin
    PutChar(X, Top,    Attribute + 61);
    PutChar(X, Bottom, Attribute + 61);
  end;

  // 3. Draw Left and Right Vertical Edges
  for Y := Top + 1 to Bottom - 1 do
  begin
    PutChar(Left,  Y, Attribute + 124);
    PutChar(Right, Y, Attribute + 124);
  end;

  DrawBox := true;
end;

function SelectionBox(const Items: array of string; const Box: tRect; var Index: SizeInt): Boolean;
var
  YStart    : integer;
  Row       : SizeInt;
  ItemIndex : SizeInt;
  ViewPort  : SizeInt;
  Visible   : SizeInt;
  RowWidth  : SizeInt;
  K         : tKeyEvent;
  C         : char;
  Done      : Boolean;
  s         : string;
begin
  YStart := min (Box.A.Y, Box.B.Y) + 1;
  if (Box.B.Y - Box.A.Y + 1 < 7) then
    raise ERangeError.Create('SelectionBox requires at least 7 rows');

  { Four rows of furniture leave this many rows for selections. }
  Visible := (Box.B.Y - Box.A.Y + 1) - 4;
  ViewPort := 0;
  RowWidth := (Box.B.X - Box.A.X) - 4;
  
  DrawBox (Box);
  repeat
    for Row := 0 to Visible - 1 do begin
      ItemIndex := ViewPort + Row;
      if ItemIndex >= Length(Items) then
        Break;
      s := ' ' + copy (Items[ItemIndex], 1, RowWidth);
      while (length (s) <= RowWidth) do
        s := s + ' ';      
      PutString(Box.A.X + 1, YStart + Row, s);
    end;
    for Row := 1 to RowWidth + 2 do
      PutChar (Box.A.X + Row, Box.B.Y - 2, MenuHighlight.TextAttr + 45);
    PutString (Box.A.X + 2, Box.B.Y - 1, #2 + 'Enter' + #3 + ' = Select, ' + #2 + 'Esc' + #3 + ' = Cancel');
    PutChar (Box.A.X + 1, YStart + Index - ViewPort, Normal.TextAttr + 62);
    SetCursorPos (Box.A.X + 1, YStart + Index - ViewPort);
    UpdateScreen(FALSE);
  
    K := GetKeyEvent;
    K := TranslateKeyEvent(K);
    C := GetKeyEventChar(K);

    if (C = #13) then begin
      Result := TRUE;
      Done := TRUE;
    end else if (C = #27) then begin
      Result := FALSE;
      Done := TRUE;
    end else
      case GetKeyEventCode(K) of
        kbdUp:
          if (Index > 0) then begin
            Dec(Index);
            if (Index < ViewPort) then
              ViewPort := Index;
          end;
        kbdDown:
          if (Index < Length(Items) - 1) then begin
            Inc(Index);
            if (Index >= ViewPort + Visible) then
              ViewPort := Index - Visible + 1;
          end;
        kbdPgUp:
          if (Index > 0) then begin
            Index := max (0, Index - Visible);
            if (Index < ViewPort) then
              ViewPort := Index;
          end;
        kbdPgDn:
          if (Index < Length(Items) - 1) then begin
            Index := min (Length (Items) - 1, Index + Visible);
            if (Index >= ViewPort + Visible) then
              ViewPort := Index - Visible + 1;
          end;
      end;
  until Done;
end;

procedure ClrScr;
var
  index,
  Limit : integer;
begin
  Limit := (ScreenWidth * ScreenHeight) - 1;
  for index := 0 to Limit do
    VideoBuf^[index] := Normal.TextAttr + 32;
end;

procedure DrawBottomLine (Text : string);
var
  XPos,
  YPos,
  index : integer;
  LineBuf : array of word;
begin
  SetLength (LineBuf, ScreenWidth);
  for index := 0 to MaxX do
    LineBuf [index] := Status.TextAttr + 32;

  XPos := 0;
  for index := 1 to length (Text) do begin
    LineBuf [XPos] := Status.TextAttr +  ord(Text [index]);
    inc (XPos);
  end;

  // Blit the status bar
  YPos := MaxY * ScreenWidth;
  for index := 0 to MaxX do
    VideoBuf^[index + YPos] := LineBuf [index];
  SetLength (LineBuf,0);
  UpdateScreen(FALSE);
end;

function InputString(X1, X2, Y: Integer; var S: string): Boolean;
var
  K          : TKeyEvent;
  C          : char;
  DX         : integer;
  X          : integer;
  Extent     : integer;
  Viewport   : integer;
  Position   : integer;
  Done       : boolean;
  InsertMode : boolean;
begin
  Result := FALSE;
  InsertMode := TRUE;
  Extent := (X2 - X1) - 1;
  if ((length (s) + 1) > Extent) then
    Viewport := (length (s) + 1) - Extent
  else
    Viewport := 1;
  Position := Length(S) + 1;
  X := X1 + Position - Viewport + 1;
  Done := FALSE;

  repeat
    SetCursorPos (X, Y);
    for DX := X1 + 1 to X2 - 1 do
      if (DX - X1 + Viewport - 1 <= Length(s)) then
        VideoBuf^[Y * ScreenWidth + DX] := Status.TextAttr + ord(s[DX - X1 + Viewport - 1])
      else
        VideoBuf^[Y * ScreenWidth + DX] := Status.TextAttr + 32;
    if (ViewPort > 1) then
      VideoBuf^[Y * ScreenWidth + X1] := StatusDim.TextAttr + 60 // <
    else
      VideoBuf^[Y * ScreenWidth + X1] := StatusDim.TextAttr + 32;
    if (Length(s) > Viewport + Extent - 1) then
      VideoBuf^[Y * ScreenWidth + X2] := StatusDim.TextAttr + 62 // >
    else
      VideoBuf^[Y * ScreenWidth + X2] := STatusDim.TextAttr + 32;
    UpdateScreen(FALSE);

    K := GetKeyEvent;
    K := TranslateKeyEvent(K);
    C := GetKeyEventChar(K);

    if C in [#32..#126] then begin
      if InsertMode then begin
        Insert(C, S, Position);
        Inc(Position);
      end else begin
        if Position <= Length(S) then
          S[Position] := C
        else
          S := S + C;
        Inc(Position);
      end;
    end else if (C = #8) then begin
      if Position > 1 then begin
        Dec(Position);
        Delete(S, Position, 1);
      end
    end else if (C = #13) then begin
      Result := TRUE;
      Done := TRUE;
    end else if (C = #27) then
      Done := TRUE      
    else case GetKeyEventCode(K) of
      kbdInsert:
        begin
          InsertMode := not InsertMode;
          if InsertMode then
            SetCursorType (crUnderline)
          else
            SetCursorType (crBlock);
        end;
      kbdLeft:
        if Position > 1 then
          Dec(Position);
      kbdRight:
        if Position <= Length(S) then
          Inc(Position);
    end;

    { position cursor and viewport }
    X := X1 + Position - Viewport + 1;
    { Cursor has moved left of the viewport. }
    if (X <= X1) then begin
      DX := X1 - X;
      Viewport := Viewport - DX;
      X := X + DX;
    end

    { Cursor has moved right of the viewport. }
    else if (X >= X2) then begin
      DX := X - X2;
      Viewport := Viewport + DX;
      X := X - DX;
    end;

  until Done;
end;

function GetFilename (var aFilename: string) : boolean;
begin
  Result := FALSE;
  DrawBottomLine ('Filename: ');
  Result := InputString(10, MaxX, MaxY, aFilename)
end;

function LoadFile : boolean;
var
  MayLoad : boolean;
  Selected : boolean;
  RepeatOnDirectory : boolean;
  FileList : tDirArray;
  FileNames : tStringArray;
  Path : string;
  index : SizeInt;
  Rect : tRect;
begin
  MayLoad := TRUE;
  Result := FALSE;
  if (Document.Dirty) then begin
    DrawBottomLine ('File has unsaved changes.  Do you wish to save? <Y/N>');
    UpdateScreen (FALSE);
    if (YesOrNo) then
      MayLoad := Document.Save;
  end;
  
  if (MayLoad) then begin
    Rect.A.X := 0;
    Rect.A.Y := 0;
    Rect.B.X := MaxX;
    Rect.B.Y := MaxY;    
    Path := GetCurrentDir;
    repeat
      index := 0;
      Selected := FALSE;
      RepeatOnDirectory := FALSE;
      ReadDirectoryContents (Path, FileList);
      SortDirectory (FileList);
      TranslateDirectoryContents (FileList, FileNames);
      Selected := SelectionBox(FileNames, Rect, index);
      if Selected then begin
        Path := ExpandFileName (Path + DirectorySeparator + FileList[index].Filename);
        if (FileList [index].Directory) then 
          RepeatOnDirectory := TRUE;
      end;
    until RepeatOnDirectory = FALSE;
    
    if Selected and (FileExists(Path)) then
      Result := Document.LoadFromFile(Path);
  end;
end;

procedure DrawStatusBar;
var
  XPos,
  YPos,
  index : integer;
  LineBuf : array of word;
  s : string;
begin
  if (MessageString <> '') then begin
    DrawBottomLine (MessageString);
    MessageString := ''
  end else begin
    SetLength (LineBuf, ScreenWidth);
    for index := 0 to MaxX do
      LineBuf [index] := Status.TextAttr;

    XPos := 0;
    s := '   Paragraph ';
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
    if Overwrite then
      s := '  [Overwrite]'
    else
      s := '  [ Insert  ]';
    for index := 1 to length (s) do begin
      LineBuf [XPos] := LineBuf [XPos] or ord(s [index]);
      inc (XPos);
    end;
    if (Document.Dirty) then begin
      s := '  <Changed>';
      for index := 1 to length (s) do begin
        LineBuf [XPos] := LineBuf [XPos] or ord(s [index]);
        inc (XPos);
      end;
    end;

    case TerminalMode of
      0 : s := 'F1 = Help, F12 = Exit';
      1 : s := '^KH = Help, ^KX = Exit';
    end;
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
  end
end;

procedure DrawScreen;
var
  index,
  XPos,
  YPos : integer;
  s : string;
  Cell : word;
  BackCursor : tCursor;
  ThisLine : tLine;
begin
  ClrScr;
  CursorX := -1;

  // Status Bar
  DrawStatusBar;

  // Blit the screen lines
  YPos := 0;
  for index := 0 to (MaxY - 1) do
    if Assigned (Scr.Line [TopLine + index]) then begin 
      ThisLine := Scr.Line [TopLine + index];
      BackCursor.Paragraph := ThisLine.Start.Paragraph;
      if (Scr.Line [TopLine + index].Relative (Cursor) = 0) then begin
        CursorX := Cursor.Position - Scr.Line[TopLine + index].Start.Position;
        CursorY := index;
      end;
      s := Scr.Line[TopLine + index].Text;
      if (length (s) > 0) then
        for XPos := 0 to Min (MaxX, length (s) - 1) do begin
          BackCursor.Position := ThisLine.Start.Position + XPos;
          If InBlock (BackCursor) then
            if (s [XPos + 1] = PARAGRAPH_MARKER) then
              Cell := BlockDim.TextAttr + ord('<')
            else
              Cell := Block.TextAttr + ord (s [XPos + 1])
          else
            if (s [XPos + 1] = PARAGRAPH_MARKER) then
              Cell := Dim.TextAttr + ord('<')
            else
              Cell := Normal.TextAttr + ord (s [XPos + 1]);
          VideoBuf^[XPos + YPos] := Cell;
        end;
      YPos := YPos + ScreenWidth;
    end;

  UpdateScreen (FALSE);
  if (CursorX > -1) then
    SetCursorPos (CursorX, CursorY);
end;

