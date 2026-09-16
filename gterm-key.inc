procedure GetKCommandKey;
var
  K     : TKeyEvent;
  C     : Char;
  Start : QWord;
  YPos  : Integer;
  s     : string;
begin
  YPos := MaxY * ScreenWidth;
  VideoBuf^[YPos    ] := StatusDim.TextAttr + 94; // ^
  VideoBuf^[YPos + 1] := StatusDim.TextAttr + 75; // K
  UpdateScreen(FALSE);
  
  try
    Start := GetTickCount64;
    repeat
      if KeyPressed then begin
        K := GetKeyEvent;
        K := TranslateKeyEvent(K);
        C := GetKeyEventChar(K);
        case UpCase(C) of
          'A', #1:
            begin
              s := Document.Filename;
              if (GetFilename (s)) then
                if (Document.SaveToFile(s)) then
                  Document.Filename := s;
            end;
          'B', #2:
            SetBlockStart;
          'C', #3:
          	begin
          	  BlockCopy;
              BlockInsert;
            end;
          'F', #6: 
            begin
              SearchReplace;
              Scr.Repaginate (Document, TopLine + CursorY);              
            end;
          'H', #8:
            Help;
          'K', #11:
            SetBlockEnd;
          'L', #12:
          	begin
			  LoadFile;
			  Scr.Repaginate (Document);
          	end;
          'M', #13:
            BlockMove;
          'N', #14:
          	begin
              NewFile;
              Scr.Repaginate (Document);
          	end;
          'Q', #17:
          	begin
          	  if (Document.Dirty) then
          	    ExitProgram := QueryExit
          	  else
          	  	ExitProgram := TRUE;
          	end;
          'S', #19:
          	begin
              if (Document.Filename = '') then begin
                s := Document.Filename;
                if (GetFilename (s)) then
                  if (Document.SaveToFile(s)) then
                    Document.Filename := s;
              end else
                Document.Save;
          	end;
          'X', #24:
			if (Document.Dirty) then
			  ExitProgram := Document.Save
			else
			  ExitProgram := TRUE;
		  'Y', #25:
		    BlockDelete;
        end;
        Exit;
      end;

      Sleep(10);
    until (GetTickCount64 - Start >= 1000);
  finally
    VideoBuf^[YPos    ] := Status.TextAttr + 32;
    VideoBuf^[YPos + 1] := Status.TextAttr + 32;
    UpdateScreen(FALSE);
  end;
end;

function YesOrNo : boolean;
var
  K : tKeyEvent;
  C : char;
begin
  Result := FALSE;
  repeat
    K := GetKeyEvent;
    K := TranslateKeyEvent (K);
    C := GetKeyEventChar (K);
  until (C in ['y', 'Y', 'n', 'N']);
  if (C in ['y', 'Y']) then
    Result := TRUE;
end;

function YesNoCancel : byte;
var
  K : tKeyEvent;
  C : char;
