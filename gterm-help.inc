function Help : boolean;
type
  HelpEntry = record
    Key,
    Text : string;
  end;
var
  R : tRect;
  K : tKeyEvent;
  index : integer;
  Page : byte;
  Entry : array [5..12] of HelpEntry;
begin
  R.A.X := 2;
  R.B.X := MaxX - 2;
  R.A.Y := 1;
  R.B.Y := 16;
  Page := 0;
  repeat
    for index := Low(Entry) to High(Entry) do begin
      Entry[index].Key := '';
      Entry[index].Text := '';
    end;
  case Page of
      0 : begin
            Entry [ 5].Key  := Choice (TerminalMode = 0, 'F1', 'Ctrl+K,H');
            Entry [ 5].Text := 'Help (this screen!)';
            Entry [ 6].Key  := Choice (TerminalMode = 0, 'F2', 'Ctrl+K,S');
            Entry [ 6].Text := 'Save (with same file name)';
            Entry [ 7].Key  := Choice (TerminalMode = 0, AltKBText + 'F2', 'Ctrl+K,A');
            Entry [ 7].Text := 'Save As (with new file name)';
            Entry [ 8].Key  := Choice (TerminalMode = 0, 'F3', 'Ctrl+K,L');
            Entry [ 8].Text := 'Load File';
            Entry [ 9].Key  := Choice (TerminalMode = 0, 'F4', 'Ctrl+K,N');
            Entry [ 9].Text := 'New File';
            if (TerminalMode = 0) then begin
              Entry [10].Key  := 'F12';
              Entry [10].Text := 'Exit FicWrite';
              Entry [11].Key := '';
              Entry [12].Key := '';
            end else begin
              Entry [10].Key  := 'Ctrl+K,X';
              Entry [10].Text := 'Exit FicWrite (no confirmation)';
              Entry [11].Key  := 'Ctrl+K,H';
              Entry [11].Text := 'Save and Exit FicWrite (no confirmation)';
              Entry [12].Key := '';
            end;
          end;
      1 : begin
            Entry [ 5].Key  := 'Ctrl+K,B';
            Entry [ 5].Text := 'Mark the start of the block';
            Entry [ 6].Key  := 'Ctrl+K,K';
            Entry [ 6].Text := 'Mark the end of the block';
            Entry [ 7].Key  := 'Ctrl+K,C';
            Entry [ 7].Text := 'Copy the marked block starting at the cursor';
            Entry [ 8].Key  := 'Ctrl+K,M';
            Entry [ 8].Text := 'Move the marked block to the cursor';
            Entry [ 9].Key  := 'Ctrl+K,Y';
            Entry [ 9].Text := 'Delete the marked block';
            Entry [10].Key  := 'Ctrl+K,F';
            Entry [10].Text := 'Search and/or Replace from cursor';
            Entry [11].Key  := 'Ctrl+L';
            Entry [11].Text := 'Find Next';
            Entry [12].Key  := '';
          end;
    end;

    for index := 5 to 12 do
      if (Entry [index].Key <> '') then
        while (length (Entry [index].Key) < 8) do
          Entry [index].Key := Entry [index].Key + ' ';
          
    DrawBox (R);
    PutString(5,3, #2 + 'FicWrite' + #3 + ' ' + version + ' (C) 2026 Timothy Groves');

    for index := 5 to 12 do 
      if (Entry [index].Key <> '') then
        PutString (5, index, #2 + Entry [index].Key + #3 + '  ' + Entry [index].Text);
    
    PutString(5,14,'Press ' + #2 + 'Esc' + #3 + ' to exit this screen, or arrow keys to switch pages');
    UpdateScreen(FALSE);
  
  	K := GetKeyEvent;
  	K := TranslateKeyEvent(K);
  	if (GetKeyEventCode(K) = kbdLeft) then
  	 Page := 0
  	else if (GetKeyEventCode(K) = kbdRight) then
  	 Page := 1;
  until (GetKeyEventChar(K) = #27);
  Result := TRUE
end;

