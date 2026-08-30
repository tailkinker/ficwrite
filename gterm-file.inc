procedure ReadDirectoryContents(const Path: string; out Entries: tDirArray);
var
  SearchRec: TSearchRec;
  SearchPath, EntryName: string;
  Count: Integer;
begin
  Entries := nil;
  Count := 0;

  // Ensure path ends with a directory delimiter
  SearchPath := IncludeTrailingPathDelimiter(Path) + '*';

  if FindFirst(SearchPath, faAnyFile, SearchRec) = 0 then begin
    try
      repeat
        EntryName := SearchRec.Name;

        if (EntryName <> '.') then begin
          // Append entry to dynamic array
          SetLength(Entries, Count + 1);
          Entries[Count].Filename := EntryName;
          Entries[Count].Directory := ((SearchRec.Attr and faDirectory) <> 0);        
          Inc(Count);
        end
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;


function CompareDirEntries(const A, B: tDirEntry): Integer;
var
  AType, BType: Integer;
begin
  { Parent directory always comes first. }
  if A.Filename = '..' then begin
    if B.Filename = '..' then
      Result := 0
    else
      Result := -1;
    Exit;
  end;

  if B.Filename = '..' then begin
    Result := 1;
    Exit;
  end;

  { Directories before files. }
  if A.Directory then
    AType := 0
  else
    AType := 1;

  if B.Directory then
    BType := 0
  else
    BType := 1;

  if AType <> BType then begin
    Result := AType - BType;
    Exit;
  end;

  { Same type: alphabetical order. }
  Result := CompareText(A.Filename, B.Filename);
end;


procedure SortDirectory(var Entries: tDirArray);
var
  i, j: Integer;
  Temp: tDirEntry;
begin
  for i := High(Entries) downto 1 do
    for j := 0 to i - 1 do
      if CompareDirEntries(Entries[j], Entries[j + 1]) > 0 then begin
        Temp := Entries[j];
        Entries[j] := Entries[j + 1];
        Entries[j + 1] := Temp;
      end;
end;


procedure TranslateDirectoryContents(const Entries : tDirArray; out Lines: tStringArray);
var
  index : integer;
begin
  SetLength (Lines, length (Entries));
  for index := 0 to length (Entries) - 1 do begin
    if (Entries [index].Filename = '..') then
      Lines [index] := #2 + '.. <parent>'
    else if (Entries [index].Directory) then
      Lines [index] := #2 + Entries [index].Filename + '/'
    else
      Lines [index] := #3 + Entries [index].Filename;
  end
end;