begin
  Result := yncCancel;
  repeat
    K := GetKeyEvent;
    K := TranslateKeyEvent (K);
    C := GetKeyEventChar (K);
  until (C in ['y', 'Y', 'n', 'N', 'c', 'C', #27]);
  if (C in ['y', 'Y']) then
    Result := yncYes
  else if (C in ['n', 'N']) then
  	Result := yncNo;
end;

function QueryExit : boolean;
var
  MayExit : boolean;
begin
  MayExit := TRUE;
  Result := FALSE;
  if (Document.Dirty) then begin
    DrawBottomLine ('File has unsaved changes.  Do you wish to save? <Y/N>');
    if (YesOrNo) then
      MayExit := Document.Save;
  end;
  if (MayExit) then begin
    DrawBottomLine ('Exit the program? <Y/N>');
    Result := YesOrNo
  end
end;

function SearchReplace : boolean;
var
  Replace : byte;
begin
  Result := FALSE;
  DrawBottomLine ('Search For: ');
  InputString(12, MaxX, MaxY, SearchTerm);
  if (Searchterm = '') then
    Exit;
    
  DrawBottomLine ('Replace? <Yes / No / Cancel>');
  SetCursorPos (28, MaxY);
  Replace := YesNoCancel;
  
  if (Replace = yncCancel) then
    Exit
  else if (Replace = yncYes) then begin
    ReplaceOnFind := TRUE;
    DrawBottomLine ('Replace with: ');
    InputString(14, MaxX, MaxY, ReplaceTerm);
  end else if (Replace = yncNo) then
    ReplaceOnFind := FALSE;
  FindNextMatch;
end;

function FindNextMatch : boolean;
var
  State : boolean;
begin
  Result := Document.Search (Cursor, BlockStart, BlockEnd, SearchTerm);
  if (Result = FALSE) then begin
    DrawBottomLine ('Search term not found.  Start again from top? (Y/N)');
    SetCursorPos (52, MaxY);
    State := YesOrNo;
    if (State = TRUE) then begin
      Cursor.Paragraph := 1;
      Cursor.Position := 1;
      Result := FindNextMatch
    end
  end else begin
    Scr.CentreLine (BlockStart);
    DrawScreen;
    if (ReplaceOnFind) then begin
      DrawBottomLine ('Replace? <Y/N>');
      SetCursorPos (15, MaxY);
      if YesOrNo then begin
        BlockDelete;
        Document.Insert (ReplaceTerm, Cursor);
      end;
    end;
  end;
end;

function NewFile : boolean;
var
  Permissions : byte;
begin
  Permissions := yncYes;
  Result := FALSE;
  if (Document.Dirty) then begin
    DrawBottomLine ('File has unsaved changes.  Do you wish to save? <Y/N/Cancel>');
    Permissions := YesNoCancel;
    if (Permissions = yncYes) then
      if not Document.Save then
      	Permissions := yncCancel;
  end;
  if (Permissions < yncCancel) then begin
  	Document.Free;
  	Document := tDocument.Create;
    Cursor.Paragraph := 1;
    Cursor.Position := 1;
    CursorX := 1;
    CursorY := 1;
    TopLine := 0;
    Overwrite := FALSE;
    ReplaceOnFind := FALSE;
    SearchTerm := '';
    ReplaceTerm := '';
    SetCursorType (crUnderline);
  	Result := TRUE
  end;
end;

function CursorMoveRightOne : boolean;
var
  LastLine : integer;
begin
  Result := TRUE;
  if (Cursor.Position < length (Document.Paragraph[Cursor.Paragraph].TextWithCR)) then
    inc (Cursor.Position)
  else if (Cursor.Paragraph < Document.ParagraphCount) then begin
    Cursor.Position := 1;
    inc (Cursor.Paragraph)
  end else
    Result := FALSE;

  LastLine := BottomLine;
  while (not Assigned (Scr.Line[LastLine])) do
  	dec (LastLine);
  while (Scr.Line[LastLine].Relative (Cursor) > 0) do
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
  ShiftState : byte;
  SavedX : integer;
  s : string;
begin
  K := GetKeyEvent;
  K := TranslateKeyEvent (K);

  C := GetKeyEventChar (K);
  ShiftState := GetKeyEventShiftState (K);
  if (C = #8) then begin
    if CursorMoveLeftOne then
      EditDelete;
    Scr.Repaginate (Document, TopLine + CursorY);
  end else if (C = #11) then begin
  	GetKCommandKey;
  end else if (C = #12) then begin
    if (SearchTerm = '') then 
      MessageString := 'No previous search!'
    else begin
      CursorMoveRightOne;
      FindNextMatch;
    end;
    Scr.Repaginate (Document, TopLine + CursorY);
  end else if (C = #13) then begin
    if Document.ParagraphBreak(Cursor) then
      Scr.Repaginate(Document, TopLine + CursorY);
  end else if (C in [' '..'~']) then begin
    if (Overwrite) then
      Document.Overwrite (C, Cursor)
    else
      Document.Insert (C, Cursor);
    Scr.Repaginate (Document, TopLine + CursorY);
  end;
  
  case GetKeyEventCode (K) of
  	kbdF1: Help;
    // Alt+F2 for Save As, because it can be emulated with Esc+F2.
    kbdF2: begin
      if ((ShiftState and kbAlt) > 0) or (Document.Filename = '') then begin
        s := Document.Filename;
        if (GetFilename (s)) then
          if (Document.SaveToFile(s)) then
            Document.Filename := s;
      end else
        Document.Save;
      end;
    KbdF3: begin
	    LoadFile;
	    Scr.Repaginate (Document);
      end;
    KbdF4: begin
      	NewFile;
      	Scr.Repaginate (Document);
      end;
    kbdF12:
      ExitProgram := QueryExit;
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
    kbdInsert:
      begin
        Overwrite := not Overwrite;
        if Overwrite then
          SetCursorType (crBlock)
        else
          SetCursorType (crUnderline);
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


