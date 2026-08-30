unit gscreen;

{$mode objfpc}{$H+}{$R+}

interface

uses
  dcommon, gdoc;

type
  tLine = class
  private
    FStart          : tCursor; // Start position of this screen line
    FText           : string; // The actual contents of the line
    FParagraphBreak : boolean; // Marks a line that is just a paragraph break
  public
    property  Start            : tCursor read FStart;
    property  Text             : string read FText write FText;
    property  IsParagraphBreak : boolean read FParagraphBreak write FParagraphBreak;
    procedure SetStart         (aParagraph, aPosition : SizeInt);
    function  Relative         (Cursor: tCursor): integer;
  end;

  tScreen = class
  private
    FLines : array of tLine;
    FLineCount : SizeInt;
    FScreenWidth : SizeInt;
    function GetLine(const Index: SizeInt): tLine;
    function AddLine : integer;    
  public
    property Line [Index: SizeInt] : tLine read GetLine;
    property LineCount : SizeInt read FLineCount;
    property ScreenWidth : SizeInt read FScreenWidth write FScreenWidth;
    constructor Create (aScreenWidth, aScreenHeight : integer);
    destructor Destroy; override;
    procedure Grow;
    procedure Repaginate (aDocument : tDocument);
    procedure Repaginate (aDocument : tDocument;  aFrom : SizeInt);
  end;
  
implementation

uses
  SysUtils
{$IFDEF DEBUG}, debug{$ENDIF};

procedure tLine.SetStart (aParagraph, aPosition : SizeInt);
begin
  FStart.Paragraph := aParagraph;
  FStart.Position  := aPosition;
end;

function tLine.Relative(Cursor: tCursor): integer;
var
  EndPosition: SizeInt;
begin
  if Cursor.Paragraph < FStart.Paragraph then
    Exit(-1);

  if Cursor.Paragraph > FStart.Paragraph then
    Exit(1);

  { Same paragraph. }
  if Cursor.Position < FStart.Position then
    Exit(-1);

  EndPosition := FStart.Position + Length(FText);

  if Cursor.Position > EndPosition then
    Exit(1);

  Result := 0;
end;

constructor tScreen.Create (aScreenWidth, aScreenHeight : integer);
begin
  inherited Create;
  FScreenWidth := aScreenWidth;
  SetLength (FLines, aScreenHeight); // Assign enough lines for the terminal
  FLines [0] := tLine.Create;
  FLineCount := 1;
end;

destructor tScreen.Destroy;
var
  index : integer;
begin
  for index := 0 to (Length (FLines) - 1) do
    if (Assigned (FLines [index])) then
      FLines [index].Free;
  SetLength (FLines, 0);
  inherited Destroy;
end;

function tScreen.GetLine(const Index: SizeInt): tLine;
begin
  if (Index < 0) or (Index >= FLineCount) then
    Result := nil
  else
    Result := FLines[Index];
end;

procedure tScreen.Grow;
var
  Size : SizeInt;
begin
  Size := Length (FLines);
  if (Size = 0) then
    Size := 1;
  Size := Size * 2;
  SetLength (FLines, Size);
end;

function tScreen.AddLine : integer;
// Used to add one new line to the end of the document.
// It is intended to be called internally;  hence why it is protected.
var
  NewLine : SizeInt;
begin
  NewLine := FLineCount; // Because the array is zero-based
  if (FLineCount = length (FLines)) then
    Grow; // Make room if needed
  inc (FLineCount);
  FLines[NewLine] := tLine.Create;
  Result := NewLine;
end;

procedure tScreen.Repaginate (aDocument : tDocument);
begin
  Repaginate (aDocument, 0);
end;

procedure tScreen.Repaginate (aDocument : tDocument;  aFrom : SizeInt);
var
  index,
  LineIndex,
  BreakAt,
  cPar,
  cPos : SizeInt;
  PFrag : string;
  Para : tParagraph;
  Done : boolean;
begin
  if (aFrom = 0) then begin // Start at the top of the document
    LineIndex := 0;
    cPar := 1;
    cPos := 1
  end else begin
    if (aFrom < 0) or (aFrom >= FLineCount) then
      raise ERangeError.CreateFmt('Screen line index out of range: %d', [aFrom]);
    cPar := FLines [aFrom].Start.Paragraph;
    cPos := FLines [aFrom].Start.Position;
    LineIndex := aFrom;
  end;
  Para := aDocument.Paragraph[cPar];
  if Assigned (Para) then
  	PFrag := Para.TextWithCR
  else
  	PFrag := '';
  if (length (PFrag) > 0) then
    PFrag := Copy(PFrag, cPos, MaxInt);  
  Done := FALSE;
  
  repeat
    FLines [LineIndex].SetStart (cPar, cPos);

    BreakAt := FScreenWidth;
    for index := 1 to FScreenWidth do begin
      if (index > length (PFrag)) then begin
        BreakAt := length (PFrag);
        Break;
      end;
      if (PFrag [index] in [#9, #32]) then
        BreakAt := index;
    end;

    FLines [LineIndex].Text := copy (PFrag, 1, BreakAt);
    FLines [LineIndex].IsParagraphBreak := FALSE;
    Delete (PFrag, 1, BreakAt);
    cPos := cPos + BreakAt;

    if (length (PFrag) = 0) then begin
      inc (cPar);
      if (cPar > aDocument.ParagraphCount) then
        Done := True
      else begin
        cPos := 1;
        Para := aDocument.Paragraph[cPar];
        if (Assigned (Para)) then
          PFrag := Para.TextWithCR
        else
          PFrag := '';
      end;
      
      inc (LineIndex);
      if (LineIndex >= FLineCount) then
        AddLine;
      with (FLines [LineIndex]) do begin
        SetStart (cPar, 0);
        Text := '';
        IsParagraphBreak := TRUE;
      end;
    end;

    inc (LineIndex);    
    if (LineIndex >= FLineCount) then
      AddLine;
  until Done;
  FLineCount := LineIndex;

  repeat
    if (Assigned (FLines [LineIndex])) then
      with (FLines [LineIndex]) do begin
        SetStart (-1, -1); // Sentinel value for "EoF"
        Text := '';
      end;
    inc (LineIndex);      
  until (LineIndex >= length (FLines));
end;

end.
