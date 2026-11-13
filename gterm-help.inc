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
  Entry : array [4..10] of HelpEntry;
const
  MAX_PAGE = 2;
begin
  R.A.X := 0;
  R.B.X := MaxX;
  R.A.Y := 0;
  R.B.Y := 14;
  Page := 0;
  repeat
    for index := Low(Entry) to High(Entry) do begin
      Entry[index].Key := '';
      Entry[index].Text := '';
    end;
  case Page of
      0 : begin
            Entry [ 4].Key  := Choice (TerminalMode = 0, 'F1', 'Ctrl+K,H');
            Entry [ 4].Text := 'Help (this screen!)';
            Entry [ 5].Key  := Choice (TerminalMode = 0, 'F2', 'Ctrl+K,S');
            Entry [ 5].Text := 'Save (with same file name)';
            Entry [ 6].Key  := Choice (TerminalMode = 0, AltKBText + 'F2', 'Ctrl+K,A');
            Entry [ 6].Text := 'Save As (with new file name)';
            Entry [ 7].Key  := Choice (TerminalMode = 0, 'F3', 'Ctrl+K,L');
            Entry [ 7].Text := 'Load File';
            Entry [ 8].Key  := Choice (TerminalMode = 0, 'F4', 'Ctrl+K,N');
            Entry [ 8].Text := 'New File';
            if (TerminalMode = 0) then begin
              Entry [ 9].Key  := 'F12';
              Entry [ 9].Text := 'Exit FicWrite';
              Entry [10].Key := '';
            end else begin
              Entry [ 9].Key  := 'Ctrl+K,Q';
              Entry [ 9].Text := 'Exit FicWrite (no confirmation)';
              Entry [10].Key  := 'Ctrl+K,X';
              Entry [10].Text := 'Save and Exit FicWrite (no confirmation)';
            end;
          end;
      1 : begin
            Entry [ 4].Key  := 'Ctrl+K,B';
            Entry [ 4].Text := 'Mark the start of the block';
            Entry [ 5].Key  := 'Ctrl+K,K';
            Entry [ 5].Text := 'Mark the end of the block';
            Entry [ 6].Key  := 'Ctrl+K,C';
            Entry [ 6].Text := 'Copy the marked block starting at the cursor';
            Entry [ 7].Key  := 'Ctrl+K,M';
            Entry [ 7].Text := 'Move the marked block to the cursor';
            Entry [ 8].Key  := 'Ctrl+K,Y';
            Entry [ 8].Text := 'Delete the marked block';
            Entry [ 9].Key  := 'Ctrl+K,F';
            Entry [ 9].Text := 'Search and/or Replace from cursor';
            Entry [10].Key  := 'Ctrl+L';
            Entry [10].Text := 'Find Next';
          end;
      2 : begin
            Entry [ 4].Key  := 'Ctrl+T,C';
            Entry [ 4].Text := 'Change the console mode';
            Entry [ 5].Key  := 'Ctrl+T,T';
            Entry [ 5].Text := 'Change the Theme';
            Entry [ 6].Key  := '';
            Entry [ 7].Key  := '';
            Entry [ 8].Key  := '';
            Entry [ 9].Key  := '';
            Entry [10].Key  := '';
          end;
    end;

    for index := 4 to 10 do
      if (Entry [index].Key <> '') then
        while (length (Entry [index].Key) < 8) do
          Entry [index].Key := Entry [index].Key + ' ';
          
    DrawBox (R);
    PutString(5, 2, #2 + 'FicWrite' + #3 + ' ' + version + ' (C) 2026 Timothy Groves');

    for index := 4 to 10 do 
      if (Entry [index].Key <> '') then
        PutString (5, index, #2 + Entry [index].Key + #3 + '  ' + Entry [index].Text);
    
    PutString(5, 12,'Press ' + #2 + 'Esc' + #3 + ' to exit this screen, or arrow keys to switch pages');
    UpdateScreen(FALSE);
  
  	K := GetKeyEvent;
  	K := TranslateKeyEvent(K);
  	if (GetKeyEventCode(K) = kbdLeft) then
  	 Page := Max (0, Page - 1)
  	else if (GetKeyEventCode(K) = kbdRight) then
  	 Page := Min (MAX_PAGE, Page + 1);
  until (GetKeyEventChar(K) = #27);
  Result := TRUE
end;